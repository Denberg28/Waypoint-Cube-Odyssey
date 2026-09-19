extends RefCounted
## Global combat-balance constants. Keep progression bonuses modest so gear,
## class identity, route choice, and player execution all continue to matter.

const PLAYER_RANKS: Array[Dictionary] = [
	{"min_level":1, "name":"WANDERER", "attack":0, "health":0, "armor":0},
	{"min_level":5, "name":"TRAILHAND", "attack":1, "health":0, "armor":0},
	{"min_level":9, "name":"WAYFARER", "attack":1, "health":1, "armor":0},
	{"min_level":13, "name":"VANGUARD", "attack":2, "health":1, "armor":0},
	{"min_level":17, "name":"LANTERNBOUND", "attack":2, "health":2, "armor":1}
]

const ENEMY_RANK_COMBAT = {
	1:{"toughness":0, "damage":0, "xp":0},
	2:{"toughness":1, "damage":0, "xp":1},
	3:{"toughness":1, "damage":1, "xp":2},
	4:{"toughness":2, "damage":1, "xp":3}
}

# Balance targets used by automated review/simulation.
const TARGET_FIRST_BOSS_SKILLED_WIN_MIN: float = 0.70
const TARGET_FIRST_BOSS_SKILLED_WIN_MAX: float = 0.98
const TARGET_COMMON_CLEAN_WIN_MIN: float = 0.40
