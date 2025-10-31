@{
  RootModule        = 'HMG.Logging.psm1'
  ModuleVersion     = '1.0.0'
  GUID              = 'e8f7d6c5-b4a3-4c2d-9e1f-0a9b8c7d6e5f'
  Author            = 'Joshua Dore'
  CompanyName       = 'Haven Management Group'
  Copyright         = '(c) 2025 Haven Management Group. All rights reserved.'
  Description       = 'Comprehensive logging module for HMG RBCMS framework with timestamped entries, multiple output formats, and structured logging.'
  PowerShellVersion = '5.1'

  FunctionsToExport = @(
    'Initialize-HMGLog',
    'Write-HMGLog',
    'Write-HMGDebug',
    'Write-HMGInfo',
    'Write-HMGSuccess',
    'Write-HMGWarning',
    'Write-HMGError',
    'Write-HMGCritical',
    'Close-HMGLog',
    'Get-HMGLogFile',
    'Get-HMGLogLevel',
    'Set-HMGLogLevel',
    'Write-HMGStructuredLog',
    'Start-HMGLogSection',
    'Stop-HMGLogSection',
    'Write-HMGLogSeparator',
    'Get-HMGLogStatistics'
  )

  CmdletsToExport   = @()
  VariablesToExport = @()
  AliasesToExport   = @()

  PrivateData       = @{
    PSData = @{
      Tags         = @('HMG', 'Logging', 'RBCMS', 'Automation')
      ProjectUri   = 'https://github.com/yourusername/hmg_RBCMS'
      ReleaseNotes = @"
Version 1.0.0 (2025-10-27)
- Initial release
- Timestamped log entries
- Multiple log levels (Debug, Info, Success, Warning, Error, Critical)
- Multiple output targets (Console, File, Structured)
- Buffered writes for performance
- Context tracking (component, step, role)
- WhatIf mode support
- Integration with HMG.Core framework
"@
    }
  }
}
