@{
    # Module manifest for HMG.ConfigValidator

    # Script module or binary module file associated with this manifest.
    RootModule        = 'HMG.ConfigValidator.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = '8f3b4d92-6a71-4e8f-b3c9-2a8f5e9c1d67'

    # Author of this module
    Author            = 'Joshua Dore'

    # Company or vendor of this module
    CompanyName       = 'Haven Management Group'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Haven Management Group. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Configuration validation module for HMG Role-Based Configuration Management System. Provides comprehensive validation of settings.psd1 including schema, types, paths, and logical consistency.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Test-HMGConfiguration',
        'Show-ConfigValidationReport', 
        'Test-ConfigValue',
        'Repair-Configuration'
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
            Tags       = @('Configuration', 'Validation', 'HMG', 'RBCMS')
            ProjectUri = 'https://github.com/hmg/rbcms'
        }
    }

    # Default prefix for commands exported from this module
    # DefaultCommandPrefix = 'HMG'
}