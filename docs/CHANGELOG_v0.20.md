# Waypoint: Cube Odyssey v0.20 — AI Game Master Core

## Locked-baseline AI architecture
- v0.19 gameplay is recorded as the locked baseline.
- Added append-only local gameplay telemetry (`waypoint_ai_gm_telemetry.jsonl`).
- Added deterministic player-profile generation before each Gemini call.
- Added a persistent developer backlog that is never auto-applied to source.

## Night Watch world state
- Night Watch output schema upgraded to v2.
- AI may feature one route for 1–3 sessions.
- AI difficulty adaptation is clamped to -1 / 0 / +1 and expires automatically.
- Additional local safety prevents difficulty increases on sparse telemetry, low completion, or high recent damage.
- Route previews identify the current Night Watch featured road.

## Daily challenges
- Allowlisted challenge types: route completion, featured-route completion, fishing catch, Elite defeat, obstacle jump.
- Challenge targets are capped at 1–3.
- Challenge rewards are locally clamped and applied by Godot, not by the external AI runner.

## Telemetry coverage
- Session start/pause/end
- Route preview and selection
- Walking/jumping and obstacle vaults
- Enemy/Elite encounters
- Route completion
- Fishing outcomes
- Cosmetic purchases/equips
- Player feedback submission

## Tooling
- `Test-NightWatch-Offline.ps1` validates the full local pipeline without an API call.
- `Inspect-AI-GameMaster.ps1` displays the generated profile, world state, backlog, and Night Watch state.
