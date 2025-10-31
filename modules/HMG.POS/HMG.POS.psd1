@{
  RootModule        = 'HMG.POS.psm1'
  ModuleVersion     = '4.4.2'
  GUID              = '68e18bd0-1021-4d76-81c0-7a2abe957f70'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  PowerShellVersion = '5.1'
  Description       = 'POS-specific configuration module with complete setup phases including DeskCam, SQL Server Express, SSMS, CounterPoint, and desktop deployment'
  RequiredModules   = @(
    @{ModuleName = 'HMG.Core'; ModuleVersion = '2.0.0' }
  )
  FunctionsToExport = @()  # Module only registers steps, no exported functions
  AliasesToExport   = @()
  CmdletsToExport   = @()
  PrivateData       = @{
    PSData = @{
      Tags         = @('POS', 'CounterPoint', 'SQL', 'Retail')
      ReleaseNotes = @'
v4.4.2 - Fixed SQL Server default instance (MSSQLSERVER) detection
- Now properly detects both MSSQLSERVER and SQLEXPRESS instances
- SQL script execution automatically detects correct instance  
- Prevents redundant SQL installation attempts
- Added multiple detection methods (service, registry, executable)
'@
    }
  }
}