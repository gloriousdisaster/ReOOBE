@{
  RootModule        = 'HMG.Core.psm1'
  ModuleVersion     = '2.1.0'
  GUID              = '7c8e5f1d-2a4b-4c9e-8d6f-1e3a5b7c9d2e'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  Copyright         = '(c) 2025 Haven Management Group. All rights reserved.'
  Description       = 'Core engine module for HMG automation framework - pure framework functionality with no step registrations.'
  PowerShellVersion = '5.1'

  FunctionsToExport = @(
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
    'Test-PendingReboot',
    'Get-HMGFramework',
    'Sync-HMGLegacyState'
  )

  CmdletsToExport   = @()
  VariablesToExport = @()
  AliasesToExport   = @()

  PrivateData       = @{
    PSData = @{
      Tags         = @('HMG', 'Automation', 'Framework', 'Core', 'Engine')
      ProjectUri   = 'https://github.com/HavenManagementGroup/hmg_RBCMS'
      ReleaseNotes = @'
Version 2.1.0
- Added dynamic path resolution functions for portable deployment
- Get-HMGProjectRoot: Finds project root from any location
- Get-HMGPath: Standardized path getter for framework components
- Find-HMGInstaller: Dynamic installer discovery with wildcard support
- Makes framework portable across development, production, and USB deployments

Version 2.0.0
- Initial release as separate module (extracted from HMG.Common 1.0)
- Contains ONLY framework functions - no step registrations
- Clean separation of concerns: engine vs. business logic
- Maintains backward compatibility through HMG.Common wrapper
'@
    }
  }
}
