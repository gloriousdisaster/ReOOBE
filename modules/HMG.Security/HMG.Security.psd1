@{
  # Module manifest for HMG.Security

  # Script module or binary module file associated with this manifest.
  RootModule        = 'HMG.Security.psm1'

  # Version number of this module.
  ModuleVersion     = '2.0.0'

  # ID used to uniquely identify this module
  GUID              = 'c8f4e7a2-9b3d-4e1a-8f5c-2d7e9a3b6c4f'

  # Author of this module
  Author            = 'Joshua Dore'

  # Company or vendor of this module
  CompanyName       = 'Haven Management Group'

  # Copyright statement for this module
  Copyright         = '(c) 2025 Haven Management Group. All rights reserved.'

  # Description of the functionality provided by this module
  Description       = 'Security module for HMG password encryption and management using AES-256 encryption with PBKDF2 key derivation.'

  # Minimum version of the PowerShell engine required by this module
  PowerShellVersion = '5.1'

  # Functions to export from this module
  FunctionsToExport = @(
    'Protect-TextWithPassword',
    'Unprotect-TextWithPassword',
    'Protect-RolePasswords',
    'Unprotect-RolePasswords',
    'Get-MasterPassword',
    'Get-RolePassword',
    'Clear-PasswordCache',
    'ConvertFrom-SecureStringPlain'
  )

  # Cmdlets to export from this module
  CmdletsToExport   = @()

  # Variables to export from this module
  VariablesToExport = @()

  # Aliases to export from this module
  AliasesToExport   = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess
  PrivateData       = @{
    PSData = @{
      # Tags applied to this module for module discovery
      Tags         = @('Security', 'Encryption', 'Password', 'AES', 'PBKDF2', 'HMG')

      # A URL to the license for this module.
      LicenseUri   = ''

      # A URL to the main website for this project.
      ProjectUri   = ''

      # A URL to an icon representing this module.
      IconUri      = ''

      # ReleaseNotes of this module
      ReleaseNotes = @'
## Version 2.0.0
- Moved module to proper PowerShell modules directory
- Renamed password files to vault terminology
- Improved cross-computer compatibility
- Fixed encoding issues when transferring blobs between computers
- Added support for returning SecureString directly from Get-MasterPassword
'@
    }
  }

  # HelpInfo URI of this module
  HelpInfoURI       = ''
}
