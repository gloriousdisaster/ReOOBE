@{
  RootModule        = 'HMG.MGR.psm1'
  ModuleVersion     = '0.1.0'
  GUID              = '4c8eb2ab-6b9d-44a1-aff3-72d9f8cca385'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  PowerShellVersion = '5.1'
  Description       = 'HMG.MGR module'
  RequiredModules   = @(
    @{ModuleName = 'HMG.Core'; ModuleVersion = '2.0.0' }
  )
  FunctionsToExport = '*'
  AliasesToExport   = @()
  CmdletsToExport   = @()
}
