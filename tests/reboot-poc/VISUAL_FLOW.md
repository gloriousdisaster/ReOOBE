# Reboot/Resume Test - Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         YOU RUN THE TEST                             │
│                  (Double-click RUN-TEST.bat)                         │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1: INITIALIZATION                                            │
│  ─────────────────────────────────────────────────────────────────  │
│  ✓ Create log directory: C:\bin\HMG\logs\reboot-test\              │
│  ✓ Initialize test state (JSON)                                     │
│  ✓ Load HMG.State module                                            │
│  ✓ Verify all functions available                                   │
│                                                                      │
│  TIME: ~3 seconds                                                    │
│  FILES CREATED: test-[timestamp].log, test-state.json               │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ Auto-continue
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 2: PRE-REBOOT TASKS                                          │
│  ─────────────────────────────────────────────────────────────────  │
│  ✓ Simulate Task 1: Configure system settings                       │
│  ✓ Simulate Task 2: Install test application                        │
│  ✓ Simulate Task 3: Update registry keys                            │
│  ✓ Simulate Task 4: Create test files                               │
│  ✓ Initialize HMG state management                                  │
│  ✓ Create scheduled task: \HMG-Test\HMG-RebootTest-Resume          │
│     └─ Will run at next logon as SYSTEM                             │
│                                                                      │
│  TIME: ~5 seconds of tasks + 30 seconds countdown                   │
│  TASK CREATED: Auto-resume on logon                                 │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
                    ╔════════════════════════╗
                    ║   30-SECOND COUNTDOWN  ║
                    ║                        ║
                    ║   Press Ctrl+C to      ║
                    ║   cancel reboot        ║
                    ╚════════════════════════╝
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        ⚠️  SYSTEM REBOOTS  ⚠️                        │
│                                                                      │
│  shutdown.exe /r /t 0                                                │
│                                                                      │
│  💾 State saved to: test-state.json                                 │
│  📅 Scheduled task ready to trigger                                 │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 │ System restarts
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    🖥️  WINDOWS STARTS UP  🖥️                       │
│                                                                      │
│  1. Boot sequence                                                    │
│  2. Login screen appears                                             │
│  3. You log in (as any user)                                         │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│             🔄  SCHEDULED TASK TRIGGERS (AUTOMATIC)  🔄             │
│                                                                      │
│  Task: \HMG-Test\HMG-RebootTest-Resume                              │
│  Runs: As SYSTEM account                                            │
│  Executes: Test-RebootResume.ps1 -Phase PostReboot                  │
│                                                                      │
│  YOU DON'T NEED TO DO ANYTHING - IT'S AUTOMATIC!                    │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ Task runs automatically
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 3: POST-REBOOT TASKS (AUTOMATIC)                             │
│  ─────────────────────────────────────────────────────────────────  │
│  ✓ Load previous test state from JSON                               │
│  ✓ Verify reboot occurred (RebootCount = 1)                         │
│  ✓ Reload HMG.State module                                          │
│  ✓ Test HMG resume detection                                        │
│  ✓ Simulate Task 5: Verify system settings                          │
│  ✓ Simulate Task 6: Check test application                          │
│  ✓ Simulate Task 7: Validate registry keys                          │
│  ✓ Simulate Task 8: Verify test files                               │
│                                                                      │
│  TIME: ~10 seconds                                                   │
│  STATE LOADED: Previous state restored                               │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ Auto-continue
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 4: CLEANUP                                                    │
│  ─────────────────────────────────────────────────────────────────  │
│  ✓ Remove scheduled task                                            │
│  ✓ Clean HMG state files                                            │
│  ✓ Generate final report                                            │
│  ✓ Write results to: test-results.txt                               │
│  ✓ Display success message                                          │
│                                                                      │
│  TIME: ~3 seconds                                                    │
│  FINAL FILE: test-results.txt                                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        ✅  TEST COMPLETE!  ✅                        │
│                                                                      │
│  ╔══════════════════════════════════════════════════════════════╗  │
│  ║              TEST COMPLETED SUCCESSFULLY                     ║  │
│  ╠══════════════════════════════════════════════════════════════╣  │
│  ║ Test Name:      RebootResume-POC                            ║  │
│  ║ Duration:       00:02:15                                     ║  │
│  ║ Reboots:        1                                            ║  │
│  ║ Tasks:          10                                           ║  │
│  ║ Errors:         0                                            ║  │
│  ╠══════════════════════════════════════════════════════════════╣  │
│  ║ Phase Results:                                               ║  │
│  ║   Init            Completed ✓                                ║  │
│  ║   PreReboot       Completed ✓                                ║  │
│  ║   PostReboot      Completed ✓                                ║  │
│  ║   Cleanup         Completed ✓                                ║  │
│  ╚══════════════════════════════════════════════════════════════╝  │
│                                                                      │
│  📁 Log Files: C:\bin\HMG\logs\reboot-test\                         │
│     ├─ test-20251028-143015.log    (detailed log)                   │
│     ├─ test-state.json              (state data)                    │
│     └─ test-results.txt             (summary)                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Timeline

```
0:00        Start test
0:03        Init complete → Auto-continue to Pre-Reboot
0:08        Pre-Reboot tasks complete
0:08-0:38   30-second countdown
0:38        System reboots
0:38-2:00   System restarts (1-2 minutes)
2:00        You log in
2:01        Scheduled task auto-runs Post-Reboot phase
2:11        Post-Reboot complete → Auto-continue to Cleanup
2:14        Cleanup complete
2:15        ✅ TEST COMPLETE - Results displayed
```

**Total: 2-3 minutes** (mostly waiting for reboot)

---

## User Interaction Required

| Phase | What You Do |
|-------|-------------|
| **Before Test** | Save all work, close apps |
| **Start Test** | Double-click RUN-TEST.bat → Confirm "Y" |
| **Pre-Reboot** | Nothing (or press Ctrl+C to cancel) |
| **Reboot** | Wait for system to restart |
| **Login** | Log back in (as any user) |
| **Post-Reboot** | Nothing (automatic) |
| **Results** | Read console output |

**Total clicks required: 1** (to start the test)

---

## What Makes This Automatic?

### Scheduled Task Details

```
Name:        HMG-RebootTest-Resume
Path:        \HMG-Test\
Trigger:     At logon of any user
Principal:   SYSTEM account
RunLevel:    Highest
Action:      powershell.exe -ExecutionPolicy Bypass 
             -File "...\Test-RebootResume.ps1" -Phase PostReboot
```

**Why SYSTEM account?**
- Works regardless of which user logs in
- Has necessary privileges for all operations
- Matches production HMG setup behavior

**When does it trigger?**
- Automatically at next user logon after reboot
- No manual intervention required
- Removes itself after successful completion

---

## Files and Their Lifecycle

### test-state.json
```
Created:  Phase 1 (Init)
Updated:  Every phase
Read:     Phase 3 (PostReboot) - This is how resume works!
Purpose:  Persist test state across reboot
```

### test-[timestamp].log
```
Created:  Phase 1 (Init)
Written:  Every log statement
Purpose:  Detailed debugging information
```

### test-results.txt
```
Created:  Phase 4 (Cleanup)
Purpose:  Final summary report
```

### Scheduled Task
```
Created:  Phase 2 (PreReboot)
Triggers: Phase 3 (PostReboot) - automatic!
Removed:  Phase 4 (Cleanup)
Purpose:  Enable automatic resume
```

---

## Key Mechanisms

### State Persistence
```powershell
# Before reboot
Save-TestState -State $state
# Saves to: test-state.json

# After reboot
$state = Get-TestState
# Loads from: test-state.json
# Knows: previous phase, reboot count, completed tasks
```

### Resume Detection
```powershell
# Script checks: Do I have previous state?
if (Test-Path $stateFile) {
    # YES → Load state and continue from next phase
    $state = Get-TestState
    $phase = $state.CurrentPhase
}
```

### Task Automation
```powershell
# Task triggers automatically at logon
# Runs: Test-RebootResume.ps1 -Phase PostReboot
# Script knows to skip Init and PreReboot phases
```

---

## Success Indicators

✅ **Visual**: Green "TEST COMPLETED SUCCESSFULLY" box  
✅ **Reboot Count**: Should be 1  
✅ **Tasks**: Should be 10  
✅ **Errors**: Should be 0  
✅ **All Phases**: Should show "Completed"  
✅ **Log File**: Should have POST-REBOOT entries  
✅ **State File**: Should show RebootCount: 1  
✅ **Task Gone**: `Get-ScheduledTask` should return nothing  

---

**This visual guide shows the complete journey from start to finish!**
