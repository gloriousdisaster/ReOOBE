
<#
.SYNOPSIS
    Camera system module for Axis Camera Station deployments.

.DESCRIPTION
    This module contains steps specific to camera/surveillance systems including:
    - Axis Camera Station client installation
    - Camera network configuration (placeholder)
    - Surveillance-specific optimizations

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.NOTES
    Version: 2.0.0 - Phase 4 Checkpoint System
    Requires: PowerShell 5.1 or higher
    Must be run as Administrator
    Depends on: HMG.Core, HMG.State modules

.CHANGELOG
    v2.0.0 - Converted to Phase 4 checkpoint system
           - Removed manual reboot flag management
           - Added section numbers to all steps
           - Implemented checkpoint-based reboot logic
    v1.0.0 - Initial release
#>

Set-StrictMode -Version Latest

# Import HMG.Core for step registration framework
$coreModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "HMG.Core\HMG.Core.psd1"
if (-not (Test-Path $coreModulePath)) {
  throw "HMG.Core module not found at: $coreModulePath. Cannot load HMG.CAM."
}
Import-Module $coreModulePath -Force -Global

# ===========================
# SECTION 1: SYSTEM CONFIGURATION & SOFTWARE INSTALLATION (25-39)
# ===========================

# Install Axis Client (Priority 25, Section 1)
Register-Step -Name "Install Axis Client" -Tags @('CAM') -Priority 25 -Section 1 -Action {
  if ($Settings.Axis.Roles -notcontains $Role) { return }

  # Check multiple possible installation paths
  $axisPaths = @(
    "$Env:ProgramFiles\AXIS Communications\AXIS Camera Station\ACSC.exe",
    "${Env:ProgramFiles(x86)}\AXIS Communications\AXIS Camera Station\ACSC.exe"
  )

  $installed = $false
  foreach ($path in $axisPaths) {
    if (Test-Path $path) {
      $installed = $true
      break
    }
  }

  if ($installed) {
    Write-Status "Axis Camera Station already installed" 'Success'
    return
  }

  $msi = Join-Path $Settings.InstallersPath $Settings.Axis.ClientMsi
  if (-not (Test-Path $msi)) {
    Write-Status "Axis MSI not found: $msi" 'Warning'
    return
  }

  Write-Status "Installing Axis Camera Station Client..." 'Info'
  Start-Process msiexec.exe -ArgumentList "/i `"$msi`" $($Settings.Axis.Arguments)" -Wait

  # Check if installation succeeded
  $installed = $false
  foreach ($path in $axisPaths) {
    if (Test-Path $path) {
      $installed = $true
      break
    }
  }

  if ($installed) {
    Write-Status "Axis Camera Station installed successfully" 'Success'
  }
  else {
    Write-Status "Axis Camera Station installation may have failed" 'Warning'
  }
}

# CAM-specific camera network configuration (placeholder for future) (Priority 30, Section 1)
Register-Step -Name "Configure Camera Network" -Tags @('CAM') -Priority 30 -Section 1 -Action {
  # This would configure network settings specific to camera systems
  # For now, just a placeholder
  Write-Status "Camera network configuration not yet implemented" 'Info'
}

# Checkpoint after initial setup (Priority 39, Section 1)
Register-Step -Name "Checkpoint: After Initial Setup" -Tags @('CAM') -Priority 39 -Section 1 -Action {
  # Get the script path from the orchestrator
  $scriptPath = if ($PSCommandPath) { 
    $PSCommandPath 
  } else { 
    "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" 
  }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'After-Initial-Setup' `
    -Section 1 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 90
  
  # If rebooting, exit this step
  if ($rebooting) { return }
}

# ===========================
# SECTION 2: CLEANUP & FINALIZATION (90-99)
# ===========================

# Run CAM-specific Custom App Removal (Priority 91, Section 2)
Register-Step -Name "Run CAM Custom App Removal" -Tags @('CAM') -Priority 91 -Section 2 -DependsOn @('Run Baseline Debloat') -Action {
  $debloatConfig = $Settings.Debloat

  # Check if custom app removal is enabled for CAM
  if (-not $debloatConfig.CAM.RemoveCustom) {
    Write-Status "CAM custom app removal not enabled" 'Info'
    return
  }

  # Validate custom apps list exists
  if (-not $debloatConfig.CAM.CustomAppsList -or -not (Test-Path $debloatConfig.CAM.CustomAppsList)) {
    Write-Status "CAM custom apps list not found: $($debloatConfig.CAM.CustomAppsList)" 'Warning'
    return
  }

  # Get the debloat script path
  if (-not $debloatConfig.Baseline.ScriptPath -or -not (Test-Path $debloatConfig.Baseline.ScriptPath)) {
    Write-Status "Debloat script not found, cannot remove custom apps" 'Warning'
    return
  }

  Write-Status "Running CAM custom app removal (includes OneDrive)..." 'Info'

  # Get script directory
  $scriptDir = Split-Path -Parent $debloatConfig.Baseline.ScriptPath
  $scriptName = Split-Path -Leaf $debloatConfig.Baseline.ScriptPath

  # Build arguments for custom app removal
  $argList = "-RemoveAppsCustom -Sysprep -Silent"
  if ($debloatConfig.Baseline.LogPath -and (Test-Path $debloatConfig.Baseline.LogPath)) {
    $argList += " -LogPath `"$($debloatConfig.Baseline.LogPath)`""
  }

  # Execute custom app removal
  Push-Location $scriptDir
  try {
    # Run with custom apps list
    $scriptBlock = [ScriptBlock]::Create(".\$scriptName $argList")
    & $scriptBlock

    Write-Status "CAM custom app removal complete" 'Success'

    # Check for created logs
    $logDir = Join-Path $scriptDir 'Logs'
    if (Test-Path $logDir) {
      $latestLog = Get-ChildItem $logDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($latestLog) {
        Write-Status "Custom app removal log: $($latestLog.FullName)" 'Info'
      }
    }
  }
  catch {
    Write-Status "CAM custom app removal failed: $_" 'Error'
    Write-Status "Error details: $($_.Exception.Message)" 'Error'
  }
  finally {
    Pop-Location
  }
}

# Final checkpoint (Priority 99, Section 2)
Register-Step -Name "Checkpoint: Final" -Tags @('CAM') -Priority 99 -Section 2 -Action {
  # Get the script path from the orchestrator
  $scriptPath = if ($PSCommandPath) { 
    $PSCommandPath 
  } else { 
    "C:\bin\RBCMS\scripts\Invoke-Setup.ps1" 
  }
  
  $rebooting = Invoke-RebootCheckpoint `
    -CheckpointName 'Final-Checkpoint' `
    -Section 2 `
    -ScriptPath $scriptPath `
    -Role $Role `
    -NextStep 100
  
  # If rebooting, exit this step
  if ($rebooting) { return }
}
