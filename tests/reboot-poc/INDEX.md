# Reboot/Resume POC Test - File Index

## Quick Start

**Easiest Way**: Double-click `RUN-TEST.bat` (requires Administrator)

**PowerShell Way**: 
```powershell
cd C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc
.\Test-RebootResume.ps1
```

---

## Files in This Directory

### Executable Files

| File | Purpose | How to Use |
|------|---------|------------|
| **Test-RebootResume.ps1** | Main test script (~700 lines) | `.\Test-RebootResume.ps1` |
| **RUN-TEST.bat** | Batch launcher with prompts | Double-click or right-click → Run as Admin |

### Documentation

| File | Purpose | When to Read |
|------|---------|--------------|
| **QUICKSTART.md** | One-page reference | Before running test |
| **README.md** | Complete guide | For detailed information |
| **INDEX.md** | This file | For file overview |

---

## Output Files (Created During Test)

Located in: `C:\bin\HMG\logs\reboot-test\`

### Automatically Created

| File | Content | Use For |
|------|---------|---------|
| **test-YYYYMMDD-HHMMSS.log** | Detailed execution log | Debugging issues |
| **test-state.json** | Test state data | Verify state persistence |
| **test-results.txt** | Final summary report | Quick success check |

### Example Log Names
```
test-20251028-143015.log
test-20251028-150323.log
test-20251028-161245.log
```

---

## Typical Workflow

### 1. Preparation (30 seconds)
```
Read QUICKSTART.md → Save all work → Close apps
```

### 2. Execution (3 seconds)
```
Double-click RUN-TEST.bat → Confirm "Y"
```

### 3. Pre-Reboot Phase (35 seconds)
```
Watch console output → 30-second countdown → System reboots
```

### 4. Reboot (1-2 minutes)
```
System restarts → Log back in
```

### 5. Post-Reboot Phase (10 seconds)
```
Script auto-runs → Completes tasks → Shows results
```

### 6. Review Results (1 minute)
```
Read console output → Check log files → Verify success
```

**Total Time**: 2-3 minutes

---

## File Relationships

```
┌─────────────────────────────────────────────────────────┐
│                     Test Directory                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  RUN-TEST.bat ──────► Test-RebootResume.ps1            │
│                              │                           │
│                              ├──► HMG.State module       │
│                              │                           │
│                              └──► Output files:          │
│                                   - test-*.log           │
│                                   - test-state.json      │
│                                   - test-results.txt     │
│                                                          │
│  Documentation:                                          │
│  - QUICKSTART.md (read first)                           │
│  - README.md (full details)                             │
│  - INDEX.md (this file)                                 │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Command Reference

### Run Test
```powershell
# Option 1: Batch launcher
.\RUN-TEST.bat

# Option 2: Direct PowerShell
.\Test-RebootResume.ps1

# Option 3: Specific phase (advanced)
.\Test-RebootResume.ps1 -Phase PreReboot
```

### View Results
```powershell
# Latest results file
Get-Content C:\bin\HMG\logs\reboot-test\test-results.txt

# Latest log file
Get-ChildItem C:\bin\HMG\logs\reboot-test\test-*.log | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content

# State file (JSON)
Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json
```

### Check Status
```powershell
# During test: Is scheduled task ready?
Get-ScheduledTask -TaskPath "\HMG-Test\"

# After test: Was task cleaned up?
Get-ScheduledTask -TaskPath "\HMG-Test\" -ErrorAction SilentlyContinue
# Should return nothing

# Check HMG state files
Get-ChildItem C:\bin\HMG\state\
```

### Cleanup
```powershell
# Remove test logs
Remove-Item C:\bin\HMG\logs\reboot-test\* -Force

# Remove scheduled task (if stuck)
Unregister-ScheduledTask -TaskPath "\HMG-Test\" -Confirm:$false

# Remove HMG state
Remove-Item C:\bin\HMG\state\* -Force
```

---

## Success Checklist

After running the test, verify:

- [ ] Console shows "TEST COMPLETED SUCCESSFULLY"
- [ ] All phases show "Completed" status
- [ ] Reboot count = 1
- [ ] Tasks completed = 10
- [ ] Errors = 0
- [ ] `test-results.txt` exists
- [ ] `test-state.json` shows RebootCount: 1
- [ ] No scheduled task remains in `\HMG-Test\`

---

## Troubleshooting Guide

### Issue: Test doesn't start
**Solution**: Run as Administrator
```batch
Right-click RUN-TEST.bat → Run as Administrator
```

### Issue: Test doesn't resume after reboot
**Solution**: Manually trigger post-reboot phase
```powershell
.\Test-RebootResume.ps1 -Phase PostReboot
```

### Issue: Can't find log files
**Solution**: Check correct directory
```powershell
Get-ChildItem C:\bin\HMG\logs\reboot-test\
```

### Issue: Want to start over
**Solution**: Clean everything
```powershell
Remove-Item C:\bin\HMG\logs\reboot-test\* -Force
Unregister-ScheduledTask -TaskPath "\HMG-Test\" -Confirm:$false -ErrorAction SilentlyContinue
.\Test-RebootResume.ps1
```

---

## What Gets Tested

### HMG.State Module Functions
- ✅ `Initialize-SetupState`
- ✅ `Set-RebootRequired`
- ✅ `Test-SetupResume`
- ✅ `Invoke-SystemReboot`
- ✅ `Complete-Setup`

### System Integration
- ✅ Scheduled task creation
- ✅ Task execution at logon
- ✅ Task cleanup
- ✅ State persistence (JSON)
- ✅ Cross-reboot resume
- ✅ SYSTEM account privileges
- ✅ Multi-user compatibility

### Data Integrity
- ✅ State serialization
- ✅ State deserialization
- ✅ Reboot count tracking
- ✅ Phase status tracking
- ✅ Task completion tracking
- ✅ Error tracking

---

## Additional Resources

### Related Documentation
- `RBCMS\.ai\REBOOT_RESUME_IMPLEMENTATION.md` - Production implementation
- `RBCMS\.ai\REBOOT_POC_TEST.md` - This test's documentation
- `RBCMS\modules\HMG.State\HMG.State.psm1` - State module source

### Test Logs Location
```
C:\bin\HMG\logs\reboot-test\
├── test-20251028-143015.log    (detailed execution log)
├── test-state.json              (test state data)
└── test-results.txt             (summary report)
```

### HMG State Files (During Test)
```
C:\bin\HMG\state\
├── current-state.json           (HMG framework state)
├── progress.json                (progress tracking)
└── reboot-required.flag         (reboot indicator)
```

---

## Support

If you encounter issues:

1. **Check the log file**: Most verbose information
   ```powershell
   notepad C:\bin\HMG\logs\reboot-test\test-*.log
   ```

2. **Check the state file**: Verify state persistence
   ```powershell
   Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json | Format-List
   ```

3. **Check scheduled tasks**: Verify task creation/cleanup
   ```powershell
   Get-ScheduledTask -TaskPath "\HMG-Test\" -ErrorAction SilentlyContinue
   ```

4. **Review documentation**: Detailed troubleshooting in README.md
   ```powershell
   notepad README.md
   ```

---

## Quick Reference Card

| Want to... | Command |
|------------|---------|
| Run test | `.\RUN-TEST.bat` or `.\Test-RebootResume.ps1` |
| View results | `Get-Content C:\bin\HMG\logs\reboot-test\test-results.txt` |
| View log | `notepad C:\bin\HMG\logs\reboot-test\test-*.log` |
| Check state | `Get-Content C:\bin\HMG\logs\reboot-test\test-state.json` |
| Check task | `Get-ScheduledTask -TaskPath "\HMG-Test\"` |
| Clean up | `Remove-Item C:\bin\HMG\logs\reboot-test\* -Force` |
| Start over | Clean up + `.\Test-RebootResume.ps1` |

---

**Version**: 1.0  
**Last Updated**: October 28, 2025  
**Status**: Ready for testing  
**Estimated Runtime**: 2-3 minutes  
**Requires**: Administrator privileges
