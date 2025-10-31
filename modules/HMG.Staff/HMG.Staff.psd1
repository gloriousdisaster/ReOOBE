@{
  RootModule        = 'HMG.Staff.psm1'
  ModuleVersion     = '2.0.0'
  GUID              = '424fa38f-1201-4e72-bd5c-b6ab6ef17caf'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  PowerShellVersion = '5.1'
  Description       = 'Administrative staff workstation configuration module'
  RequiredModules   = @(
    @{ModuleName = 'HMG.Core'; ModuleVersion = '2.0.0' }
  )
  FunctionsToExport = '*'
  AliasesToExport   = @()
  CmdletsToExport   = @()
}
