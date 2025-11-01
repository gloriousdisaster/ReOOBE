
# Auto-load module parts
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
Get-ChildItem -Path "$PSScriptRoot/Public"  -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

