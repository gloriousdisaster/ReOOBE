# HMG Username Configuration Guide

## Overview

The HMG framework supports flexible username configuration with three levels of precedence:

1. **Machine-specific overrides** (highest priority)
2. **Role-based configuration** in settings.psd1
3. **Auto-generated from computer name** (default)

## Default Behavior (Computer Name-Based)

By default, ALL roles use the sanitized computer name as the username:

| Computer Name | Generated Username |
|--------------|-------------------|
| CH-505E-POS01 | CH505EPOS01 |
| SH-MGR-DESK02 | SHMGRDESK02 |
| HQ-CAM-001 | HQCAM001 |
| ADMIN-PC-07 | ADMINPC07 |

## Configuration Methods

### Method 1: Default (Recommended)

Leave `Name = ''` in settings.psd1:

```powershell
LocalUsers = @{
    POS   = @{ Name = ''; Groups = @('Users'); Admin = $true }
    MGR   = @{ Name = ''; Groups = @('Users'); Admin = $true }
    CAM   = @{ Name = ''; Groups = @('Users'); Admin = $true }
    ADMIN = @{ Name = ''; Groups = @('Users'); Admin = $true }
}
```

### Method 2: Role-Based Hardcoded Usernames

Set specific usernames per role in settings.psd1:

```powershell
LocalUsers = @{
    POS   = @{ Name = ''; Groups = @('Users'); Admin = $true }           # Dynamic
    MGR   = @{ Name = 'HMGManager'; Groups = @('Users'); Admin = $true } # Fixed
    CAM   = @{ Name = ''; Groups = @('Users'); Admin = $true }           # Dynamic
    ADMIN = @{ Name = 'HMGAdmin'; Groups = @('Users'); Admin = $true }   # Fixed
}
```

### Method 3: Machine-Specific Overrides

Edit `config\username-overrides.psd1` for specific machines:

```powershell
@{
    Overrides = @{
        'CH-505E-POS01' = @{ Username = 'POSUser' }      # Specific POS terminal
        'OFFICE-MGR-01' = @{ Username = 'JohnSmith' }    # John's manager PC
        'LOBBY-CAM-01'  = @{ Username = 'LobbyCamera' }  # Specific camera PC
    }
}
```

## Precedence Order

The framework checks in this order (first match wins):

1. **Machine override** - Is this computer in username-overrides.psd1?
2. **Role hardcode** - Is Name set to a value in settings.psd1?
3. **Auto-generate** - Use sanitized computer name (default)

## Password Mapping

**Important**: Passwords are ALWAYS mapped by ROLE, not username!

- Even if username is "JohnSmith", a MGR system uses the MGR password
- Even with custom usernames, the role determines which password is used

## Examples

### Scenario 1: All Dynamic (Default)
```powershell
# settings.psd1
LocalUsers = @{
    POS = @{ Name = '' }  # All use computer names
    MGR = @{ Name = '' }
    CAM = @{ Name = '' }
}

# Results:
# CH-POS-01 → Username: CHPOS01, Password: POS role password
# HQ-MGR-02 → Username: HQMGR02, Password: MGR role password
```

### Scenario 2: Mixed Configuration
```powershell
# settings.psd1
LocalUsers = @{
    POS = @{ Name = '' }           # Dynamic
    MGR = @{ Name = 'HMGManager' } # Fixed
}

# username-overrides.psd1
Overrides = @{
    'CH-POS-SPECIAL' = @{ Username = 'SpecialPOS' }
}

# Results:
# CH-POS-01      → Username: CHPOS01,     Password: POS role password
# CH-POS-SPECIAL → Username: SpecialPOS,  Password: POS role password
# HQ-MGR-01      → Username: HMGManager,  Password: MGR role password
```

## Autologon Behavior

Autologon automatically uses the determined username:

- If username is generated → autologon uses generated name
- If username is hardcoded → autologon uses hardcoded name
- If username is overridden → autologon uses override

## Validation

The framework will show which method was used:

```
[Info] Running step #3: Create Local User
Using generated username from computer name: CH505EPOS01
# OR
Using hardcoded username from settings: HMGManager
# OR
Using machine-specific username override: JohnSmith
```

## Troubleshooting

### Username Too Long
Computer names over 20 characters will be truncated:
```
THIS-IS-A-VERY-LONG-COMPUTER-NAME → THISISAVERYLONGCOMPU
```

### Username Starts with Number
Will throw an error. Computer names should not start with numbers.

### Wrong Password Used
Remember: Password is determined by ROLE, not username!
- Check which role the system is configured for
- Verify the password for that role in the encrypted blob

## Best Practices

1. **Use default (computer name) for most systems** - Easier to identify
2. **Use hardcoded for shared workstations** - Same login everywhere
3. **Use overrides sparingly** - Only for special cases
4. **Document overrides** - Keep track of why they exist

## Security Notes

- All usernames get the same password per role
- Changing username doesn't change password
- Password is encrypted in blob, username is not
- Username appears in logs, password does not
