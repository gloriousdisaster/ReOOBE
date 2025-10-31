#requires -version 5.1
<#
.SYNOPSIS
    HMG UI Module - Modern visual UI components for the HMG automation framework

.DESCRIPTION
    This module handles all UI rendering including:
    - ASCII art borders and headers with gradients
    - Animated progress indicators and spinners (flicker-free)
    - Enhanced status displays with badges
    - Interactive menu rendering
    - Dynamic color theming
    - OOBE wizard functionality with animations
    - Particle effects and transitions
    - Width-aware, PS5/PS7 compatible rendering with Unicode fallbacks

.AUTHOR
    Joshua Dore

.DATE
    October 2025

.VERSION
    2.6.0 - PS5/7 hardening, width-aware, flicker fixes, emoji-free
#>

# --------------------------------------------------------------------------------------
# Module variables (themes and spinners)
# --------------------------------------------------------------------------------------

# Initialize console colors on module load
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'White'
[Console]::BackgroundColor = [ConsoleColor]::Black
[Console]::ForegroundColor = [ConsoleColor]::White

$script:UITheme = @{
  Border        = 'Cyan'
  Header        = 'White'
  MenuTitle     = 'Yellow'
  MenuItem      = 'White'
  MenuSelection = 'Green'
  DevItem       = 'Magenta'
  Warning       = 'Yellow'
  Error         = 'Red'
  Success       = 'Green'
  Info          = 'Gray'
  Footer        = 'DarkGray'
  Accent1       = 'DarkCyan'
  Accent2       = 'DarkMagenta'
  Gradient      = @('DarkCyan', 'Cyan', 'White')
}

# Modern spinner characters (Unicode first; ASCII fallback provided in code)
$script:Spinners = @{
  Dots   = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
  Line   = @('|', '/', '-', '\')
  Box    = @('◰', '◳', '◲', '◱')
  Circle = @('◐', '◓', '◑', '◒')
  Arrow  = @('←', '↖', '↑', '↗', '→', '↘', '↓', '↙')
  Bounce = @('⠁', '⠂', '⠄', '⡀', '⢀', '⠠', '⠐', '⠈')
  Pulse  = @('▁', '▂', '▃', '▄', '▅', '▆', '▇', '█', '▇', '▆', '▅', '▄', '▃', '▁')
}

# --------------------------------------------------------------------------------------
# UI Compatibility & Helpers (PS5/PS7 safe)
# --------------------------------------------------------------------------------------

if (-not $script:UISettings) {
  $script:UISettings = @{
    AsciiMode         = $false   # Auto flips to $true if Unicode seems risky
    AnimationsEnabled = $true
    MinWidth          = 60
    MaxWidth          = 120
  }
}

# PS5 typically needs explicit UTF-8 for proper glyphs; ignore failures silently
try {
  if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  }
}
catch { }

function Test-UnicodeSafe {
  try {
    $null = "✓".Length
    return $true
  }
  catch { return $false }
}

if (-not (Test-UnicodeSafe)) { $script:UISettings.AsciiMode = $true }

function Get-ConsoleWidth {
  try {
    $raw = $Host.UI.RawUI
    if ($null -ne $raw) {
      $w = [Math]::Max($raw.WindowSize.Width, $raw.BufferSize.Width)
      return [Math]::Max($script:UISettings.MinWidth, [Math]::Min($w, $script:UISettings.MaxWidth))
    }
  }
  catch { }
  return 80
}

function Resolve-Color {
  param([string]$Name, [ConsoleColor]$Default = [ConsoleColor]::Gray)
  try {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $Default }
    [ConsoleColor]::Parse([ConsoleColor], $Name, $true)
  }
  catch { $Default }
}

function Initialize-ConsoleColors {
  <#
  .SYNOPSIS
      Ensures console has black background and proper color settings
  #>
  try {
    $Host.UI.RawUI.BackgroundColor = 'Black'
    $Host.UI.RawUI.ForegroundColor = 'White'
    [Console]::BackgroundColor = [ConsoleColor]::Black
    [Console]::ForegroundColor = [ConsoleColor]::White
  }
  catch {
    # Fallback if $Host.UI.RawUI is not available
    try {
      [Console]::BackgroundColor = [ConsoleColor]::Black
      [Console]::ForegroundColor = [ConsoleColor]::White
    }
    catch { }
  }
}

function Clear-HostWithBlackBackground {
  <#
  .SYNOPSIS
      Clears the host and ensures black background is maintained
  #>
  Initialize-ConsoleColors
  Clear-Host
  # Re-apply after clear in case it resets
  Initialize-ConsoleColors
}

function Clear-ToLineEnd {
  param([int]$FromColumn = 0)
  try {
    $raw = $Host.UI.RawUI
    if ($null -ne $raw) {
      $width = Get-ConsoleWidth
      $left = $raw.CursorPosition.X
      $spaceN = [Math]::Max(0, $width - [Math]::Max($left, $FromColumn))
      if ($spaceN -gt 0) { Write-Host (' ' * $spaceN) -NoNewline }
      [Console]::SetCursorPosition($left, [Console]::CursorTop)
      return
    }
  }
  catch { }
  Write-Host (' ' * 20) -NoNewline
}

function Get-TextElementLength {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return 0 }
  try {
    $si = [System.Globalization.StringInfo]::new($Text)
    return $si.LengthInTextElements
  }
  catch { return $Text.Length }
}

function Get-GlyphSet {
  if ($script:UISettings.AsciiMode) {
    return @{
      Dot = '.'
      Check = '+'
      Cross = 'x'
      Info = 'i'
      Warning = '!'
      ArrowR = '>'
      Circle = 'o'
      Block = '#'
      Light = '-'
      PipeL = '|'
      PipeR = '|'
      H = '-'  # horizontal
      V = '|'  # vertical
      TL = '+'; TR = '+'; BL = '+'; BR = '+'
      TeeL = '|'; TeeR = '|'
    }
  }
  else {
    return @{
      Dot = '•'
      Check = '✓'
      Cross = '✗'
      Info = 'ℹ'
      Warning = '⚠'
      ArrowR = '▶'
      Circle = '●'
      Block = '█'
      Light = '░'
      PipeL = '▐'
      PipeR = '▌'
      H = '═'
      V = '║'
      TL = '╔'; TR = '╗'; BL = '╚'; BR = '╝'
      TeeL = '╠'; TeeR = '╣'
    }
  }
}

function Try-SetWindowTitle { param([string]$Text) try { if ($Host.UI.RawUI) { $Host.UI.RawUI.WindowTitle = $Text } } catch { } }

# --------------------------------------------------------------------------------------
# Functions
# --------------------------------------------------------------------------------------

function Set-WindowTitle {
  <#
  .SYNOPSIS
      Sets the PowerShell window title with HMG branding (host-safe)
  #>
  param(
    [string]$Title = "HMG RBCMS",
    [string]$Status = ""
  )
  $fullTitle = if ($Status) { "$Title - $Status" } else { $Title }
  Try-SetWindowTitle -Text $fullTitle
}

function Show-GradientText {
  <#
  .SYNOPSIS
      Displays text with a gradient color effect (width-aware)
  #>
  param(
    [string]$Text,
    [string[]]$Colors = @('DarkCyan', 'Cyan', 'White'),
    [switch]$Center
  )

  $chars = $Text.ToCharArray()
  $step = [Math]::Max(1, [Math]::Floor($chars.Count / [Math]::Max(1, $Colors.Count)))
  $width = Get-ConsoleWidth

  if ($Center) {
    $dispLen = Get-TextElementLength -Text $Text
    $pad = [Math]::Max(0, [Math]::Floor(($width - $dispLen) / 2))
    if ($pad -gt 0) { Write-Host (' ' * $pad) -NoNewline }
  }

  for ($i = 0; $i -lt $chars.Count; $i++) {
    $colorIndex = [Math]::Min([Math]::Floor($i / $step), $Colors.Count - 1)
    $fg = Resolve-Color -Name $Colors[$colorIndex] -Default ([ConsoleColor]::Gray)
    Write-Host $chars[$i] -NoNewline -ForegroundColor $fg
  }
  Write-Host ""
}


function Show-ModernSpinner {
  <#
  .SYNOPSIS
      Displays a modern animated spinner (flicker-free)
  #>
  param(
    [string]$Message = "Processing",
    [ValidateSet('Dots', 'Line', 'Box', 'Circle', 'Arrow', 'Bounce', 'Pulse')]
    [string]$Style = 'Dots',
    [int]$Frame = 0
  )

  if (-not $script:UISettings.AnimationsEnabled) {
    Write-Host ("`r  " + $Message) -NoNewline -ForegroundColor White
    Clear-ToLineEnd
    return
  }

  $spinner = $script:Spinners[$Style]
  if (-not $spinner) { $spinner = $script:Spinners['Dots'] }
  $glyphSet = Get-GlyphSet

  $ch = $spinner[$Frame % $spinner.Count]
  if ($script:UISettings.AsciiMode) {
    if ($Style -eq 'Line') { $ch = '\|/-'[$Frame % 4] }
    elseif ($Style -eq 'Dots') { $ch = $glyphSet.Dot }
    elseif ($Style -in @('Box', 'Circle', 'Bounce', 'Pulse', 'Arrow')) { $ch = $glyphSet.Circle }
  }

  $prefix = " $ch "
  $text = "$prefix$Message"

  Write-Host "`r" -NoNewline
  Write-Host $text -NoNewline -ForegroundColor White
  Clear-ToLineEnd
}

function Show-StatusBadge {
  <#
  .SYNOPSIS
      Displays a modern status badge
  #>
  param(
    [string]$Text,
    [ValidateSet('Active', 'Complete', 'Failed', 'Pending', 'Warning', 'Info')]
    [string]$Status = 'Info'
  )

  $glyph = Get-GlyphSet
  $badges = @{
    Active   = @{ Icon = $glyph.Circle; Color = 'Green'; BorderL = $glyph.PipeL; BorderR = $glyph.PipeR }
    Complete = @{ Icon = $glyph.Check; Color = 'Green'; BorderL = $glyph.PipeL; BorderR = $glyph.PipeR }
    Failed   = @{ Icon = $glyph.Cross; Color = 'Red'; BorderL = $glyph.PipeL; BorderR = $glyph.PipeR }
    Pending  = @{ Icon = $glyph.Circle; Color = 'Yellow'; BorderL = $glyph.PipeL; BorderR = $glyph.PipeR }
    Warning  = @{ Icon = $glyph.Warning; Color = 'Yellow'; BorderL = $glyph.PipeL; BorderR = $glyph.PipeR }
    Info     = @{ Icon = $glyph.Info; Color = 'Cyan'; BorderL = $glyph.PipeL; BorderR = $glyph.PipeR }
  }

  $b = $badges[$Status]
  Write-Host " " -NoNewline
  Write-Host $b.BorderL -NoNewline -ForegroundColor (Resolve-Color $b.Color)
  Write-Host " $($b.Icon) " -NoNewline -ForegroundColor (Resolve-Color $b.Color)
  Write-Host "$Text " -NoNewline -ForegroundColor White
  Write-Host $b.BorderR -ForegroundColor (Resolve-Color $b.Color)
}

function Show-ModernProgressBar {
  <#
  .SYNOPSIS
      Displays a modern animated progress bar with gradient effect (width-aware)
  #>
  param(
    [int]$Percent,
    [int]$Width = 40,
    [string]$Label = ""
  )

  $Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
  $filled = [Math]::Floor($Percent / 100 * $Width)
  $empty = $Width - $filled
  $glyph = Get-GlyphSet

  Write-Host " " -NoNewline
  Write-Host $glyph.PipeL -NoNewline -ForegroundColor (Resolve-Color 'Cyan')

  for ($i = 0; $i -lt $filled; $i++) {
    $color = if ($i -lt $filled * 0.3) { 'DarkCyan' } elseif ($i -lt $filled * 0.7) { 'Cyan' } else { 'White' }
    Write-Host $glyph.Block -NoNewline -ForegroundColor (Resolve-Color $color)
  }

  if ($empty -gt 0) {
    Write-Host ($glyph.Light * $empty) -NoNewline -ForegroundColor (Resolve-Color 'DarkGray')
  }

  Write-Host $glyph.PipeR -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
  Write-Host " $Percent% " -NoNewline -ForegroundColor White

  if ($Label) {
    Write-Host "- $Label" -ForegroundColor (Resolve-Color 'Gray')
  }
  else {
    Clear-ToLineEnd
    Write-Host ""
  }
}

function Show-PulseEffect {
  <#
  .SYNOPSIS
      Shows a pulsing text effect
  #>
  param(
    [string]$Text,
    [int]$Pulses = 3,
    [int]$Speed = 100
  )

  $colors = @('DarkGray', 'Gray', 'White', 'Cyan', 'White', 'Gray')
  for ($i = 0; $i -lt $Pulses; $i++) {
    foreach ($c in $colors) {
      Write-Host "`r$Text" -NoNewline -ForegroundColor (Resolve-Color $c)
      Start-Sleep -Milliseconds $Speed
    }
  }
  Write-Host ""
}

function Show-ParticleEffect {
  <#
  .SYNOPSIS
      Shows a simple particle/sparkle effect
  #>
  param(
    [int]$Count = 10,
    [int]$Speed = 50
  )

  $particles = @('·', '•', '*', '✦', '✧', '*')
  $colors = @('DarkCyan', 'Cyan', 'White', 'Yellow')
  if ($script:UISettings.AsciiMode) { $particles = @('.', '*', '.') }

  for ($i = 0; $i -lt $Count; $i++) {
    $particle = $particles[(Get-Random -Maximum $particles.Count)]
    $color = $colors[(Get-Random -Maximum $colors.Count)]
    $position = Get-Random -Minimum 10 -Maximum ([Math]::Max(20, (Get-ConsoleWidth) - 20))
    Write-Host (" " * $position) -NoNewline
    Write-Host $particle -ForegroundColor (Resolve-Color $color)
    Start-Sleep -Milliseconds $Speed
  }
}

function Get-BoxChar {
  <#
  .SYNOPSIS
      Returns box drawing characters for UI elements
  #>
  param(
    [ValidateSet('TopLeft', 'TopRight', 'BottomLeft', 'BottomRight',
      'Horizontal', 'Vertical', 'Cross', 'TeeLeft', 'TeeRight',
      'TeeTop', 'TeeBottom', 'HorizontalDouble', 'VerticalDouble',
      'TopLeftDouble', 'TopRightDouble', 'BottomLeftDouble', 'BottomRightDouble',
      'HorizontalThick', 'VerticalThick')]
    [string]$Type
  )

  $ascii = $script:UISettings.AsciiMode
  if ($ascii) {
    $chars = @{
      TopLeft = '+'; TopRight = '+'; BottomLeft = '+'; BottomRight = '+';
      Horizontal = '-'; Vertical = '|'; Cross = '+';
      TeeLeft = '|'; TeeRight = '|'; TeeTop = '+'; TeeBottom = '+';
      HorizontalDouble = '-'; VerticalDouble = '|';
      TopLeftDouble = '+'; TopRightDouble = '+'; BottomLeftDouble = '+'; BottomRightDouble = '+';
      HorizontalThick = '-'; VerticalThick = '|'
    }
  }
  else {
    $chars = @{
      TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝';
      Horizontal = '═'; Vertical = '║'; Cross = '╬';
      TeeLeft = '╠'; TeeRight = '╣'; TeeTop = '╦'; TeeBottom = '╩';
      HorizontalDouble = '═'; VerticalDouble = '║';
      TopLeftDouble = '╔'; TopRightDouble = '╗'; BottomLeftDouble = '╚'; BottomRightDouble = '╝';
      HorizontalThick = '━'; VerticalThick = '┃'
    }
  }
  return $chars[$Type]
}


function Show-HMGBanner {
  <#
  .SYNOPSIS
      Displays a compact left-aligned header box without stray bars
  #>
  param(
    [string]$Title = "HMG RBCMS - REimagined OOBE",
    [string]$SubTitle = "Role-Based Deployment System"
  )

  Clear-HostWithBlackBackground
  Set-WindowTitle -Title "HMG RBCMS" -Status $Title

  $width = 60   # adjust width as you like
  $g = Get-GlyphSet

  $top = $g.TL + ($g.H * ($width - 2)) + $g.TR
  $bot = $g.BL + ($g.H * ($width - 2)) + $g.BR

  Write-Host $top -ForegroundColor (Resolve-Color 'Cyan')

  # === Title line ===
  $tLen  = Get-TextElementLength -Text $Title
  $tPadL = [Math]::Max(0, [Math]::Floor(($width - 2 - $tLen) / 2))
  $tPadR = [Math]::Max(0,  $width - 2 - $tLen - $tPadL)

  Write-Host $g.V -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
  Write-Host (' ' * $tPadL) -NoNewline
  Write-Host $Title -NoNewline -ForegroundColor White
  if ($tPadR -gt 0) { Write-Host (' ' * $tPadR) -NoNewline }
  Write-Host $g.V -ForegroundColor (Resolve-Color 'Cyan')

  # === Subtitle line ===
  $sLen  = Get-TextElementLength -Text $SubTitle
  $sPadL = [Math]::Max(0, [Math]::Floor(($width - 2 - $sLen) / 2))
  $sPadR = [Math]::Max(0,  $width - 2 - $sLen - $sPadL)

  Write-Host $g.V -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
  if ($sPadL -gt 0) { Write-Host (' ' * $sPadL) -NoNewline }
  Write-Host $SubTitle -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
  if ($sPadR -gt 0) { Write-Host (' ' * $sPadR) -NoNewline }
  Write-Host $g.V -ForegroundColor (Resolve-Color 'Cyan')

  Write-Host $bot -ForegroundColor (Resolve-Color 'Cyan')
}


function Show-MenuSection {
  <#
  .SYNOPSIS
      Displays a menu section with modern formatting and proper alignment (width-aware)
  #>
  param(
    [string]$Title,
    [hashtable[]]$Items,
    [string]$Color = 'White'
  )

  $width = Get-ConsoleWidth
  $maxItemLength = 0
  foreach ($item in $Items) {
    $s = " [$($item.Key)] $($item.Text)"
    $len = Get-TextElementLength -Text $s
    if ($len -gt $maxItemLength) { $maxItemLength = $len }
  }

  $boxWidth = [Math]::Max([Math]::Min($maxItemLength + 6, $width - 4), 40)
  $bar = if ($script:UISettings.AsciiMode) { '-' } else { '─' }
  $tl = if ($script:UISettings.AsciiMode) { '+' } else { '┌' }
  $tr = if ($script:UISettings.AsciiMode) { '+' } else { '┐' }
  $bl = if ($script:UISettings.AsciiMode) { '+' } else { '└' }
  $br = if ($script:UISettings.AsciiMode) { '+' } else { '┘' }
  $v = if ($script:UISettings.AsciiMode) { '|' } else { '│' }

  if ($Title) {
    Write-Host ""
    $titleLen = Get-TextElementLength -Text $Title
    $dashCount = [Math]::Max(0, $boxWidth - $titleLen - 5)
    Write-Host " $tl─ " -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
    Write-Host $Title -NoNewline -ForegroundColor (Resolve-Color $script:UITheme.MenuTitle)
    Write-Host (" " + ($bar * $dashCount) + $tr) -ForegroundColor (Resolve-Color 'DarkCyan')
  }

  foreach ($item in $Items) {
    $key = $item.Key
    $text = $item.Text
    $itemColor = if ($item.Color) { $item.Color } else { $Color }

    $left = " $v "
    $middle = " [$key] $text"
    $contentLen = Get-TextElementLength -Text $middle
    $padding = [Math]::Max(0, $boxWidth - $contentLen - 3)

    Write-Host $left -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
    Write-Host " [$key] " -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
    Write-Host $text -NoNewline -ForegroundColor (Resolve-Color $itemColor)
    if ($padding -gt 0) { Write-Host (' ' * $padding) -NoNewline }
    Write-Host $v -ForegroundColor (Resolve-Color 'DarkCyan')
  }

  if ($Title) {
    Write-Host " $bl" -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
    Write-Host ($bar * ($boxWidth - 2)) -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
    Write-Host $br -ForegroundColor (Resolve-Color 'DarkCyan')
  }
}

function Show-Footer {
  <#
  .SYNOPSIS
      Displays a compact left-aligned footer box
  #>
  param([int]$Width)

  $width = 60   # match header width
  $g = Get-GlyphSet

  $now = Get-Date -Format 'MM/dd/yyyy HH:mm:ss'
  $mid = "$env:USERDOMAIN\$env:USERNAME@$env:COMPUTERNAME"

  $top = $g.TeeL + ($g.H * ($width - 2)) + $g.TeeR
  $bot = $g.BL + ($g.H * ($width - 2)) + $g.BR

  Write-Host $top -ForegroundColor (Resolve-Color $script:UITheme.Accent1)

  $left = " $now"
  $space = [Math]::Max(0, $width - 2 - (Get-TextElementLength $left) - (Get-TextElementLength $mid))

  Write-Host $g.V -NoNewline -ForegroundColor (Resolve-Color $script:UITheme.Border)
  Write-Host $left -NoNewline -ForegroundColor (Resolve-Color 'Gray')
  if ($space -gt 0) { Write-Host (' ' * $space) -NoNewline }
  Write-Host $mid -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
  Write-Host $g.V -ForegroundColor (Resolve-Color $script:UITheme.Border)

  Write-Host $bot -ForegroundColor (Resolve-Color $script:UITheme.Border)
}


function Show-Progress {
  <#
  .SYNOPSIS
      Displays a modern animated progress indicator
  #>
  param(
    [string]$Activity = "Processing",
    [int]$Step = 0,
    [int]$TotalSteps = 0
  )

  if ($TotalSteps -gt 0) {
    $percent = [Math]::Round(($Step / [Math]::Max(1, $TotalSteps)) * 100)
    Show-ModernSpinner -Message $Activity -Frame $Step -Style 'Dots'
    Write-Host " - " -NoNewline -ForegroundColor (Resolve-Color 'DarkGray')
    Show-ModernProgressBar -Percent $percent -Width 20
  }
  else {
    Show-ModernSpinner -Message $Activity -Frame $Step -Style 'Dots'
  }
}

function Show-TypewriterText {
  <#
  .SYNOPSIS
      Displays text with a smooth typewriter effect
  #>
  param(
    [string]$Text,
    [int]$Delay = 30,
    [string]$Color = 'White'
  )

  foreach ($char in $Text.ToCharArray()) {
    Write-Host $char -NoNewline -ForegroundColor (Resolve-Color $Color)
    Start-Sleep -Milliseconds $Delay
  }
  Write-Host ""
}

function Show-Alert {
  <#
  .SYNOPSIS
      Displays a modern alert box with icon and shadow effect
  #>
  param(
    [string]$Message,
    [ValidateSet('Info', 'Warning', 'Error', 'Success')]
    [string]$Type = 'Info'
  )

  $glyph = Get-GlyphSet
  $configs = @{
    Info    = @{ Icon = $glyph.Info; Color = 'Cyan'; BorderChar = $glyph.H }
    Warning = @{ Icon = $glyph.Warning; Color = 'Yellow'; BorderChar = $glyph.H }
    Error   = @{ Icon = $glyph.Cross; Color = 'Red'; BorderChar = $glyph.H }
    Success = @{ Icon = $glyph.Check; Color = 'Green'; BorderChar = $glyph.H }
  }

  $config = $configs[$Type]
  $width = [Math]::Max((Get-TextElementLength $Message) + 8, 40)

  Write-Host ""
  Write-Host (' ' + '╔' + ($config.BorderChar * ($width - 2)) + '╗') -ForegroundColor (Resolve-Color $config.Color)
  Write-Host (' ' + ($glyph.Light * ($width - 0))) -ForegroundColor (Resolve-Color 'DarkGray')

  $padded = " $($config.Icon)  $Message "
  $padLen = [Math]::Max(0, $width - 2 - (Get-TextElementLength $padded))
  $line = " ║$padded$([string]::new(' ', $padLen))║ "
  Write-Host $line -NoNewline -ForegroundColor (Resolve-Color $config.Color)
  Write-Host $glyph.Light -ForegroundColor (Resolve-Color 'DarkGray')

  Write-Host (' ' + '╚' + ($config.BorderChar * ($width - 2)) + '╝') -ForegroundColor (Resolve-Color $config.Color)
  Write-Host (' ' + ($glyph.Light * ($width - 0))) -ForegroundColor (Resolve-Color 'DarkGray')
  Write-Host ""
}

function Show-CountDown {
  <#
  .SYNOPSIS
      Shows a modern countdown timer with visual effects
  #>
  param(
    [int]$Seconds = 5,
    [string]$Message = "Starting in"
  )

  for ($i = $Seconds; $i -gt 0; $i--) {
    Write-Host "`r" -NoNewline
    Show-StatusBadge -Text "$Message $i seconds" -Status 'Pending'
    if ($i -le 3) {
      Start-Sleep -Milliseconds 200
      Write-Host "`r" -NoNewline
      Show-StatusBadge -Text "$Message $i seconds" -Status 'Warning'
      Start-Sleep -Milliseconds 800
    }
    else {
      Start-Sleep -Seconds 1
    }
  }

  Write-Host "`r$(' ' * 60)" -NoNewline
  Write-Host "`r"
}

function Get-MenuChoice {
  <#
  .SYNOPSIS
      Gets user menu choice with modern prompt
  #>
  param(
    [string]$Prompt = "Select option",
    [string[]]$ValidChoices,
    [switch]$AllowEscape
  )

  Write-Host ""
  Write-Host " > " -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
  Write-Host "$Prompt" -NoNewline -ForegroundColor (Resolve-Color 'Yellow')
  Write-Host ": " -NoNewline -ForegroundColor (Resolve-Color 'White')

  $choice = Read-Host

  if ($AllowEscape -and $choice -in @('q', 'Q', 'exit', 'quit')) { return 'QUIT' }

  if ($ValidChoices -and $choice -notin $ValidChoices) {
    Show-Alert -Message "Invalid selection: $choice" -Type Error
    Start-Sleep -Seconds 2
    return $null
  }

  return $choice
}

function Show-StepProgress {
  <#
  .SYNOPSIS
      Shows modern progress for multi-step operations
  #>
  param(
    [string]$StepName,
    [int]$CurrentStep,
    [int]$TotalSteps,
    [ValidateSet('Running', 'Complete', 'Failed', 'Skipped')]
    [string]$Status = 'Running'
  )

  $glyph = Get-GlyphSet
  $statusConfig = @{
    Running  = @{ Icon = $glyph.ArrowR; Color = 'Yellow'; Badge = 'Active' }
    Complete = @{ Icon = $glyph.Check; Color = 'Green'; Badge = 'Complete' }
    Failed   = @{ Icon = $glyph.Cross; Color = 'Red'; Badge = 'Failed' }
    Skipped  = @{ Icon = $glyph.Circle; Color = 'Gray'; Badge = 'Pending' }
  }

  $config = $statusConfig[$Status]
  $progressText = "[$CurrentStep/$TotalSteps]"

  Write-Host " $progressText " -NoNewline -ForegroundColor (Resolve-Color 'DarkGray')
  Write-Host "$($config.Icon) " -NoNewline -ForegroundColor (Resolve-Color $config.Color)
  Write-Host "$StepName" -ForegroundColor (Resolve-Color 'White')

  if ($Status -eq 'Running') {
    $percent = [Math]::Floor(($CurrentStep / [Math]::Max(1, $TotalSteps)) * 100)
    Write-Host "        " -NoNewline
    Show-ModernProgressBar -Percent $percent -Width 35
  }
  else {
    Write-Host ""
  }
}

function Show-SystemInfo {
  <#
  .SYNOPSIS
      Displays system information in a modern card layout (emoji-free)
  #>

  $os = Get-CimInstance Win32_OperatingSystem
  $comp = Get-CimInstance Win32_ComputerSystem
  $net = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1

  $info = @(
    @{Label = "Computer"; Value = $env:COMPUTERNAME },
    @{Label = "Domain"; Value = $env:USERDOMAIN },
    @{Label = "OS"; Value = $os.Caption },
    @{Label = "Memory"; Value = "$([math]::Round($comp.TotalPhysicalMemory / 1GB, 2)) GB" },
    @{Label = "IP"; Value = $net.IPAddress },
    @{Label = "User"; Value = $env:USERNAME }
  )

  $maxLabelLength = ($info | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
  # Ensure Get-ConsoleWidth is invoked and its numeric result is passed to [Math]::Max
  $width = [Math]::Min([Math]::Max(60, (Get-ConsoleWidth)), 100)
  $g = Get-GlyphSet

  Write-Host ""
  Write-Host (' ' + '╔' + ('═' * ($width - 2)) + '╗') -ForegroundColor (Resolve-Color 'Cyan')
  Write-Host (' ' + '║' + ' System Information'.PadRight($width - 2) + '║') -ForegroundColor (Resolve-Color 'Cyan')
  Write-Host (' ' + '╠' + ('═' * ($width - 2)) + '╣') -ForegroundColor (Resolve-Color 'Cyan')

  foreach ($item in $info) {
    $label = $item.Label.PadRight($maxLabelLength)
    $lineText = "$label : $($item.Value)"
    $pad = [Math]::Max(0, $width - 2 - (Get-TextElementLength $lineText))
    Write-Host " ║" -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
    Write-Host $label -NoNewline -ForegroundColor (Resolve-Color 'Gray')
    Write-Host " : " -NoNewline -ForegroundColor (Resolve-Color 'DarkGray')
    Write-Host $item.Value -NoNewline -ForegroundColor (Resolve-Color 'White')
    if ($pad -gt 0) { Write-Host (' ' * $pad) -NoNewline }
    Write-Host '║' -ForegroundColor (Resolve-Color 'Cyan')
  }

  Write-Host (' ' + '╚' + ('═' * ($width - 2)) + '╝') -ForegroundColor (Resolve-Color 'Cyan')
  Write-Host ""
}

function Show-AnimatedHeader {
  <#
  .SYNOPSIS
      Shows an animated header with modern fade and particle effects
  #>
  param(
    [string]$Text = "HMG Automation Framework",
    [string]$SubText = "Initializing..."
  )

  Clear-HostWithBlackBackground
  Show-ParticleEffect -Count 5 -Speed 30

  $colors = @('DarkGray', 'Gray', 'White', 'Cyan')
  foreach ($color in $colors) {
    Clear-HostWithBlackBackground
    Write-Host "`n`n"
    Show-GradientText -Text $Text -Colors @($color, 'Cyan') -Center
    $width = Get-ConsoleWidth
    $subPad = [math]::Floor(($width - (Get-TextElementLength $SubText)) / 2)
    if ($subPad -gt 0) { Write-Host (' ' * $subPad) -NoNewline }
    Write-Host $SubText -ForegroundColor (Resolve-Color 'DarkGray')
    Start-Sleep -Milliseconds 100
  }

  Show-PulseEffect -Text $Text -Pulses 1 -Speed 50
  Start-Sleep -Milliseconds 300
}

function Show-MainMenu {
  <#
  .SYNOPSIS
      Displays the modern main HMG setup menu
  #>

  Show-HMGBanner -Title "ReOOBE - System Deployment Manager" -SubTitle "Role-Based Configuration Management System"

  Write-Host ""
Write-Host "    Version " -ForegroundColor DarkGray -NoNewline
Write-Host "RC1.0.0.420.69" -ForegroundColor DarkGray -NoNewline
Write-Host " Glorious" -ForegroundColor Magenta -NoNewline
Write-Host "Disaster" -ForegroundColor Cyan -NoNewline


  Show-MenuSection -Title "System Setup Options" -Items @(
    @{Key = '1'; Text = 'Run OOBE (Out-of-Box Experience)'; Color = 'White' },
    @{Key = '2'; Text = 'Setup POS System'; Color = 'White' },
    @{Key = '3'; Text = 'Setup Manager Workstation'; Color = 'White' },
    @{Key = '4'; Text = 'Setup Camera System'; Color = 'White' },
    @{Key = '5'; Text = 'Setup Admin Workstation'; Color = 'White' }
  )


  # Write-Host ""
  # Show-MenuSection -Title "Development Tasks" -Items @(
  #   @{Key = '6'; Text = 'Validate Prerequisites Only'; Color = 'Gray' },
  #   @{Key = '7'; Text = 'Dry Run (WhatIf Mode)'; Color = 'Gray' },
  #   @{Key = '8'; Text = 'Resume from Specific Step'; Color = 'Gray' }
  #   @{Key = '9'; Text = 'Run Tests'; Color = 'Magenta' },
  #   @{Key = '0'; Text = 'View Logs'; Color = 'Magenta' },
  #   @{Key = 'C'; Text = 'Code Quality Check'; Color = 'Magenta' },
  #   @{Key = 'I'; Text = 'System Information'; Color = 'Magenta' }
  # )

  Write-Host ""
  Write-Host " " -NoNewline
  Show-StatusBadge -Text " [Q] Quit" -Status 'Failed'
 Write-Host ""
  Show-Footer
}

function Start-OOBE {
  <#
  .SYNOPSIS
      Runs the modern Out-of-Box Experience wizard

  .DESCRIPTION
      Provides a guided setup experience with:
      - Animated system role detection
      - Pre-flight validation with progress
      - Configuration summary
      - Automated setup execution

  .PARAMETER InvokeScriptPath
      Path to the Invoke-Setup.ps1 script
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$InvokeScriptPath
  )

  Show-AnimatedHeader -Text "HMG Out-of-Box Experience" -SubText "Welcome to System Setup"
  Start-Sleep -Milliseconds 400

  Clear-HostWithBlackBackground
  Show-HMGBanner -Title "Out-of-Box Experience" -SubTitle "Initial System Configuration"

  Write-Host ""
  Show-TypewriterText -Text "Welcome to the HMG System Setup Wizard!" -Color 'Cyan' -Delay 20
  Write-Host ""
  Show-TypewriterText -Text "This wizard will guide you through the initial configuration of your system." -Delay 15
  Write-Host ""
  Start-Sleep -Milliseconds 300

  # Step 1: Detect system type
  Write-Host ""
  Show-StatusBadge -Text "Step 1: System Detection" -Status 'Active'
  Write-Host ""

  for ($i = 1; $i -le 20; $i++) {
    Show-ModernSpinner -Message "Analyzing system configuration" -Frame $i -Style 'Dots'
    Start-Sleep -Milliseconds 80
  }
  Write-Host "`r$(' ' * 120)"

  $detectedRole = $null
  $hostname = $env:COMPUTERNAME

  if ($hostname -like "*POS*") { $detectedRole = "POS"; Show-StatusBadge -Text "Point of Sale system detected from hostname" -Status 'Complete' }
  elseif ($hostname -like "*MGR*" -or $hostname -like "*MANAGER*") { $detectedRole = "MGR"; Show-StatusBadge -Text "Manager workstation detected from hostname" -Status 'Complete' }
  elseif ($hostname -like "*CAM*" -or $hostname -like "*CAMERA*") { $detectedRole = "CAM"; Show-StatusBadge -Text "Camera system detected from hostname" -Status 'Complete' }
  elseif ($hostname -like "*ADMIN*") { $detectedRole = "ADMIN"; Show-StatusBadge -Text "Admin workstation detected from hostname" -Status 'Complete' }
  else { Show-StatusBadge -Text "Unable to auto-detect role" -Status 'Warning' }

  # Step 2: Role selection
  Write-Host ""
  Show-StatusBadge -Text "Step 2: Role Selection" -Status 'Active'
  Write-Host ""

  if ($detectedRole) {
    Write-Host " Detected role: " -NoNewline
    Show-StatusBadge -Text $detectedRole -Status 'Complete'
    Write-Host ""
    $accept = Get-MenuChoice -Prompt "Accept this role? (Y/n)"
    if ($accept -eq 'n') { $detectedRole = $null }
  }

  if (-not $detectedRole) {
    Write-Host ""
    Show-MenuSection -Title "Select System Role" -Items @(
      @{Key = '1'; Text = 'POS - Point of Sale Terminal'; Color = 'White' },
      @{Key = '2'; Text = 'MGR - Manager Workstation'; Color = 'White' },
      @{Key = '3'; Text = 'CAM - Camera System'; Color = 'White' },
      @{Key = '4'; Text = 'ADMIN - Administrative Workstation'; Color = 'White' }
    )

    $selection = Get-MenuChoice -Prompt "Select role" -ValidChoices @('1', '2', '3', '4')
    switch ($selection) {
      '1' { $detectedRole = 'POS' }
      '2' { $detectedRole = 'MGR' }
      '3' { $detectedRole = 'CAM' }
      '4' { $detectedRole = 'ADMIN' }
    }
  }

  if (-not $detectedRole) {
    Show-Alert -Message "No role selected. Exiting OOBE." -Type Error
    return
  }

  # Step 3: Pre-flight checks
  Write-Host ""
  Show-StatusBadge -Text "Step 3: Pre-Flight Validation" -Status 'Active'
  Write-Host ""

  $checks = @(
    "Checking network connectivity",
    "Validating installer files",
    "Checking disk space",
    "Verifying Windows version",
    "Checking administrative rights"
  )

  $i = 1
  foreach ($check in $checks) {
    Show-StepProgress -StepName $check -CurrentStep $i -TotalSteps $checks.Count -Status Running
    Start-Sleep -Milliseconds 500
    try { [Console]::SetCursorPosition(0, [Console]::CursorTop - 2) } catch { }
    Show-StepProgress -StepName $check -CurrentStep $i -TotalSteps $checks.Count -Status Complete
    $i++
  }

  # Step 4: Configuration summary
  Write-Host ""
  Show-StatusBadge -Text "Step 4: Configuration Summary" -Status 'Active'
  Write-Host ""

  $summaryBox = @"
   Role: $detectedRole
   Computer: $env:COMPUTERNAME
   Domain: $env:USERDOMAIN
   User: $env:USERNAME

   Actions to be performed:
   • Software package installation
   • System configuration
   • User account setup
   • Security policy application
   • Network configuration
"@

  Write-Host $summaryBox -ForegroundColor (Resolve-Color 'White')

  Write-Host ""
  Show-CountDown -Seconds 5 -Message "Starting configuration in"

  # Step 5: Execute
  Write-Host ""
  Show-StatusBadge -Text "Step 5: Applying Configuration" -Status 'Active'
  Write-Host ""

  Show-Alert -Message "Initiating $detectedRole configuration..." -Type Info

  & $InvokeScriptPath -Role $detectedRole

  # Completion
  Write-Host ""
  Show-ParticleEffect -Count 8 -Speed 40
  Show-Alert -Message "OOBE Complete! System configured as $detectedRole" -Type Success
  Show-PulseEffect -Text "Setup Successful!" -Pulses 2 -Speed 80

  Write-Host ""
  Write-Host "Press Enter to exit..." -ForegroundColor (Resolve-Color 'Gray')
  Read-Host
}

function Get-RoleSelection {
  <#
  .SYNOPSIS
      Modern role selection prompt
  #>

  Write-Host ""
  Show-MenuSection -Title "Select Role" -Items @(
    @{Key = '1'; Text = 'POS'; Color = 'White' },
    @{Key = '2'; Text = 'MGR'; Color = 'White' },
    @{Key = '3'; Text = 'CAM'; Color = 'White' },
    @{Key = '4'; Text = 'ADMIN'; Color = 'White' }
  )

  $selection = Get-MenuChoice -Prompt "Choice" -ValidChoices @('1', '2', '3', '4')
  switch ($selection) {
    '1' { return 'POS' }
    '2' { return 'MGR' }
    '3' { return 'CAM' }
    '4' { return 'ADMIN' }
    default { return $null }
  }
}

function Show-LogViewer {
  <#
  .SYNOPSIS
      Modern log file browser and viewer
  #>
  param(
    [string]$LogsPath = "C:\bin\HMG\logs"
  )

  Clear-HostWithBlackBackground
  Show-HMGBanner -Title "Log Viewer" -SubTitle "Recent system logs"

  if (Test-Path $LogsPath) {
    $logs = Get-ChildItem $LogsPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 10

    if ($logs) {
      Write-Host ""
      Show-MenuSection -Title "Recent Log Files" -Items @()

      $i = 1
      foreach ($log in $logs) {
        $size = [math]::Round($log.Length / 1KB, 2)
        Write-Host " │ " -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
        Write-Host " [$i] " -NoNewline -ForegroundColor (Resolve-Color 'Cyan')
        Write-Host "$($log.Name)" -NoNewline -ForegroundColor (Resolve-Color 'White')
        Write-Host " ($($log.LastWriteTime), $size KB)" -ForegroundColor (Resolve-Color 'Gray')
        $i++
      }
      Write-Host " └" -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
      Write-Host ("─" * 70) -NoNewline -ForegroundColor (Resolve-Color 'DarkCyan')
      Write-Host "┘" -ForegroundColor (Resolve-Color 'DarkCyan')

      Write-Host ""
      Write-Host " " -NoNewline
      Show-StatusBadge -Text "[B] Back to menu" -Status 'Info'

      $choice = Get-MenuChoice -Prompt "Select log to view"
      if ($choice -match '^\d+$' -and [int]$choice -le $logs.Count) {
        $selectedLog = $logs[[int]$choice - 1]
        Show-Alert -Message "Opening: $($selectedLog.Name)" -Type Info
        Start-Process notepad.exe $selectedLog.FullName | Out-Null
        return $true
      }
    }
    else {
      Show-Alert -Message "No log files found" -Type Warning
      Start-Sleep -Seconds 2
    }
  }
  else {
    Show-Alert -Message "Logs directory not found: $LogsPath" -Type Warning
    Start-Sleep -Seconds 2
  }

  return $false
}

function Show-SystemInfoScreen {
  <#
  .SYNOPSIS
      Modern system information display
  #>
  param(
    [string]$ScriptRoot
  )

  Clear-HostWithBlackBackground
  Show-HMGBanner -Title "System Information" -SubTitle "Current system status and configuration"

  Show-SystemInfo

  if ($ScriptRoot) {
    Write-Host ""

    $modules = @('HMG.Common', 'HMG.POS', 'HMG.MGR', 'HMG.CAM', 'HMG.Admin', 'HMG.UI')
    $configs = @('settings.psd1', 'roles.psd1')

    $allItems = @()
    foreach ($mod in $modules) {
      $modPath = Join-Path $ScriptRoot "modules\$mod\$mod.psd1"
      $exists = Test-Path $modPath
      $allItems += @{ Key = $mod; Text = "Module: $mod"; Color = if ($exists) { 'Green' }else { 'Red' } }
    }

    foreach ($config in $configs) {
      $configPath = Join-Path $ScriptRoot "config\$config"
      $exists = Test-Path $configPath
      $allItems += @{ Key = $config; Text = "Config: $config"; Color = if ($exists) { 'Green' }else { 'Red' } }
    }

    Show-MenuSection -Title "HMG Framework Status" -Items $allItems
  }

  Write-Host ""
  Write-Host "Press Enter to continue..." -ForegroundColor (Resolve-Color 'Gray')
  Read-Host
}

# --------------------------------------------------------------------------------------
# Module initialization
# --------------------------------------------------------------------------------------
# Initialize console colors when module loads
Initialize-ConsoleColors

# --------------------------------------------------------------------------------------
# Exported members
# --------------------------------------------------------------------------------------
Export-ModuleMember -Function @(
  'Initialize-ConsoleColors'
  'Clear-HostWithBlackBackground'
  'Set-WindowTitle'
  'Show-GradientText'
  'Show-ModernSpinner'
  'Show-StatusBadge'
  'Show-ModernProgressBar'
  'Show-PulseEffect'
  'Show-ParticleEffect'
  'Get-BoxChar'
  'Show-HMGBanner'
  'Show-MenuSection'
  'Show-Footer'
  'Show-Progress'
  'Show-TypewriterText'
  'Show-Alert'
  'Show-CountDown'
  'Get-MenuChoice'
  'Show-StepProgress'
  'Show-SystemInfo'
  'Show-AnimatedHeader'
  'Show-MainMenu'
  'Start-OOBE'
  'Get-RoleSelection'
  'Show-LogViewer'
  'Show-SystemInfoScreen'
)
