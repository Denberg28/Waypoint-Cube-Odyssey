# P2 — Obstacle Input Buffering & Command Feedback

Task ID: `codex-cb9774e9e465`
Base branch: `ai-development`
Category: `ux`

## Why this task exists
Edge-case telemetry shows players frequently spam movement commands when blocked by hazards, leading to frustrating unintended damage states.

## Acceptance criteria
- Add client-side command validation and input buffering so blocked walk commands prompt an immediate warning state rather than multiple penalty ticks.
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
- `20260918T072121Z-qa_edge_cases-feature-1`

## Codex completion contract
Return a focused implementation with a concise summary of root cause, files changed, tests run, and remaining risks. Do not merge automatically.
