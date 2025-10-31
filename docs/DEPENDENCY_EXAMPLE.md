# Example: Adding SQL Server and CounterPoint with Dependencies

This example shows how to add SQL Server Express and CounterPoint installation steps using the new priority and dependency features.

```powershell
# In HMG.POS.psm1 or HMG.Common.psm1

# SQL Server Express - needs .NET and runs before CounterPoint
Register-Step -Name "Install SQL Server Express" `
    -Tags @('POS') `
    -Priority 42 `
    -DependsOn @('.NET35') `
    -Provides @('SQLServer', 'Database') `
    -Action {
        $sqlPath = "${env:ProgramFiles}\Microsoft SQL Server\MSSQL15.SQLEXPRESS"
        if(Test-Path $sqlPath){
            Write-Status "SQL Server Express already installed" 'Success'
            return
        }
        
        $installer = Join-Path $Settings.InstallersPath "SQLEXPR_x64_ENU.exe"
        if(-not (Test-Path $installer)){
            Write-Status "SQL Express installer not found" 'Warning'
            return
        }
        
        Write-Status "Installing SQL Server Express..." 'Info'
        $args = @(
            '/Q',                          # Quiet
            '/ACTION=Install',
            '/FEATURES=SQLENGINE',
            '/INSTANCENAME=SQLEXPRESS',
            '/SQLSVCACCOUNT="NT AUTHORITY\Network Service"',
            '/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"',
            '/AGTSVCACCOUNT="NT AUTHORITY\Network Service"',
            '/SQLSVCSTARTUPTYPE=Automatic',
            '/TCPENABLED=1',              # Enable TCP/IP
            '/IACCEPTSQLSERVERLICENSETERMS'
        )
        
        Start-Process -FilePath $installer -ArgumentList $args -Wait
        Write-Status "SQL Server Express installed" 'Success'
    }

# CounterPoint - needs SQL Server and local user
Register-Step -Name "Install CounterPoint" `
    -Tags @('POS') `
    -Priority 48 `
    -DependsOn @('SQLServer', 'LocalUser') `
    -Provides @('CounterPoint', 'POSSoftware') `
    -Action {
        $cpPath = "${env:ProgramFiles(x86)}\CounterPoint"
        if(Test-Path $cpPath){
            Write-Status "CounterPoint already installed" 'Success'
            return
        }
        
        $installer = Join-Path $Settings.InstallersPath "CounterPoint\Setup.exe"
        if(-not (Test-Path $installer)){
            Write-Status "CounterPoint installer not found" 'Warning'
            return
        }
        
        Write-Status "Installing CounterPoint..." 'Info'
        
        # CounterPoint needs the local user to exist
        $userName = Get-SanitizedUsername
        
        # Run installer with parameters
        $args = @(
            '/S',                          # Silent
            "/USERNAME=$userName",
            '/SQLINSTANCE=.\SQLEXPRESS'
        )
        
        Start-Process -FilePath $installer -ArgumentList $args -Wait
        Write-Status "CounterPoint installed" 'Success'
    }

# Configure CounterPoint - runs after installation
Register-Step -Name "Configure CounterPoint" `
    -Tags @('POS') `
    -Priority 49 `
    -DependsOn @('CounterPoint') `
    -Action {
        Write-Status "Configuring CounterPoint settings..." 'Info'
        
        # Set registry keys
        $regPath = "HKLM:\SOFTWARE\CounterPoint"
        if(-not (Test-Path $regPath)){
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "StoreID" -Value $Settings.CounterPoint.StoreID
        Set-ItemProperty -Path $regPath -Name "RegisterID" -Value $env:COMPUTERNAME
        
        # Configure auto-start
        $startupPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $startupPath -Name "CounterPoint" `
            -Value "${env:ProgramFiles(x86)}\CounterPoint\CounterPoint.exe /auto"
        
        Write-Status "CounterPoint configured" 'Success'
    }
```

## Execution Order

When running `.\scripts\Invoke-Setup.ps1 -Role POS`, the steps will execute in this order:

1. **Enable .NET Framework 3.5** (Priority: 10)
   - Provides: `.NET35`
   
2. **Install SQL Server Express** (Priority: 42)
   - Depends on: `.NET35` ✓
   - Provides: `SQLServer`, `Database`
   
3. **Install CounterPoint** (Priority: 48)
   - Depends on: `SQLServer` ✓, `LocalUser` ✓
   - Provides: `CounterPoint`
   
4. **Configure CounterPoint** (Priority: 49)
   - Depends on: `CounterPoint` ✓

## Benefits of This Approach

### 1. **Automatic Ordering**
The dependency system ensures SQL Server installs before CounterPoint, even if priorities are changed.

### 2. **Failure Handling**
If SQL Server fails to install, CounterPoint won't attempt installation.

### 3. **Resume Safety**
Using `-ContinueFrom 3` would skip SQL but CounterPoint would check for the `SQLServer` capability.

### 4. **Clear Dependencies**
Anyone reading the code immediately understands the requirements.

### 5. **Modularity**
Each step is independent and reusable across different roles.

## Adding More Complex Dependencies

```powershell
# Example: A step that needs multiple prerequisites
Register-Step -Name "Configure POS Complete" `
    -Tags @('POS') `
    -Priority 95 `
    -DependsOn @(
        'SQLServer',           # Database installed
        'CounterPoint',        # POS software installed
        'LocalUser',           # User created
        'Configure Firewall',  # Ports opened
        'Configure Autologon'  # Auto-login set
    ) `
    -Action {
        Write-Status "Finalizing POS configuration..." 'Info'
        
        # All dependencies are guaranteed to be complete
        # Perform final configuration
        
        Write-Status "POS system fully configured!" 'Success'
    }
```

## Testing the Dependencies

```powershell
# See the execution order without running
.\scripts\Invoke-Setup.ps1 -Role POS -WhatIf

# Output will show:
# [Info] Resolved execution order: 15 steps to run
# [Info] Running step #1: Enable .NET Framework 3.5 (Priority: 10)
# [WhatIf] Would execute: Enable .NET Framework 3.5
# [Info] Running step #4: Install SQL Server Express (Priority: 42) [Depends on: .NET35]
# [WhatIf] Would execute: Install SQL Server Express
# [Info] Running step #6: Install CounterPoint (Priority: 48) [Depends on: SQLServer, LocalUser]
# [WhatIf] Would execute: Install CounterPoint
```

## Circular Dependency Protection

If you accidentally create a circular dependency:

```powershell
Register-Step -Name "Step A" -DependsOn @('Step B') ...
Register-Step -Name "Step B" -DependsOn @('Step A') ...
```

The framework will detect it:
```
[Error] Failed to resolve step dependencies: Circular dependency detected involving step: Step A
```

This prevents infinite loops and makes debugging easier!
