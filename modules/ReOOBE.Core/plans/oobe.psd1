#Requires -Version 5.1
<#
.SYNOPSIS
    OOBE Phase Execution Plan
    
.DESCRIPTION
    Pre-login steps that run during Windows OOBE (Out-of-Box Experience).
    These steps prepare the system for first login and copy the framework.
    
    Runs BEFORE user login - minimal steps only.
    Same for ALL systems (no role variation).
    
.NOTES
    Phase: OOBE (Pre-Login)
    Execution: Runs at OOBE screen before creating first user
    Goal: Bypass OOBE, create admin account, copy framework files, basic prep
#>

@{
    # Plan Metadata
    Name        = 'OOBE'
    Description = 'Pre-login OOBE bypass and system preparation'
    Phase       = 'OOBE'
    
    # Execution Steps
    Steps = @(
        # TODO: Define OOBE steps here
        # Example step structure:
        # @{
        #     Name   = 'Bypass OOBE'
        #     Module = 'ReOOBE.System'
        #     Action = 'Set-OOBEComplete'
        #     Params = @{}
        # }
    )
    
    # Dependencies
    RequiredModules = @(
        'ReOOBE.Core'
        'ReOOBE.System'
        'ReOOBE.Vault'
        'ReOOBE.Logging'
    )
}
