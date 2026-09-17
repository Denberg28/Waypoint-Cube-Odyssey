# ChatGPT Plus Heavy-Lift Workflow

ChatGPT Plus is an interactive engineering/review lane, not the unattended API lane.

1. Gemini 3.5 Flash-Lite runs bounded cycles on `ai-development`.
2. The cycle updates `reports/LATEST_HANDOFF.md`, generated content, and the temporary AI world state.
3. Open ChatGPT and ask to inspect the Waypoint GitHub repository and latest handoff.
4. ChatGPT can use the connected GitHub repository to review code, inspect diffs/CI, diagnose failures, and prepare deliberate engineering changes.
5. Permanent Godot changes are reviewed before merge. The locked v0.19 baseline is never silently replaced.

ChatGPT Plus does not supply API credits to GitHub Actions. If a future unattended OpenAI lane is desired, it requires separately billed OpenAI API access.
