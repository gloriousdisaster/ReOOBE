# HMG Framework - Reboot and Resume Implementation Guide

## Overview

The HMG Framework now includes comprehensive reboot and resume functionality that allows the setup process to:
- Request system reboots when needed
- Automatically resume after reboot
- Track progress across multiple reboots
- Maintain state persistence
- Handle complex multi-stage installations

## Architecture

### Components

1. **HMG.State Module** (`RBCMS/modules/HMG.State/`)
   - Core state management functionality
   - JSON-based state persistence
   - Progress tracking
   - Scheduled task management

2. **HMG.Core Module** (`RBCMS/modules/HMG.Core/`)
   - `Request-Reboot` helper function
   - `Test-PendingReboot` detection
   - Integration points for steps

3. **Enhanced Orchestrator** (`RBCMS/scripts/Invoke-Setup-StateAware.ps1`)
   - State-aware execution
   - Automatic resume detection
   - Progress visualization

4. **Demo Module** (`RBCMS/modules/HMG.RebootDemo/`)
   - Example implementations
   - Test scenarios
   - Best practices

## How It Works

### 1. State Initialization

When setup starts, the state module creates tracking files:

```powershell
# State files created in C:\bin\HMG\state\
current-state.json    # Current execution state
progress.json         # Detailed progress tracking
reboot-required.flag  # Reboot indicator
```

### 2. Progress Tracking

Each step execution is tracked:

```powershell
Update-StepProgress -StepNumber 5 -StepName "Install Updates" -Success $true
```

### 3. Reboot Request

When a step requires reboot:

```powershell
# In your step action
Request-Reboot -Message "Windows Updates require restart" -AutoResume
```

### 4. Scheduled Task Creation

The framework automatically creates a scheduled task that:
- Triggers at next logon
- Runs as SYSTEM with highest privileges
- Resumes from the next step
- Removes itself after completion

### 5. Auto-Resume

After reboot, the setup:
- Detects previous state
- Shows resume information
- Continues from the next step
- Maintains progress continuity

## Usage Examples

### Basic Step with Reboot

```powershell
Register-Step -Name "Enable Windows Feature" -Tags @('ALL') -Priority 20 -Action {
    Write-Status "Enabling .NET Framework 3.5..." 'Info'
    
    $feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3
    
    if ($feature.State -eq 'Enabled') {
        Write-Status "Already enabled" 'Success'
        return
    }
    
    $result = Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart
    
    if ($result.RestartNeeded) {
        Write-Status "Feature enabled" 'Success'
        Request-Reboot -Message ".NET Framework requires restart" -AutoResume
    }
}
```

### Multi-Stage Installation

```powershell
Register-Step -Name "Complex Application" -Tags @('MGR') -Priority 50 -Action {
    # Check installation stage
    $stageFile = "C:\bin\HMG\state\app-stage.txt"
    $stage = if (Test-Path $stageFile) { Get-Content $stageFile } else { "Stage1" }
    
    switch ($stage) {
        "Stage1" {
            Write-Status "Installing Stage 1..." 'Info'
            # Install logic here
            "Stage2" | Set-Content $stageFile
            Request-Reboot -Message "Stage 1 complete" -AutoResume
        }
        
        "Stage2" {
            Write-Status "Installing Stage 2..." 'Info'
            # Install logic here
            "Stage3" | Set-Content $stageFile
            Request-Reboot -Message "Stage 2 complete" -AutoResume
        }
        
        "Stage3" {
            Write-Status "Finalizing installation..." 'Info'
            # Final logic here
            Remove-Item $stageFile -Force
            Write-Status "Installation complete!" 'Success'
        }
    }
}
```

## Testing

### 1. Check Current State

```powershell
.\tests\Test-RebootResume.ps1 -Mode Status
```

### 2. Run Full Demo

```powershell
.\tests\Test-RebootResume.ps1 -Mode Demo
```

### 3. Simulate Reboot Scenario

```powershell
# Initialize test session
.\tests\Test-RebootResume.ps1 -Mode Initialize

# Simulate reboot requirement
.\tests\Test-RebootResume.ps1 -Mode Simulate

# Check state
.\tests\Test-RebootResume.ps1 -Mode Status
```

### 4. Clean Up

```powershell
.\tests\Test-RebootResume.ps1 -Mode Clear
```

## Running Setup with State Tracking

### Standard Execution

```powershell
# Use the state-aware orchestrator
.\scripts\Invoke-Setup-StateAware.ps1 -Role POS
```

### Disable State Tracking (Legacy Mode)

```powershell
.\scripts\Invoke-Setup-StateAware.ps1 -Role POS -NoStateTracking
```

### Manual Resume

```powershell
# If auto-resume fails, manually continue from step 5
.\scripts\Invoke-Setup-StateAware.ps1 -Role POS -ContinueFrom 5
```

## State File Structure

### current-state.json

```json
{
  "Role": "POS",
  "StartTime": "2025-10-27T10:00:00",
  "Status": "InProgress",
  "TotalSteps": 15,
  "CurrentStep": 5,
  "CompletedSteps": [...],
  "FailedSteps": [...],
  "RebootCount": 1,
  "SessionId": "guid",
  "RequiresReboot": true,
  "ResumeTask": {
    "Name": "HMG-Resume-Setup",
    "NextStep": 6,
    "CreatedAt": "2025-10-27T10:30:00"
  }
}
```

### progress.json

```json
{
  "Role": "POS",
  "StartTime": "2025-10-27T10:00:00",
  "Steps": [
    {
      "Number": 1,
      "Name": "Configure Power Settings",
      "Success": true,
      "Timestamp": "2025-10-27T10:05:00"
    }
  ]
}
```

## Key Functions

### State Management

| Function | Description |
|----------|-------------|
| `Initialize-SetupState` | Creates initial state for new session |
| `Get-SetupState` | Retrieves current state |
| `Save-SetupState` | Persists state to disk |
| `Update-StepProgress` | Records step completion |
| `Complete-Setup` | Marks setup as complete |
| `Clear-SetupState` | Removes all state files |

### Reboot Management

| Function | Description |
|----------|-------------|
| `Request-Reboot` | Called by steps to request reboot |
| `Set-RebootRequired` | Sets reboot flag and creates task |
| `Test-RebootRequired` | Checks if reboot is pending |
| `Test-PendingReboot` | Alternative reboot check |
| `Invoke-SystemReboot` | Initiates system reboot |

### Resume Management

| Function | Description |
|----------|-------------|
| `Test-SetupResume` | Checks for previous session |
| `Create-ResumeTask` | Creates scheduled task |
| `Remove-ResumeTask` | Removes scheduled task |
| `Get-ProgressSummary` | Gets execution statistics |

## Best Practices

### 1. Always Make Steps Idempotent

```powershell
# Good - checks before acting
if (-not (Test-Path $file)) {
    New-Item $file
}

# Bad - will fail on resume
New-Item $file  # Error if exists
```

### 2. Use State for Multi-Stage Operations

```powershell
# Track complex installation stages
$stageFile = "C:\bin\HMG\state\my-app-stage.txt"
$currentStage = if (Test-Path $stageFile) { 
    Get-Content $stageFile 
} else { 
    "NotStarted" 
}
```

### 3. Clean Up Stage Files

```powershell
# Always clean up temporary state files when done
if ($installComplete) {
    Remove-Item $stageFile -Force -ErrorAction SilentlyContinue
}
```

### 4. Provide Clear Messages

```powershell
Request-Reboot -Message "SQL Server installation requires restart to complete configuration" -AutoResume
```

### 5. Test Reboot Scenarios

Always test your steps with the reboot demo module to ensure they handle resume correctly.

## Troubleshooting

### State Files Location

All state files are stored in: `C:\bin\HMG\state\`

### View Current State

```powershell
Get-Content C:\bin\HMG\state\current-state.json | ConvertFrom-Json | Format-List
```

### Check Scheduled Task

```powershell
Get-ScheduledTask -TaskPath "\HMG\" -TaskName "HMG-Resume-Setup" -ErrorAction SilentlyContinue
```

### Manual State Reset

```powershell
# If state is corrupted
Remove-Item C:\bin\HMG\state\* -Force
Unregister-ScheduledTask -TaskPath "\HMG\" -TaskName "HMG-Resume-Setup" -Confirm:$false
```

### Logs

Setup logs are stored in: `C:\bin\HMG\logs\`

## Common Scenarios

### Windows Updates

```powershell
if (Get-WindowsUpdate -Install -AcceptAll) {
    Request-Reboot -Message "Windows Updates installed" -AutoResume
}
```

### Driver Installation

```powershell
$result = Install-Driver -Path $driverPath
if ($result.RebootRequired) {
    Request-Reboot -Message "Driver installation complete" -AutoResume
}
```

### Registry Changes

```powershell
Set-ItemProperty -Path $regPath -Name $name -Value $value
if ($requiresReboot) {
    Request-Reboot -Message "Registry changes require restart" -AutoResume
}
```

## Integration Checklist

- [x] HMG.State module implemented
- [x] Request-Reboot helper in HMG.Core
- [x] State-aware orchestrator created
- [x] Demo module with examples
- [x] Test suite for validation
- [x] Documentation complete

## Version History

- **v2.1.0** (October 27, 2025) - Full reboot/resume implementation
- **v2.0.0** (October 22, 2025) - Module refactoring
- **v1.0.0** (October 2025) - Initial framework

## Support

For issues or questions about the reboot/resume functionality:
1. Check the test suite: `.\tests\Test-RebootResume.ps1 -Mode Status`
2. Review logs in `C:\bin\HMG\logs\`
3. Verify state files in `C:\bin\HMG\state\`
4. Test with demo module for examples

---

*Author: Joshua Dore*  
*Date: October 2025*  
*Version: 2.1.0*
