<#
.SYNOPSIS
    Comprehensive logging module for HMG RBCMS framework.

.DESCRIPTION
    Provides enterprise-grade logging functionality with:
    - Timestamped log entries (millisecond precision)
    - Multiple log levels (Debug, Info, Success, Warning, Error, Critical)
    - Multiple output targets (Console, File, Structured)
    - Buffered writes for performance
    - Context tracking (component, step, role)
    - WhatIf mode support
    - Log statistics and metrics
    - Section-based logging for readability

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 1.0.1
    Requires: PowerShell 5.1 or higher
    
    CHANGELOG:
    v1.0.1 - Fixed critical bug: Added explicit [switch]$WhatIf parameter to Initialize-HMGLog
             Previously caused initialization to fail with "variable '$WhatIf' cannot be retrieved"
             This was preventing ALL file logging from working

    Log Entry Format:
    2025-10-27 14:32:45.123 [INFO] [HMG.POS:Install-Chrome] Starting Chrome installation

    Log Levels:
    - DEBUG: Detailed diagnostic information
    - INFO: General informational messages
    - SUCCESS: Successful operation completion
    - WARNING: Warning messages that don't stop execution
    - ERROR: Error messages (operation failed but script continues)
    - CRITICAL: Critical errors (operation failed and script should stop)
#>

#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"  # Allow logging to continue even if errors occur

#region Module State

# Script-level variables for logging state
$script:LogConfig = @{
  Initialized       = $false
  LogFile           = $null
  LogLevel          = 'INFO'
  ConsoleEnabled    = $true
  FileEnabled       = $true
  StructuredEnabled = $false
  StructuredFile    = $null
  StructuredFormat  = 'JSON'  # JSON or CSV
  BufferSize        = 1       # Write immediately (was 10)
  Buffer            = [System.Collections.Generic.List[string]]::new()
  WhatIfMode        = $false
  Context           = @{
    Role      = $null
    Component = $null
    Step      = $null
  }
  Statistics        = @{
    Debug    = 0
    Info     = 0
    Success  = 0
    Warning  = 0
    Error    = 0
    Critical = 0
    Total    = 0
  }
  SectionStack      = [System.Collections.Generic.Stack[PSCustomObject]]::new()
  StartTime         = $null
}

# Log level numeric values (for comparison)
$script:LogLevels = @{
  DEBUG    = 0
  INFO     = 1
  SUCCESS  = 2
  WARNING  = 3
  ERROR    = 4
  CRITICAL = 5
}

# Log level colors for console output
$script:LogColors = @{
  DEBUG    = 'DarkGray'
  INFO     = 'Cyan'
  SUCCESS  = 'Green'
  WARNING  = 'Yellow'
  ERROR    = 'Red'
  CRITICAL = 'Magenta'
}

#endregion Module State

#region Core Logging Functions

<#
.SYNOPSIS
    Initializes the HMG logging system.

.DESCRIPTION
    Sets up logging configuration including file paths, log levels, and output targets.
    Must be called before using other logging functions.

.PARAMETER LogPath
    Full path to the log file. If not specified, uses default location based on settings.

.PARAMETER LogLevel
    Minimum log level to record (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL).
    Default: INFO

.PARAMETER ConsoleEnabled
    Enable/disable console output. Default: $true

.PARAMETER FileEnabled
    Enable/disable file logging. Default: $true

.PARAMETER StructuredLogging
    Enable structured logging (JSON/CSV). Default: $false

.PARAMETER StructuredFormat
    Format for structured logs (JSON or CSV). Default: JSON

.PARAMETER BufferSize
    Number of log entries to buffer before writing to disk. Default: 1 (immediate write)

.PARAMETER WhatIf
    Enable WhatIf mode (logs actions without executing). Default: $false

.PARAMETER Role
    Current system role (POS, MGR, CAM, STAFF) for context tracking

.PARAMETER Component
    Component name for context tracking (e.g., 'HMG.POS', 'HMG.Baseline')

.EXAMPLE
    Initialize-HMGLog -LogPath "C:\bin\HMG\logs\setup-POS.log" -Role 'POS' -LogLevel 'DEBUG'

.EXAMPLE
    Initialize-HMGLog -Role 'MGR' -StructuredLogging -StructuredFormat 'JSON'
#>
function Initialize-HMGLog {
  [CmdletBinding()]
  param(
    [string]$LogPath,
    [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
    [string]$LogLevel = 'INFO',
    [bool]$ConsoleEnabled = $true,
    [bool]$FileEnabled = $true,
    [switch]$StructuredLogging,
    [ValidateSet('JSON', 'CSV')]
    [string]$StructuredFormat = 'JSON',
    [int]$BufferSize = 1,  # Default to immediate write (was 10)
    [switch]$WhatIf,
    [string]$Role,
    [string]$Component
  )

  try {
    # Determine log file path
    if (-not $LogPath) {
      # Try to get from global settings
      if ($global:Settings -and $global:Settings.LogsPath) {
        $logsDir = $global:Settings.LogsPath
      }
      else {
        $logsDir = "C:\bin\HMG\logs"
      }

      # Ensure directory exists
      if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
      }

      # Use role if available
      $roleStr = if ($Role) { "-$Role" } else { "" }
      $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
      $LogPath = Join-Path $logsDir "setup$roleStr-$timestamp.log"
    }

    # Update configuration
    $script:LogConfig.LogFile = $LogPath
    $script:LogConfig.LogLevel = $LogLevel.ToUpper()
    $script:LogConfig.ConsoleEnabled = $ConsoleEnabled
    $script:LogConfig.FileEnabled = $FileEnabled
    $script:LogConfig.StructuredEnabled = $StructuredLogging.IsPresent
    $script:LogConfig.StructuredFormat = $StructuredFormat
    $script:LogConfig.BufferSize = $BufferSize
    $script:LogConfig.WhatIfMode = $WhatIf.IsPresent
    $script:LogConfig.StartTime = Get-Date
    $script:LogConfig.Initialized = $true

    # Set context
    if ($Role) {
      $script:LogConfig.Context.Role = $Role
    }
    if ($Component) {
      $script:LogConfig.Context.Component = $Component
    }

    # Create log file with header
    if ($FileEnabled) {
      $header = @"
================================================================================
HMG RBCMS Setup Log
================================================================================
Log File: $LogPath
Started:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Role:     $($script:LogConfig.Context.Role)
Component: $($script:LogConfig.Context.Component)
Log Level: $LogLevel
Host:     $env:COMPUTERNAME
User:     $env:USERNAME
================================================================================

"@
      $header | Out-File -FilePath $LogPath -Encoding UTF8
    }

    # Set up structured log file
    if ($StructuredLogging) {
      $structuredPath = $LogPath -replace '\.log$', ".$($StructuredFormat.ToLower())"
      $script:LogConfig.StructuredFile = $structuredPath

      if ($StructuredFormat -eq 'CSV') {
        # CSV header
        "Timestamp,Level,Component,Step,Message" | Out-File -FilePath $structuredPath -Encoding UTF8
      }
      elseif ($StructuredFormat -eq 'JSON') {
        # JSON array start
        "[" | Out-File -FilePath $structuredPath -Encoding UTF8
      }
    }

    # Log initialization
    Write-HMGLog -Message "Logging initialized - Level: $LogLevel, File: $LogPath" -Level 'INFO' -Component 'HMG.Logging'
        
    # Force immediate flush to ensure file is created
    if ($script:LogConfig.Buffer.Count -gt 0) {
      Flush-LogBuffer
    }

  }
  catch {
    Write-Warning "Failed to initialize HMG logging: $_"
    $script:LogConfig.Initialized = $false
  }
}

<#
.SYNOPSIS
    Writes a log entry with timestamp and formatting.

.DESCRIPTION
    Core logging function that handles all log output. Automatically adds timestamps,
    formats messages, applies colors, and writes to configured outputs.

.PARAMETER Message
    The log message to write

.PARAMETER Level
    Log level (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL)

.PARAMETER Component
    Component name (overrides default from context)

.PARAMETER Step
    Step name (overrides default from context)

.PARAMETER Exception
    Exception object to include in log entry

.PARAMETER NoNewline
    Don't add newline after message (for progress indicators)

.EXAMPLE
    Write-HMGLog "Starting installation" -Level INFO
    Write-HMGLog "Installation failed" -Level ERROR -Exception $_.Exception
#>
function Write-HMGLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,

    [Parameter(Position = 1)]
    [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
    [string]$Level = 'INFO',

    [string]$Component,
    [string]$Step,
    [System.Exception]$Exception,
    [switch]$NoNewline
  )

  # Skip if not initialized (but don't fail - fallback to Write-Host)
  if (-not $script:LogConfig.Initialized) {
    Write-Host $Message
    return
  }

  # Check log level threshold
  $currentLevel = $script:LogLevels[$script:LogConfig.LogLevel]
  $messageLevel = $script:LogLevels[$Level]

  if ($messageLevel -lt $currentLevel) {
    return  # Message below threshold, skip
  }

  # Update statistics
  $script:LogConfig.Statistics[$Level]++
  $script:LogConfig.Statistics.Total++

  # Build context string
  $contextParts = @()

  $comp = if ($Component) { $Component } else { $script:LogConfig.Context.Component }
  if ($comp) { $contextParts += $comp }

  $stp = if ($Step) { $Step } else { $script:LogConfig.Context.Step }
  if ($stp) { $contextParts += $stp }

  $context = if ($contextParts.Count -gt 0) {
    "[" + ($contextParts -join ':') + "]"
  }
  else {
    ""
  }

  # Format timestamp
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

  # Build log entry
  $levelPadded = $Level.PadRight(8)
  $logEntry = "$timestamp [$levelPadded] $context $Message"

  # Add exception details if provided
  if ($Exception) {
    $logEntry += "`n    Exception: $($Exception.Message)"
    if ($Exception.InnerException) {
      $logEntry += "`n    Inner: $($Exception.InnerException.Message)"
    }
    $logEntry += "`n    Stack: $($Exception.StackTrace)"
  }

  # Add WhatIf prefix if in WhatIf mode
  if ($script:LogConfig.WhatIfMode) {
    $logEntry = "[WHATIF] $logEntry"
  }

  # Console output
  if ($script:LogConfig.ConsoleEnabled) {
    $color = $script:LogColors[$Level]
    if ($NoNewline) {
      Write-Host $logEntry -ForegroundColor $color -NoNewline
    }
    else {
      Write-Host $logEntry -ForegroundColor $color
    }
  }

  # File output (buffered)
  if ($script:LogConfig.FileEnabled -and $script:LogConfig.LogFile) {
    $script:LogConfig.Buffer.Add($logEntry)

    # Flush buffer if full
    if ($script:LogConfig.Buffer.Count -ge $script:LogConfig.BufferSize) {
      Flush-LogBuffer
    }
  }

  # Structured output
  if ($script:LogConfig.StructuredEnabled -and $script:LogConfig.StructuredFile) {
    Write-StructuredEntry -Timestamp $timestamp -Level $Level -Component $comp -Step $stp -Message $Message
  }
}

<#
.SYNOPSIS
    Flushes buffered log entries to disk.

.DESCRIPTION
    Internal function that writes buffered log entries to the log file.
    Called automatically when buffer is full or when closing log.
#>
function Flush-LogBuffer {
  [CmdletBinding()]
  param()

  if ($script:LogConfig.Buffer.Count -eq 0) {
    return
  }

  try {
    $script:LogConfig.Buffer | Out-File -FilePath $script:LogConfig.LogFile -Append -Encoding UTF8
    $script:LogConfig.Buffer.Clear()
  }
  catch {
    Write-Warning "Failed to flush log buffer: $_"
  }
}

<#
.SYNOPSIS
    Writes a structured log entry (JSON or CSV).

.DESCRIPTION
    Internal function that writes structured log data for parsing/automation.
#>
function Write-StructuredEntry {
  [CmdletBinding()]
  param(
    [string]$Timestamp,
    [string]$Level,
    [string]$Component,
    [string]$Step,
    [string]$Message
  )

  try {
    $file = $script:LogConfig.StructuredFile
    $format = $script:LogConfig.StructuredFormat

    if ($format -eq 'JSON') {
      $entry = @{
        timestamp = $Timestamp
        level     = $Level
        component = $Component
        step      = $Step
        message   = $Message
        host      = $env:COMPUTERNAME
        user      = $env:USERNAME
      } | ConvertTo-Json -Compress

      # Add comma if not first entry (this is a simple approach)
      # For production, might want more sophisticated JSON array handling
      "$entry," | Out-File -FilePath $file -Append -Encoding UTF8 -NoNewline

    }
    elseif ($format -eq 'CSV') {
      $escapedMessage = $Message -replace '"', '""'
      $line = "`"$Timestamp`",`"$Level`",`"$Component`",`"$Step`",`"$escapedMessage`""
      $line | Out-File -FilePath $file -Append -Encoding UTF8
    }
  }
  catch {
    # Silently fail - don't let structured logging break main logging
  }
}

#endregion Core Logging Functions

#region Helper Functions (Level-specific)

<#
.SYNOPSIS
    Writes a DEBUG level log entry.

.PARAMETER Message
    The debug message to log

.PARAMETER Component
    Component name for context

.PARAMETER Step
    Step name for context
#>
function Write-HMGDebug {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,
    [string]$Component,
    [string]$Step
  )
  Write-HMGLog -Message $Message -Level 'DEBUG' -Component $Component -Step $Step
}

<#
.SYNOPSIS
    Writes an INFO level log entry.
#>
function Write-HMGInfo {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,
    [string]$Component,
    [string]$Step
  )
  Write-HMGLog -Message $Message -Level 'INFO' -Component $Component -Step $Step
}

<#
.SYNOPSIS
    Writes a SUCCESS level log entry.
#>
function Write-HMGSuccess {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,
    [string]$Component,
    [string]$Step
  )
  Write-HMGLog -Message $Message -Level 'SUCCESS' -Component $Component -Step $Step
}

<#
.SYNOPSIS
    Writes a WARNING level log entry.
#>
function Write-HMGWarning {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,
    [string]$Component,
    [string]$Step
  )
  Write-HMGLog -Message $Message -Level 'WARNING' -Component $Component -Step $Step
}

<#
.SYNOPSIS
    Writes an ERROR level log entry.
#>
function Write-HMGError {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,
    [string]$Component,
    [string]$Step,
    [System.Exception]$Exception
  )
  Write-HMGLog -Message $Message -Level 'ERROR' -Component $Component -Step $Step -Exception $Exception
}

<#
.SYNOPSIS
    Writes a CRITICAL level log entry.
#>
function Write-HMGCritical {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,
    [string]$Component,
    [string]$Step,
    [System.Exception]$Exception
  )
  Write-HMGLog -Message $Message -Level 'CRITICAL' -Component $Component -Step $Step -Exception $Exception
}

#endregion Helper Functions

#region Configuration Functions

<#
.SYNOPSIS
    Gets the current log file path.

.RETURNS
    Full path to current log file, or $null if logging not initialized
#>

function Get-HMGLogFile {
  [CmdletBinding()]
  param()

  return $script:LogConfig.LogFile
}

<#
.SYNOPSIS
    Gets the current log level.

.RETURNS
    Current log level (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL)
#>

function Get-HMGLogLevel {
  [CmdletBinding()]
  param()

  return $script:LogConfig.LogLevel
}

<#
.SYNOPSIS
    Sets the log level threshold.

.PARAMETER Level
    New log level (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL)

.EXAMPLE
    Set-HMGLogLevel -Level 'DEBUG'
#>
function Set-HMGLogLevel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
    [string]$Level
  )

  $oldLevel = $script:LogConfig.LogLevel
  $script:LogConfig.LogLevel = $Level.ToUpper()
  Write-HMGLog "Log level changed from $oldLevel to $Level" -Level 'INFO' -Component 'HMG.Logging'
}

#endregion Configuration Functions

#region Section Management

<#
.SYNOPSIS
    Starts a log section with visual separator.

.DESCRIPTION
    Creates a visual section in logs for grouping related operations.
    Tracks section timing and nesting.

.PARAMETER Title
    Section title

.PARAMETER Level
    Log level for section header (default: INFO)

.EXAMPLE
    Start-HMGLogSection "Installing Chrome"
    # ... operations ...
    Stop-HMGLogSection
#>
function Start-HMGLogSection {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
    [string]$Level = 'INFO'
  )

  # Get stack count safely
  $stackCount = 0
  if ($script:LogConfig.SectionStack) {
    if ($script:LogConfig.SectionStack -is [System.Collections.Generic.Stack[PSCustomObject]]) {
      $stackCount = $script:LogConfig.SectionStack.Count
    }
    elseif ($script:LogConfig.SectionStack.PSObject.Properties.Name -contains 'Count') {
      $stackCount = $script:LogConfig.SectionStack.Count
    }
  }
  
  $indent = "  " * $stackCount
  $separator = "=" * 80

  Write-HMGLog "$indent$separator" -Level $Level
  Write-HMGLog "$indent $Title" -Level $Level
  Write-HMGLog "$indent$separator" -Level $Level

  # Push section info onto stack
  $section = [PSCustomObject]@{
    Title     = $Title
    StartTime = Get-Date
    Level     = $Level
  }
  $script:LogConfig.SectionStack.Push($section)
}

<#
.SYNOPSIS
    Stops the current log section and reports elapsed time.
#>
function Stop-HMGLogSection {
  [CmdletBinding()]
  param(
    [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
    [string]$Level
  )

  # Check if SectionStack exists and has items
  if (-not $script:LogConfig.SectionStack) {
    Write-HMGWarning "Stop-HMGLogSection called but SectionStack not initialized"
    return
  }
  
  # Check Count safely
  $stackCount = 0
  if ($script:LogConfig.SectionStack -is [System.Collections.Generic.Stack[PSCustomObject]]) {
    $stackCount = $script:LogConfig.SectionStack.Count
  }
  elseif ($script:LogConfig.SectionStack.PSObject.Properties.Name -contains 'Count') {
    $stackCount = $script:LogConfig.SectionStack.Count
  }
  
  if ($stackCount -eq 0) {
    Write-HMGWarning "Stop-HMGLogSection called without matching Start-HMGLogSection"
    return
  }

  $section = $script:LogConfig.SectionStack.Pop()
  $elapsed = (Get-Date) - $section.StartTime
  $elapsedStr = "{0:mm}:{0:ss}.{0:fff}" -f $elapsed

  $useLevel = if ($Level) { $Level } else { $section.Level }
  
  # Get count after popping, safely
  $stackCountAfterPop = 0
  if ($script:LogConfig.SectionStack) {
    if ($script:LogConfig.SectionStack -is [System.Collections.Generic.Stack[PSCustomObject]]) {
      $stackCountAfterPop = $script:LogConfig.SectionStack.Count
    }
    elseif ($script:LogConfig.SectionStack.PSObject.Properties.Name -contains 'Count') {
      $stackCountAfterPop = $script:LogConfig.SectionStack.Count
    }
  }
  
  $indent = "  " * $stackCountAfterPop

  Write-HMGLog "$indent Completed: $($section.Title) (Duration: $elapsedStr)" -Level $useLevel
  Write-HMGLog "$indent$('-' * 80)" -Level $useLevel
}

<#
.SYNOPSIS
    Writes a visual separator in the log.

.PARAMETER Character
    Character to use for separator (default: -)

.PARAMETER Length
    Length of separator (default: 80)
#>
function Write-HMGLogSeparator {
  [CmdletBinding()]
  param(
    [char]$Character = '-',
    [int]$Length = 80
  )

  Write-HMGLog ($Character.ToString() * $Length) -Level 'INFO'
}

#endregion Section Management

#region Statistics and Reporting

<#
.SYNOPSIS
    Gets logging statistics for the current session.

.RETURNS
    Hashtable with log entry counts by level and elapsed time

.EXAMPLE
    $stats = Get-HMGLogStatistics
    Write-Host "Total entries: $($stats.Total)"
    Write-Host "Errors: $($stats.Error)"
#>
function Get-HMGLogStatistics {
  [CmdletBinding()]
  param()

  $elapsed = if ($script:LogConfig.StartTime) {
    (Get-Date) - $script:LogConfig.StartTime
  }
  else {
    [TimeSpan]::Zero
  }

  return @{
    Debug       = $script:LogConfig.Statistics.Debug
    Info        = $script:LogConfig.Statistics.Info
    Success     = $script:LogConfig.Statistics.Success
    Warning     = $script:LogConfig.Statistics.Warning
    Error       = $script:LogConfig.Statistics.Error
    Critical    = $script:LogConfig.Statistics.Critical
    Total       = $script:LogConfig.Statistics.Total
    ElapsedTime = $elapsed
    LogFile     = $script:LogConfig.LogFile
  }
}

#endregion Statistics and Reporting

#region Cleanup

<#
.SYNOPSIS
    Closes the logging system and flushes all buffers.

.DESCRIPTION
    Should be called at the end of script execution to ensure all log
    entries are written to disk and resources are cleaned up.

.PARAMETER ShowStatistics
    Display logging statistics before closing

.EXAMPLE
    Close-HMGLog -ShowStatistics
#>
function Close-HMGLog {
  [CmdletBinding()]
  param(
    [switch]$ShowStatistics
  )

  if (-not $script:LogConfig.Initialized) {
    return
  }

  # Close any open sections (check if SectionStack exists and has Count property)
  if ($script:LogConfig.SectionStack) {
    # Check if it's a proper Stack with Count property
    if ($script:LogConfig.SectionStack -is [System.Collections.Generic.Stack[PSCustomObject]]) {
      while ($script:LogConfig.SectionStack.Count -gt 0) {
        Stop-HMGLogSection
      }
    }
    elseif ($script:LogConfig.SectionStack.PSObject.Properties.Name -contains 'Count') {
      # Fallback for other collection types
      while ($script:LogConfig.SectionStack.Count -gt 0) {
        Stop-HMGLogSection
      }
    }
  }

  # Show statistics if requested
  if ($ShowStatistics) {
    $stats = Get-HMGLogStatistics
    Write-HMGLogSeparator
    Write-HMGLog "Logging Statistics:" -Level 'INFO'
    Write-HMGLog "  Total Entries: $($stats.Total)" -Level 'INFO'
    Write-HMGLog "  Debug:    $($stats.Debug)" -Level 'INFO'
    Write-HMGLog "  Info:     $($stats.Info)" -Level 'INFO'
    Write-HMGLog "  Success:  $($stats.Success)" -Level 'INFO'
    Write-HMGLog "  Warning:  $($stats.Warning)" -Level 'INFO'
    Write-HMGLog "  Error:    $($stats.Error)" -Level 'INFO'
    Write-HMGLog "  Critical: $($stats.Critical)" -Level 'INFO'
    Write-HMGLog "  Elapsed:  $($stats.ElapsedTime.ToString())" -Level 'INFO'
    Write-HMGLogSeparator
  }

  # Flush any remaining buffered entries
  Flush-LogBuffer

  # Close structured log file
  if ($script:LogConfig.StructuredEnabled -and $script:LogConfig.StructuredFile) {
    if ($script:LogConfig.StructuredFormat -eq 'JSON') {
      # Close JSON array (remove trailing comma and add closing bracket)
      try {
        $content = Get-Content $script:LogConfig.StructuredFile -Raw
        $content = $content.TrimEnd(',', "`r", "`n") + "`n]"
        $content | Out-File -FilePath $script:LogConfig.StructuredFile -Encoding UTF8
      }
      catch {
        # Ignore errors on cleanup
      }
    }
  }

  # Write footer
  if ($script:LogConfig.FileEnabled -and $script:LogConfig.LogFile) {
    $footer = @"

================================================================================
Log Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
================================================================================
"@
    $footer | Out-File -FilePath $script:LogConfig.LogFile -Append -Encoding UTF8
  }

  # Mark as not initialized
  $script:LogConfig.Initialized = $false
}

#endregion Cleanup

#region Structured Logging

<#
.SYNOPSIS
    Writes a structured log entry for automation/parsing.

.DESCRIPTION
    Creates a structured log entry with key-value pairs that can be easily
    parsed by automation tools or log aggregators.

.PARAMETER EventType
    Type of event being logged

.PARAMETER Data
    Hashtable of key-value pairs to include in structured log

.EXAMPLE
    Write-HMGStructuredLog -EventType "InstallComplete" -Data @{
        Application = "Chrome"
        Version = "119.0"
        Duration = "45s"
        Success = $true
    }
#>
function Write-HMGStructuredLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$EventType,

    [Parameter(Mandatory = $true)]
    [hashtable]$Data
  )

  # Add standard fields
  $Data['EventType'] = $EventType
  $Data['Timestamp'] = Get-Date -Format 'o'
  $Data['Host'] = $env:COMPUTERNAME

  # Convert to JSON and log
  $json = $Data | ConvertTo-Json -Compress
  Write-HMGLog "Structured Event: $json" -Level 'DEBUG'
}

#endregion Structured Logging

#region Module Exports

Export-ModuleMember -Function @(
  'Initialize-HMGLog',
  'Write-HMGLog',
  'Write-HMGDebug',
  'Write-HMGInfo',
  'Write-HMGSuccess',
  'Write-HMGWarning',
  'Write-HMGError',
  'Write-HMGCritical',
  'Close-HMGLog',
  'Get-HMGLogFile',
  'Get-HMGLogLevel',
  'Set-HMGLogLevel',
  'Write-HMGStructuredLog',
  'Start-HMGLogSection',
  'Stop-HMGLogSection',
  'Write-HMGLogSeparator',
  'Get-HMGLogStatistics',
  'Flush-LogBuffer'  # Export for debugging
)

#endregion Module Exports
