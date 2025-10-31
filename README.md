# HMG PowerShell Automation Framework

A comprehensive, enterprise-grade PowerShell module framework for automated Windows workstation configuration based on organizational roles.

## 🎯 Overview

The HMG Framework is a **role-based configuration management system** that automates the deployment and configuration of Windows workstations across different organizational functions. Built entirely in PowerShell, it provides a tag-based execution engine with secure credential management and resume capability.

### Key Statistics
- **~3,800 lines** of PowerShell code across **23 files**
- **5 PowerShell modules** with formal manifests
- **15+ automated configuration steps**
- **4 organizational roles** supported
- **100% PowerShell** - no external dependencies (except optional Sysinternals Autologon)

## ✨ Features

- **🏷️ Role-based configuration**: POS, MGR, CAM, ADMIN roles with specific settings
- **🔖 Tag-based step filtering**: Execute only relevant steps per role
- **♻️ Idempotent operations**: Safe to run multiple times
- **⏯️ Resume capability**: Continue from specific step after interruption
- **📊 Data-driven**: All configuration in centralized `settings.psd1`
- **🔐 Secure password management**: AES-256 encryption with PBKDF2 key derivation
- **✅ Pre-flight validation**: Checks prerequisites before execution
- **📝 Comprehensive logging**: Full transcript of all operations
- **🧩 Modular architecture**: Separate modules for each role
- **🔄 PowerShell 7 compatible**: Works with both Windows PowerShell and PowerShell Core

## 🚀 Quick Start

### Interactive Menu (Recommended)

Run as Administrator:

```powershell
# Launch interactive menu
.\Run-HMGSetup.ps1

# Or direct execution
.\Run-HMGSetup.ps1 -Role POS -Auto
```

### Direct Orchestrator

```powershell
# Basic usage
.\scripts\Invoke-Setup.ps1 -Role POS

# Validate prerequisites only
.\scripts\Invoke-Setup.ps1 -Role MGR -ValidateOnly

# See what would happen without making changes
.\scripts\Invoke-Setup.ps1 -Role CAM -WhatIf

# Resume from step 5 after interruption
.\scripts\Invoke-Setup.ps1 -Role ADMIN -ContinueFrom 5
```

## 👥 Roles

| Role | Purpose | Key Configurations |
|------|---------|-------------------|
| **POS** | Point-of-sale terminals | No sleep, HVCI disabled, firewall rules for CounterPoint/SQL, autologon |
| **MGR** | Manager workstations | 5-min timeout, Office suite, RDP enabled, GlobalProtect VPN ready |
| **CAM** | Camera/surveillance systems | Axis client, no sleep, autologon, minimal software |
| **ADMIN** | Office staff workstations | 5-min timeout, Office suite, backup config, printer setup |

## 🔧 Configuration

### Initial Setup

1. **Create encrypted password file** (for POS, MGR, and ADMIN roles):
```powershell
# Create passwords.txt with role passwords
notepad .\security\passwords.txt

# Encrypt the passwords
.\security\Protect-HMGPasswords.ps1 -PasswordFile passwords.txt

# Test decryption
.\security\Test-PasswordSystem.ps1 -TestDecrypt
```

**Note**: CAM systems use unique passwords per machine and will prompt during setup. They do NOT use the encrypted blob.

2. **Configure settings** in `config\settings.psd1`:
```powershell
# Set to encrypted mode
PasswordMode = 'Encrypted'
EncryptedPasswordFile = 'C:\Users\jdore\projects\HMG\Z-TESTING\repo\security\passwords.blob'
```

3. **Place installer files**:
   - Chrome: `C:\bin\global\installers\googlechromestandaloneenterprise64.msi`
   - Axis (CAM): `C:\bin\global\installers\AXISCameraStationProClientSetup.msi`
   - Office: `C:\bin\global\installers\Office\` (with setup.exe, config.xml, uninstall.xml)
   - GlobalProtect: `C:\bin\global\installers\GlobalProtect64.msi` (optional)

4. **Optional: Place tools**:
   - Autologon: `C:\bin\global\tools\Autologon64.exe`
   - Win11Debloat: `C:\bin\global\tools\Win11Debloat-2025.10.06\`

## 📋 Implemented Features

### Core Steps (All Roles)
| Step | Status | Description |
|------|--------|-------------|
| .NET Framework 3.5 | ✅ | Enables legacy app support |
| Chrome Installation | ✅ | Enterprise browser deployment |
| Local User Creation | ✅ | Dynamic username from computer name |
| Power Management | ✅ | Role-specific power schemes |
| Time Zone | ✅ | Sets Eastern Time |
| Debloat | ✅ | Removes Windows bloatware |
| GlobalProtect VPN | ✅ | Conditional installation |
| Staging Agent | ✅ | Conditional deployment tool |

### Role-Specific Features
| Role | Feature | Status |
|------|---------|--------|
| **POS** | Remove Office | ✅ |
| | Disable HVCI | ✅ |
| | Firewall Rules | ✅ |
| | Autologon | ✅ |
| | SQL Express Check | ✅ |
| **MGR** | Install Office | ✅ |
| | Screen Timeout | ✅ |
| | Enable RDP | ✅ |
| | BitLocker Check | ✅ |
| **CAM** | Remove Office | ✅ |
| | Axis Client | ✅ |
| | Autologon | ✅ |
| | Camera Network | 🔄 |
| **ADMIN** | Install Office | ✅ |
| | Screen Timeout | ✅ |
| | Backup Config | 🔄 |
| | Printer Setup | 🔄 |

## 🏗️ Architecture

```
repo/
├── 📁 modules/           # PowerShell modules
│   ├── HMG.Common/      # Core functionality (650+ lines)
│   ├── HMG.POS/         # POS-specific steps
│   ├── HMG.MGR/         # Manager configurations
│   ├── HMG.CAM/         # Camera system setup
│   └── HMG.Admin/       # Office admin features
├── 📁 config/           # Configuration files
│   ├── settings.psd1    # Main configuration (240+ lines)
│   ├── roles.psd1       # Role definitions
│   └── username-overrides.psd1  # Per-machine usernames
├── 📁 security/         # Password management
│   ├── HMG.Security.psm1        # Encryption module
│   ├── Protect-HMGPasswords.ps1 # Encryption utility
│   └── passwords.blob           # Encrypted passwords
├── 📁 scripts/          # Orchestration
│   └── Invoke-Setup.ps1        # Main orchestrator (320+ lines)
├── 📁 tests/            # Test suites
│   └── HMG.Tests.ps1           # Pester tests
└── Run-HMGSetup.ps1    # Interactive menu runner
```

## 🔒 Security Features

### Password Management
- **AES-256 encryption** with PBKDF2 (100,000 iterations)
- **Random salts** per password
- **Master password** protection
- **Portable blobs** - decrypt on any machine
- **PowerShell 7 compatible** - bypasses SecureString issues
- **Session caching** to avoid repeated prompts
- **CAM Exception**: CAM systems prompt for unique credentials during setup (not stored in blob)

### Username Configuration
- **Dynamic generation** from computer name (default)
- **Role-based hardcoding** option in settings.psd1
- **Machine-specific overrides** via username-overrides.psd1
- See `docs/USERNAME_CONFIGURATION.md` for details

## 🛠️ Extending the Framework

### Adding a New Step

Edit the appropriate module and register your step:

```powershell
# In modules/HMG.Common/HMG.Common.psm1
Register-Step -Name "Install 7-Zip" -Tags @('ALL') -Action {
    $exe = "$Env:ProgramFiles\7-Zip\7z.exe"
    if(Test-Path $exe){
        Write-Status "7-Zip already installed" 'Success'
        return
    }
    
    $msi = Join-Path $Settings.InstallersPath "7z2301-x64.msi"
    if(-not (Test-Path $msi)){
        Write-Status "7-Zip MSI not found" 'Warning'
        return
    }
    
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait
    Write-Status "7-Zip installed" 'Success'
}
```

### Adding a New Role

1. Add to `config\roles.psd1`:
```powershell
@{
    Roles = @('POS','MGR','CAM','ADMIN','KIOSK')  # Add new role
}
```

2. Configure in `config\settings.psd1`
3. Create module: `modules\HMG.KIOSK\`
4. Update validation sets in scripts

## 🧪 Testing

```powershell
# Run Pester tests
Invoke-Pester -Path .\tests\HMG.Tests.ps1

# Test password system
.\security\Test-PasswordSystem.ps1 -TestDecrypt

# Validate configuration
.\scripts\Invoke-Setup.ps1 -Role POS -ValidateOnly
```

## 📊 Troubleshooting

| Issue | Solution |
|-------|----------|
| Access denied | Run as Administrator |
| Password errors | Check master password, run Test-PasswordSystem.ps1 |
| Step failed | Check logs in `C:\bin\HMG\logs\` |
| Missing files | Run with `-ValidateOnly` to check prerequisites |
| Need to test | Use `-WhatIf` parameter |
| Interrupted | Use `-ContinueFrom` with step number |

## 🗺️ Roadmap

- [ ] Scheduled task for automatic resume after reboot
- [ ] JSON structured logging
- [ ] Performance metrics per step
- [ ] Intune/domain join detection
- [ ] SQL Server Express automated installation
- [ ] CounterPoint installation module
- [ ] Central reporting server integration
- [ ] Remote execution via PowerShell remoting
- [ ] Web-based configuration portal

## 📚 Documentation

- [Password Management Guide](./security/PASSWORD_MANAGEMENT.md)
- [Username Configuration](./docs/USERNAME_CONFIGURATION.md)
- [Project Status](./CURRENT_STATUS.md)
- Module Documentation: Use `Get-Help` on any function

## 🤝 Contributing

This is an internal project for Haven Management Group. For contributions:

1. Test changes thoroughly in isolated environment
2. Update relevant documentation
3. Add Pester tests for new features
4. Follow existing code patterns
5. Use descriptive commit messages

## 📜 License

Internal use only - Haven Management Group

---

**Version**: 1.0.0  
**Author**: Joshua Dore  
**Created**: October 2025  
**PowerShell**: 5.1+ / 7.x compatible  
**Platform**: Windows 10/11 Pro/Enterprise
