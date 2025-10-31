@{
  # Module manifest for HMG.State
  RootModule           = 'HMG.State.psm1'
  ModuleVersion        = '1.1.0'
  GUID                 = 'e7c8d3f1-9a2b-4c5e-8f7a-3d2e1c9b8a7f'
  Author               = 'Joshua Dore'
  CompanyName          = 'Haven Management Group'
  Copyright            = '(c) 2025 Haven Management Group. All rights reserved.'
  Description          = 'State management module for HMG automation - handles reboot/resume functionality, progress tracking, and scheduled task management'
  PowerShellVersion    = '5.1'

  # Functions to export
  FunctionsToExport    = @(
    # State Management
    'Initialize-SetupState',
    'Save-SetupState',
    'Get-SetupState',
    'Update-StepProgress',
    'Complete-Setup',
    'Clear-SetupState',
    'Export-SetupState',

    # Progress Tracking
    'Get-Progress',
    'Get-ProgressSummary',

    # Reboot Management
    'Set-RebootRequired',
    'Test-RebootRequired',
    'Test-WindowsRebootRequired',
    'Invoke-RebootCheckpoint',
    'Invoke-SystemReboot',

    # Scheduled Tasks
    'New-ResumeTask',
    'Remove-ResumeTask',
    'Get-ResumeTaskUsername',

    # Resume Detection
    'Test-SetupResume'
  )

  # No cmdlets, variables, or aliases to export
  CmdletsToExport      = @()
  VariablesToExport    = @()
  AliasesToExport      = @()

  # Private data
  PrivateData          = @{
    PSData = @{
      Tags         = @('HMG', 'Automation', 'State', 'Reboot', 'Resume', 'Progress')
      ProjectUri   = 'https://github.com/hmg/hmg_RBCMS'
      ReleaseNotes = @'
Version 1.1.0
- Added reboot checkpoint system with three modes (Always/Check/Never)
- Implemented Test-WindowsRebootRequired for intelligent reboot detection
- Implemented Invoke-RebootCheckpoint for section-based reboot management
- Enhanced state tracking with RebootMode, CurrentSection, and checkpoint history
- Visual checkpoint UI with color-coded feedback
- Fixed scheduled task to run as logged-in user instead of SYSTEM for POS systems
- Added Get-ResumeTaskUsername helper to determine correct user from settings
- Updated New-ResumeTask, Set-RebootRequired, and Invoke-RebootCheckpoint to support user-specific tasks

Version 1.0.0
- Initial release
- JSON-based state persistence
- Automatic resume after reboot
- Scheduled task management
- Progress tracking with detailed reporting
- Support for multiple reboot cycles
'@
    }
  }

  # Default prefix
  DefaultCommandPrefix = ''
}
