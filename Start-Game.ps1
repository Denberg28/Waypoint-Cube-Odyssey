param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $GodotPath = $command.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Pass the path to your Godot 4 executable: .\Start-Game.ps1 -GodotPath "C:\Tools\Godot\Godot.exe". You can also import project.godot in the editor and press F5.'
}
& $GodotPath --path $PSScriptRoot
