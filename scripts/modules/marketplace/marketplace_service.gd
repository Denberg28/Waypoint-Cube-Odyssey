extends RefCounted
const MarketplaceCatalog = preload("res://scripts/modules/marketplace/marketplace_catalog.gd")
const PetCatalog = preload("res://scripts/modules/pets/pet_catalog.gd")

static func owns_cosmetic(host, id: String) -> bool:
	return id in host.data.cosmetics_owned

static func buy_cosmetic(host, id: String) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"]:
		host.data.last = "Visit a safe waypoint to use the marketplace."
		return false
	var item: Dictionary = MarketplaceCatalog.cosmetic(id)
	if item.is_empty():
		host.data.last = "That cosmetic is unavailable."
		return false
	if owns_cosmetic(host, id):
		host.data.last = "%s is already in your wardrobe." % str(item.name)
		return false
	var price: int = int(item.get("price", 0))
	if int(host.data.coins) < price:
		host.data.last = "You need %d more banked coins." % (price - int(host.data.coins))
		return false
	host.data.coins -= price
	host.data.cosmetics_owned.append(id)
	host.data.cosmetics_equipped[str(item.slot)] = id
	host.data.last = "Purchased and equipped: %s." % str(item.name)
	return true

static func equip_cosmetic(host, id: String) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"] or id == "" or not owns_cosmetic(host, id):
		return false
	var item: Dictionary = MarketplaceCatalog.cosmetic(id)
	if item.is_empty():
		return false
	host.data.cosmetics_equipped[str(item.slot)] = id
	host.data.last = "Equipped: %s." % str(item.name)
	return true

static func clear_cosmetic(host, slot: String) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"] or slot not in ["skin", "head", "back", "face"]:
		return false
	host.data.cosmetics_equipped[slot] = ""
	host.data.last = "%s cosmetic cleared." % slot.capitalize()
	return true

static func buy_cat_food(host, quantity: int = 1) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"]:
		host.data.last = "Visit a safe waypoint to buy cat food."
		return false
	if not bool(host.data.cat_owned):
		host.data.last = "Adopt a cat before stocking companion food."
		return false
	var amount: int = clampi(quantity, 1, 5)
	if int(host.data.cat_food_stock) >= PetCatalog.CAT_FOOD_STOCK_CAP:
		host.data.last = "Cat food pantry is already full."
		return false
	amount = mini(amount, PetCatalog.CAT_FOOD_STOCK_CAP - int(host.data.cat_food_stock))
	var total_price: int = PetCatalog.CAT_FOOD_PRICE * amount
	if int(host.data.coins) < total_price:
		host.data.last = "You need %d more banked coins for cat food." % (total_price - int(host.data.coins))
		return false
	host.data.coins -= total_price
	host.data.cat_food_stock += amount
	host.data.last = "Purchased %d cat food for %d coins. Pantry ×%d." % [amount, total_price, int(host.data.cat_food_stock)]
	return true
