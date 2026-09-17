# P1 — Route Discovery Ledger and Collection Milestones UI

Task ID: `codex-d4def2c0a053`
Base branch: `ai-development`

## Why this task exists
Explorers and collectors desire an in-game tracking interface for unique route items and completion rewards.

## Acceptance criteria
- Validate the request against current source before editing.
- Implement only if it remains relevant to the current build.
- Keep the change focused and reversible.
- Run relevant tests and report residual risk.

## Constraints
- Read AGENTS.md before implementation.
- Do not auto-merge.
- Do not modify unrelated gameplay/economy/content.
- Prefer deletion/simplification over adding compatibility layers when cleaning architecture.
- Preserve Godot 4.7.x Web compatibility.

## Validation
- `python -m pytest tests_ai_lab -q`
- Run the repository Godot Web export workflow for Godot/UI changes.

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
