# P2 — Movement Command Input Buffering

Task ID: `codex-169c647b9d8f`
Base branch: `ai-development`
Category: `stability`

## Why this task exists
Edge-case telemetry shows players attempt to queue walk commands against active hazard collisions. Buffering or ignoring invalid movement commands improves handling feel.

## Acceptance criteria
- Movement inputs queued against obstacles are filtered or buffered safely until the obstacle is cleared.
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
- `20260918T010034Z-qa_edge_cases-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
