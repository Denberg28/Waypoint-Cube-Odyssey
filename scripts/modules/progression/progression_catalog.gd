extends RefCounted
## Retention-core progression tuning. Keep this module small and deterministic.

const CAMP_LEVEL_THRESHOLDS: Array[int] = [0, 2, 5, 9]
const OBJECTIVE_BANK_COINS: int = 5
const OBJECTIVE_RESOLVE: int = 5
const RARE_EVENT_CHANCE: float = 0.26

const OBJECTIVES: Array[Dictionary] = [
	{
		"id":"trail_tally",
		"type":"coin",
		"label":"TRAIL TALLY",
		"description":"Collect 3 coin caches",
		"target":3
	},
	{
		"id":"road_hunter",
		"type":"enemy",
		"label":"ROAD HUNTER",
		"description":"Defeat 1 road enemy",
		"target":1
	},
	{
		"id":"curious_wanderer",
		"type":"discovery",
		"label":"CURIOUS WANDERER",
		"description":"Visit 1 roadside discovery",
		"target":1
	}
]
