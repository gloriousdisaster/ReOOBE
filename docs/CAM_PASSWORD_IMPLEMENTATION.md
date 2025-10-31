# CAM System Password Implementation Guide

## Overview

CAM (Camera) systems now have special password handling that prompts for unique credentials during setup, rather than using the shared encrypted password blob like other roles.

## Why This Change?

Camera systems require unique passwords per machine for security reasons. Unlike POS terminals or manager workstations that can share passwords, each camera system needs its own credentials.

## How It Works

### During Setup

When you run the setup for a CAM system:

```powershell
.\scripts\Invoke-Setup.ps1 -Role CAM
```

You will see:

```
====================================
 CAM SYSTEM CREDENTIAL CONFIGURATION
====================================
Each camera system requires unique login credentials.
Please enter the username and password for this specific CAM system.

Enter username for this CAM system: _
```

### The Process

1. **Username Prompt**:
   - Enter a unique username for this CAM system
   - Maximum 20 characters
   - Cannot start with a number
   - Cannot be empty

2. **Password Prompt**:
   - Enter a secure password
   - Confirm the password to prevent typos
   - Passwords must match
   - Cannot be empty

3. **Automatic Configuration**:
   - The system creates/updates the local user
   - Configures autologon with these credentials
   - Does NOT store in the encrypted blob file

## Comparison with Other Roles

| Role | Password Strategy | Where Stored | Setup Experience |
|------|------------------|--------------|------------------|
| POS | Shared password | Encrypted blob | Automatic, no prompts |
| MGR | Shared password | Encrypted blob | Automatic, no prompts |
| CAM | **Unique per system** | **Not stored** | **Prompts during setup** |
| ADMIN | Shared password | Encrypted blob | Automatic, no prompts |

## Testing the Feature

To test the CAM credential prompting without running the full setup:

```powershell
.\Test-CAMCredentials.ps1
```

This test script will:
- Load the necessary modules
- Simulate the credential prompting
- Validate your input
- Show you what would happen in production

## Important Notes

### Security
- CAM passwords are NOT stored in the encrypted blob file
- Each CAM system has unique credentials
- Passwords are only stored locally on that specific machine
- If you need to recreate a CAM user, you'll need to know/reset the password

### Documentation
- Document CAM credentials separately for each system
- Consider using a secure password manager
- Keep track of which username/password goes with which CAM system

### Automation
- CAM systems cannot be fully automated like other roles
- Interactive prompting is required for security
- This is by design to ensure unique credentials

## Troubleshooting

### "Username cannot start with a number"
Choose a username that starts with a letter, like `CAMUser1` instead of `1CAMUser`.

### "Passwords do not match"
The password and confirmation didn't match. Type carefully or use copy/paste.

### "Username must be 20 characters or less"
Use a shorter username. Consider abbreviations like `CAM01` instead of `CameraSystemNumber001`.

### Forgot CAM Password
Since CAM passwords aren't stored in the blob:
1. Log in as a different administrator
2. Reset the password through Computer Management
3. Update autologon if needed

## Examples

### Good CAM Usernames
- `CAM01`
- `LobbyCamera`
- `ParkingCam`
- `MainEntranceCAM`

### Bad CAM Usernames
- `1Camera` (starts with number)
- `ThisIsAVeryLongCameraSystemUsername` (too long)
- ` ` (empty/whitespace)

## Summary

The CAM password implementation provides:
- ✅ Enhanced security with unique credentials per system
- ✅ Interactive prompts during setup
- ✅ Validation to prevent common errors
- ✅ Automatic user creation and autologon configuration
- ✅ Clear visual feedback during the process

This change ensures that camera systems maintain the highest security standards while remaining easy to configure through the HMG Framework.

---

**Implementation Date**: October 2025  
**Version**: 2.1.0  
**Component**: HMG.Common module (Create Local User and Configure Autologon steps)
