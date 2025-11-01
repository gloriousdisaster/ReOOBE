#Requires -Version 5.1
<#
.SYNOPSIS
    STAFF Role Execution Plan
    
.DESCRIPTION
    Staff workstation configuration.
    Extends base setup with staff-specific applications and settings.
    
    Runs AFTER base.psd1 completes.
    
.NOTES
    Role: STAFF (Office Staff)
    Phase: Setup (Post-Login)
    Extends: base.psd1
    Goal: Install staff productivity tools and configure office workstation settings
#>

@{
    # Plan Metadata
    Name        = 'STAFF'
    Description = 'Staff workstation configuration'
    Phase       = 'Setup'
    Role        = 'STAFF'
    
    # Extends base plan
    Extends = 'base'
    
    # Execution Steps (in addition to base)
    Steps = @(
        # TODO: Define STAFF-specific steps here
        # Example step structure:
        # @{
        #     Name   = 'Install Office Tools'
        #     Module = 'ReOOBE.Apps'
        #     Action = 'Install-OfficeTools'
        #     Params = @{}
        # }
        
        # STAFF-specific steps might include:
        # - Install productivity tools
        # - Configure office applications
        # - Set up staff-specific settings
    )
    
    # Dependencies (in addition to base requirements)
    RequiredModules = @(
        'ReOOBE.Apps'
    )
}
