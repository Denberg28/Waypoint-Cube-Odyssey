# P2 — Route Discovery Ledger and Collection Milestones UI

Task ID: `codex-d4db4339cdf1`
Base branch: `ai-development`
Category: `exploration`

## Why this task exists
As an Explorer & Collector, having a dedicated ledger provides clear long-term goals beyond basic currency accumulation.

## Acceptance criteria
- An in-game UI tab displaying collected route items and milestones.
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
- `20260918T170319Z-explorer_collector-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
