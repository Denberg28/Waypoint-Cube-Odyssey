# Cube Odyssey Modules

Cube Odyssey is split into simple functional modules.

**Rule:** a module is locked unless the current update explicitly targets it. If a feature crosses module boundaries, only the required modules are updated together.

## Standard layout

Domain gameplay code lives under:

`scripts/modules/<module>/`

Use this pattern:

- `*_catalog.gd` — constants, definitions, static content
- `*_service.gd` — gameplay rules and mutations
- facade/wrapper — stable compatibility API used by the rest of the game

Current facades:

- `scripts/catalog.gd` — forwards catalog access to domain catalogs
- `scripts/state.gd` — owns save/core state and forwards domain behavior to services

This keeps old callers stable while preventing unrelated features from sharing one large implementation file.

## Physical modules

- **core**
  - `scripts/modules/core/core_catalog.gd`
  - core progression/save logic remains in `scripts/state.gd`
- **road**
  - `scripts/modules/road/road_catalog.gd`
  - `scripts/modules/road/road_service.gd`
- **enemy**
  - `scripts/modules/enemy/enemy_catalog.gd`
  - `scripts/modules/enemy/enemy_service.gd`
- **marketplace**
  - `scripts/modules/marketplace/marketplace_catalog.gd`
  - `scripts/modules/marketplace/marketplace_service.gd`
- **pets**
  - `scripts/modules/pets/pet_catalog.gd`
  - `scripts/modules/pets/pet_service.gd`
- **progression**
  - `scripts/modules/progression/progression_catalog.gd`
  - `scripts/modules/progression/progression_service.gd`
  - road objectives, Camp Renown, camp upgrade thresholds, and rare road events
- **music**
  - `scripts/music_director.gd`
  - `ai_lab/music_agent.py`
  - `runtime/music_profile.json`
- **ai_council**
  - `ai_lab/`
  - `ai_gamemaster/`
- **maps**
  - `runtime/world_map.json`
  - `ai_lab/world_architect.py`
- **visuals**
  - `scripts/visual_kit.gd`
  - `scripts/world.gd`
- **ui**
  - `scripts/main.gd`
  - `scripts/ui_refinement.gd`
  - `scripts/ui_text_sanitizer.gd`
- **telemetry**
  - `scripts/ai_telemetry.gd`
  - `runtime/public_telemetry.json`
- **godot**
  - `main.tscn`
  - `project.godot`
- **deployment**
  - `.github/workflows/`
  - `tools/repo_sanity.py`

## Update rule

For future changes:

1. Edit the owning `*_service.gd` or `*_catalog.gd` first.
2. Change `state.gd` only when the public facade needs a new method or save/core state changes.
3. Change `main.gd` only for UI/runtime wiring.
4. Change `world.gd` only for rendering/animation/world interaction.
5. Do not move unrelated behavior during feature work.

Examples:

> Cat rank balance  
> Update **pets** only.

> Buy a new pet supply  
> Update **marketplace + pets**.

> Add a road with new enemies  
> Update **road + enemy + maps/visuals only if required**.

> Fix Music Director  
> Update **music** only unless another dependency genuinely requires a change.


> Retention/progression updates  
> Update **progression** first; touch **road**, **ui**, or **visuals** only when the progression feature requires presentation or road placement changes.
