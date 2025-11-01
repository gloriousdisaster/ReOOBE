# ReOOBE Task Mapping Document

**Purpose:** Map every task from existing code to new modular structure  
**Date:** October 31, 2025  
**Status:** Planning Phase

---

## Overview

This document maps all deployment tasks from the current system to the new ReOOBE architecture. Each task is categorized by:
- **Source** - Where it currently lives (oobe.ps1, HMG.POS.psm1, etc.)
- **Domain** - Logical grouping (System, Apps, Network, etc.)
- **Target Module** - Which new module will contain it
- **Target Function** - Function name in new structure
- **Reusability** - Used by multiple roles? (Broad function?)
- **Dependencies** - What must run before this
- **Plan Category** - Where it goes in execution plans

---

## Task Categories

### Legend
- **[ALL]** - Runs on all systems (base.psd1)
- **[POS]** - POS-specific (roles/POS.psd1)
- **[MGR]** - Manager-specific (roles/MGR.psd1)
- **[CAM]** - Camera-specific (roles/CAM.psd1)
- **[ADMIN]** - Admin-specific (roles/ADMIN.psd1)
- **[REBOOT]** - Requires reboot after execution
- **[CRITICAL]** - Failure stops deployment

---

## OOBE Tasks (Currently in oobe.ps1)

### Security & Authentication

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 1 | Decrypt password vault | oobe.ps1 | Security | `Unprotect-PasswordVault` | [ALL] | ✅ Yes | None | Uses master password to decrypt role passwords |
| 2 | Create HavenAdmin account | oobe.ps1 | Security | `New-AdminAccount` | [ALL] | ✅ Yes | Password vault | Generic - can create any admin account |
| 3 | Configure AutoLogon | HMG.Baseline | Security | `Set-AutoLogon` | [ALL] | ✅ Yes | User account | Uses Sysinternals tool |

**Broad Functions:**
- `Unprotect-PasswordVault` - Any role needs passwords
- `New-AdminAccount` - Any role might need admin accounts
- `Set-AutoLogon` - Any role might need autologon

---

### Windows OOBE Bypass

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 4 | Mark OOBE complete | oobe.ps1 | OOBE | `Set-OOBEComplete` | [ALL] | ✅ Yes | None | Multiple registry keys |
| 5 | Suppress privacy experience | oobe.ps1 | OOBE | `Disable-PrivacyExperience` | [ALL] | ✅ Yes | None | Part of OOBE bypass |
| 6 | Clear setup phase flags | oobe.ps1 | OOBE | `Clear-OOBEFlags` | [ALL] | ✅ Yes | None | Remove OOBEInProgress |

**Broad Functions:**
- All OOBE functions are reusable - any deployment needs OOBE bypass

---

### System Configuration

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 7 | Remove defaultuser0 | oobe.ps1 | System | `Remove-DefaultUser` | [ALL] | ✅ Yes | None | Clean up temp account |
| 8 | Rename computer | oobe.ps1 | System | `Rename-SystemComputer` | [ALL] | ✅ Yes | None | Prompts for name |
| 9 | Set time zone | HMG.Baseline | System | `Set-SystemTimeZone` | [ALL] | ✅ Yes | None | Default: EST |
| 10 | Configure power plan | HMG.Baseline | System | `Set-PowerPlan` | [ALL] | ✅ Yes | None | High performance |
| 11 | Disable HVCI | HMG.POS | System | `Disable-HVCI` | [POS] [REBOOT] | ✅ Yes | None | Security feature disable |

**Broad Functions:**
- All system configuration functions are reusable across roles

---

### File Operations

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 12 | Copy project to C:\bin | oobe.ps1 | Deployment | `Copy-ProjectStructure` | [ALL] | ✅ Yes | None | Copies deployment + ReOOBE folders |
| 13 | Deploy desktop shortcuts | HMG.POS | Deployment | `Deploy-DesktopShortcuts` | [POS] [MGR] | ✅ Yes | User account | Generic shortcut deployment |
| 14 | Deploy RDP files | HMG.POS | Deployment | `Deploy-RDPFiles` | [POS] [MGR] | ✅ Yes | User account | Generic file deployment |
| 15 | Clean up shortcuts | HMG.POS | Deployment | `Remove-DesktopShortcuts` | [POS] | ⚠️ Maybe | None | Could be generic with params |

**Broad Functions:**
- `Copy-ProjectStructure` - Every role needs this
- `Deploy-DesktopShortcuts` - Reusable with parameters (which shortcuts, where)
- `Deploy-RDPFiles` - Reusable for any file deployment

---

### Network Configuration

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 16 | Import WiFi profiles | oobe.ps1 | Network | `Import-WiFiProfiles` | [ALL] | ✅ Yes | None | From XML files |
| 17 | Configure firewall rules | HMG.POS | Network | `Add-FirewallRules` | [POS] | ✅ Yes | None | Generic - takes rule definitions |

**Broad Functions:**
- Both network functions are broadly reusable

---

### Registry Configuration

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 18 | Apply Chrome enrollment | oobe.ps1 | System | `Set-ChromeEnrollmentToken` | [ALL] | ✅ Yes | None | Registry value |
| 19 | Disable Cortana | oobe.ps1 | System | `Disable-CortanaAboveLock` | [ALL] | ✅ Yes | None | Registry value |
| 20 | Disable web search | HMG.Baseline | System | `Disable-WindowsWebSearch` | [ALL] | ✅ Yes | None | Multiple registry keys |
| 21 | Disable consumer features | HMG.Baseline | System | `Disable-ConsumerFeatures` | [ALL] | ✅ Yes | None | Registry value |

**Broad Functions:**
- All registry functions are reusable - consider generic `Set-RegistryValue` helper

---

### Data & Logging

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 22 | Log MAC address to CSV | oobe.ps1 | Data | `Export-MACAddress` | [ALL] | ✅ Yes | None | Network tracking |

**Broad Functions:**
- `Export-MACAddress` - Useful for all deployments

---

## Application Installation Tasks

### Browser & Core Software

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 23 | Install Chrome | HMG.Baseline | Apps | `Install-Chrome` | [ALL] | ✅ Yes | None | MSI installation |
| 24 | Remove Office apps | HMG.Baseline | Apps | `Remove-OfficeApps` | [ALL] | ⚠️ Maybe | None | Uses removal tool |

**Broad Functions:**
- `Install-Chrome` - All roles need Chrome
- `Remove-OfficeApps` - Potentially reusable

---

### POS-Specific Applications

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 25 | Install DeskCam | HMG.POS | Apps | `Install-DeskCam` | [POS] | ❌ No | None | POS-specific hardware |
| 26 | Install .NET Framework 3.5 | HMG.POS | Apps | `Install-DotNetFramework35` | [POS] [REBOOT] | ✅ Yes | None | Generic framework install |
| 27 | Install SQL Server Express | HMG.POS | Apps | `Install-SQLServer` | [POS] [REBOOT] [CRITICAL] | ✅ Yes | None | Reusable for any role needing SQL |
| 28 | Install SSMS | HMG.POS | Apps | `Install-SSMS` | [POS] | ✅ Yes | SQL Server | Reusable for any role needing SSMS |
| 29 | Configure SQL Server | HMG.POS | Apps | `Invoke-SQLConfiguration` | [POS] | ⚠️ Maybe | SQL Server | Runs SQL scripts - could be generic |
| 30 | Install CP SQL Prerequisites | HMG.POS | Apps | `Install-CounterPointPrerequisites` | [POS] | ❌ No | SQL Server | CounterPoint-specific |
| 31 | Install CounterPoint | HMG.POS | Apps | `Install-CounterPoint` | [POS] [CRITICAL] | ❌ No | SQL + Prerequisites | CounterPoint-specific |

**Broad Functions:**
- `Install-DotNetFramework35` - Any role might need .NET
- `Install-SQLServer` - Reusable (MGR might need SQL)
- `Install-SSMS` - Reusable
- `Invoke-SQLConfiguration` - Could be generic "run SQL script" function

---

### System Cleanup & Optimization

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 32 | Run POS debloat script | HMG.POS | Deployment | `Invoke-DebloatScript` | [POS] | ✅ Yes | None | Generic script runner |
| 33 | Remove POS apps | HMG.POS | System | `Remove-WindowsApps` | [POS] | ✅ Yes | None | Generic app removal with list |

**Broad Functions:**
- `Invoke-DebloatScript` - Generic script execution
- `Remove-WindowsApps` - Generic with app list parameter

---

## State Management Tasks

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 34 | Create checkpoint | HMG.State | State | `New-DeploymentCheckpoint` | [ALL] | ✅ Yes | None | Save deployment state |
| 35 | Resume from checkpoint | HMG.State | State | `Resume-DeploymentCheckpoint` | [ALL] | ✅ Yes | Checkpoint file | Resume after reboot |
| 36 | Request reboot | HMG.State | State | `Request-SystemReboot` | [ALL] | ✅ Yes | None | Schedule reboot |

**Broad Functions:**
- All State functions are core infrastructure - reusable everywhere

---

## Validation & Prerequisites

| # | Task Name | Source | Target Module | Target Function | Tags | Reusable? | Dependencies | Notes |
|---|-----------|--------|---------------|-----------------|------|-----------|--------------|-------|
| 37 | Validate POS prerequisites | HMG.POS | System | `Test-Prerequisites` | [POS] | ✅ Yes | None | Generic validation with checklist |
| 38 | Check administrator rights | HMG.Core | System | `Test-AdministratorRights` | [ALL] | ✅ Yes | None | Essential check |
| 39 | Check disk space | N/A | System | `Test-DiskSpace` | [ALL] | ✅ Yes | None | Pre-flight check |

**Broad Functions:**
- `Test-Prerequisites` - Generic with checklist parameter
- All validation functions are broadly reusable

---

## Summary Statistics

### By Reusability
- **Broadly Reusable:** 35 tasks (89%)
- **Role-Specific:** 4 tasks (11%)

### By Module
- **System:** 14 tasks
- **Apps:** 11 tasks
- **Security:** 3 tasks
- **OOBE:** 3 tasks
- **Deployment:** 5 tasks
- **Network:** 2 tasks
- **State:** 3 tasks
- **Data:** 1 task

### By Execution Scope
- **[ALL] roles:** 28 tasks
- **[POS] only:** 11 tasks
- **[POS] + others:** 2 tasks

### Critical Characteristics
- **Requires Reboot:** 3 tasks
- **Critical (failure stops):** 2 tasks

---

## Module Structure Summary

Based on task analysis, here's the recommended module organization:

### **Core Module** (Orchestration)
- `Invoke-Step` ✅ Built
- `Get-ExecutionPlan` - TODO
- `Start-Deployment` - TODO

### **System Module** (14 functions)
High reusability - generic system configuration
- Time zone, power, HVCI, computer rename, etc.
- Registry helpers
- Validation functions

### **Apps Module** (11 functions)
Mixed reusability
- Generic: Chrome, .NET, SQL Server, SSMS
- Specific: DeskCam, CounterPoint

### **Security Module** (3 functions)
High reusability
- Password vault, admin accounts, autologon

### **OOBE Module** (3 functions)
High reusability
- All systems need OOBE bypass

### **Network Module** (2 functions)
High reusability
- WiFi profiles, firewall rules

### **Deployment Module** (5 functions)
High reusability
- File operations, shortcuts, script execution

### **Data Module** (1 function)
High reusability
- MAC address logging

### **State Module** (3 functions)
High reusability - core infrastructure
- Checkpoints, reboots, resume

---

## Broad Functions - Priority List

These functions should be built as **generic, parameterized, reusable**:

### Tier 1: Essential Infrastructure (Build First)
1. `Invoke-Step` ✅ Complete
2. `Get-ExecutionPlan` - Plan loading
3. `Start-Deployment` - Orchestrator
4. `New-DeploymentCheckpoint` - State management
5. `Resume-DeploymentCheckpoint` - State management

### Tier 2: Core System Functions
6. `Set-SystemTimeZone` - Used by all
7. `Set-PowerPlan` - Used by all
8. `Rename-SystemComputer` - Used by all
9. `Remove-DefaultUser` - Used by all
10. `Test-AdministratorRights` - Pre-flight check

### Tier 3: Deployment Operations
11. `Copy-ProjectStructure` - File operations
12. `Deploy-DesktopShortcuts` - File operations
13. `Invoke-DebloatScript` - Script execution
14. `Set-RegistryValue` - Registry helper (generic)

### Tier 4: Applications
15. `Install-Chrome` - Universal
16. `Install-SQLServer` - Reusable
17. `Install-SSMS` - Reusable
18. `Install-DotNetFramework35` - Reusable

### Tier 5: Security & Network
19. `Unprotect-PasswordVault` - Security
20. `New-AdminAccount` - User management
21. `Import-WiFiProfiles` - Network
22. `Add-FirewallRules` - Network

---

## Next Steps

1. **Create module skeletons** with correct folder structure
2. **Build Tier 1 functions** (execution plan, orchestrator)
3. **Define data schemas** (apps.psd1, base.psd1, roles/*.psd1)
4. **Implement one complete vertical slice** (e.g., System module)
5. **Create migration plan** for existing code

---

## Notes

- **Broad functions should be parameterized** - avoid hardcoded values
- **Role-specific logic should be in plan files**, not function code
- **Functions should be idempotent** - safe to run multiple times
- **All functions should use Invoke-Step** - consistent execution
- **Plan files control WHAT runs WHEN** - functions only know HOW

---

**Document Status:** Complete  
**Next Action:** Review and refine before building
