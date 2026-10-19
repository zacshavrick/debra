# Exports release builds into builds/.
#   builds/windows/Debra.exe   single-file exe (pck embedded)
#   builds/web/index.html         HTML5 / mobile web (PWA, no threads)
# Usage: powershell -ExecutionPolicy Bypass -File tools/build.ps1 [-Target all|windows|web] [-Debug]
param([ValidateSet('all', 'windows', 'web')][string]$Target = 'all', [switch]$Debug)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_godot.ps1"
$mode = if ($Debug) { '--export-debug' } else { '--export-release' }
& $Godot --headless --path $Project --import 2>&1 | Out-Null
$presets = @{ windows = @('Windows', 'builds/windows/Debra.exe'); web = @('Web', 'builds/web/index.html') }
foreach ($key in $presets.Keys) {
    if ($Target -ne 'all' -and $Target -ne $key) { continue }
    $name, $out = $presets[$key]
    $outPath = Join-Path $Root $out
    New-Item -ItemType Directory -Force (Split-Path $outPath) | Out-Null
    # Remove the old build first: if the game is still running, the exe is locked and
    # the export would silently keep the OLD exe. Fail loudly instead.
    if (Test-Path $outPath) {
        try { Remove-Item $outPath -Force -ErrorAction Stop }
        catch { throw "Cannot replace $out - close the running game (Debra.exe) and build again." }
    }
    Write-Host "Exporting $name -> $out"
    & $Godot --headless --path $Project $mode $name $outPath 2>&1 | Where-Object { $_ -match 'ERROR|WARNING' }
    if (-not (Test-Path $outPath)) { throw "Export failed: $name" }
}
Write-Host "Done. Web: node tools/serve-web.mjs  ->  http://localhost:8060"
