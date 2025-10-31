# Quick Troubleshooting Guide

## Issue: Success Window Not Appearing After Reboot

### Step 1: Clean Up Previous Test
```powershell
cd C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc
.\Cleanup-Test.ps1
```

This will:
- Remove any old scheduled tasks
- Clear old test state files
- Check if scripts are up-to-date
- Give you a fresh start

### Step 2: Copy Updated Script
```powershell
Copy-Item "C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" `
          "C:\bin\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" -Force
```

### Step 3: Run Fresh Test
```powershell
cd C:\bin\RBCMS\tests\reboot-poc

# Option 1: With 30-second countdown
.\Test-RebootResume.ps1

# Option 2: Skip countdown (immediate reboot)
.\Test-RebootResume.ps1 -SkipCountdown
```

### Step 4: Check Logs After Reboot
```powershell
# Check if window was supposed to appear
Get-Content C:\bin\HMG\logs\reboot-test\test-*.log | Select-String "success window"

# Check RebootCount
(Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json).RebootCount

# View last 30 lines of log
Get-ChildItem C:\bin\HMG\logs\reboot-test\test-*.log | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content -Tail 30
```

---

## New Feature: Skip Countdown

### Usage
```powershell
# Skip the 30-second countdown and reboot immediately
.\Test-RebootResume.ps1 -SkipCountdown
```

**When to use**:
- Quick testing iterations
- You're confident and don't need time to cancel
- Running automated tests

**When NOT to use**:
- First time running the test
- Unsaved work open
- Not ready for immediate reboot

---

## Common Problems & Solutions

### Problem: "RebootCount is 0 instead of 1"
**Cause**: Old version of script  
**Solution**: Copy updated script and run cleanup first

### Problem: "Scheduled task keeps running"
**Cause**: Old task from previous test  
**Solution**: Run `Cleanup-Test.ps1` to remove it

### Problem: "Window appeared but closed immediately"
**Cause**: May have been running in background as SYSTEM  
**Solution**: Check if you saw it flash - it waits for keypress now

### Problem: "Error: HMG.State module not found"
**Cause**: Script path issue  
**Solution**: Make sure you're running from the correct directory

---

## Diagnostic Commands

```powershell
# Check if scheduled task exists
Get-ScheduledTask -TaskPath "\HMG-Test\" -ErrorAction SilentlyContinue

# View current state
Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json | Format-List

# View latest results
Get-Content C:\bin\HMG\logs\reboot-test\test-results.txt

# Check script version (last modified date)
Get-Item C:\bin\RBCMS\tests\reboot-poc\Test-RebootResume.ps1 | Format-List LastWriteTime

# Find all test logs
Get-ChildItem C:\bin\HMG\logs\reboot-test\
```

---

## Fresh Start (Nuclear Option)

If all else fails, start completely fresh:

```powershell
# 1. Remove all test artifacts
Remove-Item C:\bin\HMG\logs\reboot-test\* -Force -ErrorAction SilentlyContinue
Remove-Item C:\bin\HMG\state\* -Force -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskPath "\HMG-Test\" -Confirm:$false -ErrorAction SilentlyContinue

# 2. Copy latest script
Copy-Item "C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" `
          "C:\bin\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" -Force

# 3. Run test with immediate reboot
cd C:\bin\RBCMS\tests\reboot-poc
.\Test-RebootResume.ps1 -SkipCountdown
```

---

## Expected Behavior (v2.0)

### Before Reboot
```
[Log output with green/yellow colors]
Pre-reboot tasks: ✓ ✓ ✓ ✓
Creating scheduled task: ✓

Either:
  [30-second countdown]
  OR
  [Immediate reboot with -SkipCountdown]
  
System reboots...
```

### After Reboot
```
[System starts up]
[You log in]
[Console window appears - running as SYSTEM]
[Log output]
Post-reboot tasks: ✓ ✓ ✓ ✓

╔══════════════════════════════════════════════════════════╗
║          ✓ REBOOT/RESUME TEST SUCCESSFUL ✓               ║
╠══════════════════════════════════════════════════════════╣
║  The system successfully rebooted and automatically      ║
║  resumed the test. All phases completed!                 ║
║                                                          ║
║  Reboot Count:    1                                      ║
║  Total Duration:  02:15                                  ║
║  Tasks Completed: 12                                     ║
╚══════════════════════════════════════════════════════════╝

Press any key to close this window... [WAITS HERE]
```

---

## Still Not Working?

1. **Check the log file** - it has debug output about the window:
   ```powershell
   Get-Content C:\bin\HMG\logs\reboot-test\test-*.log | Select-String "window"
   ```

2. **Verify RebootCount was saved**:
   ```powershell
   Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json | Select-Object RebootCount
   ```
   Should show: `1` (not `0`)

3. **Check if the post-reboot phase even ran**:
   ```powershell
   Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json | 
       Select-Object -ExpandProperty Phases | 
       Select-Object -ExpandProperty PostReboot
   ```
   Should show: `Status : Completed`

---

**Quick Commands for Copy/Paste**:

```powershell
# Full cleanup and retest
cd C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc; .\Cleanup-Test.ps1; Copy-Item Test-RebootResume.ps1 C:\bin\RBCMS\tests\reboot-poc\ -Force; cd C:\bin\RBCMS\tests\reboot-poc; .\Test-RebootResume.ps1 -SkipCountdown
```
