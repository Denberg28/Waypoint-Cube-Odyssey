extends RefCounted
## All launch content is free. Add gear here without changing combat code.
const GEAR = [
	{"id":"ember", "name":"Ember core", "slot":"core", "rarity":"UNCOMMON", "text":"+1 stomp damage", "attack":1},
	{"id":"storm", "name":"Storm core", "slot":"core", "rarity":"RARE", "text":"+2 stomp damage", "attack":2},
	{"id":"sun", "name":"Sunheart core", "slot":"core", "rarity":"EPIC", "text":"+3 stomp damage", "attack":3},
	{"id":"aurora", "name":"Aurora core", "slot":"core", "rarity":"LEGENDARY", "text":"+4 stomp damage", "attack":4},
	{"id":"frostbite", "name":"Frostbite core", "slot":"core", "rarity":"EPIC", "text":"+3 stomp damage; forged in deep winter", "attack":3},
	{"id":"prism", "name":"Prism core", "slot":"core", "rarity":"LEGENDARY", "text":"+4 stomp damage; resonates with gems", "attack":4},
	{"id":"bark", "name":"Bark shell", "slot":"shell", "rarity":"COMMON", "text":"+1 maximum heart", "health":1},
	{"id":"stone", "name":"Riverstone shell", "slot":"shell", "rarity":"UNCOMMON", "text":"+2 maximum hearts", "health":2},
	{"id":"moon", "name":"Moonstone shell", "slot":"shell", "rarity":"RARE", "text":"+3 maximum hearts", "health":3},
	{"id":"marshglass", "name":"Marshglass shell", "slot":"shell", "rarity":"RARE", "text":"+3 maximum hearts; smooth as river glass", "health":3},
	{"id":"crown", "name":"Guardian shell", "slot":"shell", "rarity":"EPIC", "text":"+4 maximum hearts", "health":4},
	{"id":"citadel", "name":"Citadel shell", "slot":"shell", "rarity":"LEGENDARY", "text":"+5 maximum hearts", "health":5},
	{"id":"clover", "name":"Clover charm", "slot":"charm", "rarity":"COMMON", "text":"+1 extra coin per pickup", "coins":1},
	{"id":"bell", "name":"Traveler's bell", "slot":"charm", "rarity":"UNCOMMON", "text":"+2 extra coins per pickup", "coins":2},
	{"id":"star", "name":"Star charm", "slot":"charm", "rarity":"RARE", "text":"+3 extra coins per pickup", "coins":3},
	{"id":"angler", "name":"Angler's knot", "slot":"charm", "rarity":"RARE", "text":"+2 extra coins and heal 1 heart after a trail", "coins":2, "heal":1},
	{"id":"moss", "name":"Moss core", "slot":"core", "rarity":"COMMON", "text":"Heal 1 heart after a trail", "heal":1},
	{"id":"heart", "name":"Heartwood charm", "slot":"charm", "rarity":"EPIC", "text":"Heal 2 hearts after a trail", "heal":2},
	{"id":"wayfinder", "name":"Wayfinder charm", "slot":"charm", "rarity":"LEGENDARY", "text":"+4 extra coins per pickup", "coins":4},
	{"id":"gemheart", "name":"Gemheart charm", "slot":"charm", "rarity":"LEGENDARY", "text":"+2 extra coins and heal 2 hearts after a trail", "coins":2, "heal":2},
	{"id":"one_lantern", "name":"One Lantern", "slot":"charm", "rarity":"UNIQUE", "text":"+3 extra coins per pickup and heal 2 hearts after a trail", "coins":3, "heal":2}
]
const SKINS = [
	{"name":"Apricot", "color":"ffb66e", "wins":0},
	{"name":"Sea glass", "color":"7ee4cb", "wins":1},
	{"name":"Blue hour", "color":"94baff", "wins":2},
	{"name":"Orchid", "color":"d5a5ef", "wins":3},
	{"name":"Rose quartz", "color":"f4a4b9", "wins":4},
	{"name":"Starlight", "color":"f4e7aa", "wins":5}
]

const COSMETICS = [
	# Body skins
	{"id":"skin_sage", "name":"Forest Sage", "slot":"skin", "price":120, "color":"7fb694", "text":"A calm moss-green body tint."},
	{"id":"skin_twilight", "name":"Twilight Plum", "slot":"skin", "price":160, "color":"9c87bd", "text":"A muted violet evening tint."},
	{"id":"skin_frost", "name":"Frost Pearl", "slot":"skin", "price":190, "color":"c5d7dc", "text":"A soft winter pearl finish."},
	{"id":"skin_ember", "name":"Ember Rose", "slot":"skin", "price":240, "color":"d48779", "text":"A warm ember-red finish."},
	# Head pieces
	{"id":"head_trail_cap", "name":"Trail Cap", "slot":"head", "price":90, "style":"trail_cap", "color":"69866c", "text":"A practical little trail cap."},
	{"id":"head_moon_hood", "name":"Moon Hood", "slot":"head", "price":150, "style":"moon_hood", "color":"70658e", "text":"A soft hood for night roads."},
	{"id":"head_waypoint_crown", "name":"Waypoint Crown", "slot":"head", "price":260, "style":"crown", "color":"d5b76f", "text":"A tiny crown for veteran wanderers."},
	# Back pieces
	{"id":"back_traveler_pack", "name":"Traveler Pack", "slot":"back", "price":110, "style":"pack", "color":"8b6d50", "text":"A compact expedition backpack."},
	{"id":"back_lantern", "name":"Lantern Pack", "slot":"back", "price":180, "style":"lantern", "color":"d4a864", "text":"Carries a warm waypoint lantern."},
	{"id":"back_cape", "name":"Road Cape", "slot":"back", "price":230, "style":"cape", "color":"587f77", "text":"A short cape for long roads."},
	# Face pieces
	{"id":"face_scarf", "name":"Wanderer Scarf", "slot":"face", "price":80, "style":"scarf", "color":"b56f66", "text":"A simple road scarf."},
	{"id":"face_goggles", "name":"Scout Goggles", "slot":"face", "price":140, "style":"goggles", "color":"cfb276", "text":"Small brass-colored goggles."},
	{"id":"face_star_mark", "name":"Star Mark", "slot":"face", "price":210, "style":"star_mark", "color":"ead98c", "text":"A glowing cheek-side star mark."}
]

# Persistent camp companion. The market rolls one procedural cat appearance at a
# time; the adopted design is stored in the save so the companion never changes
# unexpectedly after purchase.
const CAT_PRICE: int = 160
const CAT_SATIETY_PER_FISH: int = 30
const CAT_FOOD_PRICE: int = 12
const CAT_SATIETY_PER_FOOD: int = 20
const CAT_FOOD_STOCK_CAP: int = 99
const CAT_SATIETY_ROAD_COST: int = 10
const CAT_LEVEL_CAP: int = 10
const CAT_BOND_XP_PER_LEVEL: int = 30
const CAT_BOND_XP_PER_FEED: int = 10
const CAT_RANKS = [
	{"min_level":1, "name":"FAMILIAR", "road_coin_bonus":1},
	{"min_level":3, "name":"TRAILMATE", "road_coin_bonus":2},
	{"min_level":5, "name":"WAYFINDER", "road_coin_bonus":3},
	{"min_level":7, "name":"HEARTHGUARD", "road_coin_bonus":4},
	{"min_level":9, "name":"WAYPOINT GUARDIAN", "road_coin_bonus":5}
]
const CAT_NAMES = ["Miso", "Pebble", "Juniper", "Mochi", "Soot", "Pippin", "Nimbus", "Maple"]
const CAT_BODY_COLORS = ["c99068", "8d8177", "d6c0a2", "59656b", "b36e61", "d9d4c7"]
const CAT_ACCENT_COLORS = ["f0e1c0", "4b3f3a", "b86f52", "758e88", "d7a0a0", "eee8dc"]
const CAT_EYE_COLORS = ["e7c96f", "7fc6a4", "79a9d6", "c88bd1", "d99d63"]
const CAT_PATTERNS = ["solid", "tuxedo", "tabby", "calico", "point"]

static func cosmetic(id: String) -> Dictionary:
	for item in COSMETICS:
		if item.id == id:
			return item
	return {}

static func cosmetics_for_slot(slot: String) -> Array:
	var result: Array = []
	for item in COSMETICS:
		if str(item.slot) == slot:
			result.append(item)
	return result

const ROUTES = {
	"moss":{"name":"Moss Trail", "tag":"GENTLE / HEALING", "text":"Slimes, coin trails, and calmer hazards.", "color":"70bf99", "difficulty":0, "difficulty_label":"EASY", "encounters":"Slimes • light thorns • roadside campfire", "collectibles":"Coins • healing potions • fishing rewards • possible gear cache"},
	"forge":{"name":"Bramble Forge", "tag":"DANGEROUS / MORE LOOT", "text":"Kobolds, goblins, thorns, and two end-of-route gear rolls.", "color":"eaa06e", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Goblins • kobolds • ogres • more elites • thorns", "collectibles":"Two finish gear rolls • elite gem chance • relic charge • possible gear cache"},
	"shrine":{"name":"Moonlit Steps", "tag":"PRECISION / SHRINE", "text":"Rune paths and a blessing after the trail.", "color":"b9a1e4", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • kobolds • thorns • shrine event", "collectibles":"Coins • gear • shrine blessing • fishing rewards • possible gear cache"},
	"treasure":{"name":"Lantern Crossing", "tag":"COINS / TRAVELER", "text":"A rich detour with a traveler encounter.", "color":"ebcd7e", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • goblins • traveler event • thorns", "collectibles":"Extra coin pickups • traveler gift/trade • fishing rewards • possible gear cache"},
	"frost":{"name":"Frostfang Pass", "tag":"HARD / ELITES / GEMS", "text":"Winter hazards, ogres, elites, and improved gem rewards.", "color":"9fc7d8", "difficulty":2, "difficulty_label":"HARD", "encounters":"Ogres • kobolds • high elite chance • stronger thorns", "collectibles":"Gem tiles • guaranteed finish gem • possible bonus gear • frequent gear cache"},
	"fen":{"name":"Whispering Fen", "tag":"HARD / FISHING / RELICS", "text":"Wet paths, fishing pools, gear caches, and aggressive monsters.", "color":"86ad9c", "difficulty":2, "difficulty_label":"HARD", "encounters":"Goblins • ogres • high elite chance • stronger thorns", "collectibles":"Extra fishing pool • gem tiles • +18 finish relic charge • frequent gear cache"},
	"gloomwood":{"name":"Gloomwood Hollow", "tag":"TWILIGHT / ROOTS / GLOOMCAPS", "text":"A twilight forest woven around the Whispering Hollow Root.", "color":"8f86b8", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • goblins • kobolds • ensnaring briars • Elite ambushes", "collectibles":"Gloomcaps • every 3rd Gloomcap grants 1 gem • gear cache • Resolve"},
	"sunken_grotto":{"name":"Sunken Grotto", "tag":"CAVERNS / WATER / PEARLS", "text":"Descend through glowing crystal pools beneath the western roads.", "color":"68b8b5", "difficulty":1, "difficulty_label":"MODERATE", "encounters":"Slimes • kobolds • slick algae slopes • flooded caches", "collectibles":"Prismatic Pearls • fishing pools • gems • crystal caches"},
	"cinder_caldera":{"name":"Cinder Caldera", "tag":"EXTREME / MAGMA / ELITES", "text":"Cross a volcanic rift where magma vents split the old forge road.", "color":"d86f4f", "difficulty":3, "difficulty_label":"EXTREME", "encounters":"Ogres • goblins • magma vents • guaranteed Elite threat", "collectibles":"Magma Ember Shards • gems • high-tier gear caches • relic charge"},
	"galecrest_spire":{"name":"Galecrest Spire", "tag":"EXTREME / WIND / RUINS", "text":"Climb an alpine ruin above the eastern pass through relentless crosswinds.", "color":"91b7ce", "difficulty":3, "difficulty_label":"EXTREME", "encounters":"Ogres • kobolds • gale-force gusts • guaranteed Elite threat", "collectibles":"Skyfeather Relics • gems • summit caches • relic charge"}
}
# Road-end waypoints share one navigation grammar but inherit a visual
# identity from the location just completed. This keeps every junction readable
# while making each biome feel authored rather than copy-pasted.
const WAYPOINT_STYLES = {
	"moss":{
		"label":"MOSSWOOD", "post":"765f49", "trim":"8eb77f", "accent":"d6e5a5", "motif":"leaf"
	},
	"forge":{
		"label":"BRAMBLE FORGE", "post":"6f5143", "trim":"c87957", "accent":"f2b36f", "motif":"ember"
	},
	"shrine":{
		"label":"MOONLIT STEPS", "post":"625a70", "trim":"9b89ba", "accent":"dfd1f0", "motif":"moon"
	},
	"treasure":{
		"label":"LANTERN CROSSING", "post":"7b6242", "trim":"c59a58", "accent":"f0d787", "motif":"lantern"
	},
	"frost":{
		"label":"FROSTFANG PASS", "post":"665f5c", "trim":"8eabb8", "accent":"dbe9ef", "motif":"frost"
	},
	"fen":{
		"label":"WHISPERING FEN", "post":"53675f", "trim":"719987", "accent":"c5ded2", "motif":"reed"
	},
	"gloomwood":{
		"label":"GLOOMWOOD HOLLOW", "post":"5c4d52", "trim":"75678e", "accent":"d4c1e8", "motif":"root"
	},
	"sunken_grotto":{
		"label":"SUNKEN GROTTO", "post":"4e6667", "trim":"5fa39f", "accent":"b5e5df", "motif":"crystal"
	},
	"cinder_caldera":{
		"label":"CINDER CALDERA", "post":"62483f", "trim":"b95f45", "accent":"f1a269", "motif":"ember"
	},
	"galecrest_spire":{
		"label":"GALECREST SPIRE", "post":"59656e", "trim":"7fa6bb", "accent":"d3e8f0", "motif":"spire"
	}
}

static func waypoint_style(route_id: String) -> Dictionary:
	if WAYPOINT_STYLES.has(route_id):
		return WAYPOINT_STYLES[route_id]
	return {
		"label":"WAYPOINT", "post":"765f49", "trim":"879574", "accent":"eee1b8", "motif":"leaf"
	}

const ROUTE_CONNECTIONS = {
	"moss":["forge", "gloomwood", "camp"],
	"forge":["moss", "fen", "cinder_caldera", "camp"],
	"fen":["forge", "frost", "cinder_caldera", "galecrest_spire", "camp"],
	"treasure":["shrine", "gloomwood", "sunken_grotto", "camp"],
	"shrine":["treasure", "frost", "camp"],
	"frost":["shrine", "fen", "galecrest_spire", "camp"],
	"gloomwood":["moss", "treasure", "sunken_grotto", "camp"],
	"sunken_grotto":["gloomwood", "treasure", "camp"],
	"cinder_caldera":["forge", "fen", "camp"],
	"galecrest_spire":["frost", "fen", "camp"]
}

const ENVIRONMENTS = {
	"sunny":{"name":"Sunny", "tag":"CLEAR SKIES"},
	"cloudy":{"name":"Cloudy", "tag":"SOFT LIGHT"},
	"rainy":{"name":"Raining", "tag":"WET ROAD"},
	"sand":{"name":"Sand", "tag":"DRY CROSSWIND"},
	"winter":{"name":"Winter", "tag":"FROSTED TRAIL"}
}
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

static func item(id: String) -> Dictionary:
	for gear in GEAR:
		if gear.id == id:
			return gear
	return {}


# Base stats are applied before permanent equipment and camp upgrades.
const CLASSES = {
	"knight":{"name":"Knight", "hp":8, "attack":2, "coins":0, "heal":0, "armor":1, "trade_cost":20, "color":"b9cbd0", "perk":"Armor: reduces enemy and guardian damage by 1 (minimum 1)."},
	"magician":{"name":"Magician", "hp":5, "attack":3, "coins":0, "heal":0, "armor":0, "trade_cost":20, "color":"c3a2e8", "perk":"Arcane stomp: starts with 3 attack, but only 5 hearts."},
	"merchant":{"name":"Merchant", "hp":6, "attack":1, "coins":2, "heal":0, "armor":0, "trade_cost":12, "color":"e8c582", "perk":"Tradecraft: +2 coins per pickup; traveler gear costs 12 instead of 20."},
	"adventurer":{"name":"Adventurer", "hp":6, "attack":1, "coins":0, "heal":1, "armor":0, "trade_cost":20, "color":"93ceb0", "perk":"Trailcraft: recover 1 heart after every completed trail."}
}
const CLASS_IDS = ["knight", "magician", "merchant", "adventurer"]
