param(
    [string]$DataDir = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Runner = Join-Path $PSScriptRoot "nightly_gamemaster.py"

if (-not $DataDir) {
    $GodotRoot = Join-Path $env:APPDATA "Godot\app_userdata"
    if (-not (Test-Path $GodotRoot)) {
        throw "Godot user-data folder was not found: $GodotRoot"
    }
    $save = Get-ChildItem -Path $GodotRoot -Filter "waypoint_save_v1.json" -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $save) {
        throw "Could not locate waypoint_save_v1.json. Run the game and save once first."
    }
    $DataDir = $save.Directory.FullName
}

$Python = (Get-Command python -ErrorAction Stop).Source
$argsList = @($Runner, "--data-dir", $DataDir)
if ($Force) { $argsList += "--force" }

Write-Host "Waypoint Night Watch"
Write-Host "Data:  $DataDir"
Write-Host "Model: gemini-3.5-flash-lite"
& $Python @argsList
exit $LASTEXITCODE
