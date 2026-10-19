# Renders preview screenshots into docs/screenshots (needs a GPU; opens a window briefly).
# Usage: powershell -ExecutionPolicy Bypass -File tools/screenshot.ps1 [-Quality low|high]
param([ValidateSet('low', 'high')][string]$Quality = 'high')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_godot.ps1"
$ErrorActionPreference = 'Continue'   # Godot warnings on stderr must not abort the run
$out = Join-Path $Root 'docs/screenshots'
& $Godot --fixed-fps 60 --resolution 1280x720 --path $Project --quit-after 9000 res://tests/screenshot.tscn -- $out "--quality=$Quality" 2>&1 |
    Where-Object { $_ -match 'saved|ERROR' }
