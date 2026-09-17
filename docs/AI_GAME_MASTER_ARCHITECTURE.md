# AI Game Master Core Architecture

## Principle
**AI changes temporary world state, not the locked game engine.**

## Flow
1. Godot records compact gameplay events locally to `waypoint_ai_gm_telemetry.jsonl`.
2. Player comments remain in `waypoint_ai_gm_feedback.jsonl`.
3. The nightly Python runner derives a deterministic, non-sensitive player profile.
4. Gemini receives only the compact save snapshot, aggregate profile, recent feedback, and previous Night Watch state.
5. Gemini returns schema-constrained JSON.
6. Python clamps and validates it, then writes `waypoint_ai_gm_inbox.json`.
7. On launch, Godot validates the inbox again, applies small rewards, stores a temporary world state, and presents the Night Watch message.
8. Daily challenge progress is tracked locally by Godot.
9. Development proposals are written to `waypoint_ai_gm_backlog.json`; no proposal edits source automatically.

## Temporary adaptive controls
- Featured route: one route ID from the existing route catalog.
- Difficulty offset: -1, 0, or +1 only.
- Lifetime: 1–3 game sessions.
- Challenge type: allowlisted only.
- Reward caps are enforced both by Python and Godot.

## Automatic difficulty guard
Even if the model asks for +1 difficulty, Python forces it back to 0 when telemetry is too sparse, recent route completion is under 50%, or recent damage is high. This makes adaptation conservative by default.

## Files in the Godot user-data directory
- `waypoint_ai_gm_telemetry.jsonl` — raw compact gameplay events
- `waypoint_ai_gm_player_profile.json` — deterministic aggregate profile
- `waypoint_ai_gm_feedback.jsonl` — player comments
- `waypoint_ai_gm_inbox.json` — next one-shot update
- `waypoint_ai_gm_world_state.json` — active featured route / difficulty / challenge
- `waypoint_ai_gm_history.jsonl` — Night Watch history
- `waypoint_ai_gm_backlog.json` — review-only development proposals
- `waypoint_ai_gm_nightwatch_state.json` — scheduler duplicate protection
