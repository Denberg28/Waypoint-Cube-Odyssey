# Validation — v0.4.0 update notes

Target runtime: Godot 4.7, Compatibility renderer. This revision was updated in a tooling environment without a Godot executable; static/project checks were performed here, but the Godot runtime suites must be rerun locally.

- Godot editor import: completed without script parse errors.
- Main scene startup: ran headlessly for 40 frames without runtime errors.
- Existing state suite: 287 checks, 0 failures.
- Update suite: 68 checks, 0 failures (355 explicit checks total).
- Update checks cover class health/attack/armor/coin/heal rules, merchant price,
  legacy migration, malformed class/popup rejection, random-selector animation,
  preview cancellation, confirmation, disabled/enabled Continue, non-blocking encounter resolution, right-side message feed, no duplicate rewards, persistent
  sound settings, and forward-facing perspective camera placement.
- Generated-route checks: 30 rooms for each of four route types, validating
  complete grid size and a reachable hazard-free corridor.
- Full expedition simulation: six trails, halfway rest, guardian entry,
  reachable safe guardian targets, victory rewards, and banked coins.
- State checks: enemy telegraph phases, coin/heal/thorn outcomes, equipment
  restrictions and stats, defeat retention, camp healing and banking.
- Save checks: complete save/load round trip, backup recovery after corrupt
  primary JSON, malformed inventory and cell rejection.
- Scene integration: all modal screens, gear/help/pause UI construction,
  an animated trail hop, and an animated guardian hop; 0 failures.

Visual screenshot inspection could not be completed because the test environment
could not initialize an X display. The scene was exercised with Godot's headless
renderer. The included `tests/capture_preview.gd` can capture game screens on
a system with a working display.

These are automated correctness checks, not evidence of commercial retention,
long-term balance, or performance on every platform. Windows export, Android
export, touch gestures on physical devices, and store distribution have not
been tested here. Mobile controls are implemented; device validation remains.

Camera projection was also checked numerically: the cube and immediate left/right
landing tiles project within the gameplay area above the bottom controls at the
1280×800 design size. This is not a substitute for visual/device testing.


### v0.4 checks to rerun in Godot 4.7

- 18-step generated roads (`State.CELL_COUNT == 51`) retain a fully reachable safe corridor.
- v1/v2/v3 saves migrate to schema v4; a live v3 27-cell road is extended to 51 cells.
- Only the next five rows of props are rendered in travel mode.
- Road coordinates use the shared `World.LANE_SPACING` and `World.ROW_SPACING` constants.
- Enemy landing triggers the automatic fight card and returns to live gameplay with input unlocked.
- Combat outcome is applied once by `state.gd`; the fight animation does not award or damage separately.

## v0.15 marketplace static checks
- Cosmetic catalog: 13 unique IDs across Skin / Head / Back / Face; positive banked-coin prices.
- Save schema: v9 with v1–v8 migration fields for cosmetics.
- GDScript structural delimiter/string scan: passed.
- Python AI Game Master module: py_compile passed.
- Godot runtime still requires local Godot 4.7 verification.
