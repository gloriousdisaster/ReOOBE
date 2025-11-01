#Requires -Version 5.1
<#
.SYNOPSIS
    CAM Role Execution Plan
    
.DESCRIPTION
    Camera/Security workstation configuration.
    Extends base setup with camera-specific applications and settings.
    
    Runs AFTER base.psd1 completes.
    
.NOTES
    Role: CAM (Camera/Security)
    Phase: Setup (Post-Login)
    Extends: base.psd1
    Goal: Install DeskCam and configure camera/security settings
#>

@{
    # Plan Metadata
    Name        = 'CAM'
    Description = 'Camera/Security workstation configuration'
    Phase       = 'Setup'
    Role        = 'CAM'
    
    # Extends base plan
    Extends = 'base'
    
    # Execution Steps (in addition to base)
    Steps = @(
        # TODO: Define CAM-specific steps here
        # Example step structure:
        # @{
        #     Name   = 'Install DeskCam'
        #     Module = 'ReOOBE.Apps'
        #     Action = 'Install-DeskCam'
        #     Params = @{}
        # }
        
        # CAM-specific steps might include:
        # - Install DeskCam
        # - Configure camera settings
        # - Configure security monitoring tools
    )
    
    # Dependencies (in addition to base requirements)
    RequiredModules = @(
        'ReOOBE.Apps'  # For DeskCam
    )
}
