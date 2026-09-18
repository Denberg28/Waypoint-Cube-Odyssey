# P2 — Elite Combat Waves & Aggressive Enemy Behaviors

Task ID: `codex-2d6b89fd505f`
Base branch: `ai-development`
Category: `combat`

## Why this task exists
Current high-difficulty routes lack sufficient enemy friction, making combat feel like an afterthought rather than a core pillar of mastery.

## Acceptance criteria
- Request engine support for elite enemy profiles and multi-wave encounter triggers on difficulty 3+ routes.
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
- `20260918T072121Z-combat_challenger-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
