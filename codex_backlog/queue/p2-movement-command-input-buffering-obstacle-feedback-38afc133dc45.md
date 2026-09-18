# P2 — Movement Command Input Buffering & Obstacle Feedback

Task ID: `codex-38afc133dc45`
Base branch: `ai-development`
Category: `accessibility`

## Why this task exists
Edge-case telemetry shows players frequently attempt to keep walking into barriers before realizing a jump is required.

## Acceptance criteria
- Add input validation so that walking into an active hazard triggers an immediate contextual hint or buffers the necessary jump command.
- Use existing architecture before adding a new subsystem.
- Keep desktop and Web behavior aligned.
- Add or update tests when feasible.

## Constraints
- Read AGENTS.md before implementation.
- Do not auto-merge.
- Do not modify unrelated gameplay/economy/content.
- Do not reopen optimization-locked milestone categories unless this task is a documented material regression.
- Prefer deletion/simplification over adding compatibility layers when cleaning architecture.
- Preserve Godot 4.7.x Web compatibility.

## Validation
- `python -m pytest tests_ai_lab -q`
- Run the repository Godot Web export workflow for Godot/UI changes.

## Evidence IDs
- `20260918T170319Z-qa_edge_cases-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
