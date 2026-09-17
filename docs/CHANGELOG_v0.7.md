# Waypoint: Cube Odyssey v0.7

## Cleaner HUD
- Added three brightness presets beside the WAYPOINT brand: Sun, Half Moon, and Full Moon.
- Brightness choice is saved locally and applied without changing the selected biome.
- Reduced the movement controls to a compact lower-left dock so the center road stays visually clear.
- Moved gameplay modal windows and fight cards into the lower-right utility area beneath the status panel.
- Reduced full-screen dimming during gameplay popups.

## Environment polish
- Removed Sunny / Cloudy / weather-name text from the road and stage opening message.
- Moved cloud masses to the far shoulders instead of the center view.
- Added biome-specific side details: puddles, snow banks, ice, desert rocks, shrubs, and small sunny roadside accents.

## Challenge loop
- Added Threat levels that rise through the road and peak during the boss.
- Later rows can generate Elite slimes, goblins, kobolds, and ogres.
- Elite enemies have +1 toughness and +1 damage, but award more coins and Relic charge.
- Clean enemy wins build a streak. Every third clean win adds bonus coins.
- Taking damage or hitting thorns breaks the streak.
- Maximum-threat thorns deal 2 hearts instead of 1.

## Gear collection
- Added a persistent Relic Meter. Clean wins and Elite victories charge it.
- At 100%, the next gear reward is guaranteed Rare or better.
- Gear drops prefer unowned items within the rolled rarity before giving duplicates.
- Duplicate gear grants banked coins plus Relic charge.
- Inventory entries now display rarity directly.
- Legendary and Unique finds keep their dedicated reward popup.

## Save compatibility
- Save schema updated to version 7 with migration from v1-v6.
