<#
.SYNOPSIS
    Baseline configuration module containing steps that run on ALL systems.

.DESCRIPTION
    This module registers configuration steps that are common across all system types.
    It depends on HMG.Core for the step registration engine and helper functions.

    Steps included:
    - Core software (Chrome, Office, GlobalProtect, Staging Agent)
    - User configuration (local user creation, autologon)
    - System settings (timezone, power management)
    - Cleanup (debloat scripts)

    These steps use tags to control which roles execute them:
    - ALL: Runs on every system
    - Specific roles: POS, MGR, CAM, ADMIN

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 3.1.0 - Checkpoint System Enhanced
    Requires: PowerShell 5.1 or higher
    Requires: HMG.Core module
    Must be run as Administrator
    
.CHANGELOG
    v3.1.0 - Checkpoint system enhancements:
           - FIXED: All checkpoints now pass Settings to Invoke-RebootCheckpoint for proper username determination
           - FIXED: Priority 59 checkpoint uses 'Never' mode to prevent unnecessary reboot after user creation
           - All resume tasks now run as the configured user instead of SYSTEM
           - Autologon preserved across reboots
           - Improved checkpoint-to-user coordination
    v3.0.1 - BUGFIX: Removed Priority 39 checkpoint that caused premature reboot
           - System now flows through Section 1 into Section 2 without interruption
           - User creation and autologon now complete before first reboot
           - First reboot occurs at Priority 59 after user configuration
    v3.0.0 - Converted to Phase 4 checkpoint system
           - Added section numbers to all steps
           - Added checkpoint steps for reboot management
           - Organized steps into 5 logical sections
           - Removed need for manual reboot flag management
    v2.0.1 - Moved .NET 3.5 to POS module (POS-only requirement)
#>

#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import HMG.Core for framework functions
# The Core module must be imported here for all the framework functions to be available
$coreModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "HMG.Core\HMG.Core.psd1"
if (-not (Test-Path $coreModulePath)) {
  throw "HMG.Core module not found at: $coreModulePath. Cannot load HMG.Baseline."
}

# Import Core module for THIS module's use (not re-exported)
# HMG.Core provides the step registration framework that Baseline uses
Write-Verbose "HMG.Baseline: Loading HMG.Core module for step registration..."
Import-Module $coreModulePath -Force -Global

# IMPORTANT: We do NOT re-export Core functions. Each module has a single responsibility:
# - HMG.Core: Provides the framework (Register-Step, Write-Status, etc.)
# - HMG.Baseline: Registers common configuration steps
# Consumers must import both modules explicitly for clear dependencies

#region Step Implementations

<#
================================================================================
BASELINE STEP IMPLEMENTATION SECTION - PHASE 4 CHECKPOINT SYSTEM
================================================================================

This section contains configuration steps that run on ALL systems (or role-filtered
subsets). Steps are organized into 4 logical sections with checkpoints:

  SECTION 1: System Configuration (Priority 10-39)
    - Power settings, timezone, Office removal, Chrome installation
    - No checkpoint (flows directly into Section 2)
  
  SECTION 2: User Configuration (Priority 50-59)
    - Local user creation, autologon configuration
    - Checkpoint at Priority 59
  
  SECTION 3: Software Installation (Priority 65-74)
    - GlobalProtect VPN, Staging Agent, Office installation
    - Checkpoint at Priority 74
  
  SECTION 4: Cleanup & Finalization (Priority 90-99)
    - Baseline debloat scripts
    - Final checkpoint at Priority 99

NOTE: .NET Framework 3.5 moved to HMG.POS module (only POS systems require it for SQL Server)

Each step includes:
- Name: Unique identifier
- Tags: Role-based execution (ALL, POS, MGR, CAM, ADMIN)
- Priority: Execution order within its section
- Section: Logical grouping (1-4)
- DependsOn: Prerequisites that must complete first
- Provides: Capabilities made available after completion
- Action: ScriptBlock with the actual configuration logic

#>

# ===========================
# SECTION 1: SYSTEM CONFIGURATION (10-39)
# ===========================
# Power settings, timezone, Office removal, Chrome installation
# No checkpoint - flows directly into Section 2

# ===========================
# SECTION 3: SOFTWARE INSTALLATION (65-74)
# ===========================
# GlobalProtect VPN, Staging Agent, Office installation
# Checkpoint at Priority 74

<#
.STEP
    Install Chrome

.DESCRIPTION
    Installs Google Chrome browser silently using the enterprise MSI installer.
    Configured for all system types as Chrome is the standard browser.

.TAGS
    ALL (runs on all system types)

.PRIORITY
    25 (early, before most other software)

.PROVIDES
    Browser capability
#>
Register-Step -Name "Install Chrome" -Tags @('ALL') -Priority 25 -Section 1 -Provides @('Browser') -Action {
  # Check if this role should have Chrome
  if ($Settings.Chrome.Roles -notcontains $Role) { return }

  # Check if already installed
  $exe = "$Env:ProgramFiles\Google\Chrome\Application\chrome.exe"
  if (Test-Path $exe) {
    Write-Status "Chrome already installed" 'Success'
    return
  }

  # Verify MSI file exists
  $msi = Join-Path $Settings.InstallersPath $Settings.Chrome.Msi
  if (-not (Test-Path $msi)) {
    Write-Status "Chrome MSI not found: $msi" 'Warning'
    return
  }

  # Install Chrome silently
  Write-Status "Installing Chrome..." 'Info'
  Start-Process msiexec.exe -ArgumentList "/i `"$msi`" $($Settings.Chrome.Arguments)" -Wait

  # Verify installation
  if (Test-Path $exe) {
    Write-Status "Chrome installed successfully" 'Success'
  }
  else {
    Write-Status "Chrome installation may have failed" 'Warning'
  }
}

# NOTE: Priority 39 checkpoint removed to allow user creation to complete before first reboot
# The system will now flow through Section 1 directly into Section 2 (user configuration)
# before hitting the Priority 59 checkpoint after user setup is complete

<#
.STEP
    Install GlobalProtect VPN

.DESCRIPTION
    Installs Palo Alto GlobalProtect VPN client for systems that need
    remote network access (MGR and ADMIN systems).

.TAGS
    MGR, ADMIN

.PRIORITY
    65 (after .NET Framework which is required)

.DEPENDS ON
    .NET35 (required by GlobalProtect installer)
#>
Register-Step -Name "Install GlobalProtect VPN" -Tags @('MGR', 'ADMIN') -Priority 65 -Section 3 -Action {
  # Check if GlobalProtect is enabled globally
  if (-not $Settings.GlobalProtect.Enabled) {
    Write-Status "GlobalProtect not enabled in settings" 'Info'
    return
  }

  # Check if this role should have GlobalProtect
  if ($Settings.GlobalProtect.Roles -notcontains $Role) {
    Write-Status "GlobalProtect not configured for $Role" 'Info'
    return
  }

  # Check if already installed
  $gpPath = "${Env:ProgramFiles}\Palo Alto Networks\GlobalProtect\GlobalProtect.exe"
  if (Test-Path $gpPath) {
    Write-Status "GlobalProtect already installed" 'Success'
    return
  }

  # Verify MSI file exists
  $msi = Join-Path $Settings.InstallersPath $Settings.GlobalProtect.Msi
  if (-not (Test-Path $msi)) {
    Write-Status "GlobalProtect MSI not found: $msi" 'Warning'
    return
  }

  # Install GlobalProtect
  Write-Status "Installing GlobalProtect VPN..." 'Info'
  Start-Process msiexec.exe -ArgumentList "/i `"$msi`" $($Settings.GlobalProtect.Arguments)" -Wait

  # Verify installation
  if (Test-Path $gpPath) {
    Write-Status "GlobalProtect installed successfully" 'Success'
  }
  else {
    Write-Status "GlobalProtect installation may have failed" 'Warning'
  }
}

<#
.STEP
    Install Staging Agent

.DESCRIPTION
    Installs the Perch Works staging/deployment agent for remote management.
    Can be configured for any role via settings.

.TAGS
    ALL (but role-filtered via settings)

.PRIORITY
    66 (after GlobalProtect)
#>
Register-Step -Name "Install Staging Agent" -Tags @('ALL') -Priority 66 -Section 3 -Action {
  # Check if staging agent is enabled globally
  if (-not $Settings.StagingAgent.Enabled) {
    Write-Status "Staging Agent not enabled in settings" 'Info'
    return
  }

  # Check if this role should have the staging agent
  if ($Settings.StagingAgent.Roles -notcontains $Role) {
    Write-Status "Staging Agent not configured for $Role" 'Info'
    return
  }

  # Check if already installed (path may need adjustment based on actual install)
  $agentPath = "${Env:ProgramFiles}\StagingAgent\agent.exe"
  if (Test-Path $agentPath) {
    Write-Status "Staging Agent already installed" 'Success'
    return
  }

  # Verify MSI file exists
  $msi = Join-Path $Settings.InstallersPath $Settings.StagingAgent.Msi
  if (-not (Test-Path $msi)) {
    Write-Status "Staging Agent MSI not found: $msi" 'Warning'
    return
  }

  # Install Staging Agent
  Write-Status "Installing Staging Agent..." 'Info'
  Start-Process msiexec.exe -ArgumentList "/i `"$msi`" $($Settings.StagingAgent.Arguments)" -Wait

  Write-Status "Staging Agent installation completed" 'Info'
}

<#
.STEP
    Remove Office

.DESCRIPTION
    Uninstalls Microsoft Office from POS and CAM systems where it's not needed.
    Uses Office Deployment Tool with uninstall.xml configuration.

.TAGS
    POS, CAM

.PRIORITY
    20 (early, runs before Office installation to ensure clean state)
#>
Register-Step -Name "Remove Office" -Tags @('POS', 'CAM') -Priority 20 -Section 1 -Action {
  # Check if this role should remove Office
  if ($Settings.Office.Uninstall.Roles -notcontains $Role) { return }

  # Check if Office is installed
  if (-not (Test-OfficeInstalled)) {
    Write-Status 'Office not installed' 'Success'
    return
  }

  # Uninstall Office using ODT
  Write-Status "Removing Office..." 'Info'
  Invoke-ODT -SourcePath $Settings.Office.Uninstall.SourcePath -XmlFile $Settings.Office.Uninstall.Xml

  # Verify removal
  if (-not (Test-OfficeInstalled)) {
    Write-Status "Office removed successfully" 'Success'
  }
  else {
    Write-Status "Office removal may have failed" 'Warning'
  }
}

<#
.STEP
    Install Office

.DESCRIPTION
    Installs Microsoft Office on MGR and ADMIN systems where it's needed.
    Uses Office Deployment Tool with config.xml configuration.

.TAGS
    MGR, ADMIN

.PRIORITY
    70 (after .NET Framework which is required)

.DEPENDS ON
    .NET35 (required by Office installer)

.PROVIDES
    Office capability
#>
Register-Step -Name "Install Office" -Tags @('MGR', 'ADMIN') -Priority 70 -Section 3 -Provides @('Office') -Action {
  # Check if this role should have Office
  if ($Settings.Office.Install.Roles -notcontains $Role) { return }

  # Check if Office is already installed
  if (Test-OfficeInstalled) {
    Write-Status 'Office already installed' 'Success'
    return
  }

  # Install Office using ODT
  Write-Status "Installing Office..." 'Info'
  Invoke-ODT -SourcePath $Settings.Office.Install.SourcePath -XmlFile $Settings.Office.Install.Xml

  # Verify installation
  if (Test-OfficeInstalled) {
    Write-Status "Office installed successfully" 'Success'
  }
  else {
    Write-Status "Office installation may have failed" 'Warning'
  }
}

# Checkpoint after Section 3: Software Installation (Priority 74, Section 3)
Register-Step -Name "Checkpoint: After Software Installation" -Tags @('ALL') -Priority 74 -Section 3 -Action {
  $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" }
  
  # Get Settings from framework for username determination
  $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) {
    Get-HMGFramework
  } else {
    $null
  }
  $frameworkSettings = if ($framework) { $framework.Settings } else { $null }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-Software-Installation' `
    -Section 3 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 90 `
    -Settings $frameworkSettings
  
  if ($rebooting) { return }
}

# ===========================
# SECTION 2: USER CONFIGURATION (50-59)
# ===========================
# Local user creation, autologon configuration
# Checkpoint at Priority 59

<#
.STEP
    Create Local User

.DESCRIPTION
    Creates or updates the local user account for system login. Handles three scenarios:
    1. CAM systems: Prompts for unique username/password per system
    2. Other systems with override: Uses machine-specific override from username-overrides.psd1
    3. Other systems standard: Uses role password from encrypted blob or settings

    Username generation options:
    - Manual override (username-overrides.psd1)
    - Hardcoded in settings (Name field)
    - Auto-generated from computer name (removes hyphens)

.TAGS
    ALL (all systems need a local user)

.PRIORITY
    50 (mid-range, after software installs, before autologon)

.PROVIDES
    LocalUser, UserAccount capabilities
#>
Register-Step -Name "Create Local User" -Tags @('ALL') -Priority 50 -Section 2 -Provides @('LocalUser', 'UserAccount') -Critical -Action {
  $userConfig = $Settings.LocalUsers.$Role

  # Initialize variables
  $password = $null
  $userName = $null

  # === CAM SYSTEMS: UNIQUE CREDENTIALS ===
  if ($Role -eq 'CAM') {
    Write-Status "CAM systems require unique credentials per machine" 'Info'
    Write-Host "`n" -NoNewline
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host " CAM SYSTEM CREDENTIAL CONFIGURATION" -ForegroundColor Yellow
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "Each camera system requires unique login credentials." -ForegroundColor White
    Write-Host "Please enter the username and password for this specific CAM system." -ForegroundColor White
    Write-Host "`n" -NoNewline

    # Prompt for CAM-specific username with validation
    do {
      $userName = Read-Host "Enter username for this CAM system"
      $userName = $userName.Trim()

      if ([string]::IsNullOrWhiteSpace($userName)) {
        Write-Host "Username cannot be empty. Please try again." -ForegroundColor Red
      }
      elseif ($userName.Length -gt 20) {
        Write-Host "Username must be 20 characters or less. Please try again." -ForegroundColor Red
        $userName = $null
      }
      elseif ($userName -match '^\d') {
        Write-Host "Username cannot start with a number. Please try again." -ForegroundColor Red
        $userName = $null
      }
    } while ([string]::IsNullOrWhiteSpace($userName))

    Write-Status "Using CAM-specific username: $userName" 'Info'

    # Prompt for CAM-specific password with confirmation
    do {
      $password = Read-Host "Enter password for CAM user '$userName'" -AsSecureString
      $confirmPassword = Read-Host "Confirm password for CAM user '$userName'" -AsSecureString

      # Compare passwords
      $pass1 = ConvertTo-PlainText -Secure $password
      $pass2 = ConvertTo-PlainText -Secure $confirmPassword

      if ($pass1 -ne $pass2) {
        Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
        $password = $null
      }
      elseif ([string]::IsNullOrEmpty($pass1)) {
        Write-Host "Password cannot be empty. Please try again." -ForegroundColor Red
        $password = $null
      }
    } while ($null -eq $password)

    # Store credentials for autologon step using framework
    $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) { 
      Get-HMGFramework 
    } else { 
      $null 
    }
    
    if ($framework) {
      # Use framework's secure CAM credential storage
      $framework.SetCAMCredentials.Invoke($userName, $password)
      Write-Verbose "CAM credentials stored in HMGFramework"
    } else {
      # Fallback to script scope (legacy)
      $script:CAMUsername = $userName
      $script:CAMPassword = $password
      Write-Verbose "CAM credentials stored in script scope (legacy)"
    }

    Write-Status "CAM credentials configured successfully" 'Success'
  }
  # === NON-CAM SYSTEMS: STANDARD CREDENTIAL HANDLING ===
  else {
    # Determine username with priority order:
    # 1. Machine-specific override
    # 2. Hardcoded in settings
    # 3. Auto-generated from computer name

    $userName = $null

    # Check for machine-specific override file
    $overrideFile = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "config\username-overrides.psd1"
    if (Test-Path $overrideFile) {
      try {
        $overrides = Import-PowerShellDataFile $overrideFile
        if ($overrides.Overrides -and $overrides.Overrides.ContainsKey($env:COMPUTERNAME)) {
          $machineOverride = $overrides.Overrides[$env:COMPUTERNAME]
          if ($machineOverride.Username) {
            $userName = $machineOverride.Username
            Write-Status "Using machine-specific username override: $userName" 'Info'
          }
        }
      }
      catch {
        Write-Status "Failed to load username overrides: $_" 'Warning'
      }
    }

    # If no override, check settings configuration
    if (-not $userName) {
      if ($userConfig.Name -and $userConfig.Name -ne '' -and $userConfig.Name.ToUpper() -ne 'AUTO') {
        $userName = $userConfig.Name
        Write-Status "Using hardcoded username from settings: $userName" 'Info'
      }
      else {
        $userName = Get-SanitizedUsername
        Write-Status "Using generated username from computer name: $userName" 'Info'
      }
    }

    # Get password using centralized function
    try {
      $passwordText = Get-RolePassword -Role $Role
      Write-Status "Retrieved password for $Role (length: $($passwordText.Length))" 'Info'
    }
    catch {
      Write-Status "Failed to retrieve password: $_" 'Error'
      return
    }

    # Convert to SecureString
    Write-Status "Converting password to SecureString..." 'Info'
    try {
      $password = Microsoft.PowerShell.Security\ConvertTo-SecureString -String $passwordText -AsPlainText -Force
      if ($null -eq $password) {
        Write-Status "ConvertTo-SecureString returned null!" 'Error'
        return
      }
      Write-Status "SecureString created successfully" 'Success'
    }
    catch {
      Write-Status "Failed to convert password to SecureString: $_" 'Error'
      return
    }
  }

  # === CREATE OR UPDATE USER ACCOUNT ===
  # Validate we have both username and password
  if ([string]::IsNullOrEmpty($userName)) {
    Write-Status "Username is null or empty - cannot create user" 'Error'
    return
  }

  if ($null -eq $password) {
    Write-Status "Password SecureString is null - cannot create user" 'Error'
    return
  }

  # Check if user already exists
  $existing = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue

  if ($existing) {
    # Update existing user
    Write-Status "User '$userName' already exists. Updating password and settings." 'Info'
    Set-LocalUser -Name $userName -Password $password
    Set-LocalUser -Name $userName -PasswordNeverExpires $true -UserMayChangePassword $false
  }
  else {
    # Create new user
    $description = "Auto-created local user for $Role role"
    New-LocalUser -Name $userName -Password $password -Description $description | Out-Null
    Set-LocalUser -Name $userName -PasswordNeverExpires $true -UserMayChangePassword $false
    Write-Status "User '$userName' created with non-expiring password" 'Success'
  }

  # Ensure proper group membership
  foreach ($groupType in @('Users')) {
    if ($userConfig.Admin -eq $true) {
      $groupType = 'Administrators'
    }
    $group = Resolve-BuiltinGroupName -Builtin $groupType
    $member = Get-LocalGroupMember -Group $group -Member $userName -ErrorAction SilentlyContinue
    if (-not $member) {
      Add-LocalGroupMember -Group $group -Member $userName
      Write-Status "Added '$userName' to '$group'" 'Success'
    }
  }

  # Store username in framework and HMGState for autologon step to access
  $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) { 
    Get-HMGFramework 
  } else { 
    $null 
  }
  
  if ($framework) {
    $framework.ConfiguredUser = $userName
    Write-Verbose "Username stored in HMGFramework: $userName"
  }
  
  # Also store in HMGState for backward compatibility
  $global:HMGState.ConfiguredUser = $userName
}

<#
.STEP
    Configure Autologon

.DESCRIPTION
    Configures Windows automatic logon using Sysinternals Autologon tool.
    Different handling for CAM vs other systems:
    - CAM: Uses credentials collected during user creation
    - Other: Uses credentials from encrypted blob or settings

.TAGS
    POS, CAM (systems that need unattended boot)

.PRIORITY
    55 (after local user creation)

.DEPENDS ON
    LocalUser (must create user account first)
#>
Register-Step -Name "Configure Autologon" -Tags @('POS', 'CAM') -Priority 55 -Section 2 -DependsOn @('LocalUser') -Action {
  $autologonConfig = $Settings.Autologon.$Role

  # Check if autologon is enabled for this role
  if (-not $autologonConfig.Enable) {
    Write-Status "Autologon not enabled for $Role" 'Info'
    return
  }

  # === CAM SYSTEMS: USE PROMPTED CREDENTIALS ===
  if ($Role -eq 'CAM') {
    # Try to get credentials from framework first, then fallback to script scope
    $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) { 
      Get-HMGFramework 
    } else { 
      $null 
    }
    
    $camCreds = $null
    if ($framework) {
      $camCreds = $framework.GetCAMCredentials.Invoke()
      if ($camCreds.Username -and $camCreds.Password) {
        $userName = $camCreds.Username
        # Need to load Security module for ConvertFrom-SecureStringPlain
        $secModule = Get-Module -Name 'HMG.Security' -ErrorAction SilentlyContinue
        if ($secModule) {
          $passwordText = ConvertFrom-SecureStringPlain -Secure $camCreds.Password
        } else {
          # Fallback to basic conversion
          $cred = New-Object System.Management.Automation.PSCredential("dummy", $camCreds.Password)
          $passwordText = $cred.GetNetworkCredential().Password
        }
        Write-Status "Using CAM-specific credentials from framework for autologon" 'Info'
      }
    }
    
    # Fallback to script scope if framework not available or empty
    if (-not $userName -and $script:CAMUsername -and $script:CAMPassword) {
      $userName = $script:CAMUsername
      # Need Security module or use built-in conversion
      $secModule = Get-Module -Name 'HMG.Security' -ErrorAction SilentlyContinue
      if ($secModule) {
        $passwordText = ConvertFrom-SecureStringPlain -Secure $script:CAMPassword
      } else {
        # Fallback to basic conversion
        $cred = New-Object System.Management.Automation.PSCredential("dummy", $script:CAMPassword)
        $passwordText = $cred.GetNetworkCredential().Password
      }
      Write-Status "Using CAM-specific credentials from script scope for autologon" 'Info'
    }
    
    if (-not $userName) {
      Write-Status "CAM credentials not found. Cannot configure autologon." 'Warning'
      Write-Status "Please ensure the Create Local User step completed successfully." 'Warning'
      return
    }
  }
  # === NON-CAM SYSTEMS: USE STANDARD CREDENTIALS ===
  else {
    # Get username from framework/HMGState (set by Create Local User step) or config
    $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) { 
      Get-HMGFramework 
    } else { 
      $null 
    }
    
    $userName = if ($framework -and $framework.ConfiguredUser) {
      $framework.ConfiguredUser
    }
    elseif ($global:HMGState.ConfiguredUser) {
      $global:HMGState.ConfiguredUser
    }
    elseif (-not [string]::IsNullOrEmpty($autologonConfig.User)) {
      $autologonConfig.User
    }
    else {
      Get-SanitizedUsername
    }

    # Get password using centralized function
    try {
      $passwordText = Get-RolePassword -Role $Role
    }
    catch {
      Write-Status "Failed to retrieve password for autologon: $_" 'Warning'
      return
    }
  }

  # === CONFIGURE AUTOLOGON ===
  # Find Sysinternals Autologon tool
  $exe = Find-AutologonExe
  if (-not $exe) {
    Write-Status "Sysinternals Autologon tool not found. Skipping autologon configuration." 'Warning'
    return
  }

  # Prepare arguments
  $domain = if ($autologonConfig.Domain) { $autologonConfig.Domain } else { $env:COMPUTERNAME }
  $args = @($userName, $domain, $passwordText, '/AcceptEula')

  # Execute Autologon
  Write-Status "Configuring autologon for $domain\$userName..." 'Info'
  $p = Start-Process -FilePath $exe -ArgumentList $args -PassThru -Wait -WindowStyle Hidden

  # Check result
  switch ($p.ExitCode) {
    0 { Write-Status "Autologon configured successfully" 'Success' }
    1 { Write-Status "Autologon failed: Access denied or invalid credentials" 'Error' }
    2 { Write-Status "Autologon failed: User not found" 'Error' }
    default { Write-Status "Autologon failed with exit code: $($p.ExitCode)" 'Error' }
  }
}

# Checkpoint after Section 2: User Configuration (Priority 59, Section 2)
Register-Step -Name "Checkpoint: After User Configuration" -Tags @('ALL') -Priority 59 -Section 2 -Action {
  $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" }
  
  # Get Settings from framework to pass to checkpoint for username determination
  $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) {
    Get-HMGFramework
  } else {
    $null
  }
  $frameworkSettings = if ($framework) { $framework.Settings } else { $null }
  
  # Use 'Never' mode - user creation doesn't require reboot
  # Only reboot if a step explicitly sets $global:RebootRequired
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-User-Configuration' `
    -Section 2 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 65 `
    -RebootMode 'Never' `
    -Settings $frameworkSettings
  
  if ($rebooting) { return }
}

# (Section 1 continued - system optimization steps)

<#
.STEP
    Set Time Zone

.DESCRIPTION
    Sets the system time zone to Eastern Standard Time (EST).
    Consistent timezone simplifies logging, scheduling, and troubleshooting.

.TAGS
    ALL

.PRIORITY
    15 (very early, before most configuration)
#>
Register-Step -Name "Set Time Zone" -Tags @('ALL') -Priority 15 -Section 1 -Action {
  $targetZone = $Settings.TimeZone.Id
  $current = (Get-TimeZone).Id

  # Skip if already set
  if ($current -eq $targetZone) {
    Write-Status "Time zone already set to $targetZone" 'Success'
    return
  }

  # Change timezone
  Set-TimeZone -Id $targetZone
  Write-Status "Time zone changed from $current to $targetZone" 'Success'
}

<#
.STEP
    Configure Power Settings

.DESCRIPTION
    Configures power management settings based on role:
    - POS/CAM: High performance, no sleep, no hibernation
    - MGR/ADMIN: Balanced, with appropriate timeouts

    Settings include:
    - Power scheme (Balanced/High Performance)
    - Display timeout (AC and DC)
    - Sleep timeout (AC and DC)
    - Disk timeout
    - Hibernation (disabled for POS/CAM)

.TAGS
    ALL

.PRIORITY
    10 (very early, affects system behavior)
#>
Register-Step -Name "Configure Power Settings" -Tags @('ALL') -Priority 10 -Section 1 -Action {
  $powerConfig = $Settings.PowerPolicies.$Role
  if (-not $powerConfig) {
    Write-Status "No power configuration for $Role" 'Info'
    return
  }

  # Map power scheme name to GUID
  $schemeGuid = switch ($powerConfig.Scheme) {
    'Balanced' { '381b4222-f694-41f0-9685-ff5bb260df2e' }
    'High' { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
    'PowerSaver' { 'a1841308-3541-4fab-bc81-f71556f20b4a' }
    default { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }  # Default to High performance
  }

  # Activate the power scheme
  powercfg /setactive $schemeGuid
  Write-Status "Set power scheme to $($powerConfig.Scheme)" 'Success'

  # Configure display timeout
  if ($null -ne $powerConfig.AC_DisplayMin) {
    powercfg /change monitor-timeout-ac $powerConfig.AC_DisplayMin
    Write-Status "Set AC display timeout to $($powerConfig.AC_DisplayMin) minutes" 'Info'
  }
  if ($null -ne $powerConfig.DC_DisplayMin) {
    powercfg /change monitor-timeout-dc $powerConfig.DC_DisplayMin
    Write-Status "Set DC display timeout to $($powerConfig.DC_DisplayMin) minutes" 'Info'
  }

  # Configure sleep timeout
  if ($null -ne $powerConfig.AC_SleepMin) {
    powercfg /change standby-timeout-ac $powerConfig.AC_SleepMin
    Write-Status "Set AC sleep timeout to $($powerConfig.AC_SleepMin) minutes" 'Info'
  }
  if ($null -ne $powerConfig.DC_SleepMin) {
    powercfg /change standby-timeout-dc $powerConfig.DC_SleepMin
    Write-Status "Set DC sleep timeout to $($powerConfig.DC_SleepMin) minutes" 'Info'
  }

  # Disable disk timeout (set to never)
  powercfg /change disk-timeout-ac 0
  powercfg /change disk-timeout-dc 0

  # Disable hibernation for POS/CAM systems (retail/camera systems should stay ready)
  if ($Role -in @('POS', 'CAM')) {
    powercfg /hibernate off
    Write-Status "Hibernation disabled for $Role" 'Info'
  }
}

<#
.STEP
    Configure Screen Timeout

.DESCRIPTION
    Additional screen timeout configuration for MGR and ADMIN systems that
    overrides the default power settings. Provides separate control from
    general power management.

.TAGS
    MGR, ADMIN

.PRIORITY
    11 (right after power settings)

.DEPENDS ON
    Configure Power Settings
#>
Register-Step -Name "Configure Screen Timeout" -Tags @('MGR', 'ADMIN') -Priority 11 -Section 1 -DependsOn @('Configure Power Settings') -Action {
  if ($Settings.ScreenTimeoutMinutes.$Role) {
    $timeout = $Settings.ScreenTimeoutMinutes.$Role
    powercfg /change monitor-timeout-ac $timeout
    powercfg /change monitor-timeout-dc $timeout
    Write-Status "Screen timeout set to $timeout minutes for $Role" 'Success'
  }
}

# ===========================
# SECTION 4: CLEANUP & FINALIZATION (90-99)
# ===========================
# Baseline debloat scripts
# Final checkpoint at Priority 99

<#
.STEP
    Run Baseline Debloat

.DESCRIPTION
    Executes the Win11Debloat script to remove bloatware and unwanted Windows features.
    Runs on ALL systems with default recommended settings.

    The baseline debloat includes:
    - Removal of consumer apps (Candy Crush, Microsoft Teams, Spotify, etc.)
    - Disabling of telemetry and advertising features
    - Disabling Bing search and Cortana from Windows search
    - Showing file extensions for known file types
    - Disabling widgets on taskbar & lockscreen
    - Disabling Fast Startup
    - Application of Sysprep-safe registry modifications for new users

.TAGS
    ALL (runs on all system types)

.PRIORITY
    90 (late stage cleanup)

.NOTE
    POS and CAM systems run additional custom app removal in their respective modules
#>
Register-Step -Name "Run Baseline Debloat" -Tags @('ALL') -Priority 48 -Section 1 -Action {
  $debloatConfig = $Settings.Debloat

  # Validate baseline configuration exists
  if (-not $debloatConfig.Baseline.ScriptPath) {
    Write-Status "No baseline debloat script configured" 'Info'
    return
  }

  # Check if baseline debloat script exists
  if (-not (Test-Path $debloatConfig.Baseline.ScriptPath)) {
    Write-Status "Baseline debloat script not found: $($debloatConfig.Baseline.ScriptPath)" 'Warning'
    return
  }

  Write-Status "Running baseline debloat (Win11Debloat with recommended defaults)..." 'Info'

  # Build argument string from settings
  $argList = $debloatConfig.Baseline.Arguments
  if ($debloatConfig.Baseline.LogPath -and (Test-Path $debloatConfig.Baseline.LogPath)) {
    $argList += " -LogPath `"$($debloatConfig.Baseline.LogPath)`""
  }

  # Build full PowerShell command
  $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($debloatConfig.Baseline.ScriptPath)`" $argList"

  Write-Host "`nLaunching baseline debloat script in separate window..." -ForegroundColor Cyan
  Write-Host "Window will close automatically when complete or after 5 minute timeout." -ForegroundColor Yellow

  try {
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
      Write-Status "Baseline debloat process started (PID: $($process.Id)) - visible window" 'Info'

      # Wait for process with 5 minute timeout (300,000 milliseconds)
      $timeout = 300000
      $completed = $process.WaitForExit($timeout)

      if ($completed) {
        # Process completed within timeout
        $exitCode = $process.ExitCode
        if ($exitCode -eq 0) {
          Write-Status "Baseline debloat completed successfully" 'Success'
        }
        else {
          Write-Status "Baseline debloat returned exit code: $exitCode" 'Warning'
        }
      }
      else {
        # Timeout occurred - kill the process
        Write-Status "Baseline debloat timed out after 5 minutes - killing process" 'Warning'
        Write-Host "`nDEBLOAT TIMEOUT - Killing stuck process..." -ForegroundColor Red
        try {
          $process.Kill()
          Write-Status "Killed stuck debloat process (PID: $($process.Id))" 'Warning'
        }
        catch {
          Write-Status "Failed to kill stuck process: $_" 'Error'
        }
      }

      $process.Dispose()
    }
    else {
      Write-Status "Failed to start baseline debloat process" 'Error'
    }

    # Check for created logs
    $scriptDir = Split-Path -Parent $debloatConfig.Baseline.ScriptPath
    $logDir = Join-Path $scriptDir 'Logs'
    if (Test-Path $logDir) {
      $latestLog = Get-ChildItem $logDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($latestLog) {
        Write-Status "Debloat log: $($latestLog.FullName)" 'Info'
      }
    }
  }
  catch {
    Write-Status "Failed to run baseline debloat: $_" 'Error'
    Write-Status "Error details: $($_.Exception.Message)" 'Error'
  }
}

# Final checkpoint (Priority 99, Section 4)
Register-Step -Name "Checkpoint: Final" -Tags @('ALL') -Priority 99 -Section 4 -Action {
  $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" }
  
  # Get Settings from framework for username determination
  $framework = if (Get-Command Get-HMGFramework -ErrorAction SilentlyContinue) {
    Get-HMGFramework
  } else {
    $null
  }
  $frameworkSettings = if ($framework) { $framework.Settings } else { $null }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'Final-Checkpoint' `
    -Section 4 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 100 `
    -Settings $frameworkSettings
  
  if ($rebooting) { return }
}

# NOTE: Some steps are role-specific and defined in their respective modules:
# - Memory Integrity disable (POS-specific) → HMG.POS module
# - Firewall Rules (POS-specific) → HMG.POS module
# - POS-specific debloat scripts → HMG.POS module
# - Axis Camera Client (CAM-specific) → HMG.CAM module

#endregion Step Implementations

# This module registers common configuration steps that run on all or multiple systems.
# It does NOT export any functions - steps are registered in the global registry via HMG.Core.
