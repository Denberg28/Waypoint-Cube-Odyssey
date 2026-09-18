# P2 — Input Buffering and Movement State Validation

Task ID: `codex-5883db862622`
Base branch: `ai-development`
Category: `stability`

## Why this task exists
Edge-case analysis confirms that players can spam walk commands into static barriers, taking multiple ticks of avoidable damage.

## Acceptance criteria
- Engine-level input validation that suppresses invalid walk actions against active hazards or buffers jump transitions.
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
- `20260918T125621Z-qa_edge_cases-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
