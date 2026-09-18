# P2 — Elite Enemy Encounters and Wave Compositions on Difficulty 3+ Routes

Task ID: `codex-ae4775dc2d99`
Base branch: `ai-development`
Category: `combat`

## Why this task exists
Current high-difficulty routes like Frostfang Pass lack sufficient enemy density and mechanical friction, resulting in pacing that feels too passive.

## Acceptance criteria
- Introduce denser enemy formations, aggressive behavior profiles, and hazard-synergized combat encounters specifically for Difficulty 3 and higher routes.
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
- `20260918T170319Z-combat_challenger-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
