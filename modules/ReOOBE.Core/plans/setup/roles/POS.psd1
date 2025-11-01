#Requires -Version 5.1
<#
.SYNOPSIS
    POS Role Execution Plan
    
.DESCRIPTION
    Point-of-Sale workstation configuration.
    Extends base setup with POS-specific applications and settings.
    
    Runs AFTER base.psd1 completes.
    
.NOTES
    Role: POS (Point-of-Sale)
    Phase: Setup (Post-Login)
    Extends: base.psd1
    Goal: Install DeskCam, SQL Server, CounterPoint, configure POS settings
#>

@{
    # Plan Metadata
    Name        = 'POS'
    Description = 'Point-of-Sale workstation configuration'
    Phase       = 'Setup'
    Role        = 'POS'
    
    # Extends base plan
    Extends = 'base'
    
    # Execution Steps (in addition to base)
    Steps = @(
        # TODO: Define POS-specific steps here
        # Example step structure:
        # @{
        #     Name   = 'Install DeskCam'
        #     Module = 'ReOOBE.Apps'
        #     Action = 'Install-DeskCam'
        #     Params = @{}
        # }
        
        # POS-specific steps might include:
        # - Install SQL Server
        # - Install SSMS
        # - Install DeskCam
        # - Install CounterPoint
        # - Configure POS-specific settings
    )
    
    # Dependencies (in addition to base requirements)
    RequiredModules = @(
        'ReOOBE.Apps'  # For SQL, DeskCam, CounterPoint
    )
}
