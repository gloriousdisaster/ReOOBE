#Requires -Version 5.1
<#
.SYNOPSIS
    MGR Role Execution Plan
    
.DESCRIPTION
    Manager workstation configuration.
    Extends base setup with manager-specific applications and settings.
    
    Runs AFTER base.psd1 completes.
    
.NOTES
    Role: MGR (Manager)
    Phase: Setup (Post-Login)
    Extends: base.psd1
    Goal: Install manager-specific applications and configure management settings
#>

@{
    # Plan Metadata
    Name        = 'MGR'
    Description = 'Manager workstation configuration'
    Phase       = 'Setup'
    Role        = 'MGR'
    
    # Extends base plan
    Extends = 'base'
    
    # Execution Steps (in addition to base)
    Steps = @(
        # TODO: Define MGR-specific steps here
        # Example step structure:
        # @{
        #     Name   = 'Install Manager Tools'
        #     Module = 'ReOOBE.Apps'
        #     Action = 'Install-ManagerTools'
        #     Params = @{}
        # }
        
        # MGR-specific steps might include:
        # - Install SQL Server (for reporting)
        # - Install SSMS
        # - Additional management tools
        # - Configure manager-specific settings
    )
    
    # Dependencies (in addition to base requirements)
    RequiredModules = @(
        'ReOOBE.Apps'
    )
}
