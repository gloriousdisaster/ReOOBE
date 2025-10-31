<#
.SYNOPSIS
    POS-specific module for Point of Sale system configuration.

.DESCRIPTION
    This module contains steps specific to POS systems including:
    - DeskCam installation
    - SQL Server Express and SSMS installation
    - CounterPoint installation and configuration
    - .NET Framework 3.5 enablement
    - Firewall and security configuration
    - Desktop shortcuts and RDP deployment

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 4.7.1
    Requires: PowerShell 5.1 or higher
    Must be run as Administrator
    Depends on: HMG.Core, HMG.Logging, HMG.State modules

.CHANGELOG
    v4.7.1 - Added desktop shortcut cleanup:
           - NEW: Priority 93 step to clean up unwanted desktop shortcuts
           - Removes Microsoft Edge.lnk and NCR Counterpoint.lnk
           - Renames "NCR Counterpoint Offline POS.lnk" to "OFFLINE.lnk"
    v4.7.0 - Migrated to unified checkpoint system:
           - FIXED: Removed duplicate reboot logic (priorities 56/57) that conflicted with baseline checkpoints
           - FIXED: Converted manual Invoke-POSReboot calls to Invoke-RebootCheckpoint with Settings parameter
           - FIXED: All resume tasks now run as correct user account instead of SYSTEM
           - FIXED: Eliminated unnecessary second reboot after user configuration
           - All POS checkpoints now properly pass Settings for username determination
           - .NET Framework checkpoint uses 'Check' mode (only reboots if needed)
           - SQL checkpoint uses 'Check' mode (only reboots if needed)
           - Simplified code by removing manual resume steps (handled by checkpoint system)
    v4.6.4 - Replaced PowerShell job with .NET Process class:
           - FIXED: Eliminated job serialization issues causing "Text node type" errors
           - Now uses System.Diagnostics.Process with built-in WaitForExit timeout
           - More reliable timeout handling with direct process control
           - Cleaner implementation without job overhead
    v4.6.3 - Fixed argument passing to debloat job:
           - FIXED: Corrected ArgumentList parameter passing to PowerShell job
           - Renamed parameter to avoid conflict with automatic $args variable
           - Used unary comma operator to properly pass array to job
    v4.6.2 - Fixed debloat script hanging issue:
           - FIXED: Added 5-minute timeout protection to POS custom app removal
           - Uses PowerShell job with Wait-Job timeout to prevent indefinite hangs
           - Automatically kills stuck debloat processes if timeout occurs
           - Prevents setup from stalling during OneDrive removal
    v4.6.1 - Fixed .NET Framework 3.5 CAB file path:
           - FIXED: .NET 3.5 offline installer path now uses settings.psd1
           - Added DotNetFramework35Cab to POS.Installers configuration
           - Corrected path from 'installers' to 'files' subdirectory
           - Pre-flight validation now checks correct path
    v4.6.0 - CounterPoint SQL Prerequisites Implementation:
           - NEW: Added Priority 79 step to install CounterPoint SQL prerequisites
           - Installs 4 MSI packages: SQLSYSCLRTYPES, SHAREDMANAGEMENTOBJECTS, SQLXML4, MSSQLCMDLNUTILS
           - Intelligent detection to skip already-installed packages
           - Handles EULA acceptance automatically for MSSQLCMDLNUTILS
           - Per-MSI logging with summary reporting
           - Renumbered CounterPoint prerequisites check to Priority 78
           - Added CounterPointSQLPrereqs path to settings.psd1
           - Updated pre-flight validation to include new prerequisites path
    v4.5.0 - Major refactoring and improvements:
           - FIXED: Eliminated hardcoded paths - all paths now from settings.psd1
           - FIXED: Reboot logic duplication - new Invoke-POSReboot helper function
           - FIXED: Added comprehensive pre-flight validation at Priority 5
           - FIXED: SQL script error handling now captures output for debugging
           - All POS paths centralized in $Settings.POS configuration
           - Improved error messages and troubleshooting capabilities
    v4.4.3 - Fixed multiple errors in step execution:
           - Fixed DeskCam installation DisplayName property check
           - Fixed global:RebootRequired initialization
           - Improved SQL Server service detection to avoid errors
           - Fixed CounterPoint prerequisites SQL instance property check
           - Added proper property existence validation throughout
    v4.4.2 - Fixed SQL Server default instance (MSSQLSERVER) detection
           - Now properly detects both MSSQLSERVER and SQLEXPRESS instances
           - SQL script execution automatically detects correct instance
           - Prevents redundant SQL installation attempts
           - Added multiple detection methods (service, registry, executable)
#>

Set-StrictMode -Version Latest

# Module-level variables
$script:ModuleName = 'HMG.POS'
$script:RebootRequired = $false

# Initialize global variables if not exists
if (-not (Get-Variable -Name 'RebootRequired' -Scope Global -ErrorAction SilentlyContinue)) {
  $global:RebootRequired = $false
}

# Import HMG.Core for step registration framework
$coreModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "HMG.Core\HMG.Core.psd1"
if (-not (Test-Path $coreModulePath)) {
  throw "HMG.Core module not found at: $coreModulePath. Cannot load HMG.POS."
}
Import-Module $coreModulePath -Force -Global

# Helper function to write logs with module context
function Write-POSLog {
  param(
    [Parameter(Mandatory)]
    [string]$Message,

    [Parameter(Mandatory)]
    [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
    [string]$Level,

    [string]$Step,

    [System.Exception]$Exception
  )

  $params = @{
    Message   = $Message
    Level     = $Level
    Component = $script:ModuleName
  }

  if ($Step) { $params.Step = $Step }
  if ($Exception) { $params.Exception = $Exception }

  # Use HMG.Logging if available, otherwise fallback to Write-Status
  if (Get-Command 'Write-HMGLog' -ErrorAction SilentlyContinue) {
    Write-HMGLog @params
  }
  else {
    # Fallback to Write-Status
    $type = switch ($Level) {
      'SUCCESS' { 'Success' }
      'WARNING' { 'Warning' }
      'ERROR' { 'Error' }
      'CRITICAL' { 'Error' }
      default { 'Info' }
    }
    Write-Status -Message $Message -Type $type
  }
}

# Helper function for reboot orchestration (eliminates duplication)
function Invoke-POSReboot {
  param(
    [Parameter(Mandatory)]
    [string]$Phase,

    [Parameter(Mandatory)]
    [string]$Reason,

    [Parameter()]
    [hashtable]$Settings
  )

  $stepName = "Reboot: $Phase"

  # Initialize global variable if not exists
  if (-not (Get-Variable -Name 'RebootRequired' -Scope Global -ErrorAction SilentlyContinue)) {
    $global:RebootRequired = $false
  }

  if ($script:RebootRequired -or $global:RebootRequired) {
    Write-POSLog "$Reason - reboot required" -Level WARNING -Step $stepName

    # Try to use HMG.State module for automatic resume
    $stateModule = Get-Module -Name 'HMG.State' -ErrorAction SilentlyContinue
    if ($stateModule) {
      # Get the orchestrator script path
      $rbcmsRoot = if (Get-Command Get-RBCMSRoot -ErrorAction SilentlyContinue) {
        Get-RBCMSRoot -Silent
      }
      else {
        "C:\bin\RBCMS"
      }

      $scriptPath = Join-Path $rbcmsRoot 'scripts\Invoke-Setup.ps1'

      if (Test-Path $scriptPath) {
        Write-POSLog "Setting up automatic resume after reboot (Phase: $Phase)" -Level INFO -Step $stepName
        
        # Pass Settings parameter to Set-RebootRequired for user-based scheduled task
        if ($Settings) {
          Set-RebootRequired -CreateResumeTask -ScriptPath $scriptPath -Role 'POS' -Settings $Settings
        }
        else {
          Write-POSLog "WARNING: Settings not provided - scheduled task will run as SYSTEM" -Level WARNING -Step $stepName
          Set-RebootRequired -CreateResumeTask -ScriptPath $scriptPath -Role 'POS'
        }

        # Initiate reboot with delay
        Write-Host "`n" -NoNewline
        Invoke-SystemReboot -Delay 5
      }
      else {
        Write-POSLog "Cannot find setup script for auto-resume: $scriptPath" -Level WARNING -Step $stepName
        Write-POSLog "Manual reboot required - setup will need to be resumed manually" -Level WARNING -Step $stepName
      }
    }
    else {
      Write-POSLog "State management module not available - manual reboot required" -Level WARNING -Step $stepName
      Write-Host "`n====================================`n  MANUAL REBOOT REQUIRED`n====================================" -ForegroundColor Yellow
      Write-Host "Please reboot the system and resume setup manually." -ForegroundColor White
      Write-Host "Reason: $Reason" -ForegroundColor White
    }
  }
  else {
    Write-POSLog "No reboot required for $Phase - continuing to next phase" -Level INFO -Step $stepName
  }
}

# ===========================
# PHASE 0: PRE-FLIGHT VALIDATION (5)
# ===========================

# Validate POS Prerequisites (Priority 5)
Register-Step -Name "Validate POS Prerequisites" -Tags @('POS') -Priority 5 -Action {
  $stepName = "Validate POS Prerequisites"
  Write-POSLog "Running pre-flight validation for POS setup" -Level INFO -Step $stepName

  $validationErrors = @()
  $validationWarnings = @()

  # Validate required paths from settings
  $requiredPaths = @{
    'DeskCam Installer'        = $Settings.POS.Installers.DeskCam
    'SQL Server Installer'     = $Settings.POS.Installers.SQLServer
    'SSMS Installer'           = $Settings.POS.Installers.SSMS
    'SQL Config Script'        = $Settings.POS.Scripts.SQLConfig
    'CounterPoint SQL Prereqs' = $Settings.POS.Installers.CounterPointSQLPrereqs
    'Desktop Shortcuts'        = $Settings.POS.Deployment.DesktopShortcuts
    'RDP Files'                = $Settings.POS.Deployment.RDPFiles
  }

  foreach ($pathName in $requiredPaths.Keys) {
    $path = $requiredPaths[$pathName]
    if (-not (Test-Path $path)) {
      $validationWarnings += "Missing path: $pathName at $path"
      Write-POSLog "WARNING: $pathName not found at: $path" -Level WARNING -Step $stepName
    }
    else {
      Write-POSLog "Validated: $pathName at $path" -Level DEBUG -Step $stepName
    }
  }

  # Validate SQL Server installer structure
  $sqlPath = $Settings.POS.Installers.SQLServer
  if (Test-Path $sqlPath) {
    $setupExe = Join-Path $sqlPath "installFiles\setup.exe"
    if (-not (Test-Path $setupExe)) {
      $validationErrors += "SQL Server setup.exe not found at: $setupExe"
    }

    if ($Settings.POS.SQL.UseConfigFile) {
      $configFile = Join-Path $sqlPath $Settings.POS.SQL.ConfigFile
      if (-not (Test-Path $configFile)) {
        $validationWarnings += "SQL Server config file not found: $configFile (will use command-line params)"
        Write-POSLog "SQL config file not found, will use command-line parameters" -Level WARNING -Step $stepName
      }
    }
  }

  # Validate .NET Framework 3.5 offline installer
  $dotNetCabPath = $Settings.POS.Installers.DotNetFramework35Cab
  if (-not (Test-Path $dotNetCabPath)) {
    $validationWarnings += ".NET Framework 3.5 offline installer not found (will attempt online installation)"
    Write-POSLog ".NET 3.5 offline cab not found, will use online installation" -Level WARNING -Step $stepName
  }

  # Validate Autologon tool
  if ($Settings.Autologon.POS.Enable) {
    $autologonPath = $Settings.Autologon.POS.ToolPath
    if (-not (Test-Path $autologonPath)) {
      $validationErrors += "Autologon tool not found at: $autologonPath"
    }
  }

  # Report validation results
  if ($validationErrors.Count -gt 0) {
    Write-POSLog "PRE-FLIGHT VALIDATION FAILED with $($validationErrors.Count) critical error(s)" -Level ERROR -Step $stepName
    foreach ($validationError in $validationErrors) {
      Write-POSLog "  CRITICAL: $validationError" -Level ERROR -Step $stepName
    }
    throw "Pre-flight validation failed. Please resolve critical errors before continuing."
  }

  if ($validationWarnings.Count -gt 0) {
    Write-POSLog "Pre-flight validation completed with $($validationWarnings.Count) warning(s)" -Level WARNING -Step $stepName
    foreach ($warning in $validationWarnings) {
      Write-POSLog "  WARNING: $warning" -Level WARNING -Step $stepName
    }
  }
  else {
    Write-POSLog "Pre-flight validation passed - all critical paths verified" -Level SUCCESS -Step $stepName
  }
}

# ===========================
# PHASE 1: SYSTEM CONFIGURATION (10-20)
# ===========================

# Power settings configured by HMG.Common (Priority 10)
# Time zone configured by HMG.Common (Priority 15)
# Office removal configured by HMG.Common (Priority 20)

# ===========================
# PHASE 2: SOFTWARE INSTALLATION (25-35)
# ===========================

# Chrome installation handled by HMG.Common (Priority 25)

# Install DeskCam (Priority 26)
Register-Step -Name "Install DeskCam" -Tags @('POS') -Priority 26 -Action {
  $stepName = "Install DeskCam"
  $deskCamPath = $Settings.POS.Installers.DeskCam

  # Check if DeskCam is already installed
  $installed = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
  Where-Object { $_.PSObject.Properties.Name -contains 'DisplayName' -and
    ($_.DisplayName -like "*DeskCam*" -or $_.DisplayName -like "*Desk Camera*") }

  if ($installed) {
    Write-POSLog "DeskCam already installed: $($installed.DisplayName)" -Level SUCCESS -Step $stepName
    return
  }

  # Check if installer directory exists
  if (-not (Test-Path $deskCamPath)) {
    Write-POSLog "DeskCam installer directory not found: $deskCamPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Finding latest DeskCam installer" -Level INFO -Step $stepName

  # Find the latest installer
  $latestInstaller = Get-ChildItem -Path $deskCamPath -Filter "*.exe" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

  if (-not $latestInstaller) {
    Write-POSLog "No DeskCam installer found in $deskCamPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Installing DeskCam: $($latestInstaller.Name)" -Level INFO -Step $stepName

  try {
    $arguments = "/install /passive"
    $process = Start-Process -FilePath $latestInstaller.FullName -ArgumentList $arguments -Wait -PassThru

    if ($process.ExitCode -eq 0) {
      Write-POSLog "DeskCam installed successfully" -Level SUCCESS -Step $stepName
    }
    else {
      Write-POSLog "DeskCam installation returned exit code: $($process.ExitCode)" -Level WARNING -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to install DeskCam" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Disable Memory Integrity (Priority 30)
Register-Step -Name "Disable Memory Integrity" -Tags @('POS') -Priority 30 -Action {
  $stepName = "Disable Memory Integrity"

  if ($Settings.MemoryIntegrity.$Role -ne 'Disable') {
    Write-POSLog "Memory Integrity not set to disable for $Role" -Level INFO -Step $stepName
    return
  }

  Write-POSLog "Checking current Memory Integrity (HVCI) status" -Level INFO -Step $stepName

  $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
  if (-not (Test-Path $path)) {
    Write-POSLog "Creating registry path for HVCI configuration" -Level DEBUG -Step $stepName
    New-Item -Path $path -Force | Out-Null
  }

  $regKey = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
  $current = if ($regKey -and $null -ne $regKey.Enabled) { $regKey.Enabled } else { $null }

  if ($current -eq 0) {
    Write-POSLog "Core Isolation (HVCI) already disabled" -Level SUCCESS -Step $stepName
  }
  else {
    Write-POSLog "Disabling Core Isolation (HVCI)" -Level INFO -Step $stepName
    Set-ItemProperty -Path $path -Name Enabled -Type DWord -Value 0
    Write-POSLog "Core Isolation (HVCI) disabled. Reboot required." -Level WARNING -Step $stepName
    $script:RebootRequired = $true
    $global:RebootRequired = $true
  }
}

# Configure Firewall Rules (Priority 35)
Register-Step -Name "Configure Firewall Rules" -Tags @('POS') -Priority 35 -Action {
  $stepName = "Configure Firewall Rules"
  $firewallConfig = $Settings.Firewall.$Role

  if (-not $firewallConfig.Rules) {
    Write-POSLog "No firewall rules configured for $Role" -Level INFO -Step $stepName
    return
  }

  Write-POSLog "Configuring firewall rules for POS" -Level INFO -Step $stepName
  $rulesAdded = 0
  $rulesSkipped = 0

  foreach ($rule in $firewallConfig.Rules) {
    Write-POSLog "Processing firewall rule: $($rule.Name)" -Level DEBUG -Step $stepName

    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if ($existing) {
      Write-POSLog "Firewall rule '$($rule.Name)' already exists" -Level INFO -Step $stepName
      $rulesSkipped++
      continue
    }

    $params = @{
      DisplayName = $rule.Name
      Direction   = $rule.Direction
      LocalPort   = $rule.LocalPort
      Protocol    = $rule.Protocol
      Action      = 'Allow'
      Enabled     = 'True'
      Profile     = $rule.Profile
    }

    if ($rule.Group) {
      $params.Group = $rule.Group
    }

    try {
      New-NetFirewallRule @params | Out-Null
      Write-POSLog "Created firewall rule '$($rule.Name)'" -Level SUCCESS -Step $stepName
      $rulesAdded++
    }
    catch {
      Write-POSLog "Failed to create firewall rule '$($rule.Name)'" -Level ERROR -Step $stepName -Exception $_.Exception
    }
  }

  Write-POSLog "Firewall configuration complete - Added: $rulesAdded, Skipped: $rulesSkipped" -Level SUCCESS -Step $stepName
}

# ===========================
# PHASE 3: USER CONFIGURATION (50-59)
# ===========================

# Create Local User handled by HMG.Baseline (Priority 50)
# Configure Autologon handled by HMG.Baseline (Priority 55)
# Checkpoint: After User Configuration handled by HMG.Baseline (Priority 59)
# NOTE: Old manual reboot steps (56/57) removed - using centralized checkpoint system

# ===========================
# PHASE 4: .NET FRAMEWORK & REBOOT (60-62)
# ===========================

# Enable .NET Framework 3.5 (Priority 60)
Register-Step -Name "Enable .NET Framework 3.5" -Tags @('POS') -Priority 60 -Provides @('.NET35') -Action {
  $stepName = "Enable .NET Framework 3.5"
  $featureName = "NetFx3"
  $cabPath = $Settings.POS.Installers.DotNetFramework35Cab

  Write-POSLog "Checking .NET Framework 3.5 status" -Level INFO -Step $stepName
  $state = (Get-WindowsOptionalFeature -Online -FeatureName $featureName).State

  if ($state -eq 'Enabled') {
    Write-POSLog ".NET Framework 3.5 already enabled" -Level SUCCESS -Step $stepName
    return
  }

  # Check if cab file exists
  if (-not (Test-Path $cabPath)) {
    Write-POSLog ".NET Framework 3.5 cab file not found: $cabPath" -Level WARNING -Step $stepName
    Write-POSLog "Attempting online installation" -Level INFO -Step $stepName
    Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart
  }
  else {
    Write-POSLog "Enabling .NET Framework 3.5 using offline cab (this may take several minutes)" -Level INFO -Step $stepName

    # Run DISM with cab file
    $dismArgs = "/Online /Add-Package /PackagePath:`"$cabPath`" /Quiet /NoRestart"
    $process = Start-Process -FilePath "DISM.exe" -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
      Write-POSLog ".NET Framework 3.5 enabled successfully" -Level SUCCESS -Step $stepName
      if ($process.ExitCode -eq 3010) {
        Write-POSLog "Reboot required to complete .NET Framework 3.5 installation" -Level WARNING -Step $stepName
        $script:RebootRequired = $true
        $global:RebootRequired = $true
      }
    }
    else {
      Write-POSLog "Failed to enable .NET Framework 3.5. Exit code: $($process.ExitCode)" -Level ERROR -Step $stepName
    }
  }
}

# Checkpoint after .NET Framework (Priority 61)
Register-Step -Name "Checkpoint: After .NET Framework" -Tags @('POS') -Priority 61 -Section 3 -DependsOn @('.NET35') -Action {
  # Get RBCMS root to build correct orchestrator path (not module path!)
  $rbcmsRoot = if (Get-Command Get-RBCMSRoot -ErrorAction SilentlyContinue) {
    Get-RBCMSRoot -Silent
  }
  else {
    "C:\bin\RBCMS"
  }
  $scriptPath = Join-Path $rbcmsRoot 'scripts\Invoke-Setup.ps1'
  
  # Get Settings from framework for username determination
  $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) {
    Get-HMGFramework
  }
  else {
    $null
  }
  $frameworkSettings = if ($framework) { $framework.Settings } else { $null }
  
  # Use 'Check' mode - only reboot if .NET installation requires it
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-.NET-Framework' `
    -Section 3 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 70 `
    -RebootMode 'Check' `
    -Settings $frameworkSettings
  
  if ($rebooting) { return }
}

# NOTE: Resume after reboot is handled automatically by the checkpoint system

# ===========================
# PHASE 5: DATABASE INSTALLATION & REBOOT (70-74)
# ===========================

# Install SQL Server Express (Priority 70)
Register-Step -Name "Install SQL Server Express" -Tags @('POS') -Priority 70 -DependsOn @('.NET35') -Provides @('SQLServer') -Action {
  $stepName = "Install SQL Server Express"
  $sqlPath = $Settings.POS.Installers.SQLServer
  $configFile = Join-Path $sqlPath $Settings.POS.SQL.ConfigFile

  # Check if already installed using multiple detection methods
  $sqlInstalled = $false
  $installedInstance = $null

  # Method 1: Check for common SQL Server services
  $sqlServiceNames = @('MSSQL$SQLEXPRESS', 'MSSQLSERVER')
  foreach ($serviceName in $sqlServiceNames) {
    $sqlService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($sqlService) {
      $sqlInstalled = $true
      $installedInstance = $serviceName
      Write-POSLog "SQL Server service found: $serviceName (Status: $($sqlService.Status))" -Level SUCCESS -Step $stepName
      break
    }
  }

  # Method 2: Check registry if service check failed
  if (-not $sqlInstalled) {
    $sqlInstances = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue
    if ($sqlInstances) {
      if ($sqlInstances.PSObject.Properties.Name -contains 'MSSQLSERVER') {
        $sqlInstalled = $true
        $installedInstance = 'MSSQLSERVER'
        Write-POSLog "SQL Server default instance found in registry" -Level SUCCESS -Step $stepName
      }
      elseif ($sqlInstances.PSObject.Properties.Name -contains 'SQLEXPRESS') {
        $sqlInstalled = $true
        $installedInstance = 'SQLEXPRESS'
        Write-POSLog "SQL Server Express instance found in registry" -Level SUCCESS -Step $stepName
      }
    }
  }

  # Method 3: Check for SQL Server executable
  if (-not $sqlInstalled) {
    $sqlExePaths = @(
      "${Env:ProgramFiles}\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Binn\sqlservr.exe",
      "${Env:ProgramFiles}\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\Binn\sqlservr.exe"
    )
    foreach ($exePath in $sqlExePaths) {
      if (Test-Path $exePath) {
        $sqlInstalled = $true
        Write-POSLog "SQL Server executable found at: $exePath" -Level SUCCESS -Step $stepName
        break
      }
    }
  }

  if ($sqlInstalled) {
    Write-POSLog "SQL Server is already installed (Instance: $installedInstance) - skipping installation" -Level SUCCESS -Step $stepName
    return
  }

  # Check if installer exists
  if (-not (Test-Path $sqlPath)) {
    Write-POSLog "SQL Server installer directory not found: $sqlPath" -Level WARNING -Step $stepName
    return
  }

  $setupExe = Join-Path $sqlPath "installFiles\setup.exe"
  if (-not (Test-Path $setupExe)) {
    Write-POSLog "SQL Server setup.exe not found: $setupExe" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Installing SQL Server 2019 Express (this may take 15-20 minutes)" -Level INFO -Step $stepName

  try {
    # Use configuration file if it exists and is enabled, otherwise use command-line parameters
    if ($Settings.POS.SQL.UseConfigFile -and (Test-Path $configFile)) {
      $arguments = "/ConfigurationFile=`"$configFile`" /QUIETSIMPLE"
      Write-POSLog "Using SQL configuration file: $configFile" -Level DEBUG -Step $stepName
    }
    else {
      # Build command-line arguments from settings
      $sqlParams = $Settings.POS.SQL.CommandLineParams
      $arguments = "/ACTION=$($sqlParams.ACTION) /FEATURES=$($sqlParams.FEATURES) /INSTANCENAME=$($sqlParams.INSTANCENAME) /SECURITYMODE=$($sqlParams.SECURITYMODE) /SQLSVCACCOUNT=`"$($sqlParams.SQLSVCACCOUNT)`" /SQLSYSADMINACCOUNTS=`"$($sqlParams.SQLSYSADMINACCOUNTS)`" /AGTSVCACCOUNT=`"$($sqlParams.AGTSVCACCOUNT)`" /TCPENABLED=$($sqlParams.TCPENABLED) /QUIETSIMPLE"
      Write-POSLog "Using command-line parameters for SQL installation" -Level DEBUG -Step $stepName
    }

    $process = Start-Process -FilePath $setupExe -ArgumentList $arguments -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
      Write-POSLog "SQL Server Express installed successfully" -Level SUCCESS -Step $stepName
      
      # Refresh PATH environment variable so SQL tools are available in current session
      Write-POSLog "Refreshing PATH environment variable for current session" -Level INFO -Step $stepName
      $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
      
      if ($process.ExitCode -eq 3010) {
        Write-POSLog "Reboot required to complete SQL Server installation" -Level WARNING -Step $stepName
        $script:RebootRequired = $true
        $global:RebootRequired = $true
      }
    }
    else {
      Write-POSLog "SQL Server installation returned exit code: $($process.ExitCode)" -Level WARNING -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to install SQL Server Express" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Install SQL Server Management Studio (Priority 71)
Register-Step -Name "Install SQL Server Management Studio" -Tags @('POS') -Priority 71 -DependsOn @('SQLServer') -Action {
  $stepName = "Install SQL Server Management Studio"
  $ssmsPath = $Settings.POS.Installers.SSMS

  # Check if already installed
  $ssmsExe = "${Env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
  if ((Test-Path $ssmsExe) -or (Test-Path "${Env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe")) {
    Write-POSLog "SQL Server Management Studio already installed" -Level SUCCESS -Step $stepName
    return
  }

  # Check if installer exists
  if (-not (Test-Path $ssmsPath)) {
    Write-POSLog "SSMS installer directory not found: $ssmsPath" -Level WARNING -Step $stepName
    return
  }

  # Find SSMS setup file
  $setupExe = Get-ChildItem -Path $ssmsPath -Filter "*SSMS*.exe" | Select-Object -First 1
  if (-not $setupExe) {
    $setupExe = Get-ChildItem -Path $ssmsPath -Filter "setup.exe" | Select-Object -First 1
  }

  if (-not $setupExe) {
    Write-POSLog "SSMS setup file not found in $ssmsPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Installing SQL Server Management Studio (this may take 10-15 minutes)" -Level INFO -Step $stepName

  try {
    $arguments = "/install /passive"
    $process = Start-Process -FilePath $setupExe.FullName -ArgumentList $arguments -Wait -PassThru

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
      Write-POSLog "SQL Server Management Studio installed successfully" -Level SUCCESS -Step $stepName
      
      # Refresh PATH environment variable so sqlcmd is available in current session
      Write-POSLog "Refreshing PATH environment variable for current session" -Level INFO -Step $stepName
      $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
      
      # Verify sqlcmd is now available
      $sqlcmdCheck = Get-Command sqlcmd -ErrorAction SilentlyContinue
      if ($sqlcmdCheck) {
        Write-POSLog "sqlcmd is now available at: $($sqlcmdCheck.Source)" -Level SUCCESS -Step $stepName
      }
      else {
        Write-POSLog "sqlcmd still not found in PATH after refresh - may require reboot" -Level WARNING -Step $stepName
      }
      
      if ($process.ExitCode -eq 3010) {
        Write-POSLog "Reboot required to complete SSMS installation" -Level WARNING -Step $stepName
        $script:RebootRequired = $true
        $global:RebootRequired = $true
      }
    }
    else {
      Write-POSLog "SSMS installation returned exit code: $($process.ExitCode)" -Level WARNING -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to install SQL Server Management Studio" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Run SQL Script (Priority 72) - FIXED: Enhanced error handling with output capture
Register-Step -Name "Run SQL Script" -Tags @('POS') -Priority 72 -DependsOn @('SQLServer') -Action {
  $stepName = "Run SQL Script"
  $sqlScriptPath = $Settings.POS.Scripts.SQLConfig

  # Check if script exists
  if (-not (Test-Path $sqlScriptPath)) {
    Write-POSLog "SQL script not found: $sqlScriptPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Executing SQL script: $([System.IO.Path]::GetFileName($sqlScriptPath))" -Level INFO -Step $stepName

  # Determine SQL instance to connect to
  $sqlInstance = $null

  # Check for MSSQLSERVER (default instance)
  $mssqlService = Get-Service -Name 'MSSQLSERVER' -ErrorAction SilentlyContinue
  if ($mssqlService) {
    $sqlInstance = "."  # Default instance uses just dot or localhost
    Write-POSLog "Using default SQL Server instance (MSSQLSERVER)" -Level DEBUG -Step $stepName
  }
  else {
    # Check for SQLEXPRESS
    $sqlExpressService = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
    if ($sqlExpressService) {
      $sqlInstance = ".\SQLEXPRESS"
      Write-POSLog "Using SQL Server Express instance" -Level DEBUG -Step $stepName
    }
  }

  if (-not $sqlInstance) {
    Write-POSLog "No SQL Server instance found to execute script" -Level WARNING -Step $stepName
    return
  }

  try {
    # Check if sqlcmd is available in PATH
    $sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    
    # If not in PATH, search common SQL Server installation locations
    if (-not $sqlcmd) {
      Write-POSLog "sqlcmd not in PATH - searching SQL Server installation directories" -Level INFO -Step $stepName
      
      $possiblePaths = @(
        "${Env:ProgramFiles}\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles}\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles}\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles}\Microsoft SQL Server\120\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles}\Microsoft SQL Server\130\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles}\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles}\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles(x86)}\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles(x86)}\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles(x86)}\Microsoft SQL Server\120\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles(x86)}\Microsoft SQL Server\130\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles(x86)}\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe",
        "${Env:ProgramFiles(x86)}\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe"
      )
      
      foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
          $sqlcmdPath = $path
          Write-POSLog "Found sqlcmd at: $sqlcmdPath" -Level SUCCESS -Step $stepName
          break
        }
      }
      
      if (-not $sqlcmdPath) {
        Write-POSLog "sqlcmd not found - SQL Server tools may not be installed" -Level WARNING -Step $stepName
        return
      }
    }
    else {
      $sqlcmdPath = $sqlcmd.Source
      Write-POSLog "Using sqlcmd from PATH: $sqlcmdPath" -Level INFO -Step $stepName
    }

    # FIXED: Create output file for capturing SQL execution results
    $outputFile = Join-Path $env:TEMP "sql_script_output_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $errorFile = Join-Path $env:TEMP "sql_script_errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    Write-POSLog "SQL output will be logged to: $outputFile" -Level DEBUG -Step $stepName

    # Execute the SQL script with output capture
    $arguments = "-S $sqlInstance -i `"$sqlScriptPath`" -o `"$outputFile`" -e"
    $process = Start-Process -FilePath $sqlcmdPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardError $errorFile

    if ($process.ExitCode -eq 0) {
      Write-POSLog "SQL script executed successfully" -Level SUCCESS -Step $stepName

      # Check if output file has content to log
      if (Test-Path $outputFile) {
        $outputContent = Get-Content $outputFile -Raw
        if ($outputContent -and $outputContent.Trim()) {
          Write-POSLog "SQL script output: $($outputContent.Length) characters logged" -Level DEBUG -Step $stepName
        }
      }
    }
    else {
      Write-POSLog "SQL script execution returned exit code: $($process.ExitCode)" -Level WARNING -Step $stepName

      # Read and log error details if available
      if (Test-Path $errorFile) {
        $errorContent = Get-Content $errorFile -Raw
        if ($errorContent -and $errorContent.Trim()) {
          Write-POSLog "SQL script errors: $errorContent" -Level ERROR -Step $stepName
        }
      }

      # Also check output file for error messages
      if (Test-Path $outputFile) {
        $outputContent = Get-Content $outputFile -Raw
        if ($outputContent -and $outputContent.Trim()) {
          Write-POSLog "SQL script output (may contain errors): $outputContent" -Level WARNING -Step $stepName
        }
      }
    }

    # Cleanup temporary files after logging
    if (Test-Path $outputFile) {
      Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $errorFile) {
      Remove-Item $errorFile -Force -ErrorAction SilentlyContinue
    }
  }
  catch {
    Write-POSLog "Failed to execute SQL script" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Checkpoint after SQL Setup (Priority 73)
Register-Step -Name "Checkpoint: After SQL Setup" -Tags @('POS') -Priority 73 -Section 4 -DependsOn @('Run SQL Script') -Action {
  # Get RBCMS root to build correct orchestrator path (not module path!)
  $rbcmsRoot = if (Get-Command Get-RBCMSRoot -ErrorAction SilentlyContinue) {
    Get-RBCMSRoot -Silent
  }
  else {
    "C:\bin\RBCMS"
  }
  $scriptPath = Join-Path $rbcmsRoot 'scripts\Invoke-Setup.ps1'
  
  # Get Settings from framework for username determination
  $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) {
    Get-HMGFramework
  }
  else {
    $null
  }
  $frameworkSettings = if ($framework) { $framework.Settings } else { $null }
  
  # Use 'Check' mode - only reboot if SQL installation requires it
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-SQL-Setup' `
    -Section 4 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 78 `
    -RebootMode 'Check' `
    -Settings $frameworkSettings
  
  if ($rebooting) { return }
}

# NOTE: Resume after SQL reboot is handled automatically by the checkpoint system

# ===========================
# PHASE 6: COUNTERPOINT INSTALLATION (78-81)
# ===========================

# Check CounterPoint Prerequisites (Priority 78)
Register-Step -Name "Check CounterPoint Prerequisites" -Tags @('POS') -Priority 78 -Action {
  $stepName = "Check CounterPoint Prerequisites"
  Write-POSLog "Checking CounterPoint prerequisites" -Level INFO -Step $stepName

  # Check for SQL Server
  $sqlInstances = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue
  if ($sqlInstances) {
    $hasInstance = $false
    if ($sqlInstances.PSObject.Properties.Name -contains 'SQLEXPRESS') {
      $hasInstance = $true
      Write-POSLog "SQL Server Express instance found - prerequisite met" -Level SUCCESS -Step $stepName
    }
    elseif ($sqlInstances.PSObject.Properties.Name -contains 'MSSQLSERVER') {
      $hasInstance = $true
      Write-POSLog "SQL Server default instance found - prerequisite met" -Level SUCCESS -Step $stepName
    }

    if (-not $hasInstance) {
      Write-POSLog "No SQL Server instance found - CounterPoint requires SQL Server" -Level WARNING -Step $stepName
    }
  }
  else {
    Write-POSLog "SQL Server not found - CounterPoint requires SQL Server" -Level WARNING -Step $stepName
  }

  # Check for .NET Framework
  $dotNetKey = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -ErrorAction SilentlyContinue
  if ($dotNetKey -and $dotNetKey.Install -eq 1) {
    Write-POSLog ".NET Framework 3.5 found - prerequisite met" -Level SUCCESS -Step $stepName
  }
  else {
    Write-POSLog ".NET Framework 3.5 not found - CounterPoint may require this" -Level WARNING -Step $stepName
  }

  Write-POSLog "CounterPoint prerequisites check complete" -Level INFO -Step $stepName
}

# Install CounterPoint SQL Prerequisites (Priority 79)
Register-Step -Name "Install CounterPoint SQL Prerequisites" -Tags @('POS') -Priority 79 -DependsOn @('SQLServer') -Provides @('CPSQLPrereqs') -Action {
  $stepName = "Install CounterPoint SQL Prerequisites"
  $prereqsPath = $Settings.POS.Installers.CounterPointSQLPrereqs

  # Check if prerequisites directory exists
  if (-not (Test-Path $prereqsPath)) {
    Write-POSLog "CounterPoint SQL prerequisites directory not found: $prereqsPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Installing CounterPoint SQL prerequisites" -Level INFO -Step $stepName

  # Define the MSI files to install in order
  $msiFiles = @(
    "2. SQLSYSCLRTYPES.MSI",
    "3. SHAREDMANAGEMENTOBJECTS.MSI",
    "4. SQLXML4_SP1_X64.MSI",
    "5. MSSQLCMDLNUTILS.MSI"
  )

  # Per-MSI custom properties (EULA acceptance)
  $msiProperties = @{
    "5. MSSQLCMDLNUTILS.MSI" = "IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES"
  }

  # Create logs directory
  $logsPath = Join-Path $prereqsPath 'logs'
  if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
  }

  $installCount = 0
  $skipCount = 0
  $errorCount = 0

  foreach ($msiFile in $msiFiles) {
    $msiPath = Join-Path $prereqsPath $msiFile

    if (-not (Test-Path $msiPath)) {
      Write-POSLog "MSI file not found: $msiFile" -Level WARNING -Step $stepName
      $errorCount++
      continue
    }

    # Check if already installed by checking registry
    $msiBaseName = [System.IO.Path]::GetFileNameWithoutExtension($msiFile)
    $installed = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSObject.Properties.Name -contains 'DisplayName' -and
      $_.DisplayName -like "*$($msiBaseName.Substring(3))*" }

    if ($installed) {
      Write-POSLog "Already installed: $msiFile" -Level INFO -Step $stepName
      $skipCount++
      continue
    }

    Write-POSLog "Installing: $msiFile" -Level INFO -Step $stepName

    try {
      # Unblock file if downloaded from internet
      Unblock-File -LiteralPath $msiPath -ErrorAction SilentlyContinue

      # Create log file path
      $msiLog = Join-Path $logsPath "$msiFile.log"

      # Build msiexec arguments
      $arguments = @(
        '/i', "`"$msiPath`""
        '/qn'
        '/norestart'
        '/L*v', "`"$msiLog`""
      )

      # Add custom properties if defined for this MSI
      if ($msiProperties.ContainsKey($msiFile)) {
        $arguments += $msiProperties[$msiFile]
      }

      # Execute installation
      $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru -NoNewWindow

      if ($process.ExitCode -eq 0) {
        Write-POSLog "Successfully installed: $msiFile" -Level SUCCESS -Step $stepName
        $installCount++
      }
      elseif ($process.ExitCode -eq 1638) {
        # 1638 = Another version already installed
        Write-POSLog "Already installed (different version): $msiFile (ExitCode: 1638)" -Level INFO -Step $stepName
        $skipCount++
      }
      elseif ($process.ExitCode -eq 3010) {
        # 3010 = Success, reboot required
        Write-POSLog "Successfully installed: $msiFile (reboot required)" -Level SUCCESS -Step $stepName
        $installCount++
        $script:RebootRequired = $true
        $global:RebootRequired = $true
      }
      else {
        Write-POSLog "Failed to install: $msiFile (ExitCode: $($process.ExitCode)) - Check log: $msiLog" -Level ERROR -Step $stepName
        $errorCount++
      }
    }
    catch {
      Write-POSLog "Exception installing $msiFile" -Level ERROR -Step $stepName -Exception $_.Exception
      $errorCount++
    }
  }

  # Summary
  $totalFiles = $msiFiles.Count
  Write-POSLog "SQL Prerequisites installation complete - Total: $totalFiles, Installed: $installCount, Skipped: $skipCount, Errors: $errorCount" -Level $(if ($errorCount -gt 0) { 'WARNING' } else { 'SUCCESS' }) -Step $stepName

  if ($errorCount -gt 0) {
    Write-POSLog "Some SQL prerequisites failed to install. Check logs in: $logsPath" -Level WARNING -Step $stepName
  }
}

# Install CounterPoint (Priority 80)
Register-Step -Name "Install CounterPoint" -Tags @('POS') -Priority 80 -DependsOn @('CPSQLPrereqs') -Provides @('CounterPoint') -Action {
  $stepName = "Install CounterPoint"
  $cpPath = $Settings.POS.Installers.CounterPoint

  # Check if already installed
  $cpInstallPath = "C:\Program Files (x86)\Radiant Systems\CounterPoint"
  if (Test-Path $cpInstallPath) {
    Write-POSLog "CounterPoint appears to be already installed" -Level SUCCESS -Step $stepName
    return
  }

  # Check if installer directory exists
  if (-not (Test-Path $cpPath)) {
    Write-POSLog "CounterPoint installer directory not found: $cpPath" -Level WARNING -Step $stepName
    return
  }

  # Find ClientSetup.exe
  $setupExe = Join-Path $cpPath "ClientSetup.exe"
  if (-not (Test-Path $setupExe)) {
    Write-POSLog "CounterPoint ClientSetup.exe not found: $setupExe" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Starting CounterPoint installation (manual process)" -Level INFO -Step $stepName

  
  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "   _____ ____  _    _ _   _ _______ ______ _____  _____   ____ _____ _   _ _______ " -ForegroundColor Yellow
  Write-Host "  / ____/ __ \| |  | | \ | |__   __|  ____|  __ \|  __ \ / __ \_   _| \ | |__   __|" -ForegroundColor Yellow
  Write-Host " | |   | |  | | |  | |  \| |  | |  | |__  | |__) | |__) | |  | || | |  \| |  | |   " -ForegroundColor Yellow
  Write-Host " | |   | |  | | |  | | . ` |  | |  |  __| |  _  /|  ___/| |  | || | | . ` |  | |   " -ForegroundColor Yellow
  Write-Host " | |___| |__| | |__| | |\  |  | |  | |____| | \ \| |    | |__| || |_| |\  |  | |   " -ForegroundColor Yellow
  Write-Host "  \_____\____/ \____/|_|_\_|  |_|  |______|_|  \_\_|   __\____/_____|_|_\_|_ |_|   " -ForegroundColor Yellow
  Write-Host " |_   _| \ | |/ ____|__   __|/\   | |    | |        /\|__   __|_   _/ __ \| \ | |  " -ForegroundColor Yellow
  Write-Host "   | | |  \| | (___    | |  /  \  | |    | |       /  \  | |    | || |  | |  \| |  " -ForegroundColor Yellow
  Write-Host "   | | | . ` |\___ \   | | / /\ \ | |    | |      / /\ \ | |    | || |  | | . ` |  " -ForegroundColor Yellow
  Write-Host "  _| |_| |\  |____) |  | |/ ____ \| |____| |____ / ____ \| |   _| || |__| | |\  |  " -ForegroundColor Yellow
  Write-Host " |_____|_| \_|_____/   |_/_/    \_\______|______/_/    \_\_|  |_____\____/|_| \_|  " -ForegroundColor Yellow
  Write-Host "                                                                                    " -ForegroundColor Yellow
  Write-Host 
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host "The CounterPoint installer will launch in a separate window." -ForegroundColor White
  Write-Host "Please complete the installation manually." -ForegroundColor White

  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "        Select Low Speed Connection" -ForegroundColor Yellow
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host ""


  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "   Counterpoint installation configuration" -ForegroundColor Yellow
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host "SH Counterpoint Services" -ForegroundColor Green
  Write-Host ("Server Address:`t10.242.0.203") -ForegroundColor White
  Write-Host ("Server Port:`t`t51968") -ForegroundColor White
  Write-Host ""

  Write-Host "CH Counterpoint Services" -ForegroundColor Green
  Write-Host ("Server Address:`t10.242.0.201") -ForegroundColor White
  Write-Host ("Server Port:`t`t51968") -ForegroundColor White

  Write-Host ""
  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "Click cancel on the Register Counterpoint Node Window" -ForegroundColor White
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host ""

  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "Do NOT attempt to rename or edit the shortcuts manually after installation." -ForegroundColor Yellow
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host ""

  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "After installation is complete, return here and enter Y to continue." -ForegroundColor White
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host ""



  try {
    # Launch installer
    Write-POSLog "Launching CounterPoint ClientSetup.exe" -Level INFO -Step $stepName
    Start-Process -FilePath $setupExe -WorkingDirectory $cpPath
    Write-Host "Installer window opened. Complete the installation, then return here." -ForegroundColor Green

    # Wait for user confirmation
    do {
      Write-Host "`nEnter Y when CounterPoint installation is complete: " -NoNewline -ForegroundColor Yellow
      $response = Read-Host
    } while ($response -notmatch '^[Yy]$')

    Write-POSLog "User confirmed CounterPoint installation complete" -Level SUCCESS -Step $stepName

    # Verify installation
    if (Test-Path $cpInstallPath) {
      Write-POSLog "CounterPoint installation verified at: $cpInstallPath" -Level SUCCESS -Step $stepName
    }
    else {
      Write-POSLog "CounterPoint installation path not found - installation may have failed" -Level WARNING -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to launch CounterPoint installer" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Update CounterPoint (Priority 81)
Register-Step -Name "Update CounterPoint" -Tags @('POS') -Priority 81 -DependsOn @('CounterPoint') -Action {
  $stepName = "Update CounterPoint"
  $cpPath = $Settings.POS.Installers.CounterPoint

  # Find update file
  $updateExe = Join-Path $cpPath "CP_Patch_8.6.1.1.exe"
  if (-not (Test-Path $updateExe)) {
    Write-POSLog "CounterPoint update file not found: $updateExe" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Starting CounterPoint update (manual process)" -Level INFO -Step $stepName
  Write-Host "`n=========================================" -ForegroundColor Cyan
  Write-Host "  COUNTERPOINT UPDATE" -ForegroundColor Yellow
  Write-Host "=========================================" -ForegroundColor Cyan
  Write-Host "The CounterPoint update will launch in a separate window." -ForegroundColor White
  Write-Host "Please complete the update manually." -ForegroundColor White
  Write-Host "`nAfter update is complete, return here and enter Y to continue." -ForegroundColor Yellow
  Write-Host "=========================================`n" -ForegroundColor Cyan

  try {
    # Launch update
    Write-POSLog "Launching CounterPoint update: CP_Patch_8.6.1.1.exe" -Level INFO -Step $stepName
    Start-Process -FilePath $updateExe -WorkingDirectory $cpPath
    Write-Host "Update window opened. Complete the update, then return here." -ForegroundColor Green

    # Wait for user confirmation
    do {
      Write-Host "`nEnter Y when CounterPoint update is complete: " -NoNewline -ForegroundColor Yellow
      $response = Read-Host
    } while ($response -notmatch '^[Yy]$')

    Write-POSLog "User confirmed CounterPoint update complete" -Level SUCCESS -Step $stepName
  }
  catch {
    Write-POSLog "Failed to launch CounterPoint update" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# ===========================
# PHASE 7: CLEANUP & FINALIZATION (90-91)
# ===========================

# Run Baseline Debloat handled by HMG.Common or HMG.Baseline (Priority 90)

# Deploy Public Desktop Icons (Priority 90)
Register-Step -Name "Deploy Public Desktop Icons" -Tags @('POS') -Priority 90 -Action {
  $stepName = "Deploy Public Desktop Icons"
  $shortcutsPath = $Settings.POS.Deployment.DesktopShortcuts
  $publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")

  # Check if shortcuts directory exists
  if (-not (Test-Path $shortcutsPath)) {
    Write-POSLog "Desktop shortcuts directory not found: $shortcutsPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Deploying desktop shortcuts to Public Desktop" -Level INFO -Step $stepName

  try {
    # Copy all .lnk files to public desktop
    $shortcuts = Get-ChildItem -Path $shortcutsPath -Filter "*.lnk"
    foreach ($shortcut in $shortcuts) {
      $destination = Join-Path $publicDesktop $shortcut.Name
      Copy-Item -Path $shortcut.FullName -Destination $destination -Force
      Write-POSLog "Deployed shortcut: $($shortcut.Name)" -Level DEBUG -Step $stepName
    }

    if ($shortcuts.Count -gt 0) {
      Write-POSLog "Deployed $($shortcuts.Count) desktop shortcuts" -Level SUCCESS -Step $stepName
    }
    else {
      Write-POSLog "No shortcuts found to deploy" -Level INFO -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to deploy desktop shortcuts" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Run POS Custom App Removal (Priority 49)
Register-Step -Name "Run POS Custom App Removal" -Tags @('POS') -Priority 49 -Section 1 -Action {
  $stepName = "Run POS Custom App Removal"
  $debloatConfig = $Settings.Debloat

  if (-not $debloatConfig.POS.RemoveCustom) {
    Write-POSLog "POS custom app removal not enabled" -Level INFO -Step $stepName
    return
  }

  # Get the debloat script path
  $debloatScript = $debloatConfig.Baseline.ScriptPath
  if (-not (Test-Path $debloatScript)) {
    Write-POSLog "Debloat script not found: $debloatScript" -Level WARNING -Step $stepName
    return
  }

  # Get custom apps list path
  $customAppsList = $debloatConfig.POS.CustomAppsList
  if (-not (Test-Path $customAppsList)) {
    Write-POSLog "POS custom apps list not found: $customAppsList" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Running POS custom app removal (includes OneDrive) - 5 minute timeout" -Level INFO -Step $stepName
  Write-POSLog "Using custom apps list: $customAppsList" -Level INFO -Step $stepName

  try {
    # Build the argument string for PowerShell - include custom apps list path
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$debloatScript`" -RemoveAppsCustom -CustomAppsListPath `"$customAppsList`" -Sysprep -Silent"

    Write-Host "`nLaunching debloat script in separate window..." -ForegroundColor Cyan
    Write-Host "Window will close automatically when complete or after 5 minute timeout." -ForegroundColor Yellow

    # Create process start info - launches in visible window
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal

    # Start the process
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $started = $process.Start()

    if ($started) {
      Write-POSLog "Debloat process started (PID: $($process.Id)) - visible window" -Level INFO -Step $stepName

      # Wait for process with 5 minute timeout (300,000 milliseconds)
      $timeout = 300000
      $completed = $process.WaitForExit($timeout)

      if ($completed) {
        # Process completed within timeout
        $exitCode = $process.ExitCode
        if ($exitCode -eq 0) {
          Write-POSLog "POS custom app removal completed successfully" -Level SUCCESS -Step $stepName
        }
        else {
          Write-POSLog "POS custom app removal returned exit code: $exitCode" -Level WARNING -Step $stepName
        }
      }
      else {
        # Timeout occurred - kill the process
        Write-POSLog "POS custom app removal timed out after 5 minutes - killing process" -Level WARNING -Step $stepName
        Write-Host "`nDEBLOAT TIMEOUT - Killing stuck process..." -ForegroundColor Red
        try {
          $process.Kill()
          Write-POSLog "Killed stuck debloat process (PID: $($process.Id))" -Level WARNING -Step $stepName
        }
        catch {
          Write-POSLog "Failed to kill stuck process" -Level ERROR -Step $stepName -Exception $_.Exception
        }
      }

      $process.Dispose()
    }
    else {
      Write-POSLog "Failed to start debloat process" -Level ERROR -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to run POS custom app removal" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Deploy RDP Files and Shortcuts (Priority 92)
Register-Step -Name "Deploy RDP Files and Shortcuts" -Tags @('POS') -Priority 92 -Action {
  $stepName = "Deploy RDP Files and Shortcuts"
  $rdpPath = $Settings.POS.Deployment.RDPFiles
  $publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
  $counterpointPath = "C:\Program Files\Counterpoint"

  # Check if RDP directory exists
  if (-not (Test-Path $rdpPath)) {
    Write-POSLog "RDP files directory not found: $rdpPath" -Level WARNING -Step $stepName
    return
  }

  Write-POSLog "Deploying CounterPoint RDP files and shortcuts" -Level INFO -Step $stepName

  try {
    # Ensure CounterPoint directory exists
    if (-not (Test-Path $counterpointPath)) {
      Write-POSLog "Creating CounterPoint directory: $counterpointPath" -Level INFO -Step $stepName
      New-Item -ItemType Directory -Path $counterpointPath -Force | Out-Null
    }

    # Deploy .ico files to CounterPoint directory - FIXED: Wrap in @() to ensure array
    $icoFiles = @(Get-ChildItem -Path $rdpPath -Filter "*.ico" -ErrorAction SilentlyContinue)
    foreach ($icoFile in $icoFiles) {
      $destination = Join-Path $counterpointPath $icoFile.Name
      Copy-Item -Path $icoFile.FullName -Destination $destination -Force
      Write-POSLog "Deployed icon: $($icoFile.Name) to CounterPoint directory" -Level DEBUG -Step $stepName
    }

    # Deploy .rdp files to CounterPoint directory - FIXED: Wrap in @() to ensure array
    $rdpFiles = @(Get-ChildItem -Path $rdpPath -Filter "*.rdp" -ErrorAction SilentlyContinue)
    foreach ($rdpFile in $rdpFiles) {
      $destination = Join-Path $counterpointPath $rdpFile.Name
      Copy-Item -Path $rdpFile.FullName -Destination $destination -Force
      Write-POSLog "Deployed RDP file: $($rdpFile.Name) to CounterPoint directory" -Level DEBUG -Step $stepName
    }

    # Deploy .lnk files to Public Desktop - FIXED: Wrap in @() to ensure array
    $lnkFiles = @(Get-ChildItem -Path $rdpPath -Filter "*.lnk" -ErrorAction SilentlyContinue)
    foreach ($lnkFile in $lnkFiles) {
      $destination = Join-Path $publicDesktop $lnkFile.Name
      Copy-Item -Path $lnkFile.FullName -Destination $destination -Force
      Write-POSLog "Deployed shortcut: $($lnkFile.Name) to Public Desktop" -Level DEBUG -Step $stepName
    }

    # Summary report - Now safe because all variables are guaranteed to be arrays
    $totalFiles = $icoFiles.Count + $rdpFiles.Count + $lnkFiles.Count
    if ($totalFiles -gt 0) {
      Write-POSLog "Deployed $totalFiles CounterPoint files - Icons: $($icoFiles.Count), RDP: $($rdpFiles.Count), Shortcuts: $($lnkFiles.Count)" -Level SUCCESS -Step $stepName
    }
    else {
      Write-POSLog "No CounterPoint files found to deploy" -Level INFO -Step $stepName
    }
  }
  catch {
    Write-POSLog "Failed to deploy CounterPoint RDP files and shortcuts" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

# Clean Up Desktop Shortcuts (Priority 93)
Register-Step -Name "Clean Up Desktop Shortcuts" -Tags @('POS') -Priority 93 -Action {
  $stepName = "Clean Up Desktop Shortcuts"
  $publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")

  Write-POSLog "Cleaning up desktop shortcuts" -Level INFO -Step $stepName

  $shortcutsToDelete = @(
    "Microsoft Edge.lnk",
    "NCR Counterpoint.lnk"
  )

  $deletedCount = 0
  foreach ($shortcut in $shortcutsToDelete) {
    $shortcutPath = Join-Path $publicDesktop $shortcut
    if (Test-Path $shortcutPath) {
      try {
        Remove-Item -Path $shortcutPath -Force
        Write-POSLog "Deleted shortcut: $shortcut" -Level SUCCESS -Step $stepName
        $deletedCount++
      }
      catch {
        Write-POSLog "Failed to delete shortcut: $shortcut" -Level WARNING -Step $stepName -Exception $_.Exception
      }
    }
    else {
      Write-POSLog "Shortcut not found (already removed or never created): $shortcut" -Level DEBUG -Step $stepName
    }
  }

  # Rename NCR Counterpoint Offline POS.lnk to OFFLINE.lnk
  $offlineShortcut = Join-Path $publicDesktop "NCR Counterpoint Offline POS.lnk"
  $newOfflineName = Join-Path $publicDesktop "OFFLINE.lnk"

  if (Test-Path $offlineShortcut) {
    try {
      # Remove existing OFFLINE.lnk if it exists
      if (Test-Path $newOfflineName) {
        Remove-Item -Path $newOfflineName -Force
      }
      
      Rename-Item -Path $offlineShortcut -NewName "OFFLINE.lnk" -Force
      Write-POSLog "Renamed 'NCR Counterpoint Offline POS.lnk' to 'OFFLINE.lnk'" -Level SUCCESS -Step $stepName
    }
    catch {
      Write-POSLog "Failed to rename offline shortcut" -Level WARNING -Step $stepName -Exception $_.Exception
    }
  }
  else {
    Write-POSLog "Offline shortcut not found: NCR Counterpoint Offline POS.lnk" -Level DEBUG -Step $stepName
  }

  Write-POSLog "Desktop cleanup complete - Deleted: $deletedCount shortcuts" -Level SUCCESS -Step $stepName
}

# Disable Multi-Monitor Taskbar (Priority 95)
Register-Step -Name "Disable Multi-Monitor Taskbar" -Tags @('POS') -Priority 95 -Action {
  $stepName = "Disable Multi-Monitor Taskbar"
  
  Write-POSLog "Disabling multi-monitor taskbar feature" -Level INFO -Step $stepName
  
  try {
    # Create the registry path if it doesn't exist
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $regPath)) {
      New-Item -Path $regPath -Force | Out-Null
      Write-POSLog "Created registry path: $regPath" -Level DEBUG -Step $stepName
    }
    
    # Set the registry value to disable multi-monitor taskbar
    Set-ItemProperty -Path $regPath -Name "MMTaskbarEnabled" -Value 0 -Type DWord -Force
    Write-POSLog "Set MMTaskbarEnabled to 0 (disabled)" -Level SUCCESS -Step $stepName
    
    # Get explorer processes before killing
    $explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
    
    if ($explorerProcesses) {
      Write-POSLog "Restarting Windows Explorer to apply changes" -Level INFO -Step $stepName
      
      # Kill explorer.exe
      Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
      
      # Wait a moment for it to fully terminate
      Start-Sleep -Seconds 2
      
      # Restart explorer.exe
      Start-Process explorer.exe
      
      Write-POSLog "Windows Explorer restarted successfully" -Level SUCCESS -Step $stepName
      
      # Wait for Explorer to fully initialize
      Start-Sleep -Seconds 3
    }
    else {
      Write-POSLog "Explorer process not found - may be running in a non-interactive session" -Level WARNING -Step $stepName
    }
    
    Write-POSLog "Multi-monitor taskbar disabled successfully" -Level SUCCESS -Step $stepName
  }
  catch {
    Write-POSLog "Failed to disable multi-monitor taskbar" -Level ERROR -Step $stepName -Exception $_.Exception
  }
}

Export-ModuleMember -Function @()  # No functions to export, only steps registered
