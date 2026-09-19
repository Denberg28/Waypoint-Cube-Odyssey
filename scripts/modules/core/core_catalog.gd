extends RefCounted
## Stable core catalog: gear, skins, environments, and character classes.

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

const ENVIRONMENTS = {
	"sunny":{"name":"Sunny", "tag":"CLEAR SKIES"},
	"cloudy":{"name":"Cloudy", "tag":"SOFT LIGHT"},
	"rainy":{"name":"Raining", "tag":"WET ROAD"},
	"sand":{"name":"Sand", "tag":"DRY CROSSWIND"},
	"winter":{"name":"Winter", "tag":"FROSTED TRAIL"}
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

