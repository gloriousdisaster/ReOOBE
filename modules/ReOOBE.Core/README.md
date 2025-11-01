# ReOOBE Core Module

**Version:** 1.0.0  
**Purpose:** Central orchestration engine for the ReOOBE deployment framework

---

## Overview

The Core module provides the foundational execution layer for ReOOBE. Every deployment task—whether installing an application, configuring a system setting, or running a script—flows through the universal `Invoke-Step` wrapper.

This creates a consistent, observable, and reliable deployment experience.

---

## Key Components

### `Invoke-Step`
Universal execution wrapper that provides:
- ✅ **Detection** - Skip if already complete (unless `-Force`)
- ✅ **Structured Results** - Every step returns the same object shape
- ✅ **Logging Integration** - Automatic console and file logging
- ✅ **Error Handling** - Graceful failures with detailed reporting
- ✅ **Retry Logic** - Configurable retry attempts with delays
- ✅ **Timeouts** - Protection against hung processes
- ✅ **Verification** - Optional post-execution validation
- ✅ **WhatIf Support** - Safe preview mode

---

## Usage Examples

### Basic Application Install
```powershell
$result = Invoke-Step -Name 'Google Chrome' `
    -Category 'App' `
    -Action 'Install' `
    -DetectScript {
        Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    } `
    -WorkScript {
        $msi = "C:\deployment\global\Chrome\installer.msi"
        Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait -PassThru
    }

if ($result.Succeeded) {
    Write-Host "Chrome installed successfully in $($result.DurationS) seconds"
}
```

### System Configuration with Verification
```powershell
$result = Invoke-Step -Name 'Set Time Zone' `
    -Category 'System' `
    -Action 'Configure' `
    -DetectScript {
        (Get-TimeZone).Id -eq 'Eastern Standard Time'
    } `
    -WorkScript {
        Set-TimeZone -Id 'Eastern Standard Time'
    } `
    -VerifyScript {
        (Get-TimeZone).Id -eq 'Eastern Standard Time'
    }
```

### Critical Step with Retries
```powershell
$result = Invoke-Step -Name 'Disable HVCI' `
    -Category 'Security' `
    -Action 'Disable' `
    -Critical `
    -RetryCount 3 `
    -RetryDelaySeconds 10 `
    -DetectScript {
        $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -ErrorAction SilentlyContinue
        return ($null -eq $val -or $val.Enabled -eq 0)
    } `
    -WorkScript {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -Value 0 -Force
    } `
    -VerifyScript {
        $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -ErrorAction SilentlyContinue
        return ($null -eq $val -or $val.Enabled -eq 0)
    }
```

### Network Configuration with Timeout
```powershell
$result = Invoke-Step -Name 'Import WiFi Profile' `
    -Category 'Network' `
    -Action 'Configure' `
    -TimeoutSeconds 30 `
    -DetectScript {
        $profiles = netsh wlan show profiles 2>$null
        return ($profiles -match 'CompanyWiFi')
    } `
    -WorkScript {
        netsh wlan add profile filename="C:\config\wifi-profile.xml"
    } `
    -Metadata @{
        ProfileName = 'CompanyWiFi'
        SSID = 'Corp-Network'
    }
```

---

## Result Object Schema

Every `Invoke-Step` call returns a consistent result object:

```powershell
@{
    # Identity
    Id           = [guid]                  # Unique identifier
    Name         = "Google Chrome"         # Human-readable name
    Category     = "App"                   # Classification
    Action       = "Install"               # Operation type
    
    # Outcome
    Status       = "Completed"             # Execution status
    Succeeded    = $true                   # Boolean result
    ExitCode     = 0                       # Process exit code (if applicable)
    
    # Timing
    StartedAt    = [datetime]              # Start timestamp
    EndedAt      = [datetime]              # End timestamp
    DurationMs   = 1234                    # Milliseconds
    DurationS    = 1.234                   # Seconds
    
    # Error Handling
    ErrorMessage = $null                   # Error text if failed
    Exception    = $null                   # Full exception object
    RetryCount   = 0                       # Number of retries performed
    
    # Execution Tracking
    DetectionRan     = $true               # Was detection executed?
    Detected         = $false              # Was already complete?
    WorkRan          = $true               # Was work executed?
    VerificationRan  = $false              # Was verification executed?
    Verified         = $null               # Did verification pass?
    
    # Context
    Metadata     = @{ ... }                # Custom data
}
```

### Status Values
- `NotStarted` - Initial state
- `Skipped` - WhatIf mode or dependencies not met
- `AlreadyCompleted` - Detected as already done
- `Running` - Currently executing
- `Completed` - Successfully finished
- `CompletedWithWarnings` - Finished with non-critical issues
- `Failed` - Execution failed
- `VerificationFailed` - Work ran but verification failed
- `TimedOut` - Exceeded TimeoutSeconds

---

## Integration with Logging

`Invoke-Step` automatically integrates with the ReOOBE Logging module if available:

- **Console Output** - Via `Write-Status` (colored, formatted)
- **File Logging** - Via `Write-Log` (structured, timestamped)
- **Structured Data** - All results include metadata for reporting

If the Logging module is not loaded, `Invoke-Step` gracefully falls back to basic console output.

---

## Parameters Reference

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Name` | string | Yes | - | Human-readable step name |
| `Category` | enum | Yes | - | App, System, Security, Network, User, Script |
| `Action` | enum | Yes | - | Install, Configure, Disable, Enable, Remove, Update, Verify |
| `DetectScript` | scriptblock | Yes | - | Returns $true if already complete |
| `WorkScript` | scriptblock | Yes | - | The actual work to perform |
| `VerifyScript` | scriptblock | No | - | Optional post-execution validation |
| `Force` | switch | No | false | Skip detection, always execute |
| `Critical` | switch | No | false | Abort deployment if this fails |
| `RetryCount` | int | No | 0 | Number of retry attempts (0-10) |
| `RetryDelaySeconds` | int | No | 5 | Wait between retries (0-300) |
| `TimeoutSeconds` | int | No | 0 | Max execution time (0 = no limit, max 3600) |
| `Metadata` | hashtable | No | @{} | Custom context data |

---

## Design Philosophy

### Single Responsibility
`Invoke-Step` does ONE thing: executes a step with full observability. It doesn't know about plans, roles, or apps—it just executes what you tell it to.

### Fail-Safe by Default
- Non-critical steps log errors but don't stop the deployment
- Critical steps (`-Critical` switch) abort on failure
- Detection prevents unnecessary work
- Verification confirms success

### Observable Execution
Every step produces a complete audit trail:
- What was attempted
- What was detected
- What work was done
- Whether it succeeded
- How long it took
- What errors occurred

### Composable & Testable
- Can be mocked for testing
- Results can be aggregated for reporting
- Integrates cleanly with orchestration layers

---

## Future Components

### `Get-ExecutionPlan` *(Coming Soon)*
Loads and merges base + role-specific execution plans from data files.

### `Start-Deployment` *(Coming Soon)*
Main orchestrator that reads plans and executes steps in order.

---

## Dependencies

- **PowerShell 5.1+** (Windows PowerShell or PowerShell Core)
- **Optional**: Logging module for enhanced logging
- **Optional**: UI module for enhanced visual feedback

---

## Notes

- All scriptblocks execute in the current scope (can access variables)
- Detection/Work/Verify scripts should be idempotent
- Exit codes from processes are automatically captured
- Timeout protection uses PowerShell jobs (slight overhead)
- Retry logic includes exponential backoff capability (future enhancement)

---

## Version History

**1.0.0** (2025-10-31)
- Initial release
- `Invoke-Step` function with full feature set
- Integrated logging and UI support
- Comprehensive error handling
- Result object standardization
