# Waypoint: Cube Odyssey v0.14 — AI Game Master Night Watch

- Locked v0.13.3 as the gameplay/UI baseline.
- Added Gemini 3.5 Flash-Lite Night Watch runner using the Gemini Interactions API.
- Added structured-output schema and a second local validation/clamping boundary.
- Added one-run-per-local-day protection and append-only AI Game Master history.
- Added Windows PowerShell scripts to securely store the Gemini key, test Night Watch, install a daily scheduled task, and uninstall it.
- Added a Godot bridge that consumes one AI inbox package exactly once on the next launch.
- Nightly automatic rewards are hard-capped at 25 banked coins, 2 gems, and 10% Relic Meter charge.
- AI development suggestions are recorded for later review; source-code autopatching is intentionally disabled.
