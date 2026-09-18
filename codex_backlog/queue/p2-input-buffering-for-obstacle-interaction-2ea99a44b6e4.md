# P2 — Input Buffering for Obstacle Interaction

Task ID: `codex-2ea99a44b6e4`
Base branch: `ai-development`
Category: `accessibility`

## Why this task exists
Edge-case testing shows players frequently attempt to keep walking into obstacles before realizing a jump is required.

## Acceptance criteria
- Automatically buffer or prompt the correct jump input when a walk action is entered against a known hazard.
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
- `20260918T193357Z-qa_edge_cases-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
