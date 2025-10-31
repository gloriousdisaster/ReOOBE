@{
  InstallersPath        = 'C:\bin\deployment\global\installers'
  LogsPath              = 'C:\bin\HMG\logs'

  # Power policy per role
  PowerPolicies         = @{
    POS   = @{ Scheme = 'High'; AC_DisplayMin = 0; DC_DisplayMin = 0; AC_SleepMin = 0; DC_SleepMin = 0 }
    MGR   = @{ Scheme = 'High'; AC_DisplayMin = 5; DC_DisplayMin = 5; AC_SleepMin = 0; DC_SleepMin = 0 }
    CAM   = @{ Scheme = 'High'; AC_DisplayMin = 0; DC_DisplayMin = 0; AC_SleepMin = 0; DC_SleepMin = 0 }
    STAFF = @{ Scheme = 'High'; AC_DisplayMin = 5; DC_DisplayMin = 5; AC_SleepMin = 0; DC_SleepMin = 0 }
  }

  # Idle display timeout override (minutes) for specific roles
  ScreenTimeoutMinutes  = @{
    MGR   = 5
    STAFF = 5
  }

  # .NET Framework 3.5 configuration
  DotNetFramework       = @{
    POS   = 'Enable'    # Enable for POS systems
    MGR   = 'Leave'     # Leave as-is
    CAM   = 'Leave'     # Leave as-is
    STAFF = 'Leave'     # Leave as-is
  }

  Debloat               = @{
    Baseline = @{
      ScriptPath = 'C:\bin\deployment\global\scripts\Win11Debloat-2025.10.06\Win11Debloat.ps1'
      Arguments  = '-RunDefaults -Sysprep -Silent -CreateRestorePoint'
      LogPath    = 'C:\bin\HMG\logs'
    }
    POS      = @{
      CustomAppsList = 'C:\bin\deployment\global\scripts\Win11Debloat-2025.10.06\CustomAppsList'
      RemoveCustom   = $true    # Run additional custom app removal pass
    }
    CAM      = @{
      CustomAppsList = 'C:\bin\deployment\global\scripts\Win11Debloat-2025.10.06\CustomAppsList'
      RemoveCustom   = $true    # Run additional custom app removal pass
    }
    MGR      = @{
      RemoveCustom = $false   # Uses baseline only
    }
    STAFF    = @{
      RemoveCustom = $false   # Uses baseline only
    }
  }

  # Local user configuration
  # NOTE: "STAFF" here is a computer role for administrative staff workstations
  # "HavenAdmin" is a separate local user account created on ALL computers
  #
  # Username Options:
  #   Name = ''          : Use sanitized computer name (removes dashes)
  #   Name = 'username'  : Use hardcoded username
  #   Name = 'AUTO'      : Same as empty - use computer name
  #
  # Default: All roles use computer-name-based usernames
  LocalUsers            = @{
    POS   = @{ Name = ''; Groups = @('Users'); Admin = $true }    # Uses computer name
    MGR   = @{ Name = ''; Groups = @('Users'); Admin = $true }    # Uses computer name
    CAM   = @{ Name = ''; Groups = @('Users'); Admin = $true }    # Uses computer name
    STAFF = @{ Name = ''; Groups = @('Users'); Admin = $true }    # Uses computer name
  }

  # Examples of hardcoded usernames (uncomment and modify as needed):
  # LocalUsers = @{
  #     POS   = @{ Name = ''; Groups = @('Users'); Admin = $true }           # Dynamic
  #     MGR   = @{ Name = 'HMGManager'; Groups = @('Users'); Admin = $true } # Hardcoded
  #     CAM   = @{ Name = ''; Groups = @('Users'); Admin = $true }           # Dynamic
  #     STAFF = @{ Name = 'HMGStaff'; Groups = @('Users'); Admin = $true }   # Hardcoded
  # }

  # Password Configuration
  # Option 1: Plain-text passwords (NOT RECOMMENDED - temporary only)
  # LocalUsersPasswords  = @{
  #     POS   = @{ Pass = 'password1' }
  #     MGR   = @{ Pass = 'password2' }
  #     CAM   = @{ Pass = 'password3' }
  #     STAFF = @{ Pass = 'password4' }
  # }

  # Option 2: Encrypted passwords (RECOMMENDED)
  # Use security\Protect-HMGPasswords.ps1 to create the blob file
  PasswordMode          = 'Encrypted'  # Options: 'PlainText' or 'Encrypted'
  EncryptedPasswordFile = '.\vault\blobs\vault.blob'

  # Fallback plain-text passwords (used only if PasswordMode = 'PlainText')
  LocalUsersPasswords   = @{
    POS   = @{ Pass = '' }  # Set password here if using PlainText mode
    MGR   = @{ Pass = '' }  # Set password here if using PlainText mode
    CAM   = @{ Pass = '' }  # Set password here if using PlainText mode
    STAFF = @{ Pass = '' }  # Set password here if using PlainText mode
  }

  Autologon             = @{
    POS   = @{
      Enable   = $true
      User     = ''           # If empty, uses sanitized computer name
      Domain   = ''           # If empty, uses local computer name
      ToolPath = 'C:\bin\deployment\global\tools\Autologon64.exe'  # Found in tools folder
    }
    CAM   = @{
      Enable   = $true
      User     = ''           # If empty, uses sanitized computer name
      Domain   = ''           # If empty, uses local computer name
      ToolPath = 'C:\bin\deployment\global\tools\Autologon64.exe'
    }
    MGR   = @{
      Enable   = $false
      ToolPath = 'C:\bin\deployment\global\tools\Autologon64.exe'
    }
    STAFF = @{
      Enable   = $false
      ToolPath = 'C:\bin\deployment\global\tools\Autologon64.exe'
    }
  }

  Firewall              = @{
    POS   = @{
      Rules = @(
        @{
          Name      = 'CP TCP Inbound'
          Protocol  = 'TCP'
          LocalPort = '51968-51970'
          Direction = 'Inbound'
          Profile   = 'Any'
          Group     = 'CounterPoint Offline Ticketing'
        },
        @{
          Name      = 'CP TCP Outbound'
          Protocol  = 'TCP'
          LocalPort = '51968-51970'
          Direction = 'Outbound'
          Profile   = 'Any'
          Group     = 'CounterPoint Offline Ticketing'
        },
        @{
          Name      = 'CP UDP Inbound'
          Protocol  = 'UDP'
          LocalPort = '51968-51970'
          Direction = 'Inbound'
          Profile   = 'Any'
          Group     = 'CounterPoint Offline Ticketing'
        },
        @{
          Name      = 'CP UDP Outbound'
          Protocol  = 'UDP'
          LocalPort = '51968-51970'
          Direction = 'Outbound'
          Profile   = 'Any'
          Group     = 'CounterPoint Offline Ticketing'
        },
        @{
          Name      = 'SQL TCP Inbound'
          Protocol  = 'TCP'
          LocalPort = '1433-1434'
          Direction = 'Inbound'
          Profile   = 'Any'
          Group     = 'SQL Server'
        },
        @{
          Name      = 'SQL TCP Outbound'
          Protocol  = 'TCP'
          LocalPort = '1433-1434'
          Direction = 'Outbound'
          Profile   = 'Any'
          Group     = 'SQL Server'
        },
        @{
          Name      = 'SQL UDP Inbound'
          Protocol  = 'UDP'
          LocalPort = '1433-1434'
          Direction = 'Inbound'
          Profile   = 'Any'
          Group     = 'SQL Server'
        },
        @{
          Name      = 'SQL UDP Outbound'
          Protocol  = 'UDP'
          LocalPort = '1433-1434'
          Direction = 'Outbound'
          Profile   = 'Any'
          Group     = 'SQL Server'
        }
      )
    }
    MGR   = @{ Rules = @() }
    CAM   = @{ Rules = @() }
    STAFF = @{ Rules = @() }
  }

  # ---- App install/uninstall switches (centralized) ----

  Chrome                = @{
    Msi       = 'googlechromestandaloneenterprise64.msi'
    Arguments = '/qn /norestart'
    Roles     = @('POS', 'MGR', 'CAM', 'STAFF')  # who should install Chrome
  }

  Axis                  = @{
    ClientMsi = 'AXISCameraStationProClientSetup.msi'
    Arguments = '/qn /norestart'
    Roles     = @('CAM')                         # CAM only by default
  }

  # Additional discovered installers (optional - enable as needed)
  GlobalProtect         = @{
    Msi       = 'GlobalProtect64.msi'
    Arguments = '/qn /norestart'
    Roles     = @()  # Set to @('MGR', 'STAFF') if VPN needed for those roles
    Enabled   = $false
  }

  StagingAgent          = @{
    Msi       = 'pw_staging_agent.msi'
    Arguments = '/qn /norestart'
    Roles     = @()  # Set roles as needed
    Enabled   = $false
  }

  TimeZone              = @{
    Id = 'Eastern Standard Time'
  }

  MemoryIntegrity       = @{
    POS   = 'Disable'   # options: 'Disable' | 'Leave'
    MGR   = 'Leave'
    CAM   = 'Leave'
    STAFF = 'Leave'
  }

  # Reboot behavior during setup
  # Options: 'Always' - Reboot at every checkpoint
  #          'Check'  - Only reboot when Windows requires it (default/recommended)
  #          'Never'  - Skip all reboots (for testing/troubleshooting)
  RebootMode            = 'Check'

  # POS-specific installation paths
  POS                   = @{
    Installers = @{
      DeskCam                = 'C:\bin\deployment\pos\files\deskCameraInstaller'
      SQLServer              = 'C:\bin\deployment\pos\files\sql\MicrosoftSqlServer2019ExpressAdvanced'
      SSMS                   = 'C:\bin\deployment\pos\files\sql\MicrosoftSqlServerManagementStudio18_8'
      CounterPoint           = 'C:\bin\deployment\pos\files\counterpoint'
      CounterPointSQLPrereqs = 'C:\bin\deployment\pos\files\counterpoint\prerequisites'
      DotNetFramework35Cab   = 'C:\bin\deployment\pos\files\Microsoft-Windows-NetFx3-OnDemand-Package-31bf3856ad364e35-amd64.cab'
    }
    Scripts    = @{
      SQLConfig = 'C:\bin\deployment\pos\files\sql\SQLFacetsWithMemory.sql'
    }
    Deployment = @{
      DesktopShortcuts = 'C:\bin\deployment\pos\files\desktop-shortcuts'
      RDPFiles         = 'C:\bin\deployment\pos\files\counterpoint\rdp'
    }
    SQL        = @{
      # SQL Server configuration
      InstanceName      = 'SQLEXPRESS'
      ConfigFile        = 'ConfigurationFile.ini'  # Relative to SQLServer installer path
      UseConfigFile     = $true                     # Use INI file or command-line args
      CommandLineParams = @{
        ACTION                = 'Install'
        FEATURES              = 'SQLENGINE'
        INSTANCENAME          = 'SQLEXPRESS'
        SECURITYMODE          = 'SQL'
        SQLSVCACCOUNT         = 'NT AUTHORITY\SYSTEM'
        SQLSYSADMINACCOUNTS   = 'BUILTIN\Administrators'
        AGTSVCACCOUNT         = 'NT AUTHORITY\SYSTEM'
        TCPENABLED            = '1'
      }
    }
  }

  Office                = @{
    Install   = @{
      Roles      = @('MGR', 'STAFF')
      SourcePath = 'C:\bin\deployment\global\installers\Office'  # contains setup.exe + config.xml
      Xml        = 'config.xml'                       # Installs O365BusinessRetail
    }
    Uninstall = @{
      Roles      = @('POS', 'CAM')
      SourcePath = 'C:\bin\deployment\global\installers\Office'  # contains setup.exe + uninstall-all.xml
      Xml        = 'uninstall-all.xml'                # Removes all Office products
    }
  }
}
