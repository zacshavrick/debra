# Installs the pinned Godot editor + export templates into .tools/godot (self-contained mode).
# Usage:  powershell -ExecutionPolicy Bypass -File tools/setup-godot.ps1 [-SkipTemplates]
param([switch]$SkipTemplates)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root     = Split-Path -Parent $PSScriptRoot
$Version  = (Get-Content (Join-Path $Root 'GODOT_VERSION') -Raw).Trim()   # e.g. 4.7.2
$Tag      = "$Version-stable"
$Base     = "https://github.com/godotengine/godot/releases/download/$Tag"
$GodotDir = Join-Path $Root '.tools/godot'
$Exe      = Join-Path $GodotDir "Godot_v${Tag}_win64_console.exe"
New-Item -ItemType Directory -Force $GodotDir | Out-Null

if (-not (Test-Path $Exe)) {
    $zip = Join-Path $GodotDir 'godot.zip'
    Write-Host "Downloading Godot $Tag ..."
    Invoke-WebRequest "$Base/Godot_v${Tag}_win64.exe.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $GodotDir -Force
    Remove-Item $zip
}
# Self-contained mode: editor settings + export templates live in .tools/godot/editor_data
New-Item -ItemType File -Force (Join-Path $GodotDir '._sc_') | Out-Null

$TplDir = Join-Path $GodotDir "editor_data/export_templates/$Version.stable"
if (-not $SkipTemplates -and -not (Test-Path (Join-Path $TplDir 'version.txt'))) {
    $tpz = Join-Path $GodotDir 'templates.zip'   # .tpz is a zip; Expand-Archive wants the extension
    if (-not (Test-Path $tpz)) {
        Write-Host "Downloading export templates (~1.3 GB) ..."
        Invoke-WebRequest "$Base/Godot_v${Tag}_export_templates.tpz" -OutFile $tpz
    }
    $tmp = Join-Path $GodotDir 'tpl_tmp'
    Expand-Archive $tpz -DestinationPath $tmp -Force   # contains a templates/ folder
    New-Item -ItemType Directory -Force $TplDir | Out-Null
    Move-Item (Join-Path $tmp 'templates/*') $TplDir -Force
    Remove-Item $tmp -Recurse -Force
    Remove-Item $tpz
}
Write-Host "Godot ready: $Exe"
