<#
.SYNOPSIS
    Administrative staff workstation module for HMG automation framework.

.DESCRIPTION
    This module contains steps specific to administrative staff workstations.
    Currently, STAFF systems use baseline configuration from HMG.Baseline with no additional steps.

    STAFF-specific configuration handled in settings.psd1:
    - Office installation (priority 70)
    - 5-minute screen timeout (priority 11)
    - No autologon (manual login for security)
    - Baseline debloat only (no custom app removal)

    Note: STAFF is the computer role for administrative staff workstations.
    HavenAdmin is a separate local user account created on ALL computers.

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 2.0.0
    Requires: PowerShell 5.1 or higher
    Must be run as Administrator
    Depends on: HMG.Core, HMG.Baseline modules

    This module currently registers no steps - all STAFF configuration is handled
    through the baseline steps with role-specific filtering in settings.psd1.
#>

#requires -version 5.1
Set-StrictMode -Version Latest

# No STAFF-specific steps currently required
# All configuration handled through HMG.Baseline with role-based filtering

Export-ModuleMember -Function @()  # No functions to export, no steps registered
