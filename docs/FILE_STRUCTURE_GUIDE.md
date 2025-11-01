# ReOOBE File Structure Guide

**Purpose:** Understand what each file type does and where it belongs  
**Date:** October 31, 2025

---

## PowerShell File Types

### `.psm1` - PowerShell Script Module
**Role:** Module loader / infrastructure  
**Contains:** Module initialization, function loading, exports  
**Location:** Module root only  
**Executable:** Yes (but not directly run)

**What it does:**
- Auto-loads all function files from Public/ and Private/
- Declares which functions are exported (public API)
- Contains module-level variables
- Sets up module initialization

**Example:**
```powershell
# modules/Apps/Apps.psm1

# Module variables
$script:ModuleName = 'Apps'

# Load all public functions
$publicPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem -Path $publicPath -Filter '*.ps1' | ForEach-Object {
    . $_.FullName  # Dot-source to load into module scope
}

# Load all private functions
$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Install-Chrome',
    'Install-DeskCam',
    'Install-SQLServer'
)
```

**When to create:**
- One per module (modules/ModuleName/ModuleName.psm1)
- Required for PowerShell to recognize it as a module

---

### `.psd1` - PowerShell Data File
**Role:** Data or metadata (NO CODE ALLOWED)  
**Contains:** Hashtables, arrays, strings, numbers - pure data  
**Location:** Module root (manifest) OR data folders (config, plans, registries)  
**Executable:** No (security feature)

#### **Use Case 1: Module Manifest** (at module root)

**What it does:**
- Tells PowerShell about the module
- Metadata: version, author, description
- Dependencies: required modules
- Exported functions list

**Example:**
```powershell
# modules/Apps/Apps.psd1

@{
    # Module loader
    RootModule = 'Apps.psm1'
    
    # Version
    ModuleVersion = '1.0.0'
    
    # Unique ID
    GUID = '12345678-1234-1234-1234-123456789012'
    
    # Metadata
    Author = 'Joshua Dore'
    CompanyName = 'Haven Management Group'
    Copyright = '(c) 2025'
    Description = 'Application installation functions for ReOOBE framework'
    
    # Requirements
    PowerShellVersion = '5.1'
    RequiredModules = @('Core', 'Logging')
    
    # What this module exposes
    FunctionsToExport = @(
        'Install-Chrome',
        'Install-DeskCam',
        'Install-SQLServer'
    )
    
    # What to hide
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
```

**When to create:**
- One per module (modules/ModuleName/ModuleName.psd1)
- Required companion to .psm1 file

---

#### **Use Case 2: Data Files** (config/, plans/, registries/)

**What it does:**
- Stores configuration data
- Defines execution plans
- Contains metadata about apps, settings, etc.
- NO executable code (security)

**Example 1: App Registry**
```powershell
# modules/Core/registries/apps.psd1

@{
    Chrome = @{
        DisplayName = 'Google Chrome'
        Installer   = 'Install-Chrome'  # Function name to call
        Category    = 'Browser'
        DetectPath  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
        MsiPath     = 'C:\deployment\global\Chrome\installer.msi'
        Critical    = $false
    }
    
    DeskCam = @{
        DisplayName = 'DeskCam'
        Installer   = 'Install-DeskCam'
        Category    = 'Utility'
        DetectPath  = 'C:\Program Files\DeskCam\DeskCam.exe'
        MsiPath     = 'C:\deployment\pos\DeskCam\DeskCam.msi'
        Critical    = $false
    }
    
    SQLServer = @{
        DisplayName = 'SQL Server Express'
        Installer   = 'Install-SQLServer'
        Category    = 'Database'
        DetectPath  = 'C:\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS'
        Critical    = $true
        RequiresReboot = $true
    }
}
```

**Example 2: Execution Plan**
```powershell
# modules/Core/plans/base.psd1

@(
    @{ 
        Id = 'OOBE-Complete'
        Type = 'Setting'
        Name = 'Mark OOBE Complete'
        Function = 'Set-OOBEComplete'
        Args = @{}
        Order = 5
        Enabled = $true
    },
    
    @{ 
        Id = 'SYS-TimeZone'
        Type = 'Setting'
        Name = 'Set Time Zone'
        Function = 'Set-SystemTimeZone'
        Args = @{ TimeZone = 'Eastern Standard Time' }
        Order = 10
        Enabled = $true
    },
    
    @{
        Id = 'APP-Chrome'
        Type = 'App'
        Name = 'Google Chrome'
        AppKey = 'Chrome'  # References apps.psd1
        Order = 20
        Enabled = $true
    }
)
```

**Example 3: Role Overlay**
```powershell
# modules/Core/plans/roles/POS.psd1

@(
    # Override Chrome settings for POS
    @{ 
        Id = 'APP-Chrome'
        Override = $true
        Args = @{ 
            NoDesktopShortcut = $true
            EnrollmentToken = 'POS-TOKEN'
        }
    },
    
    # Add POS-specific steps
    @{
        Id = 'APP-DeskCam'
        Type = 'App'
        Name = 'DeskCam'
        AppKey = 'DeskCam'
        Order = 25
        Enabled = $true
    },
    
    @{
        Id = 'APP-SQLServer'
        Type = 'App'
        Name = 'SQL Server Express'
        AppKey = 'SQLServer'
        Order = 30
        Enabled = $true
        Critical = $true
    }
)
```

**Example 4: Configuration**
```powershell
# config/settings.psd1

@{
    Framework = @{
        Version = '1.0.0'
        LogLevel = 'INFO'
        LogPath = 'C:\ReOOBE\logs'
    }
    
    Deployment = @{
        SourcePath = 'D:\deployment'
        TargetPath = 'C:\deployment'
        BackupPath = 'C:\ReOOBE\backups'
    }
    
    System = @{
        DefaultTimeZone = 'Eastern Standard Time'
        PowerPlan = 'High Performance'
    }
    
    POS = @{
        Installers = @{
            DeskCam = 'C:\deployment\pos\DeskCam\DeskCam.msi'
            SQLServer = 'C:\deployment\pos\SQL'
            CounterPoint = 'C:\deployment\pos\CounterPoint'
        }
        
        SQL = @{
            InstanceName = 'SQLEXPRESS'
            UseConfigFile = $true
            ConfigFile = 'ConfigurationFile.ini'
        }
    }
}
```

**When to create:**
- App registries (what apps exist)
- Execution plans (what to run, when)
- Configuration files (settings)
- Any time you need data without code

**How to load:**
```powershell
$apps = Import-PowerShellDataFile -Path 'registries/apps.psd1'
$plan = Import-PowerShellDataFile -Path 'plans/base.psd1'
$config = Import-PowerShellDataFile -Path 'config/settings.psd1'
```

---

### `.ps1` - PowerShell Script File
**Role:** Contains functions or standalone scripts  
**Contains:** PowerShell code (functions, logic)  
**Location:** Public/, Private/ folders OR scripts/ folder  
**Executable:** Yes

#### **Use Case 1: Function Files** (in Public/, Private/)

**Convention:** ONE function per file  
**File naming:** Same as function name

**Example:**
```powershell
# modules/Apps/Public/Install-Chrome.ps1

function Install-Chrome {
    <#
    .SYNOPSIS
        Installs Google Chrome
    
    .PARAMETER MsiPath
        Path to Chrome MSI installer
    
    .PARAMETER Force
        Force reinstall even if detected
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MsiPath,
        
        [switch]$Force
    )
    
    # Just the installation logic - no orchestration
    $detected = Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    
    if (-not $detected -or $Force) {
        $process = Start-Process msiexec.exe -ArgumentList @(
            '/i',
            "`"$MsiPath`"",
            '/qn',
            '/norestart'
        ) -Wait -PassThru
        
        return $process
    }
}
```

**Why one function per file?**
- Easy to find specific functions
- Better version control (smaller diffs)
- Can load selectively if needed
- Standard PowerShell convention
- Easier to test individually

**Public vs Private:**
- **Public/** - Functions exported to users (part of public API)
- **Private/** - Helper functions (internal only, not exported)

**Example Private Function:**
```powershell
# modules/Apps/Private/Test-MsiExists.ps1

function Test-MsiExists {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        throw "MSI installer not found: $Path"
    }
    
    $extension = [System.IO.Path]::GetExtension($Path)
    if ($extension -ne '.msi') {
        throw "File is not an MSI: $Path"
    }
    
    return $true
}
```

---

#### **Use Case 2: Entry Point Scripts** (in scripts/, root)

**Purpose:** Top-level orchestration or utilities  
**Can be run directly:** Yes

**Example:**
```powershell
# scripts/Invoke-Setup.ps1

#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Main entry point for ReOOBE deployment
    
.PARAMETER Role
    System role: POS, MGR, CAM, ADMIN
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet('POS', 'MGR', 'CAM', 'ADMIN')]
    [string]$Role
)

# Import required modules
Import-Module ./modules/Core/Core.psd1 -Force
Import-Module ./modules/Logging/Logging.psd1 -Force
Import-Module ./modules/UI/UI.psd1 -Force

# Initialize logging
Initialize-Log -Role $Role

# Load configuration
$settings = Import-PowerShellDataFile -Path './config/settings.psd1'

# Get execution plan for this role
$plan = Get-ExecutionPlan -Role $Role -PlansRoot './modules/Core/plans'

# Execute deployment
$results = Start-Deployment -Plan $plan -Settings $settings

# Report results
Write-DeploymentSummary -Results $results
```

**When to create:**
- Main entry points (run.ps1, Invoke-Setup.ps1)
- Utility scripts (Export-Configuration.ps1, Test-AllModules.ps1)
- Development tools (Build-Module.ps1, New-Function.ps1)

---

## Directory Structure Explained

### Module Structure
```
modules/ModuleName/
│
├── ModuleName.psm1          # Module loader (infrastructure)
├── ModuleName.psd1          # Module manifest (metadata)
├── README.md                # Documentation
│
├── Public/                  # Exported functions (public API)
│   ├── Function1.ps1        # One function per file
│   ├── Function2.ps1
│   └── Function3.ps1
│
└── Private/                 # Internal helpers (not exported)
    ├── Helper1.ps1
    └── Helper2.ps1
```

### Core Module Structure (Special)
```
modules/Core/
│
├── Core.psm1                # Module loader
├── Core.psd1                # Module manifest
├── README.md
│
├── Public/                  # Orchestration functions
│   ├── Invoke-Step.ps1      # Universal step wrapper
│   ├── Get-ExecutionPlan.ps1    # Plan loader
│   └── Start-Deployment.ps1     # Main orchestrator
│
├── Private/                 # Internal helpers
│   └── Merge-Plans.ps1      # Helper for plan merging
│
├── plans/                   # EXECUTION PLANS (data)
│   ├── base.psd1            # Steps for all roles
│   └── roles/
│       ├── POS.psd1         # POS-specific overrides
│       ├── MGR.psd1         # Manager overrides
│       ├── CAM.psd1         # Camera overrides
│       └── ADMIN.psd1       # Admin overrides
│
└── registries/              # METADATA (data)
    └── apps.psd1            # App definitions
```

### Config Folder
```
config/
├── settings.psd1            # Main configuration
├── roles.psd1               # Role definitions
└── paths.psd1               # Path mappings
```

### Scripts Folder
```
scripts/
├── run.ps1                  # Main entry point (shows menu)
├── Invoke-Setup.ps1         # Setup orchestrator
└── Export-Logs.ps1          # Utility script
```

---

## File Type Decision Tree

**Need to store configuration data?**  
→ Create `.psd1` file in `config/`

**Need to define what steps to run?**  
→ Create `.psd1` file in `plans/`

**Need to store app metadata?**  
→ Create `.psd1` file in `registries/`

**Need to create a reusable function?**  
→ Create `.ps1` file in `modules/ModuleName/Public/`

**Need a helper function (internal only)?**  
→ Create `.ps1` file in `modules/ModuleName/Private/`

**Need module infrastructure?**  
→ Create `.psm1` + `.psd1` pair in `modules/ModuleName/`

**Need a script that runs directly?**  
→ Create `.ps1` file in `scripts/`

---

## Loading Order

### 1. Module Loading
```powershell
Import-Module ./modules/Core/Core.psd1
```
**What happens:**
1. PowerShell reads `Core.psd1` (manifest)
2. PowerShell loads `Core.psm1` (module file)
3. `Core.psm1` loads all `.ps1` files from `Public/`
4. `Core.psm1` loads all `.ps1` files from `Private/`
5. `Core.psm1` exports functions listed in manifest

### 2. Data File Loading
```powershell
$apps = Import-PowerShellDataFile './registries/apps.psd1'
$plan = Import-PowerShellDataFile './plans/base.psd1'
```
**What happens:**
1. PowerShell reads the `.psd1` file
2. Evaluates it as a hashtable
3. Returns the data structure
4. NO code execution (security)

### 3. Function Calling
```powershell
Install-Chrome -MsiPath 'C:\chrome.msi'
```
**What happens:**
1. Function exists in module scope (loaded from Public/Install-Chrome.ps1)
2. PowerShell executes the function
3. Function returns result

---

## Best Practices

### Module Files (.psm1)
- ✅ Keep it simple - just load functions and export
- ✅ Use for module-level variables
- ✅ Include initialization logic if needed
- ❌ Don't put business logic here

### Manifest Files (.psd1 at module root)
- ✅ Keep metadata accurate
- ✅ List all exported functions
- ✅ Declare dependencies
- ❌ Don't skip required fields

### Data Files (.psd1 in config/plans/registries)
- ✅ Pure data only
- ✅ Use for configuration
- ✅ Easy to read and edit
- ❌ NO executable code

### Function Files (.ps1 in Public/Private)
- ✅ One function per file
- ✅ File name = function name
- ✅ Include help documentation
- ✅ Parameter validation
- ❌ Don't mix multiple functions

### Script Files (.ps1 in scripts/)
- ✅ Use for entry points
- ✅ Include parameter validation
- ✅ Add help documentation
- ❌ Don't put reusable logic here (use modules)

---

## Summary

| File Type | Purpose | Location | Code? | Exported? |
|-----------|---------|----------|-------|-----------|
| `.psm1` | Module loader | Module root | Yes | No (infrastructure) |
| `.psd1` (manifest) | Module metadata | Module root | No | N/A |
| `.psd1` (data) | Configuration/data | config/, plans/, registries/ | No | N/A |
| `.ps1` (function) | Reusable function | Public/, Private/ | Yes | Public: Yes, Private: No |
| `.ps1` (script) | Entry point/utility | scripts/, root | Yes | N/A (run directly) |

---

**Key Insight:**  
- **Code** goes in `.ps1` and `.psm1` files
- **Data** goes in `.psd1` files
- **Functions** live in `Public/` or `Private/`
- **Plans** control WHAT runs, **functions** control HOW

---

**Document Status:** Complete  
**Next Action:** Use this as reference while building modules
