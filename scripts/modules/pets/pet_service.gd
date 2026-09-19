extends RefCounted
const PetCatalog = preload("res://scripts/modules/pets/pet_catalog.gd")

static func random_cat_design(host) -> Dictionary:
	return {
		"name": str(PetCatalog.CAT_NAMES[host.rng.randi_range(0, PetCatalog.CAT_NAMES.size() - 1)]),
		"body": str(PetCatalog.CAT_BODY_COLORS[host.rng.randi_range(0, PetCatalog.CAT_BODY_COLORS.size() - 1)]),
		"accent": str(PetCatalog.CAT_ACCENT_COLORS[host.rng.randi_range(0, PetCatalog.CAT_ACCENT_COLORS.size() - 1)]),
		"eyes": str(PetCatalog.CAT_EYE_COLORS[host.rng.randi_range(0, PetCatalog.CAT_EYE_COLORS.size() - 1)]),
		"pattern": str(PetCatalog.CAT_PATTERNS[host.rng.randi_range(0, PetCatalog.CAT_PATTERNS.size() - 1)])
	}

static func cat_design_signature(design: Dictionary) -> String:
	if design.is_empty():
		return ""
	return "%s|%s|%s|%s|%s" % [
		str(design.get("name", "")),
		str(design.get("body", "")),
		str(design.get("accent", "")),
		str(design.get("eyes", "")),
		str(design.get("pattern", ""))
	]

static func valid_cat_design(design: Dictionary) -> bool:
	if design.is_empty():
		return false
	for key in ["name", "body", "accent", "eyes", "pattern"]:
		if not design.has(key) or not design[key] is String:
			return false
	return (
		str(design.name) in PetCatalog.CAT_NAMES
		and str(design.body) in PetCatalog.CAT_BODY_COLORS
		and str(design.accent) in PetCatalog.CAT_ACCENT_COLORS
		and str(design.eyes) in PetCatalog.CAT_EYE_COLORS
		and str(design.pattern) in PetCatalog.CAT_PATTERNS
	)

static func refresh_cat_offer(host) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"]:
		host.data.last = "Visit a safe waypoint to browse companion cats."
		return false
	if bool(host.data.cat_owned):
		host.data.last = "Your adopted cat is already waiting at Lantern Camp."
		return false
	var previous: String = cat_design_signature(host.data.cat_offer)
	var next_offer: Dictionary = random_cat_design(host)
	for _attempt in range(6):
		if cat_design_signature(next_offer) != previous:
			break
		next_offer = random_cat_design(host)
	host.data.cat_offer = next_offer
	host.data.last = "The market keeper introduces a different cat."
	return true

static func cat_mood(host) -> String:
	if not bool(host.data.cat_owned):
		return "NO CAT"
	var satiety: int = clampi(int(host.data.cat_satiety), 0, 100)
	if satiety >= 85:
		return "PURRING"
	if satiety >= 60:
		return "CONTENT"
	if satiety >= 35:
		return "CURIOUS"
	if satiety >= 15:
		return "HUNGRY"
	return "GRUMPY"

static func cat_level(host) -> int:
	if not bool(host.data.cat_owned):
		return 0
	return clampi(1 + floori(float(int(host.data.cat_bond_xp)) / float(PetCatalog.CAT_BOND_XP_PER_LEVEL)), 1, PetCatalog.CAT_LEVEL_CAP)

static func cat_rank_info(host) -> Dictionary:
	var info: Dictionary = PetCatalog.CAT_RANKS[0]
	var level: int = maxi(1, cat_level(host))
	for rank_data in PetCatalog.CAT_RANKS:
		if level >= int(rank_data.min_level):
			info = rank_data
	return info

static func cat_rank_name(host) -> String:
	return "NO RANK" if not bool(host.data.cat_owned) else str(cat_rank_info(host).name)

static func cat_bond_progress(host) -> Dictionary:
	if not bool(host.data.cat_owned):
		return {"level":0, "current":0, "needed":PetCatalog.CAT_BOND_XP_PER_LEVEL, "percent":0.0}
	var level: int = cat_level(host)
	if level >= PetCatalog.CAT_LEVEL_CAP:
		return {"level":level, "current":PetCatalog.CAT_BOND_XP_PER_LEVEL, "needed":PetCatalog.CAT_BOND_XP_PER_LEVEL, "percent":100.0}
	var current: int = int(host.data.cat_bond_xp) % PetCatalog.CAT_BOND_XP_PER_LEVEL
	return {"level":level, "current":current, "needed":PetCatalog.CAT_BOND_XP_PER_LEVEL, "percent":float(current) / float(PetCatalog.CAT_BOND_XP_PER_LEVEL) * 100.0}

static func add_cat_bond_xp(host, amount: int) -> String:
	if not bool(host.data.cat_owned) or amount <= 0:
		return ""
	var old_level: int = cat_level(host)
	var max_xp: int = (PetCatalog.CAT_LEVEL_CAP - 1) * PetCatalog.CAT_BOND_XP_PER_LEVEL
	host.data.cat_bond_xp = clampi(int(host.data.cat_bond_xp) + amount, 0, max_xp)
	var new_level: int = cat_level(host)
	var result: String = "+%d Bond XP" % amount
	if new_level > old_level:
		result += "  •  CAT LEVEL %d  •  %s" % [new_level, cat_rank_name(host)]
	return result

static func cat_buff_coins(host) -> int:
	if not bool(host.data.cat_owned) or int(host.data.cat_satiety) < 35:
		return 0
	var bonus: int = int(cat_rank_info(host).road_coin_bonus)
	match cat_mood(host):
		"PURRING": bonus += 2
		"CONTENT": bonus += 1
		_: pass
	return bonus

static func cat_buff_text(host) -> String:
	var bonus: int = cat_buff_coins(host)
	if bonus <= 0:
		return "ROAD LUCK inactive  •  Feed to CURIOUS or better."
	return "ROAD LUCK  •  +%d expedition coin%s at each completed road." % [bonus, "" if bonus == 1 else "s"]

static func cat_mood_text(host) -> String:
	match cat_mood(host):
		"PURRING": return "Purring beside the lantern."
		"CONTENT": return "Content and relaxed."
		"CURIOUS": return "Curious and watching the road."
		"HUNGRY": return "Hungry and waiting for a fish."
		"GRUMPY": return "Very hungry and distinctly unimpressed."
		_: return "No companion adopted yet."

static func adopt_cat(host) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"]:
		host.data.last = "Visit a safe waypoint to adopt a companion."
		return false
	if bool(host.data.cat_owned):
		host.data.last = "You already have a cat companion."
		return false
	if not valid_cat_design(host.data.cat_offer):
		host.data.cat_offer = random_cat_design(host)
	if int(host.data.coins) < PetCatalog.CAT_PRICE:
		host.data.last = "You need %d more banked coins to adopt %s." % [PetCatalog.CAT_PRICE - int(host.data.coins), str(host.data.cat_offer.name)]
		return false
	host.data.coins -= PetCatalog.CAT_PRICE
	host.data.cat_owned = true
	host.data.cat_design = host.data.cat_offer.duplicate(true)
	host.data.cat_satiety = 70
	host.data.cat_bond_xp = 0
	host.data.last = "Adopted %s! Your new cat is waiting at Lantern Camp." % str(host.data.cat_design.name)
	return true

static func feed_cat(host) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"]:
		host.data.last = "Feed your cat at a safe waypoint."
		return false
	if not bool(host.data.cat_owned):
		host.data.last = "You have not adopted a cat yet."
		return false
	if int(host.data.fish_stock) <= 0:
		host.data.last = "%s is %s, but your fish pantry is empty. Look for fishing pools on adventures." % [str(host.data.cat_design.get("name", "Your cat")), cat_mood(host).to_lower()]
		return false
	if int(host.data.cat_satiety) >= 100:
		host.data.last = "%s is already full and refuses another fish." % str(host.data.cat_design.get("name", "Your cat"))
		return false
	host.data.fish_stock -= 1
	host.data.cat_satiety = mini(100, int(host.data.cat_satiety) + PetCatalog.CAT_SATIETY_PER_FISH)
	var bond_note: String = add_cat_bond_xp(host, PetCatalog.CAT_BOND_XP_PER_FEED)
	host.data.last = "Fed %s a trail fish. Satiety %d%%  •  %s. Fish feeding advances Bond rank." % [str(host.data.cat_design.get("name", "Your cat")), int(host.data.cat_satiety), cat_mood(host)]
	if bond_note != "":
		host.data.last += "  •  " + bond_note
	return true

static func feed_cat_food(host) -> bool:
	if host.data.mode not in ["camp", "rest", "choice"]:
		host.data.last = "Feed your cat at a safe waypoint."
		return false
	if not bool(host.data.cat_owned):
		host.data.last = "You have not adopted a cat yet."
		return false
	if int(host.data.cat_food_stock) <= 0:
		host.data.last = "Your cat food pantry is empty. Buy more at the marketplace."
		return false
	if int(host.data.cat_satiety) >= 100:
		host.data.last = "%s is already full." % str(host.data.cat_design.get("name", "Your cat"))
		return false
	host.data.cat_food_stock -= 1
	host.data.cat_satiety = mini(100, int(host.data.cat_satiety) + PetCatalog.CAT_SATIETY_PER_FOOD)
	host.data.last = "Fed %s market cat food. Satiety %d%%  •  %s. No Bond XP gained." % [str(host.data.cat_design.get("name", "Your cat")), int(host.data.cat_satiety), cat_mood(host)]
	return true

static func cat_adventure_tick(host) -> String:
	if not bool(host.data.cat_owned):
		return ""
	host.data.cat_satiety = maxi(0, int(host.data.cat_satiety) - PetCatalog.CAT_SATIETY_ROAD_COST)
	return "%s at camp: %s  •  satiety %d%%." % [str(host.data.cat_design.get("name", "Your cat")), cat_mood(host), int(host.data.cat_satiety)]
