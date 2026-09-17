# Development notes

## Scope of v0.4.0

This is a playable free vertical slice, not a finished commercial release.
The expedition has a beginning, branching choices, bankable rewards, defeat,
a midway rest, a boss, victory, and repeatable permanent progression.
The campaign currently contains one forest biome with four encounter variants.
Route choices use a crossroads signpost overlay between trails. The game does not yet depict
a freely walkable open world.

The hop combat is turn-based and tile-based, not a physics platformer. Motion
is a tweened visual representation of a deterministic grid move. This makes
warnings readable, mobile controls simple, and saves reproducible. Real-time
combat or charged jumps would require deliberate rules changes.

Not included yet: additional biomes, six-face rune rotation mechanics, skill
minigames, multiplayer, accounts, cloud saves, purchases, achievements through
store APIs, music, localization, gamepad navigation, or store-ready mobile UI.
Keep these separate from acceptance of the current free loop.

## Runtime separation

`state.gd` owns authoritative gameplay state. `main.gd` waits for hop animation
before applying the completed turn. Input is locked during the animation.
`world.gd` renders the state and never determines rewards. `catalog.gd` holds
launch content separately from logic.

Save schema is version 4, retaining the original save filename. Version 1–3 saves migrate forward; older saves receive default mana/potion fields and no pending popup. Version 3 live roads are extended safely to the new stage length. All previous gameplay fields
are preserved. Unknown future schema versions are rejected. Save writes go through a temporary file, with a
previous-good backup. Invalid main JSON falls back to that backup. Saves are
local and editable by the player: do not use this save format as payment
entitlement validation in a future commercial edition. Preserve user inventory
and existing free unlocks when introducing later content.

The procedural room generator uses a stored room seed and serializes the
resulting cells. It repairs a hazard-free corridor with at most one lane change
per row. The guardian's target is selected from reachable lanes excluding its
warning lane, so a safe damaging action always exists. No action timer exists.

## Adding content

1. Add gear to `Catalog.GEAR` with a unique id, valid slot, rarity, and stats.
2. Keep all four rarity pools nonempty or update `award_gear` accordingly.
3. Add a route descriptor and tune the generator or add authored encounters.
4. Update the choice rotation and docs; test safe corridor generation.
5. For new state fields, increment the schema and implement migration before
   shipping; the current validator requires all current keys. Preserve the v1
   migration as well as subsequent migrations.
6. Update the generator and renderer together for new cell kinds.

## Suggested next iteration

First playtest movement, camera readability, and the guardian. Observe whether
players understand side hops and identify the next row. Then test a touch
export on a real Android device. Adjust difficulty from actual play rather
than increasing the item count immediately.

Candidate next work: actual fork geometry, a short timed hopping activity,
a second forest enemy behavior, stronger gear sidegrades, camp decoration,
controller support, configurable keys, music and volume sliders.
The twelve starting items are simple stat upgrades; a future balance pass can
make more of them change playstyle.

Keep future paid features in separate content/entitlement systems. No premium
UI, purchase stubs, billing libraries, or advertising SDKs are present here.

## v0.2 title, selector and encounters

The title screen is UI state (`at_title`), never saved as the expedition mode.
Entering the title does not replace the room or class in `game.data`. A separate
rendering flag shows the entrance camp background. Continue rebuilds the saved
world and displays its pending popup before allowing movement.

The selector uses a separate preview World and preview State in a SubViewport.
The animated reel is cosmetic; its final class draw is a uniform RNG selection
from the four class IDs. Nothing modifies the save until confirmation. Rerolls
are free. Existing class gear remains equipped and affects the displayed totals.

A pre-hop enemy prompt predicts the existing combat rules. Canceling makes no
state change; confirming performs exactly one animated hop. Result popups are
stored in `data.popup` after rewards/damage are applied. Dismissing only clears
the popup; it never awards loot again. This makes Continue safe at that boundary.

Camera projection is perspective; it follows behind at positive Z relative to
the cube and looks down the negative-Z path, without horizontal yaw. The cube
faces negative Z in gameplay; the selector shows its face and class outfit.


## v0.4 focused-road pacing and combat presentation

A trail is now 18 hop decisions instead of 10. The design target is roughly a 4–6 minute focused stage for typical deliberate play, rather than an ultra-brief corridor; actual completion time still depends on player decision speed and there is no timer pressure. A progress bar and OPENING / MIDROAD / FINAL STRETCH labels make stage length legible.

The road lanes are physically wider and the camera is tighter (57° FOV, closer follow). Only five upcoming rows of gameplay props are rendered, which reduces spoilers and visual clutter while preserving the deterministic full room state. Peripheral forest props are sparser and farther from the road.

Enemy landings no longer use a confirmation modal. The chosen hop commits immediately, then a short automatic combat card communicates anticipation, impact, and outcome before returning control. This is presentation only; `state.gd` still resolves authoritative combat exactly once.
