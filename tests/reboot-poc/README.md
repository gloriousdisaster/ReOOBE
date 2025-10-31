# Reboot/Resume Proof of Concept Test

## Overview

This test script validates the core reboot/resume functionality of the HMG framework by performing a **real system reboot** and verifying that the test automatically resumes afterward.

## ⚠️ IMPORTANT WARNINGS

1. **This script performs a REAL system reboot!**
2. **Save all your work before running**
3. **Close all applications**
4. **Ensure you can log back in after reboot**

## What This Test Does

### Phase Flow

```
┌─────────────────────────────────────────────────────────────┐
│ INIT PHASE                                                  │
│ - Initializes test state                                    │
│ - Loads HMG.State module                                    │
│ - Creates log files                                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ PRE-REBOOT PHASE                                            │
│ - Simulates pre-reboot tasks (4 tasks)                      │
│ - Initializes HMG state management                          │
│ - Creates scheduled task for auto-resume                    │
│ - Initiates system reboot (30-second countdown)             │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼  SYSTEM REBOOTS
                 │
                 ▼  USER LOGS BACK IN
                 │
                 ▼  SCHEDULED TASK TRIGGERS
                 │
┌─────────────────────────────────────────────────────────────┐
│ POST-REBOOT PHASE                                           │
│ - Automatically resumes after reboot                         │
│ - Loads previous test state                                 │
│ - Verifies HMG state resume detection                       │
│ - Simulates post-reboot tasks (4 tasks)                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ CLEANUP PHASE                                               │
│ - Removes scheduled task                                    │
│ - Cleans up HMG state                                       │
│ - Generates final report                                    │
│ - Displays results                                          │
└─────────────────────────────────────────────────────────────┘
```

## How to Run

### Basic Usage (Recommended)

```powershell
# Navigate to the test directory
cd C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc

# Run the test
.\Test-RebootResume.ps1
```

That's it! The script will:
1. Run init and pre-reboot phases
2. Countdown 30 seconds (you can cancel with Ctrl+C)
3. Reboot the system
4. Automatically resume when you log back in
5. Complete post-reboot and cleanup phases
6. Display results

### What You'll See

#### Before Reboot
```
====================================================================================
PHASE: INITIALIZATION
====================================================================================
[2025-10-28 14:30:00] [INFO] Starting reboot/resume proof of concept test
[2025-10-28 14:30:00] [INFO] Computer: YOUR-PC-NAME
[2025-10-28 14:30:00] [SUCCESS] HMG.State module loaded successfully

====================================================================================
PHASE: PRE-REBOOT TASKS
====================================================================================
[2025-10-28 14:30:05] [INFO] Task: Configure system settings
[2025-10-28 14:30:06] [SUCCESS]   └─ Completed
...

╔══════════════════════════════════════════════════════════╗
║              PRE-REBOOT PHASE COMPLETE                  ║
║                                                          ║
║  The system will now reboot to test auto-resume.        ║
╚══════════════════════════════════════════════════════════╝

Rebooting in 30 seconds...
```

#### After Reboot (Automatic)
```
====================================================================================
PHASE: POST-REBOOT TASKS
====================================================================================
[2025-10-28 14:32:15] [SUCCESS] System has rebooted - resuming test
[2025-10-28 14:32:15] [SUCCESS] Loaded existing test state
[2025-10-28 14:32:15] [INFO] Reboot count: 1

╔══════════════════════════════════════════════════════════╗
║              TEST COMPLETED SUCCESSFULLY                 ║
╠══════════════════════════════════════════════════════════╣
║ Test Name:      RebootResume-POC                        ║
║ Duration:       00:02:15                                 ║
║ Reboots:        1                                        ║
║ Tasks:          10                                       ║
║ Errors:         0                                        ║
╚══════════════════════════════════════════════════════════╝
```

## Output Files

All test artifacts are stored in: `C:\bin\HMG\logs\reboot-test\`

### Files Created

1. **Test Log** - `test-[timestamp].log`
   - Complete execution log with timestamps
   - All INFO, SUCCESS, WARNING, ERROR messages
   - Detailed debugging information

2. **State File** - `test-state.json`
   - Current test state (phases, tasks, errors)
   - Used for resume detection
   - Persists across reboot

3. **Results File** - `test-results.txt`
   - Final test summary
   - Phase results
   - Task list
   - Duration and statistics

### Example State File

```json
{
  "TestName": "RebootResume-POC",
  "StartTime": "2025-10-28T14:30:00.123Z",
  "CurrentPhase": "PostReboot",
  "RebootCount": 1,
  "Phases": {
    "Init": { "Status": "Completed", "Timestamp": "2025-10-28T14:30:01Z" },
    "PreReboot": { "Status": "Completed", "Timestamp": "2025-10-28T14:31:00Z" },
    "PostReboot": { "Status": "Running", "Timestamp": "2025-10-28T14:32:15Z" }
  },
  "TasksCompleted": [
    { "Task": "Loaded HMG.State module", "Phase": "Init" },
    { "Task": "Configure system settings", "Phase": "PreReboot" },
    ...
  ],
  "Errors": []
}
```

## Advanced Usage

### Run Individual Phases (For Debugging)

```powershell
# Run only init + pre-reboot (no actual reboot)
# Good for testing task creation
.\Test-RebootResume.ps1 -Phase PreReboot

# Simulate post-reboot (requires existing state)
.\Test-RebootResume.ps1 -Phase PostReboot

# Run only cleanup
.\Test-RebootResume.ps1 -Phase Cleanup
```

### Manual Resume After Reboot

If the scheduled task doesn't fire automatically:

```powershell
# Manually trigger post-reboot phase
.\Test-RebootResume.ps1 -Phase PostReboot
```

## Validation Checklist

After running the test, verify:

- [ ] Test completed without errors
- [ ] Reboot count = 1
- [ ] All phases show "Completed" status
- [ ] 10 tasks completed (4 pre-reboot + 4 post-reboot + 2 module loads)
- [ ] No errors in test state
- [ ] Scheduled task was created and then removed
- [ ] HMG state detected resume (check post-reboot log)
- [ ] Log files exist in `C:\bin\HMG\logs\reboot-test\`

### Check Scheduled Task (Before Reboot)

```powershell
Get-ScheduledTask -TaskName "HMG-RebootTest-Resume" -TaskPath "\HMG-Test\"
```

Should show:
- **State**: Ready
- **Trigger**: At log on
- **User**: SYSTEM

### Check HMG State Files (After Reboot)

```powershell
# HMG state directory
Get-ChildItem C:\bin\HMG\state\

# View current state
Get-Content C:\bin\HMG\state\current-state.json | ConvertFrom-Json | Format-List
```

## Troubleshooting

### Test Doesn't Resume After Reboot

**Possible Causes:**
1. Scheduled task didn't create
2. Scheduled task didn't trigger
3. State file not found
4. Permissions issue

**Solutions:**

```powershell
# Check if scheduled task exists
Get-ScheduledTask -TaskName "HMG-RebootTest-Resume" -TaskPath "\HMG-Test\"

# Check task history
Get-ScheduledTask -TaskName "HMG-RebootTest-Resume" -TaskPath "\HMG-Test\" | 
    Get-ScheduledTaskInfo

# Manually run task
Start-ScheduledTask -TaskName "HMG-RebootTest-Resume" -TaskPath "\HMG-Test\"

# Manually run post-reboot phase
.\Test-RebootResume.ps1 -Phase PostReboot
```

### State File Not Found

```powershell
# Check if state file exists
Test-Path C:\bin\HMG\logs\reboot-test\test-state.json

# View state file contents
Get-Content C:\bin\HMG\logs\reboot-test\test-state.json

# If corrupted, the test must be rerun from the beginning
```

### HMG.State Module Not Found

```powershell
# Verify module path
$moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$stateModulePath = Join-Path $moduleRoot "RBCMS\modules\HMG.State\HMG.State.psd1"
Test-Path $stateModulePath

# Import manually
Import-Module $stateModulePath -Force -Verbose
```

### Permission Denied Errors

The test requires Administrator privileges. Run PowerShell as Administrator:

```powershell
# Check if running as admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

## Cleanup (If Test Fails Mid-Way)

```powershell
# Remove scheduled task
Unregister-ScheduledTask -TaskName "HMG-RebootTest-Resume" -TaskPath "\HMG-Test\" -Confirm:$false

# Clear test logs (optional)
Remove-Item C:\bin\HMG\logs\reboot-test\* -Recurse -Force

# Clear HMG state (optional)
Remove-Item C:\bin\HMG\state\* -Recurse -Force
```

## What This Tests

### HMG.State Module Functions

- ✅ `Initialize-SetupState` - Creates state files
- ✅ `Set-RebootRequired` - Marks reboot needed
- ✅ `Test-SetupResume` - Detects resume conditions
- ✅ `Complete-Setup` - Cleanup operations

### Scheduled Task Management

- ✅ Task creation with correct parameters
- ✅ Task triggers at logon
- ✅ Task runs with SYSTEM privileges
- ✅ Task executes PowerShell script
- ✅ Task cleanup after completion

### State Persistence

- ✅ State saves before reboot
- ✅ State loads after reboot
- ✅ JSON serialization/deserialization
- ✅ Reboot count tracking
- ✅ Phase status tracking

### Resume Detection

- ✅ Detects previous run
- ✅ Continues from correct phase
- ✅ Maintains task history
- ✅ Tracks errors across reboots

## Success Criteria

The test passes if:

1. ✅ All phases complete successfully
2. ✅ System reboots and resumes automatically
3. ✅ State persists across reboot
4. ✅ No errors in final report
5. ✅ Scheduled task is created and removed
6. ✅ Log files are complete and readable
7. ✅ HMG state functions work correctly

## Next Steps

Once this POC test passes, the reboot/resume functionality is validated and ready for use in the full HMG setup process.

### Integration Checklist

- [ ] Test passes on clean Windows 11 system
- [ ] Test passes with autologon configured
- [ ] Test passes when logged in as limited user
- [ ] Test passes on Windows 10
- [ ] Document any platform-specific issues
- [ ] Update main setup orchestrator if needed

## Support

If you encounter issues:

1. Check the log file: `C:\bin\HMG\logs\reboot-test\test-[timestamp].log`
2. Check the state file: `C:\bin\HMG\logs\reboot-test\test-state.json`
3. Review scheduled task: `Get-ScheduledTask -TaskPath "\HMG-Test\"`
4. Verify HMG.State module loaded: `Get-Module HMG.State`

---

**Version**: 1.0  
**Last Updated**: October 28, 2025  
**Author**: Joshua Dore
