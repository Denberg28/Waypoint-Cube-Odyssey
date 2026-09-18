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
	"fen":{"name":"Whispering Fen", "tag":"HARD / FISHING / RELICS", "text":"Wet paths, fishing pools, gear caches, and aggressive monsters.", "color":"86ad9c", "difficulty":2, "difficulty_label":"HARD", "encounters":"Goblins • ogres • high elite chance • stronger thorns", "collectibles":"Extra fishing pool • gem tiles • +18 finish relic charge • frequent gear cache"}
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
