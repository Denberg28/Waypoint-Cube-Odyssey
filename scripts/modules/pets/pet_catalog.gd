extends RefCounted
## Cat companion balance and appearance catalog.

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

