#Requires -Version 5.1

<#
.SYNOPSIS
    ReOOBE Core Module - Central orchestration engine
    
.DESCRIPTION
    This module provides the foundational execution layer for the ReOOBE deployment framework.
    All deployment tasks (apps, configurations, scripts) flow through the universal Invoke-Step
    wrapper which provides consistent execution, logging, error handling, and result reporting.
    
    Key Components:
    - Invoke-Step: Universal execution wrapper
    - Get-ExecutionPlan: Plan loader and merger (future)
    - Start-Deployment: Main orchestrator (future)
    
.NOTES
    Author: Joshua Dore
    Date: October 2025
    Version: 1.0.0
#>

# ============================================================================
# Module Initialization
# ============================================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ============================================================================
# Load Private Functions
# ============================================================================

$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        Write-Verbose "Loading private function: $($_.Name)"
        . $_.FullName
    }
}

# ============================================================================
# Load Public Functions
# ============================================================================

$publicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        Write-Verbose "Loading public function: $($_.Name)"
        . $_.FullName
    }
}

# ============================================================================
# Module Variables
# ============================================================================

# Detection result cache (optional feature for performance optimization)
$script:DetectionCache = @{}

# Step execution history (for reporting and debugging)
$script:ExecutionHistory = [System.Collections.ArrayList]::new()

# ============================================================================
# Module Exports
# ============================================================================

# Export public functions (defined in manifest, but explicit here for clarity)
Export-ModuleMember -Function @(
    'Invoke-Step'
)

# ============================================================================
# Module Cleanup
# ============================================================================

# Register cleanup handler
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Verbose "ReOOBE Core module unloading - cleaning up"
    
    # Clear caches
    if ($script:DetectionCache) {
        $script:DetectionCache.Clear()
    }
    
    if ($script:ExecutionHistory) {
        $script:ExecutionHistory.Clear()
    }
}

Write-Verbose "ReOOBE Core module loaded successfully"
