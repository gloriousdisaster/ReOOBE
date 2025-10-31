<#
.SYNOPSIS
    State management module for HMG automation framework - handles reboot and resume functionality.

.DESCRIPTION
    This module provides comprehensive state management for the HMG framework including:
    - Progress tracking across reboots
    - State file management (JSON-based)
    - Scheduled task creation for auto-resume
    - Reboot coordination and notification
    - Step completion tracking
    - Resume point calculation

    State files are stored in C:\bin\HMG\state\ and use JSON format for reliability.

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher
    Must be run as Administrator
#>

#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region Module Constants

# State file locations
$script:StateBasePath = "C:\bin\HMG\state"
$script:CurrentStateFile = Join-Path $script:StateBasePath "current-state.json"
$script:ProgressFile = Join-Path $script:StateBasePath "progress.json"
$script:RebootFlagFile = Join-Path $script:StateBasePath "reboot-required.flag"

# Scheduled task settings
$script:TaskName = "HMG-Resume-Setup"
$script:TaskPath = "\HMG\"
$script:TaskDescription = "Resumes HMG setup after reboot"

#endregion Module Constants

#region State Management Functions

<#
.SYNOPSIS
    Initializes the state management system.

.DESCRIPTION
    Creates necessary directories and initializes state files if they don't exist.
    Should be called at the beginning of setup.

.PARAMETER Role
    The current system role (POS, MGR, CAM, ADMIN)

.PARAMETER TotalSteps
    Total number of steps to be executed

.EXAMPLE
    Initialize-SetupState -Role 'POS' -TotalSteps 15
#>
function Initialize-SetupState {
  param(
    [Parameter(Mandatory)]
    [ValidateSet('POS', 'MGR', 'CAM', 'ADMIN')]
    [string]$Role,

    [Parameter(Mandatory)]
    [int]$TotalSteps,

    [ValidateSet('Always', 'Check', 'Never')]
    [string]$RebootMode = 'Check'
  )

  Write-Verbose "Initializing setup state for role: ${Role} with $TotalSteps total steps"

  # Create state directory if it doesn't exist
  if (-not (Test-Path $script:StateBasePath)) {
    New-Item -Path $script:StateBasePath -ItemType Directory -Force | Out-Null
    Write-Verbose "Created state directory: $script:StateBasePath"
  }

  # Check if we're resuming from a previous run
  $existingState = Get-SetupState

  if ($existingState -and $existingState.Status -eq 'InProgress') {
    Write-Host "Found existing setup state - resuming from step $($existingState.CurrentStep)" -ForegroundColor Yellow
    return $existingState
  }

  # Create new state
  $state = @{
    Role              = $Role
    StartTime         = Get-Date -Format 'o'
    Status            = 'InProgress'
    TotalSteps        = $TotalSteps
    CurrentStep       = 0
    CurrentSection    = 0
    CompletedSteps    = @()
    FailedSteps       = @()
    LastUpdateTime    = Get-Date -Format 'o'
    RebootCount       = 0
    SessionId         = [guid]::NewGuid().ToString()
    RebootMode        = $RebootMode
    RebootCheckpoints = @()
    CompletedSections = @()
  }

  # Save initial state
  Save-SetupState -State $state

  # Initialize progress file
  $progress = @{
    Role      = $Role
    StartTime = $state.StartTime
    Steps     = @()
  }

  Save-Progress -Progress $progress

  return $state
}

<#
.SYNOPSIS
    Saves the current setup state to disk.

.DESCRIPTION
    Persists the setup state to a JSON file for recovery after reboot.

.PARAMETER State
    The state object to save

.EXAMPLE
    Save-SetupState -State $currentState
#>
function Save-SetupState {
  param(
    [Parameter(Mandatory)]
    [hashtable]$State
  )

  try {
    # Update last modified time
    $State.LastUpdateTime = Get-Date -Format 'o'

    # Convert to JSON and save
    $State | ConvertTo-Json -Depth 10 | Set-Content -Path $script:CurrentStateFile -Force

    Write-Verbose "Saved setup state to: ${script:CurrentStateFile}"
  }
  catch {
    Write-Warning "Failed to save setup state: $_"
    throw
  }
}

<#
.SYNOPSIS
    Retrieves the current setup state from disk.

.DESCRIPTION
    Loads the persisted setup state from JSON file.

.RETURNS
    Hashtable containing the current state, or $null if no state exists

.EXAMPLE
    $state = Get-SetupState
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-SetupState {
  if (-not (Test-Path $script:CurrentStateFile)) {
    Write-Verbose "No state file found at: ${script:CurrentStateFile}"
    return $null
  }

  try {
    $content = Get-Content -Path $script:CurrentStateFile -Raw
    
    # Check if content is empty or whitespace
    if ([string]::IsNullOrWhiteSpace($content)) {
      Write-Warning "State file exists but is empty: ${script:CurrentStateFile}"
      return $null
    }
    
    $state = $content | ConvertFrom-Json
    
    # Check if ConvertFrom-Json returned null (invalid JSON)
    if (-not $state) {
      Write-Warning "State file contains invalid JSON: ${script:CurrentStateFile}"
      return $null
    }

    # Convert PSCustomObject back to hashtable for easier manipulation
    $hashtable = @{}
    $state.PSObject.Properties | ForEach-Object {
      $hashtable[$_.Name] = $_.Value
    }

    Write-Verbose "Loaded setup state from: ${script:CurrentStateFile}"
    return $hashtable
  }
  catch {
    Write-Warning "Failed to load setup state: $_"
    return $null
  }
}

<#
.SYNOPSIS
    Updates the state after a step completes.

.DESCRIPTION
    Records step completion (success or failure) and updates progress tracking.

.PARAMETER StepNumber
    The number of the completed step

.PARAMETER StepName
    The name of the completed step

.PARAMETER Success
    Whether the step completed successfully

.PARAMETER ErrorMessage
    Error message if the step failed

.EXAMPLE
    Update-StepProgress -StepNumber 5 -StepName "Install Chrome" -Success $true
#>
function Update-StepProgress {
  param(
    [Parameter(Mandatory)]
    [int]$StepNumber,

    [Parameter(Mandatory)]
    [string]$StepName,

    [Parameter(Mandatory)]
    [bool]$Success,

    [string]$ErrorMessage = ''
  )

  Write-Verbose "Updating progress for step ${StepNumber}: $StepName (Success: $Success)"

  # Load current state
  $state = Get-SetupState
  if (-not $state) {
    Write-Warning "No setup state found - cannot update progress"
    return
  }

  # Update current step
  $state.CurrentStep = $StepNumber

  # Record step result
  $stepResult = @{
    Number    = $StepNumber
    Name      = $StepName
    Success   = $Success
    Timestamp = Get-Date -Format 'o'
  }

  if ($Success) {
    # Ensure CompletedSteps is an array
    if (-not $state.CompletedSteps) {
      $state.CompletedSteps = @()
    }
    $state.CompletedSteps += $stepResult
  }
  else {
    # Ensure FailedSteps is an array
    if (-not $state.FailedSteps) {
      $state.FailedSteps = @()
    }
    $stepResult.ErrorMessage = $ErrorMessage
    $state.FailedSteps += $stepResult
  }

  # Save updated state
  Save-SetupState -State $state

  # Update progress file
  $progress = Get-Progress
  if ($progress) {
    $progress.Steps += $stepResult
    Save-Progress -Progress $progress
  }

  # Display progress
  $percentComplete = [Math]::Round(($StepNumber / $state.TotalSteps) * 100, 0)
  $statusText = if ($Success) { "COMPLETED" } else { "FAILED" }
  $statusColor = if ($Success) { "Green" } else { "Red" }

  Write-Host "[$percentComplete%] Step $StepNumber/$($state.TotalSteps): $statusText - $StepName" -ForegroundColor $statusColor
}

<#
.SYNOPSIS
    Marks the setup as complete and cleans up state files.

.DESCRIPTION
    Updates the state to show completion and optionally removes state files.

.PARAMETER Success
    Whether the setup completed successfully

.PARAMETER CleanupFiles
    Whether to remove state files after completion

.EXAMPLE
    Complete-Setup -Success $true -CleanupFiles $true
#>
function Complete-Setup {
  param(
    [Parameter(Mandatory)]
    [bool]$Success,

    [bool]$CleanupFiles = $false
  )

  Write-Verbose "Completing setup (Success: ${Success}, Cleanup: ${CleanupFiles})"

  # Load and update state
  $state = Get-SetupState
  if ($state) {
    $state.Status = if ($Success) { 'Completed' } else { 'Failed' }
    $state.EndTime = Get-Date -Format 'o'
    Save-SetupState -State $state
  }

  # Remove scheduled task if it exists
  Remove-ResumeTask -Silent

  # Remove reboot flag
  if (Test-Path $script:RebootFlagFile) {
    Remove-Item -Path $script:RebootFlagFile -Force
  }

  # Optionally cleanup all state files
  if ($CleanupFiles -and $Success) {
    Write-Verbose "Cleaning up state files"
    if (Test-Path $script:StateBasePath) {
      Remove-Item -Path $script:StateBasePath -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

#endregion State Management Functions

#region Progress Tracking Functions

<#
.SYNOPSIS
    Saves progress information to disk.

.PARAMETER Progress
    The progress object to save
#>
function Save-Progress {
  param(
    [Parameter(Mandatory)]
    [hashtable]$Progress
  )

  try {
    $Progress | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ProgressFile -Force
    Write-Verbose "Saved progress to: ${script:ProgressFile}"
  }
  catch {
    Write-Warning "Failed to save progress: $_"
  }
}

<#
.SYNOPSIS
    Retrieves progress information from disk.

.RETURNS
    Hashtable containing progress information, or $null if no progress exists
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-Progress {
  if (-not (Test-Path $script:ProgressFile)) {
    return $null
  }

  try {
    $content = Get-Content -Path $script:ProgressFile -Raw
    
    # Check if content is empty or whitespace
    if ([string]::IsNullOrWhiteSpace($content)) {
      Write-Warning "Progress file exists but is empty: ${script:ProgressFile}"
      return $null
    }
    
    $progress = $content | ConvertFrom-Json
    
    # Check if ConvertFrom-Json returned null (invalid JSON)
    if (-not $progress) {
      Write-Warning "Progress file contains invalid JSON: ${script:ProgressFile}"
      return $null
    }

    # Convert to hashtable
    $hashtable = @{}
    $progress.PSObject.Properties | ForEach-Object {
      $hashtable[$_.Name] = $_.Value
    }

    return $hashtable
  }
  catch {
    Write-Warning "Failed to load progress: $_"
    return $null
  }
}

<#
.SYNOPSIS
    Gets a summary of the current setup progress.

.DESCRIPTION
    Returns a formatted summary of completed, failed, and remaining steps.

.RETURNS
    PSCustomObject with progress summary

.EXAMPLE
    $summary = Get-ProgressSummary
    Write-Host "Completed: $($summary.CompletedCount)/$($summary.TotalSteps)"
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-ProgressSummary {
  $state = Get-SetupState

  if (-not $state) {
    return [PSCustomObject]@{
      Status          = 'Not Started'
      TotalSteps      = 0
      CompletedCount  = 0
      FailedCount     = 0
      RemainingCount  = 0
      PercentComplete = 0
      LastUpdate      = $null
    }
  }

  $completed = if ($state.CompletedSteps) { @($state.CompletedSteps).Count } else { 0 }
  $failed = if ($state.FailedSteps) { @($state.FailedSteps).Count } else { 0 }
  $remaining = $state.TotalSteps - $completed - $failed
  $percentComplete = if ($state.TotalSteps -gt 0) {
    [Math]::Round((($completed + $failed) / $state.TotalSteps) * 100, 0)
  } else { 0 }

  return [PSCustomObject]@{
    Status          = $state.Status
    TotalSteps      = $state.TotalSteps
    CompletedCount  = $completed
    FailedCount     = $failed
    RemainingCount  = $remaining
    PercentComplete = $percentComplete
    LastUpdate      = $state.LastUpdateTime
    CurrentStep     = $state.CurrentStep
    RebootCount     = $state.RebootCount
  }
}

#endregion Progress Tracking Functions

#region Reboot Management Functions

<#
.SYNOPSIS
    Checks if Windows requires a reboot.

.DESCRIPTION
    Examines multiple Windows registry keys and WMI to determine if a system reboot is pending.
    This is used by the 'Check' reboot mode to make intelligent reboot decisions.

.RETURNS
    Hashtable with IsRequired (boolean) and Reasons (array of strings)

.EXAMPLE
    $rebootCheck = Test-WindowsRebootRequired
    if ($rebootCheck.IsRequired) {
        Write-Host "Reboot needed: $($rebootCheck.Reasons -join ', ')"
    }
#>
function Test-WindowsRebootRequired {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()

  Write-Verbose "Checking if Windows requires reboot..."

  $reasons = @()
  $isRequired = $false

  try {
    # Check 1: Component Based Servicing (CBS)
    $cbsKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    if (Test-Path $cbsKey) {
      $reasons += 'Component Based Servicing pending'
      $isRequired = $true
    }

    # Check 2: Windows Update
    $wuKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    if (Test-Path $wuKey) {
      $reasons += 'Windows Update pending'
      $isRequired = $true
    }

    # Check 3: Pending File Rename Operations
    $pendingFileRenameKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $pendingFileRename = Get-ItemProperty -Path $pendingFileRenameKey -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($pendingFileRename -and $pendingFileRename.PendingFileRenameOperations) {
      $reasons += 'Pending file rename operations'
      $isRequired = $true
    }

    # Check 4: Pending Computer Rename
    $compNameKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName'
    $compName = Get-ItemProperty -Path $compNameKey -Name 'ComputerName' -ErrorAction SilentlyContinue
    $pendingCompNameKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'
    $pendingCompName = Get-ItemProperty -Path $pendingCompNameKey -Name 'ComputerName' -ErrorAction SilentlyContinue
    if ($compName -and $pendingCompName -and ($compName.ComputerName -ne $pendingCompName.ComputerName)) {
      $reasons += 'Computer rename pending'
      $isRequired = $true
    }

    # Check 5: Domain Join
    $netlogonKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon'
    $pendingJoin = Get-ItemProperty -Path $netlogonKey -Name 'JoinDomain' -ErrorAction SilentlyContinue
    if ($pendingJoin -and $pendingJoin.JoinDomain) {
      $reasons += 'Domain join pending'
      $isRequired = $true
    }

    # Check 6: SCCM Client (if present)
    # First check if the namespace exists to avoid "Invalid namespace" errors
    $sccmNamespaceExists = $null -ne (Get-WmiObject -Namespace 'root\ccm' -Class '__Namespace' -Filter "Name='ClientSDK'" -ErrorAction SilentlyContinue)
    
    if ($sccmNamespaceExists) {
      try {
        $sccm = Invoke-WmiMethod -Namespace 'root\ccm\clientsdk' -Class 'CCM_ClientUtilities' -Name 'DetermineIfRebootPending' -ErrorAction Stop
        if ($sccm.RebootPending -or $sccm.IsHardRebootPending) {
          $reasons += 'SCCM Client pending'
          $isRequired = $true
        }
      }
      catch {
        # SCCM namespace exists but method call failed - not critical
        Write-Verbose "SCCM reboot check failed: $_"
      }
    }
    else {
      Write-Verbose "SCCM Client not installed - skipping SCCM reboot check"
    }

    # Build result
    $result = @{
      IsRequired = $isRequired
      Reasons    = $reasons
      CheckedAt  = Get-Date -Format 'o'
    }

    if ($isRequired) {
      Write-Verbose "Windows reboot IS required. Reasons: $($reasons -join ', ')"
    }
    else {
      Write-Verbose "Windows reboot NOT required"
    }

    return $result
  }
  catch {
    Write-Warning "Error checking Windows reboot requirements: $_"
    # On error, default to assuming reboot needed (safer)
    return @{
      IsRequired = $true
      Reasons    = @('Error during check - defaulting to reboot required')
      CheckedAt  = Get-Date -Format 'o'
      Error      = $_.Exception.Message
    }
  }
}

<#
.SYNOPSIS
    Executes a reboot checkpoint based on the current RebootMode.

.DESCRIPTION
    This is the main checkpoint function that decides whether to reboot based on:
    - RebootMode: Always (always reboot), Check (reboot if Windows needs it), Never (never reboot)
    - Creates scheduled task for resume if rebooting
    - Updates state with checkpoint history

.PARAMETER CheckpointName
    Descriptive name for this checkpoint (e.g., 'After-Initial-Setup')

.PARAMETER Section
    Section number this checkpoint ends

.PARAMETER ScriptPath
    Path to the setup script for resume task

.PARAMETER Role
    Current system role

.PARAMETER NextStep
    Step number to resume from after reboot

.PARAMETER RebootMode
    Override the mode from state (optional)

.PARAMETER Settings
    Optional settings hashtable for determining username

.PARAMETER Username
    Optional username to run the task as. If not provided, determined from Settings.

.RETURNS
    $true if system is rebooting, $false if continuing without reboot

.EXAMPLE
    $rebooting = Invoke-RebootCheckpoint -CheckpointName 'After-Initial-Setup' -Section 1 -ScriptPath $PSCommandPath -Role 'POS' -NextStep 8 -Settings $Settings
    if ($rebooting) { exit 0 }
#>
function Invoke-RebootCheckpoint {
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)]
    [string]$CheckpointName,

    [Parameter(Mandatory)]
    [int]$Section,

    [Parameter(Mandatory)]
    [string]$ScriptPath,

    [Parameter(Mandatory)]
    [ValidateSet('POS', 'MGR', 'CAM', 'ADMIN')]
    [string]$Role,

    [Parameter(Mandatory)]
    [int]$NextStep,

    [ValidateSet('Always', 'Check', 'Never')]
    [string]$RebootMode,

    [hashtable]$Settings,

    [string]$Username = ''
  )

  Write-Verbose "Checkpoint '$CheckpointName' reached (Section $Section)"

  # Get current state to determine RebootMode if not provided
  $state = Get-SetupState
  if (-not $RebootMode -and $state) {
    $RebootMode = $state.RebootMode
  }
  if (-not $RebootMode) {
    $RebootMode = 'Check'  # Default fallback
  }

  Write-Verbose "RebootMode: $RebootMode"

  # Initialize checkpoint record
  $checkpoint = @{
    Name      = $CheckpointName
    Section   = $Section
    CheckedAt = Get-Date -Format 'o'
    Mode      = $RebootMode
    NextStep  = $NextStep
  }

  # Decision logic based on mode
  $shouldReboot = $false
  $windowsNeedsReboot = $false
  $windowsReasons = @()

  switch ($RebootMode) {
    'Always' {
      $shouldReboot = $true
      $checkpoint.RebootPerformed = $true
      $checkpoint.Reason = 'Always mode'
      Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
      Write-Host "║       Reboot Checkpoint: $($CheckpointName.PadRight(32))║" -ForegroundColor Yellow
      Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
      Write-Host "║ Mode:    Always                                          ║" -ForegroundColor Yellow
      Write-Host "║ Status:  Rebooting at checkpoint                        ║" -ForegroundColor Yellow
      Write-Host "║                                                          ║" -ForegroundColor Yellow
      Write-Host "║ ⚠ Always mode - rebooting regardless of requirements   ║" -ForegroundColor Yellow
      Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    }

    'Check' {
      # Check if Windows actually needs a reboot
      $rebootCheck = Test-WindowsRebootRequired
      $windowsNeedsReboot = $rebootCheck.IsRequired
      $windowsReasons = $rebootCheck.Reasons

      if ($windowsNeedsReboot) {
        $shouldReboot = $true
        $checkpoint.RebootPerformed = $true
        $checkpoint.WindowsRebootRequired = $true
        $checkpoint.Reasons = $windowsReasons

        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║       Reboot Checkpoint: $($CheckpointName.PadRight(32))║" -ForegroundColor Yellow
        Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host "║ Mode:    Check                                           ║" -ForegroundColor Yellow
        Write-Host "║ Status:  Windows requires reboot                        ║" -ForegroundColor Yellow
        Write-Host "║                                                          ║" -ForegroundColor Yellow
        Write-Host "║ Reasons:                                                 ║" -ForegroundColor Yellow
        foreach ($reason in $windowsReasons) {
          $paddedReason = "  - $reason".PadRight(56)
          Write-Host "║ $paddedReason║" -ForegroundColor Yellow
        }
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
      }
      else {
        $shouldReboot = $false
        $checkpoint.RebootPerformed = $false
        $checkpoint.WindowsRebootRequired = $false
        $checkpoint.ContinuedWithoutReboot = $true

        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║       Reboot Checkpoint: $($CheckpointName.PadRight(32))║" -ForegroundColor Green
        Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "║ Mode:    Check                                           ║" -ForegroundColor Green
        Write-Host "║ Status:  No reboot required                             ║" -ForegroundColor Green
        Write-Host "║                                                          ║" -ForegroundColor Green
        Write-Host "║ ✓ Windows does not require reboot                       ║" -ForegroundColor Green
        Write-Host "║ ✓ Continuing to next section...                         ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
      }
    }

    'Never' {
      $shouldReboot = $false
      $checkpoint.RebootPerformed = $false
      $checkpoint.Skipped = $true
      $checkpoint.Reason = 'Never mode'

      # Still check if Windows needs reboot to warn user
      $rebootCheck = Test-WindowsRebootRequired
      $windowsNeedsReboot = $rebootCheck.IsRequired
      $windowsReasons = $rebootCheck.Reasons

      Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
      Write-Host "║       Reboot Checkpoint: $($CheckpointName.PadRight(32))║" -ForegroundColor Cyan
      Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
      Write-Host "║ Mode:    Never                                           ║" -ForegroundColor Cyan
      Write-Host "║ Status:  Skipping reboot checkpoint                     ║" -ForegroundColor Cyan
      Write-Host "║                                                          ║" -ForegroundColor Cyan
      Write-Host "║ ℹ Reboot Mode 'Never' - continuing without reboot       ║" -ForegroundColor Cyan

      if ($windowsNeedsReboot) {
        Write-Host "║ ⚠ WARNING: Windows may require reboot                   ║" -ForegroundColor Yellow
        foreach ($reason in $windowsReasons) {
          $paddedReason = "  - $reason".PadRight(56)
          Write-Host "║ $paddedReason║" -ForegroundColor Yellow
        }
        $checkpoint.WindowsRebootRequired = $true
        $checkpoint.Reasons = $windowsReasons
      }
      else {
        Write-Host "║ ✓ Windows does not currently require reboot             ║" -ForegroundColor Cyan
      }

      $continueText = "║ ✓ Continuing to Section $(($Section + 1))..."
      Write-Host ($continueText.PadRight(57) + "║") -ForegroundColor Cyan
      Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    }
  }

  # Update state with checkpoint
  if ($state) {
    if (-not $state.RebootCheckpoints) {
      $state.RebootCheckpoints = @()
    }
    $state.RebootCheckpoints += $checkpoint
    $state.CurrentSection = $Section
    Save-SetupState -State $state
  }

  # If we're rebooting, create resume task
  if ($shouldReboot) {
    Write-Host "`n" -NoNewline
    Write-Host "Creating resume task for Section $(($Section + 1))..." -ForegroundColor Yellow

    # Determine username if not provided
    if (-not $Username -and $Settings) {
      $Username = Get-ResumeTaskUsername -Role $Role -Settings $Settings
    }

    # Create the scheduled task
    $taskCreated = New-ResumeTask -ScriptPath $ScriptPath -Role $Role -StartFromStep $NextStep -Username $Username

    if ($taskCreated) {
      Write-Host "✓ Resume task created successfully" -ForegroundColor Green
      Write-Host "✓ System will resume automatically after reboot" -ForegroundColor Green
      Write-Host ""

      # Initiate the reboot
      Invoke-SystemReboot -Delay 30

      return $true
    }
    else {
      Write-Warning "Failed to create resume task - reboot cancelled"
      return $false
    }
  }

  return $false
}

<#
.SYNOPSIS
    Marks that a reboot is required and optionally creates resume task.

.DESCRIPTION
    Sets the reboot flag and can create a scheduled task to resume setup after reboot.

.PARAMETER CreateResumeTask
    Whether to create a scheduled task for auto-resume

.PARAMETER ScriptPath
    Path to the setup script to resume

.PARAMETER Role
    The system role for resuming setup

.PARAMETER Settings
    Optional settings hashtable for determining username

.PARAMETER Username
    Optional username to run the task as. If not provided, determined from Settings.

.EXAMPLE
    Set-RebootRequired -CreateResumeTask -ScriptPath "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" -Role 'POS' -Settings $Settings
#>
function Set-RebootRequired {
  param(
    [switch]$CreateResumeTask,

    [string]$ScriptPath,

    [string]$Role,

    [hashtable]$Settings,

    [string]$Username = ''
  )

  Write-Verbose "Setting reboot required flag"

  # Create reboot flag file
  $flagContent = @{
    Timestamp = Get-Date -Format 'o'
    Reason    = 'Setup requires system reboot'
  }

  $flagContent | ConvertTo-Json | Set-Content -Path $script:RebootFlagFile -Force

  # Update state to increment reboot count
  $state = Get-SetupState
  if ($state) {
    if (-not $state.ContainsKey('RebootCount')) {
      $state.RebootCount = 0
    }
    $state.RebootCount++
    $state.RequiresReboot = $true
    Save-SetupState -State $state
  }

  # Create resume task if requested
  if ($CreateResumeTask -and $ScriptPath -and $Role) {
    # Determine username if not provided
    if (-not $Username -and $Settings) {
      $Username = Get-ResumeTaskUsername -Role $Role -Settings $Settings
    }
    
    New-ResumeTask -ScriptPath $ScriptPath -Role $Role -StartFromStep ($state.CurrentStep + 1) -Username $Username
  }

  # Set global flag
  $global:RebootRequired = $true

  Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
  Write-Host "║                    REBOOT REQUIRED                      ║" -ForegroundColor Yellow
  Write-Host "║                                                          ║" -ForegroundColor Yellow
  Write-Host "║  Setup has made changes that require a system reboot.   ║" -ForegroundColor Yellow
  Write-Host "║  Setup will automatically resume after reboot.          ║" -ForegroundColor Yellow
  Write-Host "║                                                          ║" -ForegroundColor Yellow
  Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Checks if a reboot is currently required.

.RETURNS
    $true if reboot is required, $false otherwise

.EXAMPLE
    if (Test-RebootRequired) {
        Write-Host "System needs to be rebooted"
    }
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Test-RebootRequired {
  # Check flag file
  if (Test-Path $script:RebootFlagFile) {
    return $true
  }

  # Check state file
  $state = Get-SetupState
  if ($state -and $state.RequiresReboot -eq $true) {
    return $true
  }

  # Check global variable
  if ($global:RebootRequired -eq $true) {
    return $true
  }

  return $false
}

<#
.SYNOPSIS
    Initiates a system reboot with optional delay.

.DESCRIPTION
    Schedules a system reboot and displays countdown.

.PARAMETER Delay
    Seconds to wait before reboot (default: 30)

.PARAMETER Force
    Force reboot without saving open applications

.EXAMPLE
    Invoke-SystemReboot -Delay 60
#>
function Invoke-SystemReboot {
  param(
    [int]$Delay = 30,

    [switch]$Force
  )

  Write-Host "`nSystem will reboot in $Delay seconds..." -ForegroundColor Yellow
  Write-Host "Press Ctrl+C to cancel the reboot" -ForegroundColor Gray

  # Display countdown
  for ($i = $Delay; $i -gt 0; $i--) {
    Write-Host "`rRebooting in $i seconds... " -NoNewline -ForegroundColor Yellow
    Start-Sleep -Seconds 1
  }

  Write-Host "`nInitiating reboot..." -ForegroundColor Red

  # Perform the reboot
  $args = @('/r', '/t', '0')
  if ($Force) {
    $args += '/f'
  }

  & shutdown.exe $args
}

#endregion Reboot Management Functions

#region Scheduled Task Functions

<#
.SYNOPSIS
    Creates a scheduled task to resume setup after reboot.

.DESCRIPTION
    Creates a Windows scheduled task that will run once at next logon to continue setup.
    Can run as either SYSTEM or a specific user account with elevation.

.PARAMETER ScriptPath
    Path to the setup script

.PARAMETER Role
    System role to resume

.PARAMETER StartFromStep
    Step number to resume from

.PARAMETER Username
    Username to run the task as. If not specified, runs as SYSTEM.
    For POS systems, this should be the local user account that will be logged in.

.EXAMPLE
    New-ResumeTask -ScriptPath "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" -Role 'POS' -StartFromStep 6 -Username "POS01"
    
.EXAMPLE
    New-ResumeTask -ScriptPath "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" -Role 'MGR' -StartFromStep 6
#>
function New-ResumeTask {
  param(
    [Parameter(Mandatory)]
    [string]$ScriptPath,

    [Parameter(Mandatory)]
    [string]$Role,

    [Parameter(Mandatory)]
    [int]$StartFromStep,

    [Parameter()]
    [string]$Username = ''
  )

  Write-Verbose "Creating resume task for step $StartFromStep"

  try {
    # Remove any existing task
    Remove-ResumeTask -Silent

    # Build PowerShell command
    $pwshExe = (Get-Command powershell.exe).Source
    $arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"& '$ScriptPath' -Role '$Role' -ContinueFrom $StartFromStep`""

    # Create task action
    $action = New-ScheduledTaskAction -Execute $pwshExe -Argument $arguments

    # Create trigger (at logon)
    if ($Username) {
      # Trigger for specific user logon
      $trigger = New-ScheduledTaskTrigger -AtLogOn -User $Username
    } else {
      # Trigger for any user logon
      $trigger = New-ScheduledTaskTrigger -AtLogOn
    }

    # Create principal based on whether username is specified
    if ($Username) {
      # Run as specific user with highest privileges (elevated)
      Write-Verbose "Creating task to run as user: $Username with elevation"
      $principal = New-ScheduledTaskPrincipal -UserId $Username -LogonType Interactive -RunLevel Highest
    } else {
      # Run as SYSTEM with highest privileges
      Write-Verbose "Creating task to run as SYSTEM"
      $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    }

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
      -AllowStartIfOnBatteries `
      -DontStopIfGoingOnBatteries `
      -StartWhenAvailable `
      -RestartCount 3 `
      -RestartInterval (New-TimeSpan -Minutes 1)

    # Register the task
    $task = Register-ScheduledTask `
      -TaskName $script:TaskName `
      -TaskPath $script:TaskPath `
      -Action $action `
      -Trigger $trigger `
      -Principal $principal `
      -Settings $settings `
      -Description $script:TaskDescription `
      -Force

    if ($task) {
      $userInfo = if ($Username) { "as user '$Username'" } else { "as SYSTEM" }
      Write-Host "Created scheduled task '$script:TaskName' to resume at step $StartFromStep $userInfo" -ForegroundColor Green

      # Save task info to state
      $state = Get-SetupState
      if ($state) {
        $state.ResumeTask = @{
          Name      = $script:TaskName
          Path      = $script:TaskPath
          NextStep  = $StartFromStep
          Username  = $Username
          CreatedAt = Get-Date -Format 'o'
        }
        Save-SetupState -State $state
      }

      return $true
    }
    else {
      Write-Warning "Failed to create scheduled task"
      return $false
    }
  }
  catch {
    Write-Error "Failed to create resume task: $_"
    return $false
  }
}

<#
.SYNOPSIS
    Removes the resume scheduled task.

.PARAMETER Silent
    Suppress warning messages if task doesn't exist

.EXAMPLE
    Remove-ResumeTask -Silent
#>
function Remove-ResumeTask {
  param(
    [switch]$Silent
  )

  try {
    $task = Get-ScheduledTask -TaskName $script:TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue

    if ($task) {
      Unregister-ScheduledTask -TaskName $script:TaskName -TaskPath $script:TaskPath -Confirm:$false
      Write-Verbose "Removed scheduled task: $script:TaskName"

      # Update state
      $state = Get-SetupState
      if ($state -and $state.ContainsKey('ResumeTask')) {
        $state.Remove('ResumeTask')
        Save-SetupState -State $state
      }
    }
    elseif (-not $Silent) {
      Write-Verbose "Scheduled task '$script:TaskName' not found"
    }
  }
  catch {
    if (-not $Silent) {
      Write-Warning "Failed to remove scheduled task: $_"
    }
  }
}

<#
.SYNOPSIS
    Restores autologon configuration after a scheduled task resume.

.DESCRIPTION
    Windows disables autologon when a scheduled task runs at user logon.
    This function re-enables autologon after the resume task has run.

.PARAMETER Username
    The username for autologon

.PARAMETER Role
    The system role

.PARAMETER Settings
    Settings hashtable containing autologon configuration

.EXAMPLE
    Restore-AutologonAfterResume -Username "POS01" -Role "POS" -Settings $Settings
#>
function Restore-AutologonAfterResume {
  param(
    [Parameter(Mandatory)]
    [string]$Username,
    
    [Parameter(Mandatory)]
    [string]$Role,
    
    [Parameter(Mandatory)]
    [hashtable]$Settings
  )

  Write-Verbose "Checking if autologon needs to be restored for $Role/$Username"

  # Check if this role uses autologon
  if (-not $Settings.ContainsKey('Autologon')) {
    Write-Verbose "No autologon configuration in settings"
    return
  }

  $autologonConfig = $Settings.Autologon[$Role]
  if (-not $autologonConfig -or -not $autologonConfig.Enable) {
    Write-Verbose "Autologon not enabled for role: $Role"
    return
  }

  # Find the autologon executable
  $autologonExe = $null
  if ($Settings.Autologon[$Role].ToolPath -and (Test-Path $Settings.Autologon[$Role].ToolPath)) {
    $autologonExe = $Settings.Autologon[$Role].ToolPath
  }
  else {
    # Try to find it in common locations
    $searchPaths = @(
      "C:\bin\global\files\Autologon64.exe",
      "C:\bin\global\files\Autologon.exe",
      "${Env:ProgramFiles}\Sysinternals\Autologon64.exe",
      "${Env:ProgramFiles}\Sysinternals\Autologon.exe"
    )
    
    foreach ($path in $searchPaths) {
      if (Test-Path $path) {
        $autologonExe = $path
        break
      }
    }
  }

  if (-not $autologonExe) {
    Write-Warning "Autologon executable not found - cannot restore autologon"
    return
  }

  # Get password for this role
  try {
    # Try to get password using Get-RolePassword if available
    if (Get-Command Get-RolePassword -ErrorAction SilentlyContinue) {
      $passwordText = Get-RolePassword -Role $Role
    }
    else {
      Write-Warning "Get-RolePassword function not available - cannot restore autologon"
      return
    }
  }
  catch {
    Write-Warning "Failed to retrieve password for autologon restore: $_"
    return
  }

  # Re-enable autologon
  $domain = if ($autologonConfig.Domain) { $autologonConfig.Domain } else { $env:COMPUTERNAME }
  $args = @($Username, $domain, $passwordText, '/AcceptEula')

  Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "║          RESTORING AUTOLOGON AFTER RESUME                ║" -ForegroundColor Cyan
  Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
  Write-Host "║ Windows disables autologon when scheduled tasks run     ║" -ForegroundColor Cyan
  Write-Host "║ at logon. Re-enabling autologon now...                  ║" -ForegroundColor Cyan
  Write-Host "║                                                          ║" -ForegroundColor Cyan
  Write-Host "║ User:   $($Username.PadRight(48))║" -ForegroundColor Cyan
  Write-Host "║ Domain: $($domain.PadRight(48))║" -ForegroundColor Cyan
  Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

  try {
    $p = Start-Process -FilePath $autologonExe -ArgumentList $args -PassThru -Wait -WindowStyle Hidden

    switch ($p.ExitCode) {
      0 { 
        Write-Host "✓ Autologon restored successfully" -ForegroundColor Green 
        Write-Verbose "Autologon re-enabled for ${domain}\${Username}"
      }
      1 { Write-Warning "Autologon restore failed: Access denied or invalid credentials" }
      2 { Write-Warning "Autologon restore failed: User not found" }
      default { Write-Warning "Autologon restore failed with exit code: $($p.ExitCode)" }
    }
  }
  catch {
    Write-Warning "Exception while restoring autologon: $_"
  }
}

<#
.SYNOPSIS
    Gets the username for the scheduled task based on role and settings.

.DESCRIPTION
    Determines the correct username to use for the scheduled task resume.
    For POS systems with autologon, returns the autologon username.
    For other systems, returns empty string (runs as SYSTEM).

.PARAMETER Role
    The system role (POS, MGR, CAM, ADMIN)

.PARAMETER Settings
    The settings hashtable containing autologon and user configuration

.RETURNS
    Username string, or empty string to run as SYSTEM

.EXAMPLE
    $username = Get-ResumeTaskUsername -Role 'POS' -Settings $Settings
#>
function Get-ResumeTaskUsername {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('POS', 'MGR', 'CAM', 'ADMIN', 'STAFF')]
    [string]$Role,

    [Parameter()]
    [hashtable]$Settings
  )

  # Default to empty string (SYSTEM)
  $username = ''

  # Check if we have settings and autologon config
  if ($Settings -and $Settings.ContainsKey('Autologon')) {
    $autologonConfig = $Settings.Autologon[$Role]
    
    if ($autologonConfig -and $autologonConfig.Enable -eq $true) {
      # Autologon is enabled for this role
      # Get the username from autologon config
      if ($autologonConfig.User) {
        $username = $autologonConfig.User
      }
      else {
        # Empty means use sanitized computer name
        $computerName = $env:COMPUTERNAME
        $username = $computerName -replace '-', ''
      }
      
      Write-Verbose "Determined resume task username for ${Role} - $username (from autologon config)"
    }
    else {
      # No autologon or disabled - use SYSTEM
      Write-Verbose "No autologon configured for $Role - will use SYSTEM"
    }
  }
  elseif ($Settings -and $Settings.ContainsKey('LocalUsers')) {
    # Fallback: Check LocalUsers config
    $userConfig = $Settings.LocalUsers[$Role]
    if ($userConfig -and $userConfig.Name) {
      if ($userConfig.Name -eq 'AUTO' -or $userConfig.Name -eq '') {
        $computerName = $env:COMPUTERNAME
        $username = $computerName -replace '-', ''
      }
      else {
        $username = $userConfig.Name
      }
      Write-Verbose "Determined resume task username for ${Role} - $username (from LocalUsers config)"
    }
  }
  else {
    Write-Verbose "No settings provided - will use SYSTEM for resume task"
  }

  return $username
}

#endregion Scheduled Task Functions

#region Resume Detection Functions

<#
.SYNOPSIS
    Determines if setup is resuming from a previous run.

.DESCRIPTION
    Checks for existing state files and determines the appropriate resume point.

.RETURNS
    Hashtable with resume information, or $null if fresh start

.EXAMPLE
    $resumeInfo = Test-SetupResume
    if ($resumeInfo) {
        Write-Host "Resuming from step $($resumeInfo.NextStep)"
    }
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Test-SetupResume {
  $state = Get-SetupState

  if (-not $state) {
    Write-Verbose "No existing state - fresh start"
    return $null
  }

  if ($state.Status -ne 'InProgress') {
    Write-Verbose "Previous setup status: ${state.Status}"
    return $null
  }

  # Calculate next step
  $nextStep = $state.CurrentStep + 1

  # Check if we're past the last step
  if ($nextStep -gt $state.TotalSteps) {
    Write-Verbose "All steps completed in previous run"
    return @{
      ShouldResume = $false
      Reason       = 'AllStepsCompleted'
    }
  }

  # Build resume information
  $resumeInfo = @{
    ShouldResume   = $true
    NextStep       = $nextStep
    Role           = $state.Role
    PreviousStep   = $state.CurrentStep
    SessionId      = $state.SessionId
    RebootCount    = $state.RebootCount
    CompletedSteps = @($state.CompletedSteps).Count
    FailedSteps    = @($state.FailedSteps).Count
  }

  Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "║              RESUMING PREVIOUS SETUP SESSION              ║" -ForegroundColor Cyan
  Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
  Write-Host "║ Role:           $($resumeInfo.Role.PadRight(42))║" -ForegroundColor Cyan
  Write-Host "║ Resuming from:  Step $($resumeInfo.NextStep.ToString().PadRight(37))║" -ForegroundColor Cyan
  Write-Host "║ Completed:      $($resumeInfo.CompletedSteps.ToString().PadRight(42))║" -ForegroundColor Cyan
  Write-Host "║ Failed:         $($resumeInfo.FailedSteps.ToString().PadRight(42))║" -ForegroundColor Cyan
  Write-Host "║ Reboot Count:   $($resumeInfo.RebootCount.ToString().PadRight(42))║" -ForegroundColor Cyan
  Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

  return $resumeInfo
}

#endregion Resume Detection Functions

#region Utility Functions

<#
.SYNOPSIS
    Clears all setup state files.

.DESCRIPTION
    Removes all state files to allow a fresh start.

.PARAMETER Force
    Skip confirmation prompt

.EXAMPLE
    Clear-SetupState -Force
#>
function Clear-SetupState {
  param(
    [switch]$Force
  )

  if (-not $Force) {
    Write-Host "This will remove all setup state files and progress tracking." -ForegroundColor Yellow
    Write-Host "Continue? (y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    if ($response -ne 'y') {
      Write-Host "Cancelled" -ForegroundColor Gray
      return
    }
  }

  # Remove scheduled task
  Remove-ResumeTask -Silent

  # Remove state directory
  if (Test-Path $script:StateBasePath) {
    Remove-Item -Path $script:StateBasePath -Recurse -Force
    Write-Host "Cleared all setup state files" -ForegroundColor Green
  }
  else {
    Write-Host "No state files found" -ForegroundColor Gray
  }
}

<#
.SYNOPSIS
    Exports the current setup state to a file.

.PARAMETER Path
    Path where to save the exported state

.EXAMPLE
    Export-SetupState -Path "C:\temp\setup-state-backup.json"
#>
function Export-SetupState {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $state = Get-SetupState
  if (-not $state) {
    Write-Warning "No setup state to export"
    return
  }

  $progress = Get-Progress

  $export = @{
    State        = $state
    Progress     = $progress
    ExportedAt   = Get-Date -Format 'o'
    ExportedBy   = $env:USERNAME
    ComputerName = $env:COMPUTERNAME
  }

  $export | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Force
  Write-Host "Exported setup state to: $Path" -ForegroundColor Green
}

#endregion Utility Functions

#region Module Exports

Export-ModuleMember -Function @(
  # State Management
  'Initialize-SetupState',
  'Save-SetupState',
  'Get-SetupState',
  'Update-StepProgress',
  'Complete-Setup',
  'Clear-SetupState',
  'Export-SetupState',

  # Progress Tracking
  'Get-Progress',
  'Get-ProgressSummary',

  # Reboot Management
  'Set-RebootRequired',
  'Test-RebootRequired',
  'Test-WindowsRebootRequired',
  'Invoke-RebootCheckpoint',
  'Invoke-SystemReboot',

  # Scheduled Tasks
  'New-ResumeTask',
  'Remove-ResumeTask',
  'Get-ResumeTaskUsername',

  # Resume Detection
  'Test-SetupResume'
)

#endregion Module Exports
