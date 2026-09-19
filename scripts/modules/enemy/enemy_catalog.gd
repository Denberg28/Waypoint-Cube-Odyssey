extends RefCounted
## Enemy combat and visual identity catalog.

const ENEMIES = {
	# XP follows combat threat: common enemies give modest progress, while
	# ogres and elites are meaningfully better without allowing farm-heavy
	# routes to outpace road-completion rewards.
	"slime":{"name":"Moss Slime", "toughness":1, "damage":1, "reward":3, "consolation":2, "xp":2},
	"goblin":{"name":"Road Goblin", "toughness":2, "damage":2, "reward":4, "consolation":3, "xp":3},
	"kobold":{"name":"Trail Kobold", "toughness":2, "damage":2, "reward":4, "consolation":3, "xp":3},
	"ogre":{"name":"Waystone Ogre", "toughness":3, "damage":3, "reward":5, "consolation":3, "xp":5}
}

# Visual identity is deliberately separate from combat stats. Each enemy type
# owns a recognizable equipment silhouette, while deterministic palette
# variants make repeat encounters feel less cloned without changing balance.
const ENEMY_VISUALS = {
	"slime":{
		"armor":"moss_shell", "helmet":"leaf_cap", "weapon":"thorn_spike",
		"palettes":[
			{"body":"78c7aa", "armor":"4f7769", "helmet":"86a95f", "weapon":"6f5a43"},
			{"body":"74b7c5", "armor":"486d79", "helmet":"86a875", "weapon":"66543f"},
			{"body":"9bbf75", "armor":"5f794d", "helmet":"b2a56b", "weapon":"705944"}
		]
	},
	"goblin":{
		"armor":"scrap_vest", "helmet":"iron_cap", "weapon":"short_sword",
		"palettes":[
			{"body":"76b15f", "armor":"6f655c", "helmet":"4c5559", "weapon":"b7a77d"},
			{"body":"84a95d", "armor":"755d4c", "helmet":"53585c", "weapon":"c0aa78"},
			{"body":"65aa72", "armor":"5c6b64", "helmet":"4a535a", "weapon":"a9956e"}
		]
	},
	"kobold":{
		"armor":"scale_coat", "helmet":"horn_guard", "weapon":"spear",
		"palettes":[
			{"body":"c78a67", "armor":"6b7583", "helmet":"59636e", "weapon":"a68559"},
			{"body":"b97964", "armor":"6d665b", "helmet":"555b61", "weapon":"b49a68"},
			{"body":"c59a63", "armor":"66747a", "helmet":"4e5d66", "weapon":"9b805a"}
		]
	},
	"ogre":{
		"armor":"plate_harness", "helmet":"war_helm", "weapon":"stone_hammer",
		"palettes":[
			{"body":"98a36a", "armor":"68665e", "helmet":"51575b", "weapon":"81705a"},
			{"body":"879b6e", "armor":"74665b", "helmet":"565b5e", "weapon":"8d7458"},
			{"body":"a18d70", "armor":"646a6b", "helmet":"50555a", "weapon":"7e6a58"}
		]
	}
}

const ENEMY_RANKS = {
	1:{"name":"COMMON", "trim":"8aa49a"},
	2:{"name":"HARDENED", "trim":"9db18c"},
	3:{"name":"VETERAN", "trim":"c3a66f"},
	4:{"name":"CHAMPION", "trim":"d18c64"}
}

# Elite profiles activate only when effective danger is 3+. Each enemy keeps a
# distinct combat identity rather than receiving the same generic stat bump.
const ELITE_BEHAVIORS = {
	"slime":{
		"id":"ambusher", "name":"Ambusher", "telegraph":"AMBUSH",
		"initiative":"ambush", "toughness_bonus":0, "damage_bonus":0,
		"reward_bonus":2, "consolation_bonus":1, "relic_bonus":2, "gem_chance":0.18, "xp_bonus":2
	},
	"goblin":{
		"id":"skirmisher", "name":"Skirmisher", "telegraph":"SKIRMISH",
		"initiative":"aggressive", "toughness_bonus":1, "damage_bonus":0,
		"reward_bonus":2, "consolation_bonus":1, "relic_bonus":3, "gem_chance":0.20, "xp_bonus":3
	},
	"kobold":{
		"id":"bulwark", "name":"Bulwark", "telegraph":"GUARD",
		"initiative":"normal", "toughness_bonus":2, "damage_bonus":0,
		"reward_bonus":3, "consolation_bonus":1, "relic_bonus":4, "gem_chance":0.24, "xp_bonus":3
	},
	"ogre":{
		"id":"crusher", "name":"Crusher", "telegraph":"HEAVY",
		"initiative":"normal", "toughness_bonus":1, "damage_bonus":2,
		"reward_bonus":4, "consolation_bonus":2, "relic_bonus":5, "gem_chance":0.28, "xp_bonus":4
	}
}

