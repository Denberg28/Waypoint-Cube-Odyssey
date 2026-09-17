param([string]$DataDir = "")

$ErrorActionPreference = "Stop"
$Runner = Join-Path $PSScriptRoot "nightly_gamemaster.py"

if (-not $DataDir) {
    $GodotRoot = Join-Path $env:APPDATA "Godot\app_userdata"
    $save = Get-ChildItem -Path $GodotRoot -Filter "waypoint_save_v1.json" -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $save) { throw "Could not locate waypoint_save_v1.json. Run the game and save once first." }
    $DataDir = $save.Directory.FullName
}

$Python = (Get-Command python -ErrorAction Stop).Source
Write-Host "Waypoint AI GM Offline Dry Run"
Write-Host "Data: $DataDir"
& $Python $Runner --data-dir $DataDir --dry-run --force
exit $LASTEXITCODE
