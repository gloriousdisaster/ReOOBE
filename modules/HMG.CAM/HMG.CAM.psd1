@{
  RootModule        = 'HMG.CAM.psm1'
  ModuleVersion     = '0.1.0'
  GUID              = 'e5ede9ea-71f4-4a83-9f47-5e57de72894c'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  PowerShellVersion = '5.1'
  Description       = 'HMG.CAM module'
  RequiredModules   = @(
    @{ModuleName = 'HMG.Core'; ModuleVersion = '2.0.0' }
  )
  FunctionsToExport = '*'
  AliasesToExport   = @()
  CmdletsToExport   = @()
}
