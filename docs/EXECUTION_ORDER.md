# HMG Framework Execution Order Documentation

## Overview

The HMG Framework now includes an advanced execution system with **Priority-based ordering** and **Dependency resolution** to ensure steps run in the correct sequence.

## Features

### 1. Priority System
Steps execute in order of priority (lower numbers run first).

### 2. Dependency Resolution
Steps can depend on other steps or capabilities, ensuring prerequisites are met.

### 3. Topological Sorting
Automatic circular dependency detection and resolution.

## Priority Levels

The framework uses a standardized priority scale:

| Priority Range | Category | Description |
|----------------|----------|-------------|
| **10-20** | Prerequisites | Framework components (.NET, etc.) |
| **25-29** | Removals | Uninstalling software |
| **30-40** | Core Software | Essential applications |
| **50-59** | User & Security | User accounts, passwords |
| **60-69** | System Security | Firewall, HVCI, etc. |
| **70-79** | System Settings | Time zone, power |
| **80-89** | Optimizations | Performance tweaks |
| **90-100** | Cleanup | Debloat, final steps |

## Step Registration

### Basic Registration
```powershell
Register-Step -Name "Step Name" -Tags @('POS') -Action {
    # Step implementation
}
```

### With Priority
```powershell
Register-Step -Name "Install Chrome" -Tags @('ALL') -Priority 30 -Action {
    # Installs early as core software
}
```

### With Dependencies
```powershell
Register-Step -Name "Configure Autologon" -Tags @('POS') `
    -Priority 55 `
    -DependsOn @('LocalUser') `
    -Action {
        # Will only run after 'Create Local User' completes
    }
```

### Providing Capabilities
```powershell
Register-Step -Name "Enable .NET Framework 3.5" -Tags @('ALL') `
    -Priority 10 `
    -Provides @('.NET35') `
    -Action {
        # Other steps can depend on '.NET35'
    }
```

## Current Step Configuration

| Step | Priority | Dependencies | Provides |
|------|----------|--------------|----------|
| Enable .NET Framework 3.5 | 10 | - | .NET35 |
| Remove Office | 25 | - | - |
| Install Chrome | 30 | - | Browser |
| Install GlobalProtect | 35 | .NET35 | - |
| Install Staging Agent | 36 | - | - |
| Install Office | 40 | .NET35 | Office |
| Create Local User | 50 | - | LocalUser, UserAccount |
| Configure Autologon | 55 | LocalUser | - |
| Disable Memory Integrity | 60 | - | - |
| Configure Firewall | 65 | - | - |
| Set Time Zone | 70 | - | - |
| Configure Power | 75 | - | - |
| Screen Timeout | 76 | Configure Power Settings | - |
| Run Debloat | 90 | - | - |

## Execution Flow

### 1. Tag Filtering
Only steps matching the role's tags are considered.

### 2. Priority Sorting
Steps are sorted by priority value (ascending).

### 3. Dependency Resolution
Dependencies are resolved using topological sorting:
- Each step's dependencies must run first
- Circular dependencies are detected and reported
- Missing dependencies generate warnings

### 4. Sequential Execution
Steps run in the resolved order.

## Example Execution Order

### POS Role
```
1. Enable .NET Framework 3.5 (Priority: 10)
2. Remove Office (Priority: 25)
3. Install Chrome (Priority: 30)
4. Install Staging Agent (Priority: 36) [if enabled]
5. Create Local User (Priority: 50)
6. Configure Autologon (Priority: 55) [depends on LocalUser]
7. Disable Memory Integrity (Priority: 60)
8. Configure Firewall Rules (Priority: 65)
9. Set Time Zone (Priority: 70)
10. Configure Power Settings (Priority: 75)
11. Run Debloat Scripts (Priority: 90)
```

### MGR Role
```
1. Enable .NET Framework 3.5 (Priority: 10)
2. Install Chrome (Priority: 30)
3. Install GlobalProtect VPN (Priority: 35) [depends on .NET35]
4. Install Staging Agent (Priority: 36) [if enabled]
5. Install Office (Priority: 40) [depends on .NET35]
6. Create Local User (Priority: 50)
7. Set Time Zone (Priority: 70)
8. Configure Power Settings (Priority: 75)
9. Configure Screen Timeout (Priority: 76) [depends on Power Settings]
10. Run Debloat Scripts (Priority: 90)
```

## Advanced Usage

### Creating Complex Dependencies
```powershell
Register-Step -Name "Configure SQL Server" `
    -Tags @('POS') `
    -Priority 45 `
    -DependsOn @('.NET35', 'LocalUser') `
    -Provides @('SQLServer', 'Database') `
    -Action {
        # Requires both .NET and a local user
    }
```

### Conditional Dependencies
```powershell
Register-Step -Name "Install App" -Tags @('ALL') -Priority 35 -Action {
    # Check if dependency was met
    if($script:CompletedSteps -contains 'Office'){
        # Office is installed, do something
    }
}
```

### Dynamic Priority
While not built-in, you can register steps conditionally:
```powershell
$priority = if($Settings.FastMode) { 20 } else { 50 }
Register-Step -Name "Special Step" -Priority $priority -Tags @('ALL') -Action {
    # Runs early in fast mode
}
```

## Troubleshooting

### Circular Dependency Error
```
"Circular dependency detected involving step: StepName"
```
**Solution**: Review the dependency chain and remove circular references.

### Missing Dependency Warning
```
"Step 'X' depends on 'Y' which is not available"
```
**Solution**: Ensure the dependency step is registered and has matching tags.

### Viewing Execution Order
```powershell
# Dry run to see order without executing
.\scripts\Invoke-Setup.ps1 -Role POS -WhatIf

# Output shows:
# [Info] Running step #1: Enable .NET Framework 3.5 (Priority: 10)
# [WhatIf] Would execute: Enable .NET Framework 3.5
# [Info] Running step #2: Remove Office (Priority: 25)
# [WhatIf] Would execute: Remove Office
# ...
```

## Best Practices

### 1. Use Standard Priority Ranges
Stick to the defined priority ranges for consistency.

### 2. Declare All Dependencies
If a step requires another, explicitly declare it.

### 3. Provide Capabilities
Use the `Provides` parameter for steps that enable features.

### 4. Test Execution Order
Use `-WhatIf` to verify the execution sequence.

### 5. Document Priority Decisions
Comment why a specific priority was chosen:
```powershell
# Priority 35: Must run after Chrome (30) but before Office (40)
Register-Step -Name "Configure Browser" -Priority 35 ...
```

## Migration Guide

### Updating Existing Steps
Old format:
```powershell
Register-Step -Name "Install Chrome" -Tags @('ALL') -Action { ... }
```

New format with priority:
```powershell
Register-Step -Name "Install Chrome" -Tags @('ALL') -Priority 30 -Action { ... }
```

### Default Priority
Steps without explicit priority get `Priority = 50` (middle range).

## Implementation Details

### The Sorting Algorithm
1. Filter steps by tags
2. Sort by priority value
3. Build dependency graph
4. Perform topological sort
5. Return execution sequence

### The Visit-Step Function
Implements depth-first search for dependency resolution:
- Tracks visited nodes
- Detects circular dependencies
- Ensures dependencies run first

### Execution Tracking
- `$script:CompletedSteps` tracks what has run
- Each step's `Executed` property is set when complete
- Dependencies can check completion status

## Future Enhancements

### Parallel Execution
Steps with same priority and no interdependencies could run in parallel.

### Conditional Dependencies
Dependencies that are optional based on settings.

### Priority Groups
Named priority groups instead of numbers:
```powershell
-Priority 'Prerequisites'  # Maps to 10-20
-Priority 'CoreSoftware'   # Maps to 30-40
```

### Dependency Providers
Multiple steps providing the same capability:
```powershell
# Either Chrome OR Edge satisfies 'Browser' dependency
Register-Step -Name "Install Chrome" -Provides @('Browser') ...
Register-Step -Name "Install Edge" -Provides @('Browser') ...
```

## Summary

The priority and dependency system ensures:
- ✅ Correct execution order
- ✅ Prerequisites are met
- ✅ No circular dependencies
- ✅ Clear, maintainable configuration
- ✅ Flexible enough for complex scenarios

This makes the HMG Framework more robust and enterprise-ready!
