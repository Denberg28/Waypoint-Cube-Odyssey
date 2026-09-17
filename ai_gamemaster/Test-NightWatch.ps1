param([string]$DataDir = "")
& (Join-Path $PSScriptRoot "Run-Nightly-GameMaster.ps1") -DataDir $DataDir -Force
