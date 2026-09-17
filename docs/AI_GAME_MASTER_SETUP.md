# AI Game Master Setup — v0.20

## 1. Lock/reference
The AI branch is based on v0.19. Its SHA-256 is recorded in `BASELINE_LOCK.md`.

## 2. Store the Gemini key
Run:

```powershell
.\ai_gamemaster\Setup-Gemini-Key.ps1
```

Restart PowerShell after setting the user environment variable if needed.

## 3. Generate telemetry
Play normally. v0.20 records compact local telemetry automatically. No network request is made by the game.

## 4. Test without API cost

```powershell
.\ai_gamemaster\Test-NightWatch-Offline.ps1
```

This generates a sample v2 inbox, player profile, and backlog without contacting Gemini. Launch the game afterward to test inbox consumption.

## 5. Test Gemini manually

```powershell
.\ai_gamemaster\Test-NightWatch.ps1
```

## 6. Inspect AI state

```powershell
.\ai_gamemaster\Inspect-AI-GameMaster.ps1
```

## 7. Install nightly execution

```powershell
.\ai_gamemaster\Install-Nightly-GameMaster.ps1 -At "03:00"
```

Night Watch runs at most once per local calendar day unless forced.
