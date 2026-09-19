# Ui

**Status:** Locked unless explicitly targeted by the current update.

## Responsibility

HUD, menus, modal panels and user controls.

## Current files

- `scripts/main.gd`
- `scripts/ui_refinement.gd`
- `scripts/ui_text_sanitizer.gd`

## Rule

Do not modify this module during unrelated work. If a requested feature needs this module and another module, update only the required modules together.

Existing shared files may appear in more than one module. They remain compatibility files until that subsystem is intentionally extracted during a future targeted update.
