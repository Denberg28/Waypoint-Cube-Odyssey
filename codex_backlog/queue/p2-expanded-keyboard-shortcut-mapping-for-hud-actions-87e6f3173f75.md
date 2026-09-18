# P2 — Expanded Keyboard Shortcut Mapping for HUD Actions

Task ID: `codex-87e6f3173f75`
Base branch: `ai-development`
Category: `accessibility`

## Why this task exists
Improves overall usability and accessibility compliance for navigation.

## Acceptance criteria
- Fully bindable keyboard shortcuts for movement, combat prompts, and marketplace toggles.
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
- `20260918T125621Z-accessibility_ux-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
