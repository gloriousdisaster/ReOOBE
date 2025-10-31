@{
  # Path Configuration for HMG RBCMS Framework
  # These paths are resolved dynamically based on the execution context

  # Deployment paths (after OOBE copies files)
  DeployedRoot     = 'C:\bin'
  DeployedRBCMS    = 'C:\bin\RBCMS'

  # Relative paths (resolved from RBCMS root)
  SecurityPath     = '.\security'
  PasswordBlobPath = '.\security\secrets\blobs\passwords.blob'
  ConfigPath       = '.\config'
  ModulesPath      = '.\modules'
  ScriptsPath      = '.\scripts'

  # Installation paths
  InstallersPath   = 'C:\bin\global\installers'
  ToolsPath        = 'C:\bin\global\tools'
  LogsPath         = 'C:\bin\HMG\logs'
}
