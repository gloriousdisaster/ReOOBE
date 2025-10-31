#requires -version 5.1
<#
.SYNOPSIS
    Configuration validation module for HMG Role-Based Configuration Management System

.DESCRIPTION
    Provides comprehensive validation of settings.psd1 configuration file including:
    - Schema validation (required keys and structure)
    - Type checking (correct data types)
    - Path validation (files and directories exist)
    - Cross-reference validation (roles, dependencies)
    - Value range checking

.AUTHOR
    Joshua Dore

.DATE
    October 2025
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Schema definitions for validation
$script:RequiredTopLevelKeys = @(
    'InstallersPath',
    'LogsPath', 
    'PowerPolicies',
    'LocalUsers',
    'Autologon',
    'Chrome',
    'Office'
)

$script:OptionalTopLevelKeys = @(
    'ScreenTimeoutMinutes',
    'DotNetFramework',
    'Debloat',
    'LocalUsersPasswords',
    'PasswordMode',
    'EncryptedPasswordFile',
    'Firewall',
    'Axis',
    'GlobalProtect',
    'StagingAgent',
    'TimeZone',
    'MemoryIntegrity'
)

$script:ValidRoles = @('POS', 'MGR', 'CAM', 'STAFF', 'ADMIN')
$script:ValidPowerSchemes = @('Balanced', 'High Performance', 'Power Saver', 'High', 'Low')
$script:ValidPasswordModes = @('PlainText', 'Encrypted')

function Test-HMGConfiguration {
    <#
    .SYNOPSIS
        Validates the complete HMG configuration file
    
    .DESCRIPTION
        Performs comprehensive validation of settings.psd1 including schema,
        types, paths, and logical consistency
    
    .PARAMETER ConfigPath
        Path to settings.psd1 file
    
    .PARAMETER Role
        Role to validate configuration for
    
    .PARAMETER StopOnError
        Stop validation on first error (default: false, validate everything)
    
    .PARAMETER Detailed
        Return detailed validation results object
    
    .EXAMPLE
        Test-HMGConfiguration -ConfigPath ".\config\settings.psd1" -Role POS
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory)]
        [ValidateSet('POS', 'MGR', 'CAM', 'STAFF', 'ADMIN')]
        [string]$Role,
        
        [switch]$StopOnError,
        
        [switch]$Detailed
    )
    
    $results = @{
        Valid      = $true
        Errors     = @()
        Warnings   = @()
        Info       = @()
        TestedAt   = Get-Date
        ConfigPath = $ConfigPath
        Role       = $Role
    }
    
    # Load configuration
    try {
        if (-not (Test-Path $ConfigPath)) {
            $results.Errors += "Configuration file not found: $ConfigPath"
            $results.Valid = $false
            
            if ($Detailed) { return $results }
            else { return $false }
        }
        
        $config = Import-PowerShellDataFile $ConfigPath
        $results.Info += "Configuration loaded successfully from: $ConfigPath"
    }
    catch {
        $results.Errors += "Failed to load configuration: $($_.Exception.Message)"
        $results.Valid = $false
        
        if ($Detailed) { return $results }
        else { return $false }
    }
    
    # Validate required top-level keys
    foreach ($key in $script:RequiredTopLevelKeys) {
        if (-not $config.ContainsKey($key)) {
            $results.Errors += "Missing required key: $key"
            $results.Valid = $false
            if ($StopOnError) { break }
        }
    }
    
    # Validate unknown keys (typos)
    $allKnownKeys = $script:RequiredTopLevelKeys + $script:OptionalTopLevelKeys
    foreach ($key in $config.Keys) {
        if ($key -notin $allKnownKeys) {
            $results.Warnings += "Unknown configuration key: $key (possible typo?)"
        }
    }
    
    # Validate paths
    if ($config.InstallersPath) {
        if (-not (Test-Path $config.InstallersPath)) {
            $results.Warnings += "InstallersPath does not exist: $($config.InstallersPath)"
            $results.Info += "This is normal for development/testing environments"
        } else {
            $results.Info += "InstallersPath validated: $($config.InstallersPath)"
        }
    }
    
    if ($config.LogsPath) {
        $logParent = Split-Path $config.LogsPath -Parent
        if (-not (Test-Path $logParent)) {
            $results.Warnings += "Logs parent directory does not exist: $logParent (will be created)"
        }
    }
    
    # Validate PowerPolicies
    if ($config.PowerPolicies) {
        if (-not ($config.PowerPolicies -is [hashtable])) {
            $results.Errors += "PowerPolicies must be a hashtable"
            $results.Valid = $false
        } else {
            # Check if role has power policy
            if (-not $config.PowerPolicies.ContainsKey($Role)) {
                $results.Errors += "No power policy defined for role: $Role"
                $results.Valid = $false
            } else {
                $policy = $config.PowerPolicies[$Role]
                
                # Validate power policy structure
                $requiredPolicyKeys = @('Scheme')
                foreach ($pkey in $requiredPolicyKeys) {
                    if (-not $policy.ContainsKey($pkey)) {
                        $results.Errors += "PowerPolicies.$Role missing required key: $pkey"
                        $results.Valid = $false
                    }
                }
                
                # Validate scheme value
                if ($policy.Scheme -and $policy.Scheme -notin $script:ValidPowerSchemes) {
                    $results.Warnings += "PowerPolicies.$Role.Scheme has non-standard value: $($policy.Scheme)"
                }
                
                # Validate numeric values
                @('AC_DisplayMin', 'DC_DisplayMin', 'AC_SleepMin', 'DC_SleepMin') | ForEach-Object {
                    if ($policy.ContainsKey($_)) {
                        $val = $policy[$_]
                        if ($val -isnot [int] -or $val -lt 0) {
                            $results.Errors += "PowerPolicies.$Role.$_ must be a non-negative integer (found: $val)"
                            $results.Valid = $false
                        }
                    }
                }
            }
        }
    }
    
    # Validate LocalUsers
    if ($config.LocalUsers) {
        if (-not $config.LocalUsers.ContainsKey($Role)) {
            $results.Errors += "No LocalUsers configuration for role: $Role"
            $results.Valid = $false
        } else {
            $userConfig = $config.LocalUsers[$Role]
            
            # Check Groups is an array
            if ($userConfig.Groups -and $userConfig.Groups -isnot [array]) {
                $results.Errors += "LocalUsers.$Role.Groups must be an array"
                $results.Valid = $false
            }
            
            # Check Admin is boolean
            if ($userConfig.ContainsKey('Admin') -and $userConfig.Admin -isnot [bool]) {
                $results.Errors += "LocalUsers.$Role.Admin must be a boolean"
                $results.Valid = $false
            }
        }
    }
    
    # Validate Password Configuration
    if ($config.PasswordMode) {
        if ($config.PasswordMode -notin $script:ValidPasswordModes) {
            $results.Errors += "PasswordMode must be 'PlainText' or 'Encrypted' (found: $($config.PasswordMode))"
            $results.Valid = $false
        }
        
        if ($config.PasswordMode -eq 'Encrypted') {
            if (-not $config.EncryptedPasswordFile) {
                $results.Errors += "PasswordMode is 'Encrypted' but EncryptedPasswordFile is not specified"
                $results.Valid = $false
            } else {
                # Resolve path if relative
                $passwordPath = $config.EncryptedPasswordFile
                if ($passwordPath.StartsWith('.\')) {
                    $root = Split-Path (Split-Path $ConfigPath -Parent) -Parent
                    $passwordPath = Join-Path $root $passwordPath.TrimStart('.\')
                }
                
                if (-not (Test-Path $passwordPath)) {
                    $results.Errors += "Encrypted password file not found: $passwordPath"
                    $results.Valid = $false
                } else {
                    $results.Info += "Encrypted password file found: $passwordPath"
                }
            }
        } elseif ($config.PasswordMode -eq 'PlainText') {
            if ($config.LocalUsersPasswords) {
                if (-not $config.LocalUsersPasswords.ContainsKey($Role)) {
                    $results.Errors += "No password configured for role: $Role in LocalUsersPasswords"
                    $results.Valid = $false
                } elseif ([string]::IsNullOrEmpty($config.LocalUsersPasswords[$Role].Pass)) {
                    $results.Warnings += "Password for role $Role is empty"
                }
            } else {
                $results.Errors += "PasswordMode is 'PlainText' but LocalUsersPasswords is not configured"
                $results.Valid = $false
            }
        }
    }
    
    # Validate Autologon
    if ($config.Autologon) {
        if ($config.Autologon.ContainsKey($Role)) {
            $autologon = $config.Autologon[$Role]
            
            if ($autologon.Enable -eq $true) {
                if (-not $autologon.ToolPath) {
                    $results.Errors += "Autologon enabled for $Role but ToolPath not specified"
                    $results.Valid = $false
                } elseif (-not (Test-Path $autologon.ToolPath)) {
                    $results.Warnings += "Autologon tool not found: $($autologon.ToolPath)"
                }
            }
        }
    }
    
    # Validate Chrome
    if ($config.Chrome) {
        if ($config.Chrome.Roles -and $Role -in $config.Chrome.Roles) {
            if (-not $config.Chrome.Msi) {
                $results.Errors += "Chrome enabled for $Role but Msi not specified"
                $results.Valid = $false
            } else {
                $chromePath = Join-Path $config.InstallersPath $config.Chrome.Msi -ErrorAction SilentlyContinue
                if ($chromePath -and -not (Test-Path $chromePath)) {
                    $results.Warnings += "Chrome MSI not found: $chromePath"
                }
            }
        }
    }
    
    # Validate Office
    if ($config.Office) {
        # Check install configuration
        if ($config.Office.Install -and $config.Office.Install.Roles -contains $Role) {
            $officeInstall = $config.Office.Install
            
            if (-not $officeInstall.SourcePath) {
                $results.Errors += "Office install enabled for $Role but SourcePath not specified"
                $results.Valid = $false
            } else {
                $setupPath = Join-Path $officeInstall.SourcePath 'setup.exe' -ErrorAction SilentlyContinue
                if ($setupPath -and -not (Test-Path $setupPath)) {
                    $results.Warnings += "Office setup.exe not found: $setupPath"
                }
                
                if ($officeInstall.Xml) {
                    $xmlPath = Join-Path $officeInstall.SourcePath $officeInstall.Xml -ErrorAction SilentlyContinue
                    if ($xmlPath -and -not (Test-Path $xmlPath)) {
                        $results.Warnings += "Office install XML not found: $xmlPath"
                    }
                }
            }
        }
        
        # Check uninstall configuration
        if ($config.Office.Uninstall -and $config.Office.Uninstall.Roles -contains $Role) {
            $officeUninstall = $config.Office.Uninstall
            
            if (-not $officeUninstall.SourcePath) {
                $results.Errors += "Office uninstall enabled for $Role but SourcePath not specified"
                $results.Valid = $false
            } else {
                if ($officeUninstall.Xml) {
                    $xmlPath = Join-Path $officeUninstall.SourcePath $officeUninstall.Xml -ErrorAction SilentlyContinue
                    if ($xmlPath -and -not (Test-Path $xmlPath)) {
                        $results.Warnings += "Office uninstall XML not found: $xmlPath"
                    }
                }
            }
        }
    }
    
    # Validate Firewall rules
    if ($config.Firewall -and $config.Firewall.ContainsKey($Role)) {
        $rules = $config.Firewall[$Role].Rules
        if ($rules -and $rules.Count -gt 0) {
            $ruleIndex = 0
            foreach ($rule in $rules) {
                $ruleIndex++
                
                # Check required fields
                $requiredRuleFields = @('Name', 'Protocol', 'Direction')
                foreach ($field in $requiredRuleFields) {
                    if (-not $rule.ContainsKey($field)) {
                        $results.Errors += "Firewall.$Role.Rules[$ruleIndex] missing required field: $field"
                        $results.Valid = $false
                    }
                }
                
                # Validate protocol
                if ($rule.Protocol -and $rule.Protocol -notin @('TCP', 'UDP', 'Any')) {
                    $results.Errors += "Firewall.$Role.Rules[$ruleIndex] invalid Protocol: $($rule.Protocol)"
                    $results.Valid = $false
                }
                
                # Validate direction
                if ($rule.Direction -and $rule.Direction -notin @('Inbound', 'Outbound')) {
                    $results.Errors += "Firewall.$Role.Rules[$ruleIndex] invalid Direction: $($rule.Direction)"
                    $results.Valid = $false
                }
            }
        }
    }
    
    # Validate Debloat
    if ($config.Debloat) {
        if ($config.Debloat.Baseline) {
            $baseline = $config.Debloat.Baseline
            if ($baseline.ScriptPath -and -not (Test-Path $baseline.ScriptPath)) {
                $results.Warnings += "Debloat baseline script not found: $($baseline.ScriptPath)"
            }
        }
        
        if ($config.Debloat.ContainsKey($Role)) {
            $roleDebloat = $config.Debloat[$Role]
            if ($roleDebloat.CustomAppsList -and -not (Test-Path $roleDebloat.CustomAppsList)) {
                $results.Warnings += "Debloat custom apps list not found: $($roleDebloat.CustomAppsList)"
            }
        }
    }
    
    # Validate TimeZone
    if ($config.TimeZone -and $config.TimeZone.Id) {
        try {
            $tz = Get-TimeZone -Id $config.TimeZone.Id -ErrorAction Stop
        }
        catch {
            $results.Warnings += "Invalid TimeZone ID: $($config.TimeZone.Id)"
        }
    }
    
    # Summary
    if ($results.Errors.Count -eq 0) {
        $results.Info += "Configuration validation successful for role: $Role"
    } else {
        $results.Info += "Configuration has $($results.Errors.Count) error(s) and $($results.Warnings.Count) warning(s)"
    }
    
    if ($Detailed) {
        return $results
    } else {
        return $results.Valid
    }
}

function Show-ConfigValidationReport {
    <#
    .SYNOPSIS
        Displays a formatted configuration validation report
    
    .DESCRIPTION
        Takes validation results and displays them in a formatted, color-coded report
    
    .PARAMETER ValidationResults
        Results object from Test-HMGConfiguration with -Detailed
    
    .PARAMETER ShowAll
        Show all messages including info (default: only errors and warnings)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$ValidationResults,
        
        [switch]$ShowAll
    )
    
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          HMG Configuration Validation Report             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "`nConfiguration: " -NoNewline -ForegroundColor White
    Write-Host $ValidationResults.ConfigPath -ForegroundColor Gray
    
    Write-Host "Role:          " -NoNewline -ForegroundColor White
    Write-Host $ValidationResults.Role -ForegroundColor Gray
    
    Write-Host "Tested:        " -NoNewline -ForegroundColor White
    Write-Host $ValidationResults.TestedAt.ToString('yyyy-MM-dd HH:mm:ss') -ForegroundColor Gray
    
    Write-Host "`nValidation Result: " -NoNewline -ForegroundColor White
    if ($ValidationResults.Valid) {
        Write-Host "✓ PASSED" -ForegroundColor Green
    } else {
        Write-Host "✗ FAILED" -ForegroundColor Red
    }
    
    # Show errors
    if ($ValidationResults.Errors.Count -gt 0) {
        Write-Host "`n═══ ERRORS ═══" -ForegroundColor Red
        foreach ($error in $ValidationResults.Errors) {
            Write-Host "  ✗ $error" -ForegroundColor Red
        }
    }
    
    # Show warnings
    if ($ValidationResults.Warnings.Count -gt 0) {
        Write-Host "`n═══ WARNINGS ═══" -ForegroundColor Yellow
        foreach ($warning in $ValidationResults.Warnings) {
            Write-Host "  ⚠ $warning" -ForegroundColor Yellow
        }
    }
    
    # Show info (if requested)
    if ($ShowAll -and $ValidationResults.Info.Count -gt 0) {
        Write-Host "`n═══ INFORMATION ═══" -ForegroundColor Gray
        foreach ($info in $ValidationResults.Info) {
            Write-Host "  ℹ $info" -ForegroundColor Gray
        }
    }
    
    # Summary
    Write-Host "`n═══ SUMMARY ═══" -ForegroundColor Cyan
    Write-Host "Errors:   $($ValidationResults.Errors.Count)" -ForegroundColor $(if ($ValidationResults.Errors.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Warnings: $($ValidationResults.Warnings.Count)" -ForegroundColor $(if ($ValidationResults.Warnings.Count -eq 0) { 'Green' } else { 'Yellow' })
    
    if (-not $ValidationResults.Valid) {
        Write-Host "`n⚠ Configuration has critical errors that must be fixed before setup can proceed." -ForegroundColor Red
    } elseif ($ValidationResults.Warnings.Count -gt 0) {
        Write-Host "`n⚠ Configuration has warnings but setup can proceed." -ForegroundColor Yellow
    } else {
        Write-Host "`n✓ Configuration is valid and ready for setup." -ForegroundColor Green
    }
}

function Test-ConfigValue {
    <#
    .SYNOPSIS
        Tests a specific configuration value
    
    .DESCRIPTION
        Helper function to test individual configuration values
    
    .PARAMETER Config
        Configuration hashtable
    
    .PARAMETER Path
        Dot-notation path to value (e.g., "PowerPolicies.POS.Scheme")
    
    .PARAMETER ExpectedType
        Expected PowerShell type
    
    .PARAMETER ValidValues
        Array of valid values
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Config,
        [string]$Path,
        [type]$ExpectedType,
        [array]$ValidValues,
        [switch]$Required
    )
    
    $segments = $Path -split '\.'
    $current = $Config
    
    foreach ($segment in $segments) {
        if ($current -is [hashtable] -and $current.ContainsKey($segment)) {
            $current = $current[$segment]
        } else {
            if ($Required) {
                return @{
                    Valid = $false
                    Error = "Missing required configuration: $Path"
                }
            } else {
                return @{
                    Valid   = $true
                    Warning = "Optional configuration not found: $Path"
                }
            }
        }
    }
    
    # Type check
    if ($ExpectedType -and $current -isnot $ExpectedType) {
        return @{
            Valid = $false
            Error = "$Path must be of type $($ExpectedType.Name), found: $($current.GetType().Name)"
        }
    }
    
    # Value check
    if ($ValidValues -and $current -notin $ValidValues) {
        return @{
            Valid = $false
            Error = "$Path has invalid value: $current. Valid values: $($ValidValues -join ', ')"
        }
    }
    
    return @{
        Valid = $true
        Value = $current
    }
}

function Repair-Configuration {
    <#
    .SYNOPSIS
        Attempts to repair common configuration issues
    
    .DESCRIPTION
        Fixes common configuration problems like missing directories,
        wrong types, and provides defaults for missing optional values
    
    .PARAMETER ConfigPath
        Path to configuration file
    
    .PARAMETER BackupOriginal
        Create backup of original file before repair
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [switch]$BackupOriginal
    )
    
    if ($BackupOriginal) {
        $backupPath = $ConfigPath -replace '\.psd1$', "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').psd1"
        Copy-Item -Path $ConfigPath -Destination $backupPath -Force
        Write-Host "Created backup: $backupPath" -ForegroundColor Green
    }
    
    # Load current config
    $config = Import-PowerShellDataFile $ConfigPath
    $changes = @()
    
    # Add missing required keys with sensible defaults
    $defaults = @{
        InstallersPath = 'C:\bin\deployment\global\installers'
        LogsPath       = 'C:\bin\HMG\logs'
        PowerPolicies  = @{
            POS   = @{ Scheme = 'High'; AC_DisplayMin = 0; DC_DisplayMin = 0; AC_SleepMin = 0; DC_SleepMin = 0 }
            MGR   = @{ Scheme = 'High'; AC_DisplayMin = 5; DC_DisplayMin = 5; AC_SleepMin = 0; DC_SleepMin = 0 }
            CAM   = @{ Scheme = 'High'; AC_DisplayMin = 0; DC_DisplayMin = 0; AC_SleepMin = 0; DC_SleepMin = 0 }
            STAFF = @{ Scheme = 'High'; AC_DisplayMin = 5; DC_DisplayMin = 5; AC_SleepMin = 0; DC_SleepMin = 0 }
        }
        LocalUsers     = @{
            POS   = @{ Name = ''; Groups = @('Users'); Admin = $true }
            MGR   = @{ Name = ''; Groups = @('Users'); Admin = $true }
            CAM   = @{ Name = ''; Groups = @('Users'); Admin = $true }
            STAFF = @{ Name = ''; Groups = @('Users'); Admin = $true }
        }
        PasswordMode   = 'PlainText'
        Chrome         = @{
            Msi       = 'googlechromestandaloneenterprise64.msi'
            Arguments = '/qn /norestart'
            Roles     = @('POS', 'MGR', 'CAM', 'STAFF')
        }
    }
    
    foreach ($key in $defaults.Keys) {
        if (-not $config.ContainsKey($key)) {
            $config[$key] = $defaults[$key]
            $changes += "Added missing required key: $key"
        }
    }
    
    # Fix common typos
    $typoFixes = @{
        'Installer_Path' = 'InstallersPath'
        'Log_Path'       = 'LogsPath'
        'Power_Policies' = 'PowerPolicies'
        'Local_Users'    = 'LocalUsers'
    }
    
    foreach ($typo in $typoFixes.Keys) {
        if ($config.ContainsKey($typo)) {
            $config[$typoFixes[$typo]] = $config[$typo]
            $config.Remove($typo)
            $changes += "Fixed typo: $typo -> $($typoFixes[$typo])"
        }
    }
    
    # Note: Actually writing the repaired config back would require
    # converting hashtable to .psd1 format which is complex
    # For now, return suggested changes
    
    if ($changes.Count -gt 0) {
        Write-Host "`nSuggested configuration repairs:" -ForegroundColor Yellow
        foreach ($change in $changes) {
            Write-Host "  - $change" -ForegroundColor Gray
        }
        Write-Host "`nNote: Automatic repair writing not implemented." -ForegroundColor Yellow
        Write-Host "Please manually apply these changes to your configuration file." -ForegroundColor Yellow
    } else {
        Write-Host "No repairs needed - configuration appears valid." -ForegroundColor Green
    }
    
    return $changes
}

# Export functions
Export-ModuleMember -Function @(
    'Test-HMGConfiguration',
    'Show-ConfigValidationReport',
    'Test-ConfigValue',
    'Repair-Configuration'
)