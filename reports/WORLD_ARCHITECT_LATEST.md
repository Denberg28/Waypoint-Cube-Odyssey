# Waypoint World Architect — Latest Council Resolution

Decision: **EXPAND**

Expanding the world map by introducing a new planned region, 'Gloomwood Hollow', connected to existing nodes 'moss' and 'treasure'. This expansion responds to high exploration demand from the Explorer & Collector council persona and strong telemetry activity on surrounding routes like Moss Trail and Lantern Crossing.

## Council basis
- Explorer & Collector requested route discovery ledgers and unique regional collectibles.
- Aggregate telemetry shows robust player activity across Moss Trail (moss) and Lantern Crossing (treasure).
- World Architect expansion guidelines support connecting new planned regions to 1-3 existing map nodes without overlapping coordinates.

## Map action
- Added planned region **Gloomwood Hollow** (`gloomwood`)
- Difficulty concept: 2
- Theme: twilight forest and ancient roots
- Connections: moss, treasure
- Landmark: The Whispering Hollow Root
- Hazard: Ensnaring Briars
- Collectible: Gloomcaps
- Architect status at council time: **planned / non-playable**, pending separate implementation.

> Guardrail: the World Architect may expand the planning graph but cannot delete or rewrite existing playable routes and cannot promote a proposal to playable by itself.

## Implementation status

- **PROMOTED TO PLAYABLE** on the `ai-development` branch after engineering implementation.
- Gloomwood Hollow now has a dedicated twilight biome, Ensnaring Briar hazard presentation, the Whispering Hollow Root landmark, and persistent Gloomcap collection.
- The World Architect remains planning-only; this promotion was performed by the implementation workflow.
