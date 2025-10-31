# Quick Start - Reboot/Resume Test

## ONE COMMAND TO RUN

```powershell
cd C:\Users\jdore\projects\HMG\hmg_RBCMS\RBCMS\tests\reboot-poc
.\Test-RebootResume.ps1
```

## What Happens

1. Script runs pre-reboot tasks (30 seconds)
2. **30-second countdown** to reboot (you can cancel with Ctrl+C)
3. System reboots
4. Log back in (as any user)
5. Script **automatically resumes** post-reboot tasks
6. Results displayed

## Quick Checks

### Before Running
```powershell
# Verify you're admin
[bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
```

### During Test (In Another PowerShell Window)
```powershell
# Watch the log file
Get-Content C:\bin\HMG\logs\reboot-test\*.log -Wait -Tail 20
```

### After Reboot
```powershell
# Check if task triggered
Get-ScheduledTask -TaskPath "\HMG-Test\" | Get-ScheduledTaskInfo

# View results
Get-Content C:\bin\HMG\logs\reboot-test\test-results.txt
```

## Success Looks Like

```
╔══════════════════════════════════════════════════════════╗
║              TEST COMPLETED SUCCESSFULLY                 ║
╠══════════════════════════════════════════════════════════╣
║ Test Name:      RebootResume-POC                        ║
║ Duration:       00:02:15                                 ║
║ Reboots:        1                                        ║
║ Tasks:          10                                       ║
║ Errors:         0                                        ║
╠══════════════════════════════════════════════════════════╣
║ Phase Results:                                           ║
║   Init            Completed                              ║
║   PreReboot       Completed                              ║
║   PostReboot      Completed                              ║
║   Cleanup         Completed                              ║
╚══════════════════════════════════════════════════════════╝
```

## Troubleshooting One-Liners

```powershell
# Didn't resume? Manually trigger post-reboot
.\Test-RebootResume.ps1 -Phase PostReboot

# Clear everything and start over
Remove-Item C:\bin\HMG\logs\reboot-test\* -Force
Unregister-ScheduledTask -TaskPath "\HMG-Test\" -Confirm:$false
.\Test-RebootResume.ps1

# View full log
notepad (Get-ChildItem C:\bin\HMG\logs\reboot-test\test-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

## Files to Check

| File | Purpose |
|------|---------|
| `C:\bin\HMG\logs\reboot-test\test-*.log` | Detailed log |
| `C:\bin\HMG\logs\reboot-test\test-state.json` | Test state |
| `C:\bin\HMG\logs\reboot-test\test-results.txt` | Final report |

## Expected Timeline

- **Init Phase**: 2-3 seconds
- **Pre-Reboot Phase**: 5-7 seconds
- **Countdown**: 30 seconds
- **Reboot**: 1-2 minutes (depends on system)
- **Post-Reboot Phase**: 5-7 seconds
- **Cleanup Phase**: 2-3 seconds

**Total**: ~2-3 minutes including reboot

---

⚠️ **Remember**: This does a REAL reboot! Save your work first.
