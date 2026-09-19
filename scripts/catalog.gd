extends RefCounted
## Compatibility facade. Domain data lives in scripts/modules/* catalogs.
## Existing callers keep using Catalog.* so modules can evolve independently.

const CoreCatalog = preload("res://scripts/modules/core/core_catalog.gd")
const MarketplaceCatalog = preload("res://scripts/modules/marketplace/marketplace_catalog.gd")
const PetCatalog = preload("res://scripts/modules/pets/pet_catalog.gd")
const RoadCatalog = preload("res://scripts/modules/road/road_catalog.gd")
const EnemyCatalog = preload("res://scripts/modules/enemy/enemy_catalog.gd")

const GEAR = CoreCatalog.GEAR
const SKINS = CoreCatalog.SKINS
const ENVIRONMENTS = CoreCatalog.ENVIRONMENTS
const CLASSES = CoreCatalog.CLASSES
const CLASS_IDS = CoreCatalog.CLASS_IDS

const COSMETICS = MarketplaceCatalog.COSMETICS

const CAT_PRICE = PetCatalog.CAT_PRICE
const CAT_SATIETY_PER_FISH = PetCatalog.CAT_SATIETY_PER_FISH
const CAT_FOOD_PRICE = PetCatalog.CAT_FOOD_PRICE
const CAT_SATIETY_PER_FOOD = PetCatalog.CAT_SATIETY_PER_FOOD
const CAT_FOOD_STOCK_CAP = PetCatalog.CAT_FOOD_STOCK_CAP
const CAT_SATIETY_ROAD_COST = PetCatalog.CAT_SATIETY_ROAD_COST
const CAT_LEVEL_CAP = PetCatalog.CAT_LEVEL_CAP
const CAT_BOND_XP_PER_LEVEL = PetCatalog.CAT_BOND_XP_PER_LEVEL
const CAT_BOND_XP_PER_FEED = PetCatalog.CAT_BOND_XP_PER_FEED
const CAT_RANKS = PetCatalog.CAT_RANKS
const CAT_NAMES = PetCatalog.CAT_NAMES
const CAT_BODY_COLORS = PetCatalog.CAT_BODY_COLORS
const CAT_ACCENT_COLORS = PetCatalog.CAT_ACCENT_COLORS
const CAT_EYE_COLORS = PetCatalog.CAT_EYE_COLORS
const CAT_PATTERNS = PetCatalog.CAT_PATTERNS

const ROUTES = RoadCatalog.ROUTES
const WAYPOINT_STYLES = RoadCatalog.WAYPOINT_STYLES
const ROUTE_CONNECTIONS = RoadCatalog.ROUTE_CONNECTIONS

const ENEMIES = EnemyCatalog.ENEMIES
const ENEMY_VISUALS = EnemyCatalog.ENEMY_VISUALS
const ENEMY_RANKS = EnemyCatalog.ENEMY_RANKS
const ELITE_BEHAVIORS = EnemyCatalog.ELITE_BEHAVIORS

static func item(id: String) -> Dictionary:
	return CoreCatalog.item(id)

static func cosmetic(id: String) -> Dictionary:
	return MarketplaceCatalog.cosmetic(id)

static func cosmetics_for_slot(slot: String) -> Array:
	return MarketplaceCatalog.cosmetics_for_slot(slot)

static func waypoint_style(route_id: String) -> Dictionary:
	return RoadCatalog.waypoint_style(route_id)
