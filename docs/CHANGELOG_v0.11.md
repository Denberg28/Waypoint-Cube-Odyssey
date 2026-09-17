# Waypoint: Cube Odyssey v0.11

## Minimized status panel
- Added a persistent Minimize / Expand control to the right-side status rail.
- Compact mode reduces the rail to a short top-right quick-action dock.
- Compact mode shows only Equip Best, Use Heal, Use Mana, and one latest-message line, plus the Expand control required to restore the panel.
- The latest message is trimmed to one line to avoid pulling focus away from the road.
- Expanded mode restores character stats, equipment, potions, threat/streak/relic details, adventure messages, and AI Game Master feedback.
- The selected panel state is stored in `user://waypoint_settings.cfg` and restored on launch.

## Compatibility
- Gameplay save schema remains version 8.
- No progression data is changed by this UI update.
