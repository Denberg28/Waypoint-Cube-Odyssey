# Cube Odyssey Modules

Cube Odyssey is organized into simple functional modules.

**Rule:** a module is considered locked unless the current update explicitly targets it. Do not make opportunistic changes to unrelated modules. If a feature crosses module boundaries, only the required modules are opened for that update.

This structure is intentionally lightweight. Existing stable gameplay files are not being aggressively moved yet; they will be extracted gradually when that module is intentionally updated.

## Modules

- **core** — game state, progression, save fundamentals, shared catalog rules
- **godot** — scene startup, runtime orchestration, Godot integration
- **ui** — HUD, menus, panels, controls
- **music** — procedural music, ambience, Music Director
- **ai_council** — AI council, beta testers, governance, Night Watch
- **maps** — world map, expansion topology
- **visuals** — lightweight 3D rendering, character/world visuals
- **road** — route generation, hazards, waypoints, traversal
- **enemy** — enemy stats, ranks, encounters, combat-facing visuals
- **marketplace** — cosmetics, purchases, companion marketplace supplies
- **pets** — cat companion, care, satiety, bond/rank, pet animation
- **telemetry** — privacy-safe gameplay telemetry
- **deployment** — tests, Web export, GitHub Pages deployment

## Shared legacy files

The following files currently contain multiple modules and remain stable compatibility files:

- `scripts/main.gd`
- `scripts/state.gd`
- `scripts/catalog.gd`
- `scripts/world.gd`

We will split parts out of these files gradually only when a specific module is being updated.

## Update practice

Example:

> "Update cat feeding"

Open: **pets + marketplace + core** only if required.

> "Add a new road"

Open: **road + maps + visuals** only if required.

> "Fix Music Director"

Open: **music** only unless another dependency genuinely needs a change.
