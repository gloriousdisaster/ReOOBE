@{
  # Module manifest for HMG.UI

  # Script module or binary module file associated with this manifest.
  RootModule           = 'HMG.UI.psm1'

  # Version number of this module.
  ModuleVersion        = '2.6.0'

  # Supported PSEditions
  CompatiblePSEditions = @('Desktop', 'Core')

  # ID used to uniquely identify this module
  GUID                 = 'a8d4b3c2-1f6e-4d5a-9c7b-2e8f4a3b5d7c'

  # Author of this module
  Author               = 'Joshua Dore'

  # Company or vendor of this module
  CompanyName          = 'Haven Management Group'

  # Copyright statement for this module
  Copyright            = '(c) 2025 Haven Management Group. All rights reserved.'

  # Description of the functionality provided by this module
  Description          = 'Modern UI components for HMG automation framework with gradient effects, animated spinners, status badges, and enhanced visual elements'

  # Minimum version of the PowerShell engine required by this module
  PowerShellVersion    = '5.1'

  # Functions to export from this module
  FunctionsToExport    = @(
    'Set-UIAnimationSpeed',
    'Test-ConsoleInteractive',
    'Set-WindowTitle',
    'Show-GradientText',
    'Show-ModernSpinner',
    'Show-StatusBadge',
    'Show-ModernProgressBar',
    'Show-PulseEffect',
    'Show-ParticleEffect',
    'Get-BoxChar',
    'Show-HMGBanner',
    'Show-MenuSection',
    'Show-Footer',
    'Show-Progress',
    'Show-TypewriterText',
    'Show-Alert',
    'Show-CountDown',
    'Get-MenuChoice',
    'Show-StepProgress',
    'Show-SystemInfo',
    'Show-AnimatedHeader',
    'Show-MainMenu',
    'Start-OOBE',
    'Get-RoleSelection',
    'Show-LogViewer',
    'Show-SystemInfoScreen'
  )

  # Cmdlets to export from this module
  CmdletsToExport      = @()

  # Variables to export from this module
  VariablesToExport    = @()

  # Aliases to export from this module
  AliasesToExport      = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess
  PrivateData          = @{
    PSData = @{
      Tags         = @('UI', 'Menu', 'Console', 'Display', 'Modern', 'Animated')
      ProjectUri   = 'https://github.com/HavenManagementGroup/HMG-Automation'
      ReleaseNotes = @'
Version 2.6.0 - Stability & Error Handling Improvements
- Added comprehensive error handling to all UI functions
- Fixed console compatibility issues (ISE, VS Code support)
- Removed emojis per coding standards
- Fixed alignment bugs in Show-MenuSection
- Added parameter validation throughout
- Improved Show-SystemInfo with error handling and fallbacks
- Fixed division by zero risk in Show-GradientText
- Added animation speed control (Set-UIAnimationSpeed)
- Added console capability testing (Test-ConsoleInteractive)
- Consistent width handling across functions
- Enhanced Get-MenuChoice with retry logic
- Added input validation to Start-OOBE
- Better error recovery and fallback outputs
- Width boundary handling in Show-Footer

Version 2.5.1 - Alignment Fix
- Fixed menu section alignment issues
- Improved border calculations for proper sizing
- Better padding and spacing in menu items
- Right borders now align correctly

Version 2.5.0 - Modern UI Update
- Added gradient text effects
- New modern spinner styles (Dots, Circle, Pulse, etc.)
- Status badges with icons
- Enhanced progress bars with gradient fill
- Pulse and particle effects
- Window title management
- Improved menu sections with modern borders
- Enhanced alert boxes with shadows
- Better color theming throughout
'@
    }
  }
}
