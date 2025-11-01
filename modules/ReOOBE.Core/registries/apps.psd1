#Requires -Version 5.1
<#
.SYNOPSIS
    Application Registry
    
.DESCRIPTION
    Central registry of all applications that can be deployed by the framework.
    Contains metadata about each application including installation details,
    dependencies, and configuration requirements.
    
.NOTES
    This registry is used by:
    - Get-ExecutionPlan to resolve app dependencies
    - Install-* functions in ReOOBE.Apps module
    - Validation and verification steps
#>

@{
    # Google Chrome
    Chrome = @{
        Name            = 'Google Chrome'
        Description     = 'Web browser'
        Module          = 'ReOOBE.Apps'
        InstallFunction = 'Install-Chrome'
        Version         = 'Latest'
        Architecture    = 'x64'
        Dependencies    = @()  # No dependencies
        Roles           = @('POS', 'MGR', 'CAM', 'STAFF')  # Available to all roles
    }
    
    # DeskCam
    DeskCam = @{
        Name            = 'DeskCam'
        Description     = 'Security camera software'
        Module          = 'ReOOBE.Apps'
        InstallFunction = 'Install-DeskCam'
        Version         = 'Latest'
        Architecture    = 'x64'
        Dependencies    = @()
        Roles           = @('POS', 'CAM')  # Only POS and CAM roles
    }
    
    # SQL Server
    SQLServer = @{
        Name            = 'Microsoft SQL Server'
        Description     = 'Database server'
        Module          = 'ReOOBE.Apps'
        InstallFunction = 'Install-SQLServer'
        Version         = '2019'
        Architecture    = 'x64'
        Dependencies    = @('.NET Framework 3.5')
        Roles           = @('POS', 'MGR')  # POS and Manager workstations
    }
    
    # SQL Server Management Studio
    SSMS = @{
        Name            = 'SQL Server Management Studio'
        Description     = 'SQL Server management tool'
        Module          = 'ReOOBE.Apps'
        InstallFunction = 'Install-SSMS'
        Version         = 'Latest'
        Architecture    = 'x64'
        Dependencies    = @('SQLServer')  # Requires SQL Server
        Roles           = @('POS', 'MGR')
    }
    
    # CounterPoint
    CounterPoint = @{
        Name            = 'CounterPoint'
        Description     = 'Point-of-sale software'
        Module          = 'ReOOBE.Apps'
        InstallFunction = 'Install-CounterPoint'
        Version         = 'Latest'
        Architecture    = 'x64'
        Dependencies    = @('SQLServer')  # Requires SQL Server
        Roles           = @('POS')  # POS only
    }
    
    # .NET Framework 3.5
    DotNetFramework35 = @{
        Name            = '.NET Framework 3.5'
        Description     = 'Legacy .NET runtime'
        Module          = 'ReOOBE.Apps'
        InstallFunction = 'Install-DotNetFramework35'
        Version         = '3.5'
        Architecture    = 'x64'
        Dependencies    = @()
        Roles           = @('POS', 'MGR')  # Required for SQL Server
    }
    
    # TODO: Add more applications as needed
    # Example template:
    # AppName = @{
    #     Name            = 'Full Application Name'
    #     Description     = 'Brief description'
    #     Module          = 'ReOOBE.Apps'
    #     InstallFunction = 'Install-AppName'
    #     Version         = 'Version or Latest'
    #     Architecture    = 'x64 or x86'
    #     Dependencies    = @('Dependency1', 'Dependency2')
    #     Roles           = @('Role1', 'Role2')
    # }
}
