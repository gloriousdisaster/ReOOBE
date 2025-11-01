#Requires -Version 5.1
<#
.SYNOPSIS
    Base Setup Execution Plan
    
.DESCRIPTION
    Common post-login steps that run for ALL systems regardless of role.
    This includes core applications, system settings, and baseline configurations.
    
    Runs AFTER user login as HavenAdmin.
    Role-specific plans will build upon this base.
    
.NOTES
    Phase: Setup (Post-Login)
    Execution: Runs after first login, before role-specific steps
    Goal: Install common apps, configure system baseline, prepare for role deployment
#>

@{
    # Plan Metadata
    Name        = 'Base Setup'
    Description = 'Common setup steps for all systems'
    Phase       = 'Setup'
    
    # Execution Steps
    Steps = @(
        # TODO: Define base setup steps here
        # Example step structure:
        # @{
        #     Name   = 'Install Chrome'
        #     Module = 'ReOOBE.Apps'
        #     Action = 'Install-Chrome'
        #     Params = @{}
        # }
        
        # Common steps might include:
        # - Set time zone
        # - Set power plan
        # - Install Chrome
        # - Configure firewall
        # - Disable HVCI
        # - Configure system settings
    )
    
    # Dependencies
    RequiredModules = @(
        'ReOOBE.Core'
        'ReOOBE.Apps'
        'ReOOBE.System'
        'ReOOBE.Logging'
    )
}
