
<#
.SYNOPSIS
    Manager workstation module for HMG automation framework.

.DESCRIPTION
    This module contains steps specific to Manager workstations.
    MGR systems use baseline configuration from HMG.Baseline with minimal additional steps.

    MGR-specific configuration handled in settings.psd1:
    - Office installation (priority 70)
    - 5-minute screen timeout (priority 11)
    - No autologon (manual login for security)
    - Baseline debloat only (no custom app removal)

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 3.0.0 - Phase 4 Checkpoint System
    Requires: PowerShell 5.1 or higher
    Must be run as Administrator
    Depends on: HMG.Core, HMG.Baseline, HMG.State modules

.CHANGELOG
    v3.0.0 - Converted to Phase 4 checkpoint system
           - Added checkpoint steps for reboot management
           - Organized into logical sections
    v2.0.0 - Initial modular implementation
#>

#requires -version 5.1
Set-StrictMode -Version Latest

# Import HMG.Core for step registration framework
$coreModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "HMG.Core\HMG.Core.psd1"
if (-not (Test-Path $coreModulePath)) {
  throw "HMG.Core module not found at: $coreModulePath. Cannot load HMG.MGR."
}
Import-Module $coreModulePath -Force -Global

# ===========================
# SECTION 1: SYSTEM CONFIGURATION (10-39)
# ===========================

# Power settings, timezone, and Chrome installation handled by HMG.Baseline

# Checkpoint after system configuration (Priority 39, Section 1)
Register-Step -Name "Checkpoint: After System Configuration" -Tags @('MGR') -Priority 39 -Section 1 -Action {
  # Get the script path from the orchestrator
  $scriptPath = if ($PSCommandPath) { 
    $PSCommandPath 
  } else { 
    "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" 
  }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-System-Configuration' `
    -Section 1 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 70
  
  # If rebooting, exit this step
  if ($rebooting) { return }
}

# ===========================
# SECTION 2: SOFTWARE INSTALLATION (70-89)
# ===========================

# Office installation handled by HMG.Baseline (Priority 70)

# Checkpoint after software installation (Priority 79, Section 2)
Register-Step -Name "Checkpoint: After Software Installation" -Tags @('MGR') -Priority 79 -Section 2 -Action {
  # Get the script path from the orchestrator
  $scriptPath = if ($PSCommandPath) { 
    $PSCommandPath 
  } else { 
    "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" 
  }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-Software-Installation' `
    -Section 2 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 90
  
  # If rebooting, exit this step
  if ($rebooting) { return }
}

# ===========================
# SECTION 3: CLEANUP & FINALIZATION (90-99)
# ===========================

# Baseline debloat handled by HMG.Baseline (Priority 90)

# Final checkpoint (Priority 99, Section 3)
Register-Step -Name "Checkpoint: Final" -Tags @('MGR') -Priority 99 -Section 3 -Action {
  # Get the script path from the orchestrator
  $scriptPath = if ($PSCommandPath) { 
    $PSCommandPath 
  } else { 
    "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" 
  }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'Final-Checkpoint' `
    -Section 3 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 100
  
  # If rebooting, exit this step
  if ($rebooting) { return }
}

Export-ModuleMember -Function @()  # No functions to export, only steps registered
