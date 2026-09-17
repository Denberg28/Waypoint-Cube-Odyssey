$TaskName = "Waypoint Cube Odyssey - Night Watch AI GM"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Removed scheduled task: $TaskName"
