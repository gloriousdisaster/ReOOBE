<#
.SYNOPSIS
    Core engine module for HMG automation framework - pure framework functionality.

.DESCRIPTION
    This module provides the foundational framework components with NO step registrations:
    - Step registry and execution engine
    - Path resolution functions
    - Helper functions for user management and system operations
    - Password and credential handling
    - Tool discovery utilities
    - Office deployment helpers

    This module contains ONLY framework functions and does NOT register any steps.
    Steps are registered by HMG.Baseline and role-specific modules.

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 2.0.0 (Extracted from HMG.Common 1.0)
    Requires: PowerShell 5.1 or higher
    Must be run as Administrator
    Breaking Change: This is a new module split from HMG.Common
    
    Error Handling Policy:
    
    THROW (stops execution):
    - Missing required configuration (settings.psd1, roles.psd1)
    - Missing critical modules (HMG.Core)
    - Programming errors (null references, invalid parameters)
    - Critical step failures (marked with -Critical flag)
    
    WARN + RETURN (continues execution):
    - Optional features not available (Autologon.exe not found)
    - Non-critical installers missing (MSI files)
    - Network connectivity issues (internet, domain controller)
    - Optional step failures
    
    SILENT SKIP (no warning):
    - Steps not applicable to current role (tag filtering)
    - Already-completed checks (idempotency)
    - Features explicitly disabled in settings
#>

#requires -version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region Module Initialization

# Load centralized state management
$stateManagementPath = Join-Path $PSScriptRoot "StateManagement.ps1"
if (Test-Path $stateManagementPath) {
  . $stateManagementPath
  Write-Verbose "Loaded centralized state management"
  
  # Note: Get-HMGFramework is defined later in this module and will be available after module loads
} else {
  Write-Warning "StateManagement.ps1 not found - using legacy state initialization"
  # Fallback to old initialization for backward compatibility
  $script:RebootRequired = $false
  $script:CompletedSteps = @()
  $script:ConfiguredUser = $null
  $global:RebootRequired = $false
  
  if (-not (Test-Path variable:global:HMGState)) {
    $global:HMGState = @{
      Steps       = @()
      FailedSteps = @()
    }
  }
}

# Define wrapper functions for StateManagement functions to ensure they're in module scope
function Get-HMGFramework {
    <#
    .SYNOPSIS
        Returns the global HMG Framework state object
    
    .DESCRIPTION
        Provides access to the centralized framework state management object
        
    .EXAMPLE
        $framework = Get-HMGFramework
        $password = $framework.GetRolePassword('POS')
    #>
    return $global:HMGFramework
}

function Sync-HMGLegacyState {
    <#
    .SYNOPSIS
        Forces a sync between HMGFramework and legacy HMGState
    
    .DESCRIPTION
        Ensures backward compatibility by syncing framework state to legacy globals
    #>
    if ($global:HMGFramework -and $global:HMGState) {
        $global:HMGState.Steps = $global:HMGFramework.Steps
        $global:HMGState.FailedSteps = $global:HMGFramework.FailedSteps
        $global:HMGState.Settings = $global:HMGFramework.Settings
        $global:HMGState.ConfiguredUser = $global:HMGFramework.ConfiguredUser
        
        # Sync decrypted passwords if they exist
        if ($global:HMGFramework._passwords.DecryptedPasswords) {
            $global:HMGState.DecryptedPasswords = $global:HMGFramework._passwords.DecryptedPasswords
        }
    }
}

# Get framework reference for this module
$framework = Get-HMGFramework

#endregion Module Initialization

#region Path Resolution Functions

<#
.SYNOPSIS
    Resolves relative or malformed configuration file paths to absolute paths.

.DESCRIPTION
    Attempts to resolve configuration file paths using multiple strategies:
    1. Returns path if already absolute and exists
    2. Resolves relative paths from RBCMS root
    3. Tries standard deployment locations (C:\bin\RBCMS)
    4. Falls back to original path if resolution fails

.PARAMETER Path
    The path to resolve (can be relative, absolute, or malformed)

.RETURNS
    Resolved absolute path if found, otherwise returns original path

.EXAMPLE
    $configPath = Resolve-ConfigPath -Path ".\config\settings.psd1"
    # Returns: C:\bin\RBCMS\config\settings.psd1 (or project path equivalent)
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Path
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Path
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Resolve-ConfigPath {
  param([string]$Path)

  if ([string]::IsNullOrEmpty($Path)) { return $null }

  # If already absolute, check if it exists
  if ([System.IO.Path]::IsPathRooted($Path)) {
    if (Test-Path $Path) { return $Path }
    # If absolute path doesn't exist, try to extract relative part
    if ($Path -match 'RBCMS\\(.+)$') {
      $relativePart = $matches[1]
      # Try to find RBCMS root and build path
      $rbcmsRoot = Get-RBCMSRoot -Silent
      if ($rbcmsRoot) {
        $newPath = Join-Path $rbcmsRoot $relativePart
        if (Test-Path $newPath) { return $newPath }
      }
    }
  }

  # Handle relative paths
  if ($Path.StartsWith('.\') -or $Path.StartsWith('..\')) {
    # First try relative to script root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

    # Walk up to find RBCMS root
    $testPath = $scriptRoot
    while ($testPath -and (Split-Path $testPath -Parent)) {
      if ((Split-Path $testPath -Leaf) -eq 'RBCMS') {
        $resolved = Join-Path $testPath $Path.TrimStart('.\')
        if (Test-Path $resolved) { return $resolved }
      }
      $testPath = Split-Path $testPath -Parent
      $rbcmsTest = Join-Path $testPath 'RBCMS'
      if (Test-Path $rbcmsTest) {
        $resolved = Join-Path $rbcmsTest $Path.TrimStart('.\')
        if (Test-Path $resolved) { return $resolved }
      }
    }
  }

  # Try standard locations
  $standardPaths = @(
    "C:\bin\RBCMS\$($Path.TrimStart('.\'))",
    (Join-Path (Get-Location).Path $Path)
  )

  foreach ($test in $standardPaths) {
    if (Test-Path $test) { return $test }
  }

  return $Path  # Return original if can't resolve
}

<#
.SYNOPSIS
    Locates the RBCMS root directory regardless of execution context.

.DESCRIPTION
    Searches for the RBCMS root using multiple strategies:
    1. Checks for deployed environment (C:\bin\RBCMS)
    2. Walks up directory tree to find RBCMS folder
    3. Returns null if not found (with optional warning)

.PARAMETER Silent
    Suppresses warning message if RBCMS root cannot be located

.RETURNS
    Full path to RBCMS root directory, or $null if not found

.EXAMPLE
    $root = Get-RBCMSRoot
    # Returns: C:\bin\RBCMS or C:\Users\user\projects\HMG\hmg_RBCMS\RBCMS
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Silent
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Silent
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-RBCMSRoot {
  param([switch]$Silent)

  # Priority 1: Check if we're in the deployed environment
  if (Test-Path "C:\bin\RBCMS") {
    return "C:\bin\RBCMS"
  }

  # Priority 2: Check if we're running from within RBCMS structure
  $currentPath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
  if ($currentPath) {
    $testPath = $currentPath
    while ($testPath -and (Split-Path $testPath -Parent)) {
      if ((Split-Path $testPath -Leaf) -eq 'RBCMS') {
        return $testPath
      }
      $parentTest = Join-Path (Split-Path $testPath -Parent) 'RBCMS'
      if (Test-Path $parentTest) {
        return $parentTest
      }
      $testPath = Split-Path $testPath -Parent
    }
  }

  if (-not $Silent) {
    Write-Warning "Unable to locate RBCMS root directory"
  }
  return $null
}

<#
.SYNOPSIS
    Locates the HMG project root directory (parent of RBCMS and deployment folders).

.DESCRIPTION
    Calculates the project root by walking up the directory tree from the current
    module or script location to find the directory containing both RBCMS and
    deployment folders. Works in development, production, or any portable location.
    
    Project structure:
    <anywhere>\
    ├── RBCMS\
    └── deployment\

.PARAMETER Silent
    Suppresses warning message if project root cannot be located

.RETURNS
    Full path to project root directory, or $null if not found

.EXAMPLE
    $root = Get-HMGProjectRoot
    # Returns: C:\Users\jdore\projects\HMG\hmg_RBCMS (dev)
    # Returns: C:\bin (production)
    # Returns: D:\HMG (USB drive)
#>
function Get-HMGProjectRoot {
  param([switch]$Silent)

  # Try from $PSScriptRoot first (works in modules and scripts)
  if ($PSScriptRoot) {
    $current = $PSScriptRoot
    
    # Walk up the directory tree looking for RBCMS and deployment folders
    while ($current) {
      $rbcms = Join-Path $current "RBCMS"
      $deployment = Join-Path $current "deployment"
      
      if ((Test-Path $rbcms) -and (Test-Path $deployment)) {
        return $current
      }
      
      $parent = Split-Path $current -Parent
      if ($parent -eq $current) { break }  # At root, stop
      $current = $parent
    }
  }
  
  # Fallback: Check if we're already in production location
  if ((Test-Path "C:\bin\RBCMS") -and (Test-Path "C:\bin\deployment")) {
    return "C:\bin"
  }
  
  if (-not $Silent) {
    Write-Warning "Could not determine HMG project root. Ensure RBCMS and deployment folders exist."
  }
  
  return $null
}

<#
.SYNOPSIS
    Returns standardized paths within the HMG project structure.

.DESCRIPTION
    Provides a centralized way to get paths for different components of the HMG
    framework. All paths are calculated dynamically based on the project root,
    making the framework portable across different deployment locations.

.PARAMETER PathType
    Type of path to retrieve (ProjectRoot, RBCMS, Deployment, DeploymentPOS, etc.)

.PARAMETER SubPath
    Optional sub-path to append to the base path

.RETURNS
    Full path string for the requested component

.EXAMPLE
    Get-HMGPath -PathType DeploymentPOS
    # Returns: C:\<root>\deployment\pos
    
.EXAMPLE
    Get-HMGPath -PathType DeploymentPOS -SubPath "02-installers\04-deskCameraInstaller"
    # Returns: C:\<root>\deployment\pos\02-installers\04-deskCameraInstaller
#>
function Get-HMGPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('ProjectRoot', 'RBCMS', 'Deployment', 'DeploymentGlobal', 
                 'DeploymentPOS', 'DeploymentMGR', 'DeploymentCAM', 'DeploymentAdmin',
                 'Logs', 'Config', 'Modules', 'Scripts', 'Vault')]
    [string]$PathType,
    
    [Parameter()]
    [string]$SubPath
  )
  
  $root = Get-HMGProjectRoot
  if (-not $root) {
    throw "Cannot determine HMG project root. Ensure RBCMS and deployment folders exist in the project structure."
  }
  
  $paths = @{
    ProjectRoot      = $root
    RBCMS            = Join-Path $root "RBCMS"
    Deployment       = Join-Path $root "deployment"
    DeploymentGlobal = Join-Path $root "deployment\global"
    DeploymentPOS    = Join-Path $root "deployment\pos"
    DeploymentMGR    = Join-Path $root "deployment\mgr"
    DeploymentCAM    = Join-Path $root "deployment\cam"
    DeploymentAdmin  = Join-Path $root "deployment\admin"
    Logs             = Join-Path $root "RBCMS\logs"
    Config           = Join-Path $root "RBCMS\config"
    Modules          = Join-Path $root "RBCMS\modules"
    Scripts          = Join-Path $root "RBCMS\scripts"
    Vault            = Join-Path $root "RBCMS\vault"
  }
  
  $basePath = $paths[$PathType]
  
  if ($SubPath) {
    return Join-Path $basePath $SubPath
  }
  
  return $basePath
}

<#
.SYNOPSIS
    Searches for an installer file within deployment folders.

.DESCRIPTION
    Dynamically searches for installer files in the deployment structure.
    This allows the folder structure to change without breaking the code.
    Searches recursively within the role's deployment folder or a specific
    sub-path if provided.

.PARAMETER Role
    The role whose deployment folder to search (POS, MGR, CAM, Admin, Global)

.PARAMETER FilePattern
    File name pattern to search for (supports wildcards like "SetupDeskCamera*.exe")

.PARAMETER SearchPath
    Optional sub-path within the deployment folder to limit search scope
    Supports wildcards (e.g., "*SQL*\installFiles")

.PARAMETER AllMatches
    If specified, returns all matching files instead of just the first/newest

.RETURNS
    FileInfo object(s) for matching installer file(s), or $null if not found

.EXAMPLE
    Find-HMGInstaller -Role POS -FilePattern "SetupDeskCamera*.exe"
    # Searches: C:\<root>\deployment\pos\**\SetupDeskCamera*.exe
    
.EXAMPLE
    Find-HMGInstaller -Role POS -FilePattern "setup.exe" -SearchPath "*SQL*\installFiles"
    # Searches: C:\<root>\deployment\pos\*SQL*\installFiles\setup.exe
    
.EXAMPLE
    Find-HMGInstaller -Role Global -FilePattern "Win11Debloat.ps1" -SearchPath "scripts"
    # Searches: C:\<root>\deployment\global\scripts\Win11Debloat.ps1
#>
function Find-HMGInstaller {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('POS', 'MGR', 'CAM', 'Admin', 'Global')]
    [string]$Role,
    
    [Parameter(Mandatory)]
    [string]$FilePattern,
    
    [Parameter()]
    [string]$SearchPath,
    
    [switch]$AllMatches
  )
  
  $deploymentPath = switch ($Role) {
    'Global' { Get-HMGPath -PathType DeploymentGlobal }
    'POS'    { Get-HMGPath -PathType DeploymentPOS }
    'MGR'    { Get-HMGPath -PathType DeploymentMGR }
    'CAM'    { Get-HMGPath -PathType DeploymentCAM }
    'Admin'  { Get-HMGPath -PathType DeploymentAdmin }
  }
  
  if (-not (Test-Path $deploymentPath)) {
    Write-Warning "Deployment path not found: $deploymentPath"
    return $null
  }
  
  # If SearchPath contains wildcards, resolve them first
  if ($SearchPath -and ($SearchPath -match '\*')) {
    $searchPaths = @()
    $searchPathPattern = Join-Path $deploymentPath $SearchPath
    
    # Get directories matching the wildcard pattern
    $parentPath = Split-Path $searchPathPattern -Parent
    $leafPattern = Split-Path $searchPathPattern -Leaf
    
    if (Test-Path $parentPath) {
      $matchedDirs = Get-ChildItem -Path $parentPath -Directory -Filter $leafPattern -ErrorAction SilentlyContinue
      foreach ($dir in $matchedDirs) {
        # Check if the full path pattern matches
        $fullPattern = Join-Path $deploymentPath $SearchPath
        if ($dir.FullName -like $fullPattern) {
          $searchPaths += $dir.FullName
        }
      }
    }
    
    # Search in all matched directories
    $results = @()
    foreach ($searchDir in $searchPaths) {
      if (Test-Path $searchDir) {
        $found = Get-ChildItem -Path $searchDir -Filter $FilePattern -Recurse -File -ErrorAction SilentlyContinue
        if ($found) {
          $results += $found
        }
      }
    }
  }
  else {
    # Standard search with or without sub-path
    if ($SearchPath) {
      $deploymentPath = Join-Path $deploymentPath $SearchPath
    }
    
    if (-not (Test-Path $deploymentPath)) {
      Write-Verbose "Search path not found: $deploymentPath"
      return $null
    }
    
    $results = Get-ChildItem -Path $deploymentPath -Filter $FilePattern -Recurse -File -ErrorAction SilentlyContinue
  }
  
  if (-not $results) {
    return $null
  }
  
  if ($AllMatches) {
    return $results
  }
  
  # Return most recent if multiple found
  return $results | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

#endregion Path Resolution Functions

#region Status and Logging Functions

<#
.SYNOPSIS
    Writes a formatted status message to the console with color coding.

.DESCRIPTION
    Provides consistent status messaging throughout the framework with visual
    distinction between different message types using color coding.
    
    Automatically integrates with HMG.Logging when available to provide:
    - Timestamped log entries with millisecond precision
    - Dual output (console + structured log file)
    - Buffered writes for performance
    
    Falls back to simple Write-Host when HMG.Logging is not loaded.

.PARAMETER Message
    The message text to display

.PARAMETER Type
    Message type that determines color: Info (Cyan), Success (Green), Warning (Yellow), Error (Red)

.PARAMETER Component
    Optional component name for HMG.Logging context (e.g., 'HMG.POS')

.PARAMETER Step
    Optional step name for HMG.Logging context

.EXAMPLE
    Write-Status "Installing Chrome..." 'Info'
    Write-Status "Installation complete" 'Success'
    Write-Status "Warning: File not found" 'Warning' -Component 'HMG.Baseline' -Step 'Install-Chrome'
#>
function Write-Status {
  param(
    [string]$Message, 
    [ValidateSet('Info', 'Success', 'Warning', 'Error')]$Type = 'Info',
    [string]$Component,
    [string]$Step
  )
  
  # Check if HMG.Logging module is available
  $loggingAvailable = $false
  if (Get-Command 'Write-HMGLog' -ErrorAction SilentlyContinue) {
    $loggingAvailable = $true
  }
  
  if ($loggingAvailable) {
    # Use HMG.Logging for timestamped, structured logging
    $level = switch ($Type) {
      'Success' { 'SUCCESS' }
      'Warning' { 'WARNING' }
      'Error' { 'ERROR' }
      default { 'INFO' }
    }
    
    # Build parameters for Write-HMGLog
    $logParams = @{  
      Message = $Message
      Level   = $level
    }
    
    if ($Component) { $logParams['Component'] = $Component }
    if ($Step) { $logParams['Step'] = $Step }
    
    # Call the logging function
    Write-HMGLog @logParams
  }
  else {
    # Fallback to simple Write-Host when logging not available
    $color = switch ($Type) {
      'Success' { 'Green' }
      'Warning' { 'Yellow' }
      'Error' { 'Red' }
      default { 'Cyan' }
    }
    Write-Host ("[{0}] {1}" -f $Type, $Message) -ForegroundColor $color
  }
}

#endregion Status and Logging Functions

#region Step Registry and Execution Engine

<#
.SYNOPSIS
    Initializes the global step registry if it doesn't already exist.

.DESCRIPTION
    The step registry is a global collection that holds all registered configuration
    steps from all loaded modules. Each step includes its name, tags, action, priority,
    and dependency information.
#>

# Initialize Steps array through framework
if ($framework) {
  Write-Verbose "Using HMGFramework.Steps for step registry"
  # Ensure Steps is initialized as an array
  if ($null -eq $framework.Steps) {
    Write-Verbose "Initializing framework.Steps as empty array"
    $framework.Steps = @()
  }
  # Ensure global Steps points to framework's Steps for backward compatibility
  $global:Steps = $framework.Steps
} else {
  # This shouldn't happen as framework is initialized in StateManagement.ps1
  Write-Warning "HMGFramework not available - falling back to legacy mode"
  if (-not (Test-Path variable:global:Steps)) {
    $global:Steps = @()
  }
}

<#
.SYNOPSIS
    Registers a configuration step in the global step registry.

.DESCRIPTION
    Adds a new step to the framework's execution queue with metadata including:
    - Name: Unique identifier for the step
    - Tags: Role-based tags (POS, MGR, CAM, ADMIN, ALL)
    - Action: ScriptBlock containing the step's logic
    - Priority: Execution order (10-100, lower runs first)
    - DependsOn: Array of step names that must complete first
    - Provides: Capabilities this step makes available

.PARAMETER Name
    Unique name for the step (must not already exist)

.PARAMETER Tags
    Array of role tags determining which systems run this step

.PARAMETER Action
    ScriptBlock containing the step's execution logic

.PARAMETER Priority
    Execution priority (10-20: Prerequisites, 30-40: Installations, 50-60: User config,
    70-80: System settings, 90-100: Cleanup). Default: 50

.PARAMETER DependsOn
    Array of step names or capabilities required before this step runs

.PARAMETER Provides
    Array of capabilities this step provides (for dependency resolution)

.EXAMPLE
    Register-Step -Name "Install Chrome" -Tags @('ALL') -Priority 30 `
      -Provides @('Browser') -Action { # installation logic }
#>
function Register-Step {
  param(
    [string]$Name,
    [string[]]$Tags,
    [ScriptBlock]$Action,
    [int]$Priority = 50,          # Default priority (lower = earlier execution)
    [string[]]$DependsOn = @(),   # Steps that must run before this one
    [string[]]$Provides = @(),    # Capabilities this step provides (for dependency resolution)
    [switch]$Critical              # NEW - indicates step MUST succeed
  )

  # Create step object
  $step = [pscustomobject]@{
    Name      = $Name
    Tags      = $Tags
    Action    = $Action
    Priority  = $Priority
    DependsOn = $DependsOn
    Provides  = @($Name) + $Provides  # Step always provides its own name
    Critical  = $Critical.IsPresent   # NEW - store critical flag
    Executed  = $false
    Skipped   = $false
  }

  # Always use framework for registration (it handles backward compatibility)
  if ($framework) {
    # Check for duplicate using framework's Steps
    if ($framework.Steps | Where-Object { $_.Name -eq $Name }) {
      Write-Warning "Step '$Name' already registered. Skipping duplicate."
      return
    }
    $framework.RegisterStep.Invoke($step)
  } else {
    # Framework should always be available, this is a fallback
    Write-Warning "Framework not available - using direct registration"
    if ($global:Steps | Where-Object { $_.Name -eq $Name }) {
      Write-Warning "Step '$Name' already registered. Skipping duplicate."
      return
    }
    $global:Steps += $step
    # Also update HMGState for consistency
    if ($global:HMGState) {
      $global:HMGState.Steps = $global:Steps
    }
  }
}

<#
.SYNOPSIS
    Filters and sorts steps for the current role with dependency resolution.

.DESCRIPTION
    Processes the global step registry to:
    1. Filter steps matching the current role's tags (or 'ALL' tag)
    2. Sort by priority (lower numbers execute first)
    3. Resolve dependencies to ensure proper execution order
    4. Detect circular dependencies

.PARAMETER Steps
    Array of step objects to process (usually $global:Steps)

.PARAMETER Role
    Current system role (POS, MGR, CAM, or ADMIN)

.RETURNS
    Array of sorted steps ready for execution

.EXAMPLE
    $stepsToRun = Get-SortedSteps -Steps $global:Steps -Role 'POS'
#>
function Get-SortedSteps {
  param(
    [array]$Steps,
    [string]$Role
  )

  Write-Verbose "Get-SortedSteps: Processing $(@($Steps).Count) steps for role: $Role"

  # Step 1: Filter steps by role tags
  # Include steps with 'ALL' tag OR steps with the current role tag
  $filtered = @()
  foreach ($step in $Steps) {
    # Normalize step tags to uppercase array
    $stepTags = @($step.Tags | ForEach-Object { $_.ToUpperInvariant() })

    # Include if has 'ALL' tag OR has the current role tag
    $includeStep = ('ALL' -in $stepTags) -or ($Role.ToUpperInvariant() -in $stepTags)

    Write-Verbose ("Step '{0}' [Tags: {1}] -> {2}" -f `
        $step.Name, ($stepTags -join ', '), $(if ($includeStep) { 'INCLUDE' }else { 'SKIP' }))

    if ($includeStep) {
      $filtered += $step
    }
  }

  Write-Verbose "Filtered to $($filtered.Count) steps for $Role role"

  # Step 2: Sort by Priority then Name
  $sorted = @($filtered | Sort-Object Priority, Name)

  # Step 3: Dependency resolution using depth-first search
  # This ensures steps execute after their dependencies
  $resolved = New-Object System.Collections.ArrayList
  $visited  = @{}   # Tracks completed dependency checks
  $visiting = @{}   # Tracks in-progress checks (for circular dependency detection)

  # Recursive function to resolve a single step's dependencies
  function Test-StepDependency {
    param($Step)

    # Detect circular dependencies
    if ($visiting[$Step.Name]) {
      throw "Circular dependency detected: $($Step.Name)"
    }

    # Skip if already processed
    if ($visited[$Step.Name]) { return }

    # Mark as currently being processed
    $visiting[$Step.Name] = $true

    # Process each dependency recursively
    foreach ($depName in @($Step.DependsOn)) {
      # Find the step that provides this dependency
      $dep = $sorted | Where-Object { $_.Provides -contains $depName } | Select-Object -First 1
      if ($dep) {
        Test-StepDependency -Step $dep
      } else {
        # Dependency not found - check if it was completed in a previous run
        if (-not ($script:CompletedSteps -contains $depName)) {
          Write-Warning "Step '$($Step.Name)' depends on '$depName' which isn't available or completed yet"
        }
      }
    }

    # Mark as fully processed and add to execution list
    $visiting[$Step.Name] = $false
    $visited[$Step.Name]  = $true
    $null = $resolved.Add($Step)  # Use ArrayList.Add() to avoid scoping issues
  }

  # Resolve dependencies for all steps
  foreach ($s in $sorted) {
    if ($s) { Test-StepDependency -Step $s }
  }

  Write-Verbose "Resolved to $($resolved.Count) steps after dependency resolution"
  return @($resolved)
}

<#
.SYNOPSIS
    Executes all registered steps for the current role in dependency order.

.DESCRIPTION
    The main execution engine that:
    1. Filters steps for the current role
    2. Resolves dependencies and determines execution order
    3. Executes each step's action script block
    4. Tracks completed steps for dependency resolution
    5. Handles errors and optional WhatIf mode

.PARAMETER Role
    Current system role (POS, MGR, CAM, or ADMIN)

.PARAMETER ContinueFrom
    Step number to resume from (for interrupted executions)

.PARAMETER WhatIf
    If specified, shows what would be executed without making changes

.EXAMPLE
    Invoke-Steps -Role 'POS'
    Invoke-Steps -Role 'MGR' -WhatIf
    Invoke-Steps -Role 'POS' -ContinueFrom 5
#>
function Invoke-Steps {
  [CmdletBinding()]
  param(
    [string]$Role,
    [int]$ContinueFrom = 0,
    [switch]$WhatIf,
    [switch]$TrackProgress
  )

  # Make Role available globally and in framework for the steps to use
  $global:Role = $Role
  
  # Also set in framework if available
  if ($framework) {
    $framework.Role = $Role
  }

  Write-Status "Invoke-Steps called with $($global:Steps.Count) steps available for role: $Role" 'Info'

  # Get sorted and dependency-resolved steps for this role
  try {
    $stepsToRun = @(Get-SortedSteps -Steps $global:Steps -Role $Role)
    if ($null -eq $stepsToRun) {
      $stepsToRun = @()
    }
  }
  catch {
    Write-Status "Failed to resolve step dependencies: $_" 'Error'
    Write-Verbose "Error details: $($_.Exception.Message)"
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    return
  }

  Write-Status "Resolved execution order: $(@($stepsToRun).Count) steps to run for $Role" 'Info'

  if ($WhatIf) {
    Write-Status "Running in WhatIf mode - no changes will be made" 'Warning'
  }

  # Initialize state tracking if requested
  if ($TrackProgress) {
    # Try to load HMG.State module if available
    $stateModule = Get-Module -Name 'HMG.State' -ErrorAction SilentlyContinue
    if (-not $stateModule) {
      $stateModulePath = Join-Path (Get-RBCMSRoot) 'modules\HMG.State\HMG.State.psd1'
      if (Test-Path $stateModulePath) {
        Import-Module $stateModulePath -Force -Global
        $stateModule = Get-Module -Name 'HMG.State'
      }
    }

    if ($stateModule) {
      # Check if we're resuming
      $resumeInfo = Test-SetupResume
      if ($resumeInfo -and $resumeInfo.ShouldResume) {
        $ContinueFrom = $resumeInfo.NextStep - 1  # Adjust for 0-based indexing
        Write-Status "Resuming from step $($resumeInfo.NextStep)" 'Info'
      }
      else {
        # Initialize new state
        Initialize-SetupState -Role $Role -TotalSteps $stepsToRun.Count
      }
    }
  }

  # Initialize state tracking
  $i = 0
  $script:CompletedSteps = @()
  
  # Reset failed steps tracking in framework
  if ($framework) {
    $framework.FailedSteps = @()
  } else {
    $global:HMGState.FailedSteps = @()
  }

  foreach ($s in $stepsToRun) {
    $i++

    # Skip steps if continuing from a specific point
    if ($i -le $ContinueFrom) { continue }

    # Show step information with dependencies
    $depInfo = ""
    if (@($s.DependsOn).Count -gt 0) {
      $depInfo = " [Depends on: $($s.DependsOn -join ', ')]"
    }

    Write-Status "Running step #${i}: $($s.Name) (Priority: $($s.Priority))$depInfo" 'Info'

    if ($WhatIf) {
      Write-Status "  [WhatIf] Would execute: $($s.Name)" 'Info'
    }
    else {
      try {
        # Execute the step's action
        & $s.Action
        $s.Executed = $true
        $script:CompletedSteps += $s.Provides

        # Update progress tracking if enabled
        if ($TrackProgress -and $stateModule) {
          Update-StepProgress -StepNumber $i -StepName $s.Name -Success $true
        }
      }
      catch {
        $s.Executed = $false
        
        # Check if this is a critical step
        if ($s.Critical) {
          Write-Status "CRITICAL STEP FAILED: $($s.Name)" 'Error'
          Write-Status "Error: $($_.Exception.Message)" 'Error'
          Write-Status "Cannot continue - setup must be corrected and restarted" 'Error'
          
          if ($TrackProgress -and $stateModule) {
            Update-StepProgress -StepNumber $i -StepName $s.Name -Success $false -ErrorMessage $_.Exception.Message
          }
          
          # Log and exit - don't try to continue
          throw "Critical step '$($s.Name)' failed: $($_.Exception.Message)"
        }
        else {
          # Non-critical failure - log and continue
          Write-Status "Optional step '$($s.Name)' failed: $($_.Exception.Message)" 'Warning'
          
          # Use framework method to add failed step
          if ($framework) {
            $framework.AddFailedStep.Invoke($s.Name, $_.Exception.Message, $i)
          } else {
            # Fallback to direct update
            $global:HMGState.FailedSteps += [pscustomobject]@{
              StepNumber = $i
              Name       = $s.Name
              Error      = $_.Exception.Message
            }
          }
          
          if ($TrackProgress -and $stateModule) {
            Update-StepProgress -StepNumber $i -StepName $s.Name -Success $false -ErrorMessage $_.Exception.Message
          }
          
          Write-Verbose "Continuing with remaining steps despite failure"
        }
      }
    }
  }

  # Report summary at the end
  # Safely get failed steps and ensure it's an array
  $failedSteps = if ($framework) { $framework.FailedSteps } else { $global:HMGState.FailedSteps }
  
  # Ensure we have an array (handles null, single object, or collection)
  $failedStepsArray = @()
  if ($null -ne $failedSteps) {
    $failedStepsArray = @($failedSteps)
  }
  
  # Check count safely
  if ($failedStepsArray.Count -gt 0) {
    Write-Host ""
    Write-Status "=== Execution completed with $($failedStepsArray.Count) failed step(s) ===" 'Warning'
    foreach ($failed in $failedStepsArray) {
      Write-Host "  Step #$($failed.StepNumber): $($failed.Name)" -ForegroundColor Yellow
      Write-Host "    Error: $($failed.Error)" -ForegroundColor Red
    }
    Write-Host ""
  }
}

#endregion Step Registry and Execution Engine

#region System and Security Helper Functions

<#
.SYNOPSIS
    Tests if the current PowerShell session is running with administrator privileges.

.RETURNS
    $true if running as administrator, $false otherwise

.EXAMPLE
    if (-not (Test-Administrator)) {
        Write-Error "This script requires administrator privileges"
        exit 1
    }
#>

function Test-Administrator {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  return $isAdmin
}

<#
.SYNOPSIS
    Generates a sanitized username from the computer name.

.DESCRIPTION
    Creates a valid Windows username by:
    - Removing hyphens from computer name
    - Validating length (max 20 characters)
    - Ensuring doesn't start with a number

.PARAMETER ComputerName
    Computer name to sanitize (defaults to current computer)

.RETURNS
    Sanitized username string

.EXAMPLE
    $username = Get-SanitizedUsername
    # If computer name is "POS-01" returns "POS01"
#>

function Get-SanitizedUsername {
  param([string]$ComputerName = $env:COMPUTERNAME)

  # Remove hyphens
  $sanitized = ($ComputerName -replace '-', '')

  # Validate the resulting username
  if ([string]::IsNullOrWhiteSpace($sanitized)) {
    throw "Computer name results in empty username after sanitization"
  }
  if ($sanitized.Length -gt 20) {
    $sanitized = $sanitized.Substring(0, 20)
    Write-Warning "Username truncated to 20 characters: $sanitized"
  }
  if ($sanitized -match '^\d') {
    throw "Username cannot start with a number: $sanitized"
  }

  return $sanitized
}

<#
.SYNOPSIS
    Resolves localized Windows built-in group names using SIDs.

.DESCRIPTION
    Windows built-in groups have different names in different languages.
    This function uses the well-known SID to get the correct group name
    regardless of system language.

.PARAMETER Builtin
    The built-in group type (Administrators or Users)

.RETURNS
    Localized group name (e.g., "Administrators", "Administrateurs", etc.)

.EXAMPLE
    $adminGroup = Resolve-BuiltinGroupName -Builtin 'Administrators'
    Add-LocalGroupMember -Group $adminGroup -Member 'username'
#>

function Resolve-BuiltinGroupName {
  param([ValidateSet('Administrators', 'Users')]$Builtin)

  # Well-known SIDs for built-in groups
  $sid = switch ($Builtin) {
    'Administrators' { 'S-1-5-32-544' }
    'Users' { 'S-1-5-32-545' }
  }

  try {
    # Translate SID to account name
    ((New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount])).Value.Split('\')[-1]
  }
  catch {
    # Fallback to English name if translation fails
    $Builtin
  }
}

#endregion System and Security Helper Functions

#region Password and Credential Functions


<#
.SYNOPSIS
    Retrieves the password for a specific role from HMGState cache.

.DESCRIPTION
    Simplified password retrieval function that:
    1. Gets password from $global:HMGState.DecryptedPasswords (encrypted mode)
    2. Gets password from $global:HMGState.Settings (plaintext mode)
    3. Throws descriptive errors if password not available
    
    The orchestrator MUST decrypt passwords during startup and store in HMGState.
    Steps should NEVER decrypt on their own - single point of decryption.

.PARAMETER Role
    The system role (POS, MGR, CAM, ADMIN) to get password for

.RETURNS
    Plain text password string

.THROWS
    Descriptive error if password not available

.EXAMPLE
    $passwordText = Get-RolePassword -Role 'POS'
    $securePass = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
#>
function Get-RolePassword {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('POS', 'MGR', 'CAM', 'ADMIN')]
    [string]$Role
  )
  
  # Always use framework for password retrieval (it handles all modes)
  if ($framework) {
    return $framework.GetRolePassword.Invoke($Role)
  }
  
  # Emergency fallback - this shouldn't happen
  throw "HMGFramework not available - cannot retrieve password. This indicates a critical initialization failure."
}

#endregion Password and Credential Functions

#region Tool Discovery Functions

<#
.SYNOPSIS
    Locates the Sysinternals Autologon executable.

.DESCRIPTION
    Searches multiple locations for Autologon64.exe or Autologon.exe:
    1. Path specified in settings
    2. Standard deployment locations
    3. Current directory and subdirectories
    4. System PATH environment variable

.RETURNS
    Full path to Autologon executable, or $null if not found

.EXAMPLE
    $autologonPath = Find-AutologonExe
    if ($autologonPath) {
        & $autologonPath $username $domain $password
    }
#>

function Find-AutologonExe {
  $candidates = @()

  # Check settings path first
  if ($Settings.Autologon.$Role.ToolPath) {
    $candidates += $Settings.Autologon.$Role.ToolPath
  }

  # Standard locations
  $candidates += @(
    'C:\bin\deployment\global\tools\Autologon64.exe',
    'C:\bin\deployment\global\tools\Autologon.exe',
    (Join-Path (Get-Location) 'dependancies\Autologon64.exe'),
    (Join-Path (Get-Location) 'dependancies\Autologon.exe'),
    (Join-Path (Get-Location) 'Autologon64.exe'),
    (Join-Path (Get-Location) 'Autologon.exe')
  )

  # Check PATH environment variable
  $fromPath = @('Autologon64.exe', 'Autologon.exe') | ForEach-Object {
    Get-Command $_ -ErrorAction SilentlyContinue
  } | Select-Object -First 1
  if ($fromPath) { $candidates += $fromPath.Source }

  # Return first existing path
  foreach ($c in $candidates | Where-Object { $_ } | Select-Object -Unique) {
    if (Test-Path $c) { return (Resolve-Path $c).Path }
  }

  return $null
}

#endregion Tool Discovery Functions

#region Office Deployment Functions

<#
.SYNOPSIS
    Executes the Office Deployment Tool (setup.exe) with a configuration XML.

.DESCRIPTION
    Runs Office setup.exe in configure mode with the specified XML file.
    Used for both installation and uninstallation of Office.

.PARAMETER SourcePath
    Path to the folder containing setup.exe and the XML file

.PARAMETER XmlFile
    Name of the XML configuration file (e.g., "config.xml" or "uninstall.xml")

.EXAMPLE
    Invoke-ODT -SourcePath "C:\bin\Office" -XmlFile "config.xml"
#>
function Invoke-ODT {
  param([string]$SourcePath, [string]$XmlFile)

  $setup = Join-Path $SourcePath 'setup.exe'
  $xml = Join-Path $SourcePath $XmlFile

  if (-not (Test-Path $setup)) { throw "setup.exe missing in $SourcePath" }
  if (-not (Test-Path $xml)) { throw "XML missing in $SourcePath" }

  Start-Process -FilePath $setup -ArgumentList "/configure `"$xml`"" -Wait -NoNewWindow
}

<#
.SYNOPSIS
    Checks if Microsoft Office is installed on the system.

.DESCRIPTION
    Detects Office installation using two methods:
    1. Checks for Click-to-Run installation files
    2. Checks for MSI-based Office packages

.RETURNS
    $true if Office is detected, $false otherwise

.EXAMPLE
    if (Test-OfficeInstalled) {
        Write-Host "Office is already installed"
    }
#>

function Test-OfficeInstalled {
  # Check for Click-to-Run installation
  $c2r = Get-ChildItem "$Env:ProgramFiles\Microsoft Office\root\Office*" -EA SilentlyContinue
  if ($c2r) { return $true }

  # Check for MSI-based installation
  $pkg = Get-Package -Name '*Office*' -ProviderName msi* -EA SilentlyContinue
  return [bool]$pkg
}

#endregion Office Deployment Functions

#region Reboot Helper Functions

<#
.SYNOPSIS
    Requests a system reboot from within a step.

.DESCRIPTION
    Helper function that steps can call to indicate a reboot is needed.
    Integrates with HMG.State module if available for automatic resume.

.PARAMETER Message
    Optional message explaining why reboot is needed

.PARAMETER AutoResume
    Whether to create a scheduled task for automatic resume

.EXAMPLE
    Request-Reboot -Message "Windows features require restart" -AutoResume
#>
function Request-Reboot {
  param(
    [string]$Message = "System changes require a restart",
    [switch]$AutoResume
  )

  Write-Status "Reboot requested: $Message" 'Warning'

  # Set the global flag
  $global:RebootRequired = $true
  $script:RebootRequired = $true

  # Try to use HMG.State module if available
  $stateModule = Get-Module -Name 'HMG.State' -ErrorAction SilentlyContinue
  if ($stateModule) {
    # Get the current script path
    $scriptPath = if ($PSCommandPath) {
      # Try to find the orchestrator script
      $rbcmsRoot = Get-RBCMSRoot
      if ($rbcmsRoot) {
        Join-Path $rbcmsRoot 'scripts\Invoke-Setup.ps1'
      }
      else {
        $PSCommandPath
      }
    }
    else {
      'C:\bin\RBCMS\scripts\Invoke-Setup.ps1'
    }

    # Set reboot required with optional auto-resume
    if ($AutoResume -and $global:Role -and (Test-Path $scriptPath)) {
      Set-RebootRequired -CreateResumeTask -ScriptPath $scriptPath -Role $global:Role
    }
    else {
      Set-RebootRequired
    }
  }
  else {
    # Fallback if state module not available
    Write-Host "`n====================================" -ForegroundColor Yellow
    Write-Host "       REBOOT REQUIRED" -ForegroundColor Yellow
    Write-Host "====================================" -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor White
    Write-Host "====================================" -ForegroundColor Yellow
  }
}

<#
.SYNOPSIS
    Checks if a reboot has been requested during execution.

.RETURNS
    $true if reboot is pending, $false otherwise

.EXAMPLE
    if (Test-PendingReboot) {
        Write-Host "Setup will continue after reboot"
    }
#>
function Test-PendingReboot {
  # Check all possible locations
  if ($global:RebootRequired -eq $true) { return $true }
  if ($script:RebootRequired -eq $true) { return $true }

  # Check with state module if available
  $stateModule = Get-Module -Name 'HMG.State' -ErrorAction SilentlyContinue
  if ($stateModule) {
    return Test-RebootRequired
  }

  return $false
}

#endregion Reboot Helper Functions

#region Module Exports

<#
.SYNOPSIS
    Export public functions for use by other modules and scripts.

.DESCRIPTION
    Makes key functions available to the orchestrator and other modules:
    - Write-Status: Consistent logging
    - Register-Step, Get-SortedSteps, Invoke-Steps: Step engine
    - Helper functions: User management, password handling, tool discovery
#>
# Build export list dynamically to include framework functions if defined
$exportFunctions = @(
  'Write-Status',
  'Register-Step',
  'Get-SortedSteps',
  'Invoke-Steps',
  'Test-Administrator',
  'Get-SanitizedUsername',
  'Resolve-BuiltinGroupName',
  'Get-RolePassword',
  'Find-AutologonExe',
  'Invoke-ODT',
  'Test-OfficeInstalled',
  'Get-RBCMSRoot',
  'Get-HMGProjectRoot',
  'Get-HMGPath',
  'Find-HMGInstaller',
  'Resolve-ConfigPath',
  'Request-Reboot',
  'Test-PendingReboot'
)

# Export framework functions (now defined in this module)
$exportFunctions += 'Get-HMGFramework'
$exportFunctions += 'Sync-HMGLegacyState'

Export-ModuleMember -Function $exportFunctions

#endregion Module Exports
