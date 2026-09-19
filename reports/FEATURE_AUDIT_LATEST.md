# Cube Odyssey — Feature Audit

Updated: 2026-09-19

## Verification status

- GitHub Python/contract suite: **59 passed**
- Python compile check: **passed**
- Godot 4.7.2 headless import: **passed**
- Godot 4.7.2 Web export: **passed**
- GitHub Pages Web tester deployment: **passed**
- Latest gameplay code build verified at commit `f650009c8b17e7e3cbe41d216365fa4e585dd803`; commits after it in this audit only refresh tests/contracts.

## Market + cat companion

Status: **implemented and integrated**

Verified flow:
1. Marketplace exposes a CAT tab.
2. A procedural cat offer is generated from name/body/accent/eyes/pattern pools.
3. Player can refresh the offer without cost before adoption.
4. Adoption validates safe-waypoint state, prevents duplicate ownership, checks banked coins, deducts the configured price, persists the selected design, and starts satiety at 70.
5. Fishing adds persistent fish portions to the pantry.
6. Feeding consumes exactly one fish, raises satiety, and updates mood.
7. Road completion reduces satiety by the configured progression cost; no wall-clock decay is used.
8. Adopted cat is rendered at Lantern Camp.
9. Save validation and v15 migration preserve pet/fish fields.
10. Telemetry covers adoption, offer refresh, feeding, successful cosmetic actions, and failed cosmetic actions.

Optimization notes:
- Cat appearance changes only before adoption; adopted appearance is stable.
- Satiety is progression-based, avoiding background timers and punishing offline time.
- Marketplace refresh remains explicit rather than changing the offer while the player is deciding.

## Battle presentation

Status: **implemented**

Changes:
- Combat card height increased for additional information.
- Enemy rank/loadout text is visible during encounters.
- Encounter/windup timings were lengthened.
- A 0–100 tug-of-war balance meter begins at center.
- Four suspense beats move the meter back and forth before settling toward the resolved outcome.
- Final state explicitly shows YOU WIN or FOE WINS.
- Existing combat resolution remains authoritative; the suspense meter is presentation only and cannot alter damage/rewards.
- Existing encounter, attack, impact, victory, hurt, and music-ducking audio paths remain in use.

## Enemy visual variety

Status: **implemented**

Each normal enemy type now has a distinct equipment identity:
- Moss Slime — moss shell, leaf cap, thorn spike
- Road Goblin — scrap vest, iron cap, short sword
- Trail Kobold — scale coat, horn guard, spear
- Waystone Ogre — plate harness, war helm, stone hammer

Rank system:
- COMMON
- HARDENED
- VETERAN
- CHAMPION (elite)

Visual variation:
- Multiple body/armor/helmet/weapon palettes per enemy type.
- Palette selection is deterministic from route seed + row + lane + enemy type, so enemies vary between encounters but do not change color when the scene rebuilds.
- Higher ranks add shoulder armor/trim.
- Elites retain crown/telegraph treatment and use Champion rank.

## Waypoints, maps, progression and UI regression review

The automated contract suite currently covers:
- level/star progression
- Resolve
- elite profiles
- route generation and safe corridor
- Gloomwood
- Sunken Grotto
- Cinder Caldera
- Galecrest Spire
- standardized/RPG waypoint geometry
- road posts
- cat companion and feeding loop
- save migrations
- Development Review synchronization
- beta tester simulation
- market telemetry
- combat suspense meter
- enemy visual rank/loadout system

## Remaining validation boundary

The automated Godot build proves the project parses/imports and exports successfully. The contract suite verifies integration points and state rules. Subjective presentation still benefits from a human browser smoke test for:
- battle pacing on desktop/mobile
- readability of long enemy loadout labels
- armor/weapon silhouette visibility at typical camera distance
- tug-of-war meter clarity
- cat and marketplace usability

No blocking implementation or build failure remains in this audit.
