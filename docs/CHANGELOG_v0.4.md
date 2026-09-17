# Waypoint: Cube Odyssey — v0.4

## Focused road pacing

- Trail length increased from 10 to 18 hop decisions.
- Road lanes widened and the follow camera tightened to keep the character and immediate choices dominant on screen.
- Only the next five rows of gameplay props are revealed at a time; full room state remains deterministic and saved.
- Forest decoration is sparser near the road and pushed farther into the shoulders.
- Added regular low-pressure breather rows to break up hazards and fights.
- Added a compact stage progress bar with Opening / Midroad / Final Stretch phases.

## Combat presentation

- Enemy landings resolve automatically without a confirmation modal.
- Added a compact animated fight card with anticipation, impact, and result beats.
- Player-hit and clean-strike outcomes use distinct squash/flash animation cues.
- Heartwood Keeper slam/strike actions also use the combat presentation.
- Combat rules remain authoritative in `state.gd`; presentation never applies extra damage or rewards.

## Save compatibility

- Save schema updated to version 4.
- Version 1, 2, and 3 saves migrate forward.
- Existing v3 live 10-step roads are safely extended instead of being discarded.
