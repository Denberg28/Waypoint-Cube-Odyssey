# P2 — Elite Enemy Waves & Aggressive Encounter Pacing on Difficulty 3+ Routes

Task ID: `codex-156858f18c5d`
Base branch: `ai-development`
Category: `combat`

## Why this task exists
Current high-difficulty routes feature sparse enemy spacing, making combat feel trivial rather than challenging.

## Acceptance criteria
- Add elite enemy variants and increased encounter frequency to routes with difficulty 3 or higher.
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
- `20260918T010034Z-combat_challenger-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
