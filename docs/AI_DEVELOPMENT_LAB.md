# Waypoint AI Development Lab v0.21

## Trust boundary
- Godot v0.19 is the locked production baseline.
- `ai-development` is the continuously evolving development branch.
- Gemini may generate only validated world-state/content-pack JSON plus backlog reports.
- Gemini never edits Godot source automatically.
- Source-code improvements are reviewed manually before porting back to Godot.

## Automated loop
GitHub Actions schedules an hourly opportunity at minute 17. `AI_MAX_DAILY_CYCLES` limits paid calls; default 8/day, maximum supported by the guard is 24/day. Each successful cycle updates `runtime/ai_world_state.json`, creates a timestamped content pack, runs contract tests, then commits only validated generated state to `ai-development`.

## Streamlit
Deploy `streamlit_app.py` from the `ai-development` branch. It is a fast browser playtest lab, not a replacement for the Godot renderer. Streamlit session state is intentionally treated as ephemeral. Do not put API keys in source or `.streamlit/secrets.toml` under version control.

## ChatGPT Plus
ChatGPT Plus is used interactively for high-value engineering, design review, debugging, code review, and deliberate Godot ports. It is not callable as a GitHub Actions API credential. Automated OpenAI calls would require separately billed API access, so v0.21 uses Gemini for unattended automation.

## Heavy-lift handoff
Every AI cycle writes `reports/LATEST_HANDOFF.md`. This is the compact artifact to open/review with ChatGPT through the connected GitHub repository. Gemini remains the unattended high-volume worker; ChatGPT is the deliberate deep-review/engineering lane.
