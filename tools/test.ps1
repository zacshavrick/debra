# Imports assets and runs the headless smoke test. Exit code 0 = pass.
# Usage: powershell -ExecutionPolicy Bypass -File tools/test.ps1
# --quit-after is only a hang guard; a run cut off by it must not count as a
# pass, so success requires the "SMOKE TEST PASSED" line.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_godot.ps1"
# Godot prints warnings on stderr; in PowerShell 5.1 those become error records,
# which must not abort the run. Pass/fail is decided by the PASSED line below.
$ErrorActionPreference = 'Continue'
& $Godot --headless --path $Project --import 2>&1 | Out-Null
$out = & $Godot --headless --path $Project --quit-after 90000 res://tests/smoke_test.tscn 2>&1 |
    ForEach-Object { "$_" } | Where-Object { $_ -notmatch '^\[' }
$out
if ($LASTEXITCODE -ne 0 -or -not ($out -match 'SMOKE TEST PASSED')) {
    Write-Host "Smoke test did not pass (failed, crashed or timed out)."
    exit 1
}
exit 0
