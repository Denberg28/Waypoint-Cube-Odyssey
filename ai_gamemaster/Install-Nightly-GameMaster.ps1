param(
    [string]$At = "03:00"
)

$ErrorActionPreference = "Stop"
$TaskName = "Waypoint Cube Odyssey - Night Watch AI GM"
$RunScript = Join-Path $PSScriptRoot "Run-Nightly-GameMaster.ps1"
if (-not (Test-Path $RunScript)) { throw "Runner not found: $RunScript" }

try {
    $time = [DateTime]::ParseExact($At, "HH:mm", [Globalization.CultureInfo]::InvariantCulture)
}
catch {
    throw "Use -At HH:mm, for example -At 03:00"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RunScript`""
$trigger = New-ScheduledTaskTrigger -Daily -At $time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Minutes 20)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Generates a bounded Gemini Night Watch update for Waypoint." -Force | Out-Null
Write-Host "Installed scheduled task: $TaskName"
Write-Host "Runs daily at $At local time. StartWhenAvailable and WakeToRun are enabled."
Write-Host "If the PC is fully powered off, Windows will run it when the task next becomes available."
