param([string]$DataDir = "")
$ErrorActionPreference = "Stop"
if (-not $DataDir) {
    $GodotRoot = Join-Path $env:APPDATA "Godot\app_userdata"
    $save = Get-ChildItem -Path $GodotRoot -Filter "waypoint_save_v1.json" -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $save) { throw "Could not locate Waypoint user data." }
    $DataDir = $save.Directory.FullName
}
Write-Host "`n=== AI GAME MASTER STATUS ===" -ForegroundColor Cyan
foreach ($name in @("waypoint_ai_gm_player_profile.json", "waypoint_ai_gm_world_state.json", "waypoint_ai_gm_backlog.json", "waypoint_ai_gm_nightwatch_state.json")) {
    $path = Join-Path $DataDir $name
    Write-Host "`n--- $name ---" -ForegroundColor Yellow
    if (Test-Path $path) { Get-Content $path -Raw } else { Write-Host "Not created yet." }
}
