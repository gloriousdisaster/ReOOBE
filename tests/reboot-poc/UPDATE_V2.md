# 🎉 Reboot/Resume Test v2.0 - Fixes Applied!

## What Was Fixed

### 1. ✅ RebootCount Bug
**Before**: Showed `0` even after successful reboot  
**After**: Now correctly shows `1`

**The Fix**: State is now saved immediately after incrementing the counter, before any other operations that reload state.

### 2. ✅ Visible Success Window
**Before**: Console flashed quickly and closed  
**After**: Prominent **cyan success box** appears and **waits for user input**

**What You'll See After Reboot**:
```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║          ✓ REBOOT/RESUME TEST SUCCESSFUL ✓               ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  The system successfully rebooted and automatically      ║
║  resumed the test. All phases completed!                 ║
║                                                          ║
║  Reboot Count:    1                                      ║
║  Total Duration:  02:15                                  ║
║  Tasks Completed: 12                                     ║
║                                                          ║
║  Log Directory:                                          ║
║  C:\bin\HMG\logs\reboot-test\                            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Press any key to close this window...
```

**This window**:
- ✅ Appears automatically after reboot
- ✅ Stays visible until you press a key
- ✅ Shows clear success status
- ✅ Only appears on post-reboot run (not before reboot)

---

## How to Test the New Version

### Step 1: Copy Updated Script

```powershell
Copy-Item "C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" `
          "C:\bin\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" -Force
```

### Step 2: Run the Test

```powershell
cd C:\bin\RBCMS\tests\reboot-poc
.\Test-RebootResume.ps1
```

### Step 3: What to Expect

**Before Reboot**:
- Normal colored output
- 30-second countdown
- System reboots

**After Reboot** (🆕 NEW BEHAVIOR):
- Log back in
- **Cyan window pops up automatically**
- **Window stays visible** showing success message
- **Press any key to close** (or just close the window)

### Step 4: Verify the Fixes

```powershell
# Check that RebootCount is now 1 (not 0)
(Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json).RebootCount

# Should show: 1

# Also check the results file
Get-Content C:\bin\HMG\logs\reboot-test\test-results.txt | Select-String "Reboots:"

# Should show: Reboots: 1
```

---

## Quick Copy/Paste Commands

```powershell
# Update the script
Copy-Item "C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" "C:\bin\RBCMS\tests\reboot-poc\Test-RebootResume.ps1" -Force

# Run the test
cd C:\bin\RBCMS\tests\reboot-poc; .\Test-RebootResume.ps1

# After reboot, verify RebootCount = 1
(Get-Content C:\bin\HMG\logs\reboot-test\test-state.json | ConvertFrom-Json).RebootCount
```

---

## What Changed in the Code

### Fix #1: RebootCount Increment
```powershell
# OLD CODE (buggy):
$state.RebootCount++
Update-TestState -Phase 'PostReboot' -Status 'Running'
# ^ This reloads state from disk, losing the increment!

# NEW CODE (fixed):
$state.RebootCount++
Save-TestState -State $state  # ← Save immediately!
Write-TestLog "Reboot count incremented to: $($state.RebootCount)" -Level INFO
Update-TestState -Phase 'PostReboot' -Status 'Running'
```

### Fix #2: Success Window
```powershell
# Added at the end of Invoke-CleanupPhase:
if ($state.RebootCount -gt 0) {
    # Show cyan success box
    Write-Host "╔══════════...╗" -ForegroundColor Cyan
    # ... success message ...
    
    # WAIT for user input before closing
    Write-Host "Press any key to close this window..." -ForegroundColor Yellow -NoNewline
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
```

---

## Success Criteria

After running the updated test, you should see:

✅ **RebootCount = 1** (not 0)  
✅ **Cyan success window appears** after reboot  
✅ **Window waits for keypress** before closing  
✅ **All 12 tasks completed**  
✅ **All 4 phases show "Completed"**  
✅ **0 errors**  

---

## Ready to Test!

The updated script is in:
- **Project**: `C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc\Test-RebootResume.ps1`

Copy it to your test location and run it again. You should now see the visible success window after reboot! 🎉

---

**Version**: 2.0  
**Date**: October 28, 2025  
**Changes**: RebootCount bug fixed + Visible success window added  
**Status**: ✅ Ready to test
