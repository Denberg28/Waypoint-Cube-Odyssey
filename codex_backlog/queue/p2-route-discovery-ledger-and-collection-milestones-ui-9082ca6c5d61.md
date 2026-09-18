# P2 — Route Discovery Ledger and Collection Milestones UI

Task ID: `codex-9082ca6c5d61`
Base branch: `ai-development`
Category: `exploration`

## Why this task exists
Without a ledger, tracking unique route collectibles like Gloomcaps or Root Relics relies purely on external notes or memory.

## Acceptance criteria
- An in-game collection menu tracking discovered items and rewarding completionists upon fully exploring a route catalog.
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
- `20260918T193357Z-explorer_collector-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
