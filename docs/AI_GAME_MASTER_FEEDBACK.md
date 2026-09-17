# AI Game Master Feedback Integration

Waypoint v0.10 includes a local-only feedback interface designed for a future AI Game Master service.

## Current behavior

The expanded right-side status rail contains an **AI Game Master Feedback** feed, multiline input, and **Send Feedback** button. No network call or AI inference occurs in this build.

Each submission is written to:

`user://waypoint_ai_gm_feedback.jsonl`

The file uses one JSON object per line and keeps a bounded local queue.

## Feedback record schema

Each queued record contains:

- `schema` — feedback schema version.
- `id` — local feedback identifier.
- `created_unix` — creation timestamp.
- `source` — `player_feedback`.
- `status` — currently `queued_local`.
- `message` — player feedback text.
- `context` — gameplay snapshot at the moment of submission.

The context currently includes game mode, class, route, environment, expedition stage, road row, HP, maximum HP, mana, attack, threat level, streak, Relic Meter, banked and carried coins, gems, fishing count, equipped items, and owned gear count.

## Intended future AI Game Master pipeline

1. Read locally queued feedback records.
2. Combine feedback with aggregated gameplay telemetry and version metadata.
3. Classify comments such as balance, difficulty, UI, pacing, audio, rewards, bugs, and content requests.
4. Detect repeated themes instead of reacting to one isolated comment.
5. Produce structured game-design recommendations with supporting evidence.
6. Convert approved recommendations into a developer-facing update plan or patch specification.
7. Mark processed feedback with an integration status in a future service layer.

The current game intentionally does **not** auto-edit itself or send player feedback externally. A future connector/service can be added behind this stable local schema without replacing the UI.
