@{
  RootModule        = 'HMG.Baseline.psm1'
  ModuleVersion     = '3.0.1'
  GUID              = '9f2d8e6c-4b7a-4e5d-9c8f-3a6e2b9d4c1f'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  Copyright         = '(c) 2025 Haven Management Group. All rights reserved.'
  Description       = 'Baseline configuration module containing common steps that run on all systems. Depends on HMG.Core for the step registration framework.'
  PowerShellVersion = '5.1'

  RequiredModules   = @(
    @{ModuleName = 'HMG.Core'; ModuleVersion = '2.0.0' }
  )

  FunctionsToExport = @()  # Baseline doesn't export functions - it only registers steps
  CmdletsToExport   = @()
  VariablesToExport = @()
  AliasesToExport   = @()

  PrivateData       = @{
    PSData = @{
      Tags         = @('HMG', 'Automation', 'Baseline', 'Configuration', 'Steps')
      ProjectUri   = 'https://github.com/HavenManagementGroup/hmg_RBCMS'
      ReleaseNotes = @'
Version 3.0.1
- BUGFIX: Removed Priority 39 checkpoint that caused premature reboot
- System now flows through Section 1 directly into Section 2 without interruption
- User creation (Priority 50) and autologon (Priority 55) now complete before first reboot
- First reboot occurs at Priority 59 after user configuration is complete
- This ensures proper user context for subsequent steps and scheduled tasks

Module Responsibilities:
- HMG.Core provides the framework (Register-Step, Write-Status, etc.)
- HMG.Baseline only registers common configuration steps
- Steps include:
  * Core software (Chrome, Office, GlobalProtect, Staging Agent)
  * User configuration (local user creation, autologon)
  * System settings (timezone, power management)
  * Cleanup (debloat scripts)
  * Note: .NET 3.5 in HMG.POS module (POS-only requirement)

Proper usage:
- Import-Module HMG.Core    # For framework functions
- Import-Module HMG.Baseline # For common steps
- Import-Module HMG.[Role]   # For role-specific steps
'@
    }
  }
}
