# Deployment

**Status:** Locked unless explicitly targeted by the current update.

## Responsibility

Tests, Godot Web export and Pages deployment.

## Current files

- `.github/workflows/`
- `tools/repo_sanity.py`

## Rule

Do not modify this module during unrelated work. If a requested feature needs this module and another module, update only the required modules together.

Existing shared files may appear in more than one module. They remain compatibility files until that subsystem is intentionally extracted during a future targeted update.
