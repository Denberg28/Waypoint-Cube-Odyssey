# Waypoint: Cube Odyssey — Free prototype v0.11

A compact voxel adventure for Godot 4.7. The project uses procedural geometry, generated UI, synthesized effects, and original procedural bard-style background music. No paid assets, backend, or network connection are required.

## Open in Godot

1. Extract the ZIP.
2. Open Godot 4.7.
3. Import `project.godot`.
4. Press **F6** for the main scene or **F5** to run the project.

`Start-Game.ps1` is included for Windows launch convenience.

## Core road loop

Choose a cube class, select a crossroads route, then hop through an 18-decision trail. Only the next few rows are exposed so attention stays on the character and road. Keyboard controls are **A / Left**, **Space / W / Up**, and **D / Right**. The compact movement dock remains in the lower-left.

Gameplay popups and combat cards are smaller and anchored at the bottom center so they read clearly without covering the main action. Crossroads route selection now uses the same centered popup lane instead of appearing on the left side.

## Status rail and AI Game Master feedback

The right-side status area remains a wider, near-full-height rail for detailed play information, but it can now be minimized into a small quick-action dock. Compact mode shows only **Equip Best**, **Use Heal**, **Use Mana**, and a single latest-message line so the road stays visually dominant. Expanding restores character stats, equipment, potions, challenge/relic information, adventure messages, and the **AI Game Master Feedback** section.

The feedback interface is future-ready but local-only in v0.10. Player notes are stored in `user://waypoint_ai_gm_feedback.jsonl` together with a snapshot of the current route, stage, threat, HP, gear, gems, streak, relic progress, and related gameplay context. This gives a future AI Game Master integration structured material for balance analysis and update recommendations without redesigning the UI. No feedback is transmitted externally in this build.

See `docs/AI_GAME_MASTER_FEEDBACK.md` for the intended integration pipeline and record schema.

## Environments and brightness

Sunny, cloudy, rainy, sand, and winter biomes use softer, lower-contrast palettes. Winter snow, ambient light, and sun intensity were reduced significantly to avoid the previous overexposed appearance. Clouds remain on the far shoulders rather than the center sightline.

Use the **Sun / Half Moon / Full Moon** controls beside **WAYPOINT** to choose a saved brightness preset.

## Roadside discoveries

Special encounters are optional detours and are placed away from the guaranteed safe corridor when possible.

- **Roadside Campfire** — stop without advancing the road, listen to synthesized cricket calls and fire crackle, and view the environment.
- **Fishing Pool** — click when the moving ripple enters the gold target ring. Success can return fish, permanent gems, or equipment.
- **Gem Crystal** — permanent gem reward plus Relic Meter energy.
- **Gear Cache** — random equipment encounter with a visible chest and collection popup.

## Gems and gear collection

Gems are a permanent collection currency. At Lantern Camp, the halfway rest, or a crossroads, spend **6 gems** at the **Gem Forge** for an immediate **Rare-or-better** equipment roll.

The Relic Meter remains active: clean wins and Elite victories charge it, and at 100% the next ordinary gear drop is guaranteed Rare or better. Drops prefer unowned gear before duplicates when possible. The equipment pool now includes additional fishing-, frost-, and gem-themed items.

## Difficulty and routes

Threat now scales from **1 to 5**. Later rows, later expedition stages, and harder routes increase Elite frequency and hazard pressure.

Existing routes remain, with two new high-risk choices:

- **Frostfang Pass** — Hard / Elites / Gems. More ogres and elites, stronger winter pressure, guaranteed gem reward at completion, and a chance at an extra gear roll.
- **Whispering Fen** — Hard / Fishing / Relics. More fishing opportunities, gear caches, mixed enemies, and additional Relic Meter progress.

## Audio

Effects and music remain separate settings. The game now includes five randomized original procedural bard-style variants for camp, road, fishing, campfire, and boss moods. Fishing has splash/catch effects, and roadside campfires use a separate synthesized ambience layer for crickets and crackling fire.

## Persistence

v0.15 uses gameplay save schema **version 9** and migrates saves from versions 1–8. Saves include cosmetics ownership/equipment, gems, fish caught, Relic Meter, streak, gear, route, biome, expedition state, and boss state.

See `docs/CHANGELOG_v0.11.md` for the latest status-panel changes.


## v0.11.1
- When the status rail is minimized, the compact quick-action dock now appears in the lower-right corner instead of the upper-right.


## v0.12
- Reduced popup and right-panel font sizes for a cleaner, more compact UI.
- Simplified the equipment window and hid inferior gear while auto-equip is active.
- Kept only best gear choices visible, with manual swap available only for tied top options.


## v0.13
- Removed internal scrolling from character selection and normal popup dialogs.
- Simplified character selection into one preview, one stat block, one primary action, and two compact secondary actions.
- Standardized popup typography and button sizing.
- Simplified equipment and color selection to reduce menu density.


## v0.13.1
- Removed excess empty space from the popup cards and the minimized quick-action panel.


## v0.13.2
- Fixed the remaining excess empty space in popup windows by auto-fitting popup height to the content.


## v0.13.3
- Fixed the fishing popup so the button is fully visible on screen.

## v0.14 AI Game Master — Night Watch

The v0.13.3 gameplay baseline is locked. v0.14 adds an isolated Gemini Night Watch layer using `gemini-3.5-flash-lite`.

Night Watch can process the existing local AI feedback queue while you are away, create a small next-session world event, and grant tightly capped overnight progression. It does not autonomously rewrite the game source.

Start with `docs/AI_GAME_MASTER_SETUP.md` and `docs/BASELINE_LOCK.md`.


## v0.14.1 UI safety pass
- Standardized popup sizing and fixed hidden/cut-off controls by fitting cards to content within viewport-safe margins.


## v0.15 Marketplace
- Spend banked coins on permanent character cosmetics at Lantern Camp and safe waypoints.
- Customize four independent slots: Skin, Head, Back, and Face.
- Cosmetics are visual-only and do not affect combat balance.


## v0.16 — Clickable Camp & Crossroads
- Lantern Camp now exposes Start Adventure and Marketplace / Wardrobe directly.
- A 3D MARKET sign is clickable in camp.
- Crossroads signs are now clickable and use the current stage's actual route names.


## v0.17
- Click a crossroads sign to preview route difficulty, encounters, and collectibles before pressing Start Adventure.
- Bottom popup and mini-window alignment is standardized to one baseline.


## v0.18 — Walk + Jump
Normal tile movement now uses a short walking animation. Space / JUMP retains the original jump-style forward movement.


## v0.20 AI Game Master Core

The v0.19 gameplay baseline is locked. v0.20 adds local telemetry, deterministic player profiling, bounded Night Watch difficulty/featured-route directives, executable daily challenges, and a review-only development backlog. Use `ai_gamemaster\Test-NightWatch-Offline.ps1` before making live Gemini calls.


## v0.21 AI Development Lab
Run `Run-Streamlit-Lab.ps1` for the browser playtest edition. Run `Setup-GitHub-AI-Lab.ps1` to initialize/push the repository, create `ai-development`, and securely configure the Gemini GitHub Actions secret. See `docs/AI_DEVELOPMENT_LAB.md`.


## v0.22 — Gemini Beta Tester Council
Six `gemini-3.5-flash-lite` synthetic beta tester agents now review executable Streamlit play traces from distinct player perspectives. Their structured feedback and feature requests feed the hourly AI development cycle. Safe content requests may become bounded temporary experiments in the Streamlit development build; source/UI/engine changes remain review-only backlog items. See `docs/BETA_TESTER_COUNCIL.md`.

Offline validation: `python -m ai_lab.beta_testers --offline` followed by `python -m ai_lab.cycle --offline`.


## v0.22.1 setup hotfix

Fixed `Setup-GitHub-AI-Lab.ps1` so a fresh local repository with no `origin` remote is detected without triggering a Windows PowerShell NativeCommandError. Existing repositories with an `origin` continue to push normally.

## v0.23 — Odyssey Hunt retention hook
- Every trail now hides one optional **Waypoint Shard** away from the guaranteed safe corridor.
- Collect **3 shards in one expedition** to crack an **Odyssey Cache** with a guaranteed Rare-or-better permanent gear roll.
- The shard counter is visible in the status rail, route previews explain the hunt, and shards have a distinct gold world marker and pickup chime.
- Existing saves migrate to gameplay schema **version 10** without resetting permanent progression.
- Extra shards after opening the cache convert into Relic charge so later detours remain useful.
