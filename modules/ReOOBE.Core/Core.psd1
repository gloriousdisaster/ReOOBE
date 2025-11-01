@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Core.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID              = '3a7f8e2d-9c4b-4f6e-a1d5-7b9c3e8f2a6d'

    # Author of this module
    Author            = 'Joshua Dore'

    # Company or vendor of this module
    CompanyName       = 'Haven Management Group'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Haven Management Group. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Core orchestration engine for ReOOBE deployment framework. Provides universal step execution wrapper and plan management.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-Step'
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
            Tags         = @('ReOOBE', 'Deployment', 'Framework', 'Orchestration', 'Core')
            ProjectUri   = 'https://github.com/HavenManagementGroup/ReOOBE'
            ReleaseNotes = @'
Version 1.0.0 (2025-10-31)
- Initial release
- Invoke-Step: Universal execution wrapper for all deployment tasks
- Structured result objects with consistent schema
- Integrated logging and UI feedback
- Retry logic with configurable delays
- Timeout protection
- Critical vs non-critical error handling
- Detection phase (skip if already complete)
- Verification phase (confirm success)
- WhatIf support
'@
        }
    }
}
