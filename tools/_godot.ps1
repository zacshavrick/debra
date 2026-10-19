# Shared helper: resolves the Godot console binary. Dot-source from other tools.
# Order: $env:GODOT, then .tools/godot (installed by setup-godot.ps1).
$Root    = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $Root 'game'
$Version = (Get-Content (Join-Path $Root 'GODOT_VERSION') -Raw).Trim()
$Godot   = $env:GODOT
if (-not $Godot) { $Godot = Join-Path $Root ".tools/godot/Godot_v$Version-stable_win64_console.exe" }
if (-not (Test-Path $Godot)) {
    throw "Godot not found at $Godot. Run: powershell -ExecutionPolicy Bypass -File tools/setup-godot.ps1"
}
