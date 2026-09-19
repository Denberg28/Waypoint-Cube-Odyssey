# Cube Odyssey — Full Code Review & Sanitization Audit

Updated: 2026-09-19
Branch: `ai-development`

## Final verification state

- Python / contract tests: **62 passed**
- Repository sanitation gate: **SANITY_OK**
- Python compile pass: **passed**
- Godot 4.7.2 project import: **passed**
- Full `main.tscn` startup smoke: **passed**
- Crossroads world-build smoke: **passed**
- Core gameplay feature invariant smoke: **passed**
- Godot Web release export: **passed**
- GitHub Pages deployment: **passed**

The deployed gameplay build passed all Godot runtime gates before export.

## Sanitization work completed

### 1. Crossroads / UI reliability

- Removed the temporary Crossroads fallback route panel completely.
- Removed stale `route_panel`, `route_box`, `show_routes()`, and route-window API references.
- Corrected malformed `show_mode()` indentation left by the UI removal.
- Removed the obsolete UIRefinement route-panel styling hook.
- Added a contract preventing the deleted fallback API from reappearing.
- Added Streamlit Godot iframe cache-busting so refreshed sessions request the current build.

### 2. Full-scene runtime protection

The Web deploy pipeline now blocks publication unless all of these succeed:

1. Godot resource import
2. Full main-scene startup
3. Crossroads world construction
4. Core feature invariants
5. Web export
6. Pages deployment

The full-scene smoke additionally exercises:
- route preview modal
- cat marketplace modal
- cat adoption / companion modal
- combat presentation controls

### 3. Gameplay state invariants

A dedicated Godot feature smoke now verifies:

- fresh v15 state is save-valid
- cat offer generation and refresh
- cat purchase/adoption
- fish feeding and satiety changes
- cosmetic marketplace purchase
- generation of every playable route
- exact road cell count
- save validity after route generation
- invalid external route IDs safely fall back to Moss Trail
- expansion collectible counters
- ranked enemy visual variants

### 4. Route catalog drift eliminated

Previously:
- Godot had 10 playable routes
- AI Game Master layers still whitelisted the original 7

Now:
- `game_data/routes.json` is the Python-side route source of truth
- Godot AI validation uses `Catalog.ROUTES`
- Streamlit already reads `game_data/routes.json`
- Night Watch derives routes from the same JSON catalog
- AI contracts derive routes from the same JSON catalog
- regression coverage confirms all layers match

This includes:
- Sunken Grotto
- Cinder Caldera
- Galecrest Spire

### 5. Save / migration review

Current schema: **v15**

Verified:
- current reset state emits v15
- validator requires v15
- legacy saves through v14 migrate to v15
- cat fields are validated
- expansion collectible fields are validated
- cosmetics and equipment references are catalog-validated
- route IDs and mode values are validated
- travel cell structure and uniqueness are validated

### 6. Market + cat companion

Verified flow:

- random cat offer
- free offer reroll before adoption
- safe-waypoint-only adoption
- banked-coin affordability check
- stable adopted appearance
- fishing pantry integration
- feed consumes one fish
- satiety capped at 100
- progression-based hunger only
- mood thresholds
- camp rendering
- save migration
- telemetry for adoption / refresh / feeding

Marketplace telemetry was sanitized so failed cosmetic purchases are not logged as successful transactions.

### 7. Combat

Verified implementation:

- longer encounter presentation
- rank/loadout description
- tug-of-war suspense meter
- multiple struggle beats
- explicit win/loss visual outcome
- underlying combat resolution remains authoritative
- animation cannot alter the computed battle result

Combat UI controls are now covered by the full main-scene startup smoke.

### 8. Enemy visuals

Verified:

- type-specific armor
- type-specific helmet
- type-specific weapon
- Common / Hardened / Veteran / Champion ranks
- Elite = Champion presentation
- deterministic palette variation using route seed + row + lane + enemy type
- stable appearance across scene rebuilds

### 9. Web visual performance

Visual creation now routes through `VisualKit`.

Optimizations:
- shared BoxMesh
- shared CylinderMesh families
- shared SphereMesh
- shared material cache
- Web/light visual profile
- lower roadside marker density
- fewer decorative lanterns / banners / rope details
- fewer foliage props
- reduced precipitation geometry
- reduced cloud count
- reduced enemy micro-detail while preserving silhouette

Remaining intentional direct mesh allocation:
- the Lantern Camp tent PrismMesh, created only once per camp build

### 10. Dead code removed

Removed unused legacy UI implementations:

- `scripts/ui_shell.gd`
- `scripts/header_drawer.gd`
- `scripts/ui_icon_fallback.gd`

These were not referenced by `project.godot`, `main.tscn`, or active UI code.

### 11. Telemetry privacy checks

Verified by contract:

- Web remote telemetry requires explicit `telemetry=1`
- desktop remote debug is disabled
- free-text fields named result/message/feedback/text are excluded from remote details
- remote strings are length-limited
- save files are not uploaded by telemetry code

Note: database-side Supabase RLS / retention policy is external to this repository and was not independently audited in this code-only pass.

### 12. Repository sanitation gate

`tools/repo_sanity.py` now checks:

- project resource references exist
- main scene resource references exist
- JSON catalogs parse
- all game routes exist as active/playable world-map routes
- AI layers derive routes from shared catalogs
- deleted Crossroads fallback APIs stay deleted
- retired UI scripts stay retired
- save schema remains v15

The gate runs in CI before Python compile completion.

## Remaining non-blocking engineering debt

No blocking runtime/build issue remains in this review.

The main remaining maintainability item is structural rather than functional:
- `scripts/main.gd` and `scripts/world.gd` are large programmatic files. They are currently covered by stronger smoke tests, but later refactoring into smaller feature modules would reduce change risk further.

This is not required for the current playable Web build and should be done only as a controlled refactor with existing smoke tests kept intact.

## Current conclusion

The current `ai-development` branch is sanitized across:
- startup
- route selection
- save state
- map generation
- marketplace
- cat companion
- fishing
- combat
- enemy visuals
- expansion maps
- AI Game Master route integration
- telemetry client sanitization
- Web rendering
- CI / deployment

No known blocking implementation, parse, startup, route-generation, or Web-export failure remains.
