# P2 — High-Contrast UI Focus Indicators

Task ID: `codex-6145039036f6`
Base branch: `ai-development`
Category: `accessibility`

## Why this task exists
Clear focus states reduce cognitive load and navigation errors for accessibility-focused users.

## Acceptance criteria
- Add distinct visual highlighting and focus rings to marketplace items, route selectors, and buttons.
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
- `20260918T223155Z-accessibility_ux-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
