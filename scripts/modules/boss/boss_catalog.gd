extends RefCounted
## Four fixed boss profiles. They all reuse the proven lane/rune encounter.

const BOSSES = {
	"heartwood_keeper":{
		"name":"The Heartwood Keeper",
		"hp":14, "damage":2, "reward":30, "xp":60, "resolve":28, "relic":35,
		"telegraph":"ROOT SLAM", "idle":"breathe",
		"body":"857957", "trim":"73996c", "accent":"f3d881",
		"pattern":[0, -1, 1, 0, 1, -1]
	},
	"ember_colossus":{
		"name":"The Ember Colossus",
		"hp":12, "damage":3, "reward":36, "xp":65, "resolve":30, "relic":38,
		"telegraph":"EMBER CRASH", "idle":"pulse",
		"body":"704238", "trim":"b65a3f", "accent":"ffb36d",
		"pattern":[-1, 1, 0, 1, -1, 0]
	},
	"tide_warden":{
		"name":"The Tide Warden",
		"hp":16, "damage":2, "reward":34, "xp":65, "resolve":30, "relic":38,
		"telegraph":"TIDAL SWEEP", "idle":"float",
		"body":"456f78", "trim":"5fa9a3", "accent":"bfe8df",
		"pattern":[0, -1, 0, 1, 0, -1]
	},
	"gale_sentinel":{
		"name":"The Gale Sentinel",
		"hp":13, "damage":2, "reward":38, "xp":70, "resolve":32, "relic":40,
		"telegraph":"GALE BREAK", "idle":"sway",
		"body":"65757d", "trim":"91aeb8", "accent":"e0f1f6",
		"pattern":[1, 0, -1, 1, -1, 0]
	}
}

const DEFAULT_BOSS_ID: String = "heartwood_keeper"
