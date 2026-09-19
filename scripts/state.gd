extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
const PetService = preload("res://scripts/modules/pets/pet_service.gd")
const MarketplaceService = preload("res://scripts/modules/marketplace/marketplace_service.gd")
const EnemyService = preload("res://scripts/modules/enemy/enemy_service.gd")
const RoadService = preload("res://scripts/modules/road/road_service.gd")
const ProgressionService = preload("res://scripts/modules/progression/progression_service.gd")
const BalanceService = preload("res://scripts/modules/balance/balance_service.gd")
const BossService = preload("res://scripts/modules/boss/boss_service.gd")
const STAGE_STEPS: int = 18
const GENERATED_ROWS: int = STAGE_STEPS - 1
const CELL_COUNT: int = GENERATED_ROWS * 3
const LEVEL_CAP: int = 20
const START_LEVEL: int = 1
const START_XP: int = 0
const SAVE_PATH = "user://waypoint_save_v1.json"
var save_path: String = SAVE_PATH
var data: Dictionary
var notice: String = ""
var rng = RandomNumberGenerator.new()
var ai_difficulty_offset: int = 0
var ai_featured_route: String = ""

func _init() -> void:
	rng.randomize()
	reset()

func reset() -> void:
	data = {
		"version":18,
		"mode":"camp",
		"hp":6,
		"mana":3,
		"coins":0,
		"bag":0,
		"stage":0,
		"row":0,
		"lane":0,
		"route":"moss",
		"environment":"sunny",
		"cells":[],
		"seed":1,
		"inventory":[],
		"equipped":{"core":"", "shell":"", "charm":""},
		"wins":0,
		"runs":0,
		"skin":0,
		"cosmetics_owned":[],
		"cosmetics_equipped":{"skin":"", "head":"", "back":"", "face":""},
		"camp_level":0,
		"camp_renown":0,
		"road_objective":{},
		"rare_events_seen":0,
		"kills":0,
		"level":START_LEVEL,
		"xp":START_XP,
		"resolve":0,
		"turn":0,
		"boss_hp":12,
		"danger":0,
		"target":-1,
		"blessing":0,
		"class_id":"adventurer",
		"popup":{},
		"potions":{"heal":1, "mana":1},
		"streak":0,
		"relic_charge":0,
		"gems":0,
		"fish_caught":0,
		"fish_stock":0,
		"cat_food_stock":0,
		"cat_owned":false,
		"cat_design":{},
		"cat_offer":{},
		"cat_satiety":0,
		"cat_bond_xp":0,
		"gloomcaps":0,
		"prismatic_pearls":0,
		"ember_shards":0,
		"skyfeathers":0,
		"last":"Welcome, little wanderer. Your first journey starts here."
	}
	data.cat_offer = random_cat_design()

func initialize_new_account_progression() -> void:
	# A brand-new save always begins unranked: zero filled stars and zero XP.
	# Level 1 is the baseline display level; star_quarter_count() returns 0 here.
	data.level = START_LEVEL
	data.xp = START_XP

func start_fresh_character(class_id: String, skin_index: int = 0) -> void:
	# Destructive fresh start: reset all character/account progression to the
	# shipped baseline while leaving device settings untouched (settings live
	# outside this save file). The selected class begins its first expedition.
	reset()
	initialize_new_account_progression()
	data.skin = clampi(skin_index, 0, Catalog.SKINS.size() - 1)
	begin(class_id)
	data.last = "Fresh character created. 0 stars, 0 XP, no previous progression."

func xp_to_next(level_value: int = -1) -> int:
	var current: int = int(data.level) if level_value < 0 else level_value
	if current >= LEVEL_CAP:
		return 0
	return 30 + (current - 1) * 8

func award_xp(amount: int) -> String:
	if amount <= 0 or int(data.level) >= LEVEL_CAP:
		return ""
	var old_level: int = int(data.level)
	data.xp += amount
	while int(data.level) < LEVEL_CAP:
		var needed: int = xp_to_next()
		if needed <= 0 or int(data.xp) < needed:
			break
		data.xp -= needed
		data.level += 1
	if int(data.level) >= LEVEL_CAP:
		data.level = LEVEL_CAP
		data.xp = 0
	var message: String = "+%d XP" % amount
	if int(data.level) > old_level:
		message += "  •  LEVEL UP! %d" % int(data.level)
		if int(data.level) == LEVEL_CAP:
			message += "  •  FIVE-STAR MAX"
	return message

func enemy_xp_value(kind: String, elite: bool = false) -> int:
	var profile: Dictionary = enemy_profile(kind)
	var rank: int = enemy_rank(kind, elite)
	var value: int = int(profile.get("xp", 0)) + BalanceService.enemy_rank_modifier(rank, "xp")
	if elite:
		value += int(elite_behavior(kind).get("xp_bonus", 0))
	return maxi(0, value)

func enemy_combat_stats(kind: String, elite: bool = false) -> Dictionary:
	var profile: Dictionary = enemy_profile(kind)
	var behavior: Dictionary = elite_behavior(kind) if elite else {}
	var rank: int = enemy_rank(kind, elite)
	var danger: int = danger_level()
	var level_value: int = int(data.get("level", 1))
	var toughness: int = (
		int(profile.get("toughness", 1))
		+ int(behavior.get("toughness_bonus", 0))
		+ BalanceService.enemy_rank_modifier(rank, "toughness")
		+ BalanceService.enemy_progression_toughness(level_value, danger)
	)
	var damage_value: int = (
		int(profile.get("damage", 1))
		+ int(behavior.get("damage_bonus", 0))
		+ BalanceService.enemy_rank_modifier(rank, "damage")
		+ BalanceService.enemy_progression_damage(level_value, danger, elite)
	)
	return {
		"rank":rank,
		"rank_name":enemy_rank_name(kind, elite),
		"toughness":maxi(1, toughness),
		"damage":maxi(1, damage_value),
		"effective_damage":enemy_damage(maxi(1, damage_value))
	}

func encounter_balance_percent(kind: String, elite: bool = false) -> float:
	var stats: Dictionary = enemy_combat_stats(kind, elite)
	var player_power: float = float(maxi(1, attack()))
	var enemy_power: float = float(maxi(1, int(stats.get("toughness", 1))))
	var ratio: float = player_power / (player_power + enemy_power)
	return clampf(ratio * 100.0, 12.0, 88.0)

func add_resolve(amount: int) -> String:
	# Positive-only motivation meter. Resolve never decreases on defeat.
	# At 100%, useful supplies are granted and overflow carries forward.
	if amount <= 0:
		return ""
	var total: int = maxi(0, int(data.resolve)) + amount
	var rewards: int = 0
	while total >= 100:
		total -= 100
		rewards += 1
	data.resolve = total
	if rewards > 0:
		data.potions.heal += rewards
		data.potions.mana += rewards
		return "+%d Resolve  •  RESOLVE SUPPLY! +%d healing +%d mana potion%s" % [amount, rewards, rewards, "" if rewards == 1 else "s"]
	return "+%d Resolve  •  %d%% toward Resolve Supply" % [amount, int(data.resolve)]

func star_quarter_count() -> int:
	var level_value: int = clampi(int(data.level), 1, LEVEL_CAP)
	# Level 1 begins unranked. Level 4 is the first full star; after that,
	# each level advances by one quarter-star until Level 20 reaches five stars.
	if level_value <= 1:
		return 0
	if level_value == 2:
		return 1
	if level_value == 3:
		return 2
	return level_value

func star_rank_text() -> String:
	var quarters: int = star_quarter_count()
	var full_stars: int = quarters / 4
	var remainder: int = quarters % 4
	var stars: Array[String] = []
	for i in range(5):
		if i < full_stars:
			stars.append("★")
		elif i == full_stars and remainder > 0:
			stars.append(["", "¼★", "½★", "¾★"][remainder])
		else:
			stars.append("☆")
	return "LV %02d  •  %s" % [int(data.level), " ".join(stars)]

func level_progress_text() -> String:
	if int(data.level) >= LEVEL_CAP:
		return "MAX LEVEL"
	return "XP %d / %d" % [int(data.xp), xp_to_next()]

func player_rank_name() -> String:
	return BalanceService.player_rank_name(int(data.level))

func player_rank_bonus(key: String) -> int:
	return BalanceService.player_rank_bonus(int(data.level), key)

func stat(key: String) -> int:
	var value: int = int(class_info().get(key, 0))
	for id in data.equipped.values():
		value += int(Catalog.item(str(id)).get(key, 0))
	return value

func max_hp() -> int:
	return int(class_info().hp) + stat("health") + int(data.camp_level) + player_rank_bonus("health")

func attack() -> int:
	return stat("attack") + int(data.blessing) + player_rank_bonus("attack")

func max_mana() -> int:
	return 5 if str(data.class_id) == "magician" else 3

func best_owned_gear_id(slot: String) -> String:
	if slot not in ["core", "shell", "charm"]:
		return ""
	var best_id: String = ""
	var best_score: int = -999
	for raw_id in data.inventory:
		var gear_id: String = str(raw_id)
		var gear: Dictionary = Catalog.item(gear_id)
		if gear.is_empty() or str(gear.get("slot", "")) != slot:
			continue
		var score: int = int(gear.get("attack", 0)) * 5 + int(gear.get("health", 0)) * 4 + int(gear.get("coins", 0)) * 2 + int(gear.get("heal", 0)) * 3
		if str(gear.get("rarity", "")) == "LEGENDARY":
			score += 2
		elif str(gear.get("rarity", "")) == "UNIQUE":
			score += 4
		if score > best_score:
			best_score = score
			best_id = gear_id
	return best_id

func sanitized_equipped_id(slot: String) -> String:
	if slot not in ["core", "shell", "charm"]:
		return ""
	var gear_id: String = str(data.equipped.get(slot, ""))
	if gear_id == "":
		return ""
	if gear_id not in data.inventory:
		return ""
	var gear: Dictionary = Catalog.item(gear_id)
	if gear.is_empty() or str(gear.get("slot", "")) != slot:
		return ""
	return gear_id

func repair_equipment_slots() -> bool:
	var changed: bool = false
	for slot in ["core", "shell", "charm"]:
		var safe_id: String = sanitized_equipped_id(slot)
		if str(data.equipped.get(slot, "")) != safe_id:
			data.equipped[slot] = safe_id
			changed = true
	return changed

func equip_best() -> void:
	if data.mode not in ["camp", "rest", "choice"]:
		data.last = "Equipment can only be changed at a safe waypoint."
		return
	repair_equipment_slots()
	var equipped_count: int = 0
	for slot in ["core", "shell", "charm"]:
		var best_id: String = best_owned_gear_id(slot)
		if best_id != "":
			data.equipped[slot] = best_id
			equipped_count += 1
	data.hp = mini(int(data.hp), max_hp())
	if equipped_count == 0:
		data.last = "No equippable gear is owned yet."
	else:
		data.last = "Best available equipment equipped in %d slot%s." % [equipped_count, "" if equipped_count == 1 else "s"]

func random_cat_design() -> Dictionary:
	return PetService.random_cat_design(self)

func cat_design_signature(design: Dictionary) -> String:
	return PetService.cat_design_signature(design)

func valid_cat_design(design: Dictionary) -> bool:
	return PetService.valid_cat_design(design)

func refresh_cat_offer() -> bool:
	return PetService.refresh_cat_offer(self)

func cat_mood() -> String:
	return PetService.cat_mood(self)

func cat_level() -> int:
	return PetService.cat_level(self)

func cat_rank_info() -> Dictionary:
	return PetService.cat_rank_info(self)

func cat_rank_name() -> String:
	return PetService.cat_rank_name(self)

func cat_bond_progress() -> Dictionary:
	return PetService.cat_bond_progress(self)

func add_cat_bond_xp(amount: int) -> String:
	return PetService.add_cat_bond_xp(self, amount)

func cat_buff_coins() -> int:
	return PetService.cat_buff_coins(self)

func cat_buff_text() -> String:
	return PetService.cat_buff_text(self)

func cat_mood_text() -> String:
	return PetService.cat_mood_text(self)

func adopt_cat() -> bool:
	return PetService.adopt_cat(self)

func feed_cat() -> bool:
	return PetService.feed_cat(self)

func buy_cat_food(quantity: int = 1) -> bool:
	return MarketplaceService.buy_cat_food(self, quantity)

func feed_cat_food() -> bool:
	return PetService.feed_cat_food(self)

func cat_adventure_tick() -> String:
	return PetService.cat_adventure_tick(self)

func owns_cosmetic(id: String) -> bool:
	return MarketplaceService.owns_cosmetic(self, id)

func buy_cosmetic(id: String) -> bool:
	return MarketplaceService.buy_cosmetic(self, id)

func equip_cosmetic(id: String) -> bool:
	return MarketplaceService.equip_cosmetic(self, id)

func clear_cosmetic(slot: String) -> bool:
	return MarketplaceService.clear_cosmetic(self, slot)

func use_potion(kind: String) -> bool:
	if kind not in ["heal", "mana"] or not data.potions.has(kind) or int(data.potions[kind]) <= 0:
		return false
	if kind == "heal":
		if int(data.hp) >= max_hp():
			data.last = "Hearts are already full."
			return false
		data.potions.heal -= 1
		data.hp = mini(max_hp(), int(data.hp) + 3)
		data.last = "Healing potion used: +3 hearts."
	else:
		if int(data.mana) >= max_mana():
			data.last = "Mana is already full."
			return false
		data.potions.mana -= 1
		data.mana = mini(max_mana(), int(data.mana) + 3)
		data.last = "Mana potion used: +3 mana."
	return true

func class_info() -> Dictionary:
	return Catalog.CLASSES[str(data.class_id)]

func enemy_damage(amount: int) -> int:
	return maxi(1, amount - stat("armor") - player_rank_bonus("armor"))

func environment_name() -> String:
	return str(Catalog.ENVIRONMENTS.get(str(data.environment), {"name":"Sunny"}).get("name", "Sunny"))

func roll_environment(route: String) -> String:
	return RoadService.roll_environment(self, route)

func enemy_profile(kind: String) -> Dictionary:
	return EnemyService.enemy_profile(kind)

func enemy_rank(kind: String, elite: bool = false) -> int:
	return EnemyService.enemy_rank(self, kind, elite)

func enemy_rank_name(kind: String, elite: bool = false) -> String:
	return EnemyService.enemy_rank_name(self, kind, elite)

func enemy_visual_variant(kind: String, row: int = -1, lane: int = 0, elite: bool = false) -> Dictionary:
	return EnemyService.enemy_visual_variant(self, kind, row, lane, elite)

func elite_behavior(kind: String) -> Dictionary:
	return EnemyService.elite_behavior(kind)

func enemy_kind_for_route(route: String, local_rng: RandomNumberGenerator) -> String:
	return EnemyService.enemy_kind_for_route(self, route, local_rng)

static func route_options_for_stage_index(stage_index: int) -> Array:
	return RoadService.route_options_for_stage_index(stage_index)

func begin_road_objective() -> Dictionary:
	return ProgressionService.begin_road_objective(self)

func progression_record_cell(kind: String, result_text: String) -> String:
	return ProgressionService.record_cell_result(self, kind, result_text)

func claim_road_objective() -> String:
	return ProgressionService.claim_road_objective(self)

func objective_text() -> String:
	return ProgressionService.objective_text(self)

func camp_renown_text() -> String:
	return ProgressionService.camp_renown_text(self)

func resolve_rare_event() -> String:
	return ProgressionService.resolve_rare_event(self)

func prepare_new_expedition() -> void:
	data.popup = {}
	data.row = 0
	data.lane = 0
	data.cells = []
	data.road_objective = {}
	data.runs += 1
	data.stage = 0
	data.bag = 0
	data.blessing = 0
	data.streak = 0
	data.mode = "choice"
	data.last = "Choose a route. Every road has something to offer."

func begin(class_id: String = "") -> void:
	# Explicit character creation/new-character selection starts at full resources.
	# Ordinary expedition turnover must use leave_camp_for_crossroads(), which
	# preserves the character's current hearts and mana.
	if class_id in Catalog.CLASSES:
		data.class_id = class_id
	data.hp = max_hp()
	data.mana = max_mana()
	prepare_new_expedition()

func make_room(route: String) -> void:
	# Route IDs can originate from UI, AI directives, or migrated state. Never
	# allow an unknown key to index the catalog and crash the session.
	if route not in Catalog.ROUTES:
		data.last = "Unknown road request; returning to Moss Trail."
		route = "moss"
	data.route = route
	data.environment = roll_environment(route)
	data.mode = "travel"
	data.row = 0
	data.lane = 0
	data.turn = 0
	data.seed = rng.randi_range(1, 9999999)
	var local_rng = RandomNumberGenerator.new()
	local_rng.seed = int(data.seed)
	data.cells = []
	var route_difficulty: int = clampi(int(Catalog.ROUTES[route].get("difficulty", 0)) + ai_difficulty_offset, 0, 4)
	for row in range(1, STAGE_STEPS):
		var safe_lane: int = local_rng.randi_range(-1, 1)
		var breather: bool = row in [1, 6, 12, 17]
		for lane in range(-1, 2):
			var kind: String = "empty"
			var roll: float = local_rng.randf()
			if breather:
				kind = "coin" if lane == safe_lane or roll < 0.28 else "empty"
			elif lane == safe_lane:
				kind = "coin" if roll < 0.58 else "empty"
			else:
				var spike_limit: float = 0.14 + float(route_difficulty) * 0.025
				var base_enemy_limit: float = 0.39
				if route == "forge":
					base_enemy_limit = 0.52
				elif route == "cinder_caldera":
					base_enemy_limit = 0.58
				elif route == "galecrest_spire":
					base_enemy_limit = 0.54
				elif route == "sunken_grotto":
					base_enemy_limit = 0.43
				var enemy_limit: float = base_enemy_limit + float(route_difficulty) * 0.055
				if roll < spike_limit:
					kind = "spike"
				elif roll < enemy_limit:
					kind = enemy_kind_for_route(route, local_rng)
				elif roll < 0.69:
					kind = "coin"
				elif roll < 0.75 and route in ["frost", "fen", "sunken_grotto", "cinder_caldera", "galecrest_spire"]:
					kind = "gem"
				elif roll < 0.77 and route == "gloomwood":
					kind = "gloomcap"
				elif roll < 0.82 and route == "moss":
					kind = "heal"
			data.cells.append({"row":row, "lane":lane, "kind":kind, "cleared":false, "elite":false})
	# Repair a guaranteed hazard-free corridor. Special encounters are placed away from it.
	var corridor_lanes: Dictionary = {}
	var corridor: int = 0
	for row in range(1, STAGE_STEPS):
		corridor = clampi(corridor + local_rng.randi_range(-1, 1), -1, 1)
		corridor_lanes[row] = corridor
		for cell in data.cells:
			if int(cell.row) == row and int(cell.lane) == corridor:
				cell.kind = "coin" if row % 2 == 0 else "empty"
	# Optional roadside discoveries: players can stay on the safe corridor or detour.
	place_special_cell(6, int(corridor_lanes[6]), "campfire", local_rng)
	place_special_cell(12, int(corridor_lanes[12]), "fishing", local_rng)
	if local_rng.randf() < (0.90 if route in ["cinder_caldera", "galecrest_spire"] else (0.78 if route in ["frost", "fen", "sunken_grotto"] else 0.48)):
		place_special_cell(15, int(corridor_lanes[15]), "gear_cache", local_rng)
	if route == "fen":
		place_special_cell(9, int(corridor_lanes[9]), "fishing", local_rng)
	if route == "gloomwood":
		place_special_cell(9, int(corridor_lanes[9]), "gloomcap", local_rng)
		place_special_cell(14, int(corridor_lanes[14]), "gloomcap", local_rng)
	elif route == "sunken_grotto":
		place_special_cell(9, int(corridor_lanes[9]), "fishing", local_rng)
		place_special_cell(14, int(corridor_lanes[14]), "prismatic_pearl", local_rng)
	elif route == "cinder_caldera":
		place_special_cell(9, int(corridor_lanes[9]), "ember_shard", local_rng)
		place_special_cell(14, int(corridor_lanes[14]), "ember_shard", local_rng)
	elif route == "galecrest_spire":
		place_special_cell(9, int(corridor_lanes[9]), "skyfeather", local_rng)
		place_special_cell(14, int(corridor_lanes[14]), "skyfeather", local_rng)
	# Effective danger begins at 1 + route difficulty. Danger 3+ roads get one
	# guaranteed elite profile encounter off the safe corridor; later elites
	# still use the deterministic chance system.
	if 1 + route_difficulty >= 3:
		place_elite_encounter(route, corridor_lanes, local_rng)
	ProgressionService.maybe_place_rare_event(self, corridor_lanes, local_rng)
	begin_road_objective()
	data.last = "The road reveals only a few steps ahead. " + objective_text()

func place_elite_encounter(route: String, corridor_lanes: Dictionary, local_rng: RandomNumberGenerator) -> void:
	var elite_row: int = 10
	var safe_lane: int = int(corridor_lanes.get(elite_row, 0))
	var candidates: Array[int] = []
	for lane in range(-1, 2):
		if lane != safe_lane:
			candidates.append(lane)
	if candidates.is_empty():
		return
	var elite_lane: int = candidates[local_rng.randi_range(0, candidates.size() - 1)]
	var cell: Dictionary = cell_at(elite_row, elite_lane)
	if cell.is_empty():
		return
	cell.kind = enemy_kind_for_route(route, local_rng)
	cell.elite = true

func place_special_cell(row: int, safe_lane: int, kind: String, local_rng: RandomNumberGenerator) -> void:
	var candidates: Array[int] = []
	for lane in range(-1, 2):
		if lane != safe_lane:
			candidates.append(lane)
	if candidates.is_empty():
		return
	var chosen_lane: int = candidates[local_rng.randi_range(0, candidates.size() - 1)]
	var cell: Dictionary = cell_at(row, chosen_lane)
	if not cell.is_empty():
		cell.kind = kind

func cell_at(row: int, lane: int) -> Dictionary:
	for cell in data.cells:
		if int(cell.row) == row and int(cell.lane) == lane:
			return cell
	return {}

func enemy_active(cell: Dictionary) -> bool:
	var base_active: bool = (int(data.turn) + int(cell.row) + int(cell.lane) + 3) % 2 == 0
	if not enemy_elite(cell):
		return base_active
	var behavior: Dictionary = elite_behavior(str(cell.get("kind", "slime")))
	match str(behavior.get("initiative", "normal")):
		"ambush":
			return true
		"aggressive":
			var signature: int = absi(int(data.seed) + int(cell.row) * 17 + int(cell.lane) * 31 + int(data.turn) * 7) % 3
			return signature < 2
		_:
			return base_active

func danger_level() -> int:
	if str(data.mode) == "boss":
		return 5
	if str(data.mode) not in ["travel", "campfire", "fishing"]:
		return 1
	var level: int = 1 + int(Catalog.ROUTES.get(str(data.route), {}).get("difficulty", 0)) + ai_difficulty_offset
	if int(data.row) >= 6:
		level += 1
	if int(data.row) >= 12:
		level += 1
	if int(data.stage) >= 3:
		level += 1
	return clampi(level, 1, 5)

func enemy_elite(cell: Dictionary) -> bool:
	if cell.is_empty() or str(cell.get("kind", "")) not in ["slime", "goblin", "kobold", "ogre"]:
		return false
	if danger_level() < 3 or int(cell.row) < 5:
		return false
	if bool(cell.get("elite", false)):
		return true
	var chance: int = 12 + int(data.stage) * 2 + (danger_level() - 3) * 6
	if str(data.route) == "forge":
		chance += 5
	elif str(data.route) in ["frost", "fen"]:
		chance += 9
	elif str(data.route) in ["cinder_caldera", "galecrest_spire"]:
		chance += 14
	chance = mini(chance, 42)
	var signature: int = absi(int(data.seed) + int(cell.row) * 37 + int(cell.lane) * 101 + int(data.stage) * 19) % 100
	return signature < chance

func add_relic_charge(amount: int) -> void:
	data.relic_charge = clampi(int(data.relic_charge) + amount, 0, 100)

func resolve_enemy(kind: String, active: bool, elite: bool = false) -> String:
	var profile: Dictionary = enemy_profile(kind)
	var behavior: Dictionary = elite_behavior(kind) if elite else {}
	var combat: Dictionary = enemy_combat_stats(kind, elite)
	var toughness: int = int(combat.toughness)
	var damage_value: int = int(combat.damage)
	var reward: int = int(profile.reward) + int(behavior.get("reward_bonus", 0))
	var consolation: int = int(profile.consolation) + int(behavior.get("consolation_bonus", 0))
	var enemy_name: String = str(profile.name)
	if elite:
		enemy_name = "Elite %s %s" % [str(behavior.get("name", "")), str(profile.name)]
	var result: String = ""
	if active:
		var damage: int = enemy_damage(damage_value)
		data.hp -= damage
		data.streak = 0
		add_relic_charge(4 if elite else 2)
		result = "%s struck first! Lost %d hearts." % [enemy_name, damage]
	elif attack() < toughness:
		data.hp -= 1
		data.bag += consolation
		data.kills += 1
		data.streak = 0
		add_relic_charge(8 if elite else 4)
		var hard_xp: String = award_xp(enemy_xp_value(kind, elite))
		var hard_resolve: String = add_resolve(4) if elite else ""
		result = "Hard fight. %s defeated! +%d coins, but lost 1 heart." % [enemy_name, consolation]
		if hard_xp != "":
			result += "  " + hard_xp
		if hard_resolve != "":
			result += "  " + hard_resolve
	else:
		data.kills += 1
		data.streak += 1
		var streak_bonus: int = 2 if int(data.streak) > 0 and int(data.streak) % 3 == 0 else 0
		data.bag += reward + streak_bonus
		var elite_relic_bonus: int = int(behavior.get("relic_bonus", 0)) if elite else 0
		add_relic_charge((18 if elite else 9) + elite_relic_bonus + mini(int(data.streak), 5))
		var clean_xp: String = award_xp(enemy_xp_value(kind, elite))
		var clean_resolve: String = add_resolve(4) if elite else ""
		result = "%s defeated! +%d coins." % [enemy_name, reward + streak_bonus]
		if clean_xp != "":
			result += "  " + clean_xp
		if clean_resolve != "":
			result += "  " + clean_resolve
		if elite and rng.randf() < float(behavior.get("gem_chance", 0.22)):
			data.gems += 1
			result += " Found 1 gem!"
		if streak_bonus > 0:
			result += " Streak bonus!"
	if int(data.relic_charge) >= 100:
		result += " Relic meter full — next gear is Rare or better."
	return result

func collect_gloomcap() -> String:
	data.gloomcaps += 1
	var result: String = "Gloomcap collected! Regional collection: %d." % int(data.gloomcaps)
	var resolve_note: String = add_resolve(3)
	if resolve_note != "":
		result += "  " + resolve_note
	if int(data.gloomcaps) % 3 == 0:
		data.gems += 1
		result += "  Collector milestone: +1 gem!"
	return result

func jumpable_cell(cell: Dictionary) -> bool:
	if cell.is_empty() or bool(cell.get("cleared", false)):
		return false
	return str(cell.get("kind", "")) in ["spike"]

func collect_region_collectible(kind: String) -> String:
	match kind:
		"prismatic_pearl":
			data.prismatic_pearls += 1
			add_relic_charge(8)
			if int(data.prismatic_pearls) % 3 == 0:
				data.gems += 1
				return "Prismatic Pearl found! Every third pearl crystallizes into +1 gem."
			return "Prismatic Pearl found. The grotto collection grows."
		"ember_shard":
			data.ember_shards += 1
			add_relic_charge(12)
			if int(data.ember_shards) % 3 == 0:
				data.bag += 8
				return "Magma Ember Shard secured! Third shard bonus: +8 expedition coins."
			return "Magma Ember Shard secured. Relic energy surges."
		"skyfeather":
			data.skyfeathers += 1
			add_relic_charge(10)
			if int(data.skyfeathers) % 3 == 0:
				var feather_resolve: String = add_resolve(8)
				return "Skyfeather Relic recovered! Third feather bonus: " + feather_resolve
			return "Skyfeather Relic recovered from the high ruins."
		_:
			return ""

func route_hazard_name() -> String:
	match str(data.route):
		"gloomwood":
			return "ensnaring briars"
		"sunken_grotto":
			return "slick algae slope"
		"cinder_caldera":
			return "magma vent"
		"galecrest_spire":
			return "gale-force gust"
		_:
			return "thorns"

func jump_distance(direction: int = 0) -> int:
	if data.mode != "travel":
		return 1
	var lane: int = clampi(int(data.lane) + direction, -1, 1)
	var obstacle_row: int = int(data.row) + 1
	if obstacle_row >= STAGE_STEPS:
		return 1
	var obstacle: Dictionary = cell_at(obstacle_row, lane)
	if jumpable_cell(obstacle) and int(data.row) + 2 <= STAGE_STEPS:
		return 2
	return 1

func jump_hop(direction: int = 0) -> String:
	if data.mode != "travel":
		return ""
	var distance: int = jump_distance(direction)
	if distance <= 1:
		return hop(direction)
	data.lane = clampi(int(data.lane) + direction, -1, 1)
	var obstacle_row: int = int(data.row) + 1
	var obstacle: Dictionary = cell_at(obstacle_row, int(data.lane))
	var obstacle_name: String = "obstacle"
	if not obstacle.is_empty():
		if str(obstacle.kind) == "spike":
			obstacle_name = route_hazard_name()
		obstacle.cleared = true
	data.row += 2
	var cell: Dictionary = cell_at(int(data.row), int(data.lane))
	var landing_result: String = ""
	if not cell.is_empty() and not bool(cell.cleared):
		match str(cell.kind):
			"coin":
				var count: int = 2 + stat("coins") + (2 if data.route == "treasure" else 0)
				data.bag += count
				if rng.randf() < 0.12:
					data.potions.mana += 1
					landing_result = "+%d expedition coins + mana potion" % count
				else:
					landing_result = "+%d expedition coins" % count
			"gem":
				var amount: int = 2 if data.route == "frost" and rng.randf() < 0.25 else 1
				data.gems += amount
				add_relic_charge(10 * amount)
				landing_result = "Found %d gem%s! Relic energy rises." % [amount, "" if amount == 1 else "s"]
			"heal":
				data.potions.heal += 1
				landing_result = "Found a healing potion."
			"spike":
				var thorn_damage: int = 2 if danger_level() >= 4 else 1
				data.hp -= thorn_damage
				data.streak = 0
				landing_result = "Hit the %s! Lost %d heart%s." % [route_hazard_name(), thorn_damage, "" if thorn_damage == 1 else "s"]
			"campfire":
				data.mode = "campfire"
				landing_result = "A roadside campfire crackles beside the trail."
			"fishing":
				data.mode = "fishing"
				landing_result = "A quiet pool ripples beside the road."
			"gear_cache":
				var cache_loot: String = award_gear(false, true, "ROADSIDE GEAR CACHE")
				if rng.randf() < 0.30:
					data.gems += 1
					cache_loot += " + 1 gem"
				landing_result = "Hidden cache: " + cache_loot
			"gloomcap":
				landing_result = collect_gloomcap()
			"prismatic_pearl", "ember_shard", "skyfeather":
				landing_result = collect_region_collectible(str(cell.kind))
			"rare_event":
				landing_result = resolve_rare_event()
			"slime", "goblin", "kobold", "ogre":
				landing_result = resolve_enemy(str(cell.kind), enemy_active(cell), enemy_elite(cell))
		var objective_note: String = progression_record_cell(str(cell.kind), landing_result)
		if objective_note != "":
			landing_result += "  " + objective_note
		cell.cleared = true
	var result: String = "Jumped cleanly over the %s!" % obstacle_name
	if landing_result != "":
		result += " " + landing_result
	data.turn += 1
	data.last = result
	if data.hp <= 0:
		defeat()
	elif data.row >= STAGE_STEPS and data.mode == "travel":
		finish_room()
	return str(data.last)

func hop(direction: int) -> String:
	if data.mode != "travel":
		return ""
	data.lane = clampi(int(data.lane) + direction, -1, 1)
	data.row += 1
	var cell: Dictionary = cell_at(int(data.row), int(data.lane))
	var result: String = "A little further along the road."
	if not cell.is_empty() and not bool(cell.cleared):
		match str(cell.kind):
			"coin":
				var count: int = 2 + stat("coins") + (2 if data.route == "treasure" else 0)
				data.bag += count
				if rng.randf() < 0.12:
					data.potions.mana += 1
					result = "+%d expedition coins + mana potion" % count
				else:
					result = "+%d expedition coins" % count
			"gem":
				var amount: int = 2 if data.route == "frost" and rng.randf() < 0.25 else 1
				data.gems += amount
				add_relic_charge(10 * amount)
				result = "Found %d gem%s! Relic energy rises." % [amount, "" if amount == 1 else "s"]
			"heal":
				data.potions.heal += 1
				result = "Found a healing potion."
			"spike":
				var thorn_damage: int = 2 if danger_level() >= 4 else 1
				data.hp -= thorn_damage
				data.streak = 0
				result = "%s! Lost %d heart%s. Look for the clear tiles." % [route_hazard_name().capitalize(), thorn_damage, "" if thorn_damage == 1 else "s"]
			"campfire":
				data.mode = "campfire"
				result = "A roadside campfire crackles beside the trail. No rush — listen and look around."
			"fishing":
				data.mode = "fishing"
				result = "A quiet pool ripples beside the road. Time one cast for a chance at fish, gems, or gear."
			"gear_cache":
				var cache_loot: String = award_gear(false, true, "ROADSIDE GEAR CACHE")
				if rng.randf() < 0.30:
					data.gems += 1
					cache_loot += " + 1 gem"
				result = "Hidden cache: " + cache_loot
			"gloomcap":
				result = collect_gloomcap()
			"prismatic_pearl", "ember_shard", "skyfeather":
				result = collect_region_collectible(str(cell.kind))
			"rare_event":
				result = resolve_rare_event()
			"slime", "goblin", "kobold", "ogre":
				result = resolve_enemy(str(cell.kind), enemy_active(cell), enemy_elite(cell))
		var objective_note: String = progression_record_cell(str(cell.kind), result)
		if objective_note != "":
			result += "  " + objective_note
		cell.cleared = true
	data.turn += 1
	data.last = result
	if data.hp <= 0:
		defeat()
	elif data.row >= STAGE_STEPS and data.mode == "travel":
		finish_room()
	return str(data.last)

func leave_campfire() -> void:
	if data.mode == "campfire":
		data.mode = "travel"
		data.last = "The embers fade behind you. The road continues."

func leave_fishing() -> void:
	if data.mode == "fishing":
		data.mode = "travel"
		data.last = "You leave the pool undisturbed and return to the road."

func resolve_fishing(accuracy: float) -> String:
	if data.mode != "fishing":
		return ""
	data.mode = "travel"
	var quality: float = clampf(accuracy, 0.0, 1.0)
	if quality <= 0.0:
		data.last = "The ripple slipped past the hook. Nothing caught this time."
		return str(data.last)
	data.fish_caught += 1
	var roll: float = rng.randf()
	var gear_cutoff: float = 0.12 + quality * 0.12
	var gem_cutoff: float = gear_cutoff + 0.22 + quality * 0.12
	if roll < gear_cutoff:
		var gear_text: String = award_gear(quality >= 0.88, true, "FISHING TREASURE")
		data.last = "The line goes heavy — treasure! " + gear_text
	elif roll < gem_cutoff:
		var gems_found: int = 2 if quality >= 0.82 else 1
		data.gems += gems_found
		add_relic_charge(12 * gems_found)
		data.last = "A river gem flashes beneath the water. +%d gem%s." % [gems_found, "" if gems_found == 1 else "s"]
	else:
		var fish_value: int = 4 + int(round(quality * 7.0))
		var fish_portions: int = 2 if quality >= 0.90 else 1
		data.bag += fish_value
		data.fish_stock += fish_portions
		if quality >= 0.90 and rng.randf() < 0.35:
			data.potions.heal += 1
			data.last = "Perfect catch! Rare fish worth %d coins + %d cat-fish + healing potion." % [fish_value, fish_portions]
		else:
			data.last = "Caught a trail fish worth %d expedition coins. +%d fish for the cat pantry." % [fish_value, fish_portions]
	return str(data.last)

func register_special_popup(chosen: Dictionary) -> void:
	var rarity: String = str(chosen.get("rarity", "COMMON"))
	if rarity not in ["LEGENDARY", "UNIQUE"]:
		return
	if not data.popup.is_empty():
		return
	data.popup = {
		"tag": "%s FIND" % rarity,
		"heading": str(chosen.name),
		"body": "%s\nThis item is permanent and can be equipped at a rest area." % str(chosen.text)
	}

func award_gear(force_rare: bool = false, popup_all: bool = false, popup_tag: String = "GEAR FIND") -> String:
	var meter_charged: bool = int(data.relic_charge) >= 100
	var charged: bool = force_rare or meter_charged
	var roll: float = rng.randf()
	var rarity: String = "COMMON"
	if charged:
		if meter_charged:
			data.relic_charge = maxi(0, int(data.relic_charge) - 100)
		if roll < 0.04:
			rarity = "UNIQUE"
		elif roll < 0.18:
			rarity = "LEGENDARY"
		elif roll < 0.46:
			rarity = "EPIC"
		else:
			rarity = "RARE"
	else:
		if roll < 0.015:
			rarity = "UNIQUE"
		elif roll < 0.055:
			rarity = "LEGENDARY"
		elif roll < 0.14:
			rarity = "EPIC"
		elif roll < 0.34:
			rarity = "RARE"
		elif roll < 0.66:
			rarity = "UNCOMMON"
	var candidates: Array = []
	for gear in Catalog.GEAR:
		if gear.rarity == rarity:
			candidates.append(gear)
	if candidates.is_empty():
		for gear in Catalog.GEAR:
			if gear.rarity == "COMMON":
				candidates.append(gear)
	var unowned: Array = []
	for gear in candidates:
		if gear.id not in data.inventory:
			unowned.append(gear)
	var pool: Array = unowned if not unowned.is_empty() else candidates
	var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	if chosen.id in data.inventory:
		var duplicate_reward: int = 8
		if chosen.rarity == "LEGENDARY":
			duplicate_reward = 12
		elif chosen.rarity == "UNIQUE":
			duplicate_reward = 16
		data.coins += duplicate_reward
		add_relic_charge(15)
		return "%s duplicate → %d banked coins + relic charge" % [chosen.name, duplicate_reward]
	data.inventory.append(chosen.id)
	if popup_all and data.popup.is_empty():
		data.popup = {
			"tag": popup_tag,
			"heading": "%s  [%s]" % [str(chosen.name), str(chosen.rarity)],
			"body": "%s\nAdded permanently to your collection." % str(chosen.text)
		}
	else:
		register_special_popup(chosen)
	return "NEW • %s [%s]" % [chosen.name, chosen.rarity]

func forge_with_gems() -> String:
	if data.mode not in ["camp", "rest", "choice"]:
		return "Gem forging is only available at a safe waypoint."
	if int(data.gems) < 6:
		data.last = "You need %d more gems for a Rare+ forge." % (6 - int(data.gems))
		return str(data.last)
	data.gems -= 6
	var saved_relic: int = int(data.relic_charge)
	var result: String = award_gear(true, true, "GEM FORGE")
	data.relic_charge = saved_relic
	data.last = "Gem forge: " + result
	return str(data.last)

func finish_room() -> void:
	data.stage += 1
	data.hp = mini(max_hp(), int(data.hp) + stat("heal"))
	var objective_reward: String = claim_road_objective()
	var route_xp: String = award_xp(20)
	var route_resolve: String = add_resolve(12)
	var cat_road_bonus: int = cat_buff_coins()
	if cat_road_bonus > 0:
		data.bag += cat_road_bonus
	var cat_status: String = cat_adventure_tick()
	var loot: String = award_gear()
	if data.route == "forge":
		loot += "\n" + award_gear()
	elif data.route == "frost":
		data.gems += 1
		loot += "\n+1 guaranteed frost gem"
		if rng.randf() < 0.35:
			loot += "\n" + award_gear()
	elif data.route == "fen":
		add_relic_charge(18)
		loot += "\n+18 relic charge"
	elif data.route == "sunken_grotto":
		data.gems += 1
		loot += "\n+1 grotto gem"
		if rng.randf() < 0.25:
			data.fish_stock += 1
			loot += "\n+1 preserved cave fish for the cat pantry"
	elif data.route == "cinder_caldera":
		add_relic_charge(24)
		data.bag += 10
		loot += "\n+24 relic charge\n+10 expedition coins from ember salvage"
	elif data.route == "galecrest_spire":
		add_relic_charge(22)
		var summit_resolve: String = add_resolve(6)
		loot += "\n+22 relic charge"
		if summit_resolve != "":
			loot += "\n" + summit_resolve + " from summit mastery"
	data.last = "WAYPOINT REWARD
Found: " + loot
	if objective_reward != "":
		data.last += "
" + objective_reward
	if route_xp != "":
		data.last += "\n" + route_xp
	if route_resolve != "":
		data.last += "\n" + route_resolve
	if cat_road_bonus > 0:
		data.last += "\nCat Road Luck: +%d expedition coin%s." % [cat_road_bonus, "" if cat_road_bonus == 1 else "s"]
	if cat_status != "":
		data.last += "\n" + cat_status
	data.last += "\nGear is permanent. Equip it at a rest area."
	data.mode = "reward"

func after_reward() -> void:
	if data.route == "shrine":
		data.mode = "shrine"
	elif data.route == "treasure":
		data.mode = "traveler"
	else:
		next_stage()

func next_stage() -> void:
	if int(data.stage) >= 6:
		data.mode = "boss_intro"
		return
	if int(data.stage) == 3:
		# Mid-expedition checkpoint banks loose coins only. Hearts and mana carry
		# forward so attrition, healing gear, potions, and route choices matter.
		bank()
	# Every normal road ends at one simple marker that sends the player to camp.
	data.mode = "road_end"

func bank() -> void:
	data.coins += int(data.bag)
	data.bag = 0

func boss_profile() -> Dictionary:
	return BossService.profile_for_route(str(data.route))

func boss_name() -> String:
	return BossService.boss_name(str(data.route))

func boss_max_hp() -> int:
	return BossService.max_hp(self)

func boss_damage() -> int:
	return BossService.damage(self)

func start_boss() -> void:
	BossService.start(self)

func boss_hop(direction: int) -> String:
	return BossService.resolve_hop(self, direction)

func defeat() -> void:
	data.popup = {}
	data.hp = 0
	data.last = "The lantern brought you home. Lost %d unbanked coins.\nYour XP, Resolve, equipment, cosmetics, and banked coins are safe." % int(data.bag)
	data.bag = 0
	data.mode = "defeat"

func return_camp() -> void:
	var previous_mode: String = str(data.mode)
	data.popup = {}
	data.mode = "camp"
	# Camp is a navigation/supply hub, not a free full-heal trigger. Current
	# hearts and mana persist. Explicit healing comes from trail-heal perks,
	# potions, authored recovery sources, or a one-heart post-defeat revival.
	# Only explicit new-character selection starts at full resources in begin().
	data.hp = clampi(int(data.hp), 0, max_hp())
	data.mana = clampi(int(data.mana), 0, max_mana())
	data.blessing = 0
	data.streak = 0
	data.row = 0
	data.lane = 0
	# Returning from the road-end waypoint preserves expedition stage. Other
	# home returns end the expedition and clear loose expedition state.
	if previous_mode != "road_end":
		data.stage = 0
		data.cells = []
		data.bag = 0
	data.last = "Lantern Camp is safe, but hearts do not refill automatically. Use supplies if needed."

func revive_at_camp() -> bool:
	if data.mode != "camp" or int(data.hp) > 0:
		return false
	# Defeat recovery is explicit and minimal: revive to one heart only.
	# It never refills mana and cannot be repeated while already alive.
	data.hp = 1
	data.last = "The lantern rekindles one heart. Recover further with supplies or trail-heal effects."
	return true

func leave_camp_for_crossroads() -> void:
	if data.mode != "camp":
		return
	if int(data.hp) <= 0:
		data.last = "You need at least one heart before leaving Lantern Camp."
		return
	# Stage 0 with no active road means a new expedition cycle for the SAME
	# character. Preserve current HP/mana instead of calling begin() and healing.
	if int(data.stage) == 0 and data.cells.is_empty():
		prepare_new_expedition()
		return
	data.popup = {}
	data.mode = "choice"
	data.row = 0
	data.lane = 0
	data.last = "Crossroads ahead. Choose the next road."

func equip(id: String) -> void:
	if data.mode not in ["camp", "rest", "choice"] or id not in data.inventory:
		return
	var gear: Dictionary = Catalog.item(id)
	data.equipped[gear.slot] = id
	data.hp = mini(int(data.hp), max_hp())

func save_game() -> bool:
	var temp: String = save_path + ".tmp"
	var f = FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		notice = "Save failed. Check available storage."
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var err: int = DirAccess.rename_absolute(temp, save_path)
	if err != OK:
		notice = "Save failed (%d). Your previous save is preserved." % err
		return false
	notice = "Progress saved"
	return true

func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.get("version") not in [18, 18.0]:
		return false
	if value.get("class_id") not in Catalog.CLASSES or not value.get("popup") is Dictionary:
		return false
	if str(value.get("environment", "sunny")) not in Catalog.ENVIRONMENTS:
		return false
	if not value.popup.is_empty():
		for key in ["heading", "body", "tag"]:
			if not value.popup.get(key) is String:
				return false
	for key in data:
		if not value.has(key):
			return false
	for key in ["hp", "mana", "coins", "bag", "stage", "row", "lane", "seed", "wins", "runs", "skin", "camp_level", "camp_renown", "rare_events_seen", "kills", "level", "xp", "resolve", "turn", "boss_hp", "danger", "target", "blessing", "streak", "relic_charge", "gems", "fish_caught", "fish_stock", "cat_food_stock", "cat_satiety", "cat_bond_xp", "gloomcaps", "prismatic_pearls", "ember_shards", "skyfeathers"]:
		if not (value[key] is int or value[key] is float):
			return false
	if int(value.hp) < 0 or int(value.mana) < 0 or int(value.coins) < 0 or int(value.bag) < 0 or int(value.wins) < 0 or int(value.runs) < 0 or int(value.kills) < 0 or int(value.camp_renown) < 0 or int(value.rare_events_seen) < 0:
		return false
	if int(value.streak) < 0 or int(value.relic_charge) < 0 or int(value.relic_charge) > 100 or int(value.gems) < 0 or int(value.fish_caught) < 0 or int(value.fish_stock) < 0 or int(value.cat_food_stock) < 0 or int(value.cat_food_stock) > Catalog.CAT_FOOD_STOCK_CAP or int(value.cat_satiety) < 0 or int(value.cat_satiety) > 100 or int(value.cat_bond_xp) < 0 or int(value.cat_bond_xp) > (Catalog.CAT_LEVEL_CAP - 1) * Catalog.CAT_BOND_XP_PER_LEVEL or int(value.gloomcaps) < 0 or int(value.prismatic_pearls) < 0 or int(value.ember_shards) < 0 or int(value.skyfeathers) < 0:
		return false
	if int(value.level) < 1 or int(value.level) > LEVEL_CAP or int(value.xp) < 0:
		return false
	if int(value.resolve) < 0 or int(value.resolve) >= 100:
		return false
	if int(value.level) < LEVEL_CAP and int(value.xp) >= xp_to_next(int(value.level)):
		return false
	if int(value.level) == LEVEL_CAP and int(value.xp) != 0:
		return false
	if not value.inventory is Array or not value.cells is Array or not value.equipped is Dictionary or not value.potions is Dictionary:
		return false
	if not value.road_objective is Dictionary or not ProgressionService.valid_objective(value.road_objective):
		return false
	if not value.cosmetics_owned is Array or not value.cosmetics_equipped is Dictionary:
		return false
	if not value.cat_owned is bool or not value.cat_design is Dictionary or not value.cat_offer is Dictionary:
		return false
	if not valid_cat_design(value.cat_offer):
		return false
	if bool(value.cat_owned):
		if not valid_cat_design(value.cat_design):
			return false
	else:
		if not value.cat_design.is_empty():
			return false
		if int(value.cat_satiety) != 0 or int(value.cat_bond_xp) != 0 or int(value.cat_food_stock) != 0:
			return false
	for slot in ["skin", "head", "back", "face"]:
		if not value.cosmetics_equipped.has(slot):
			return false
		var cosmetic_id: String = str(value.cosmetics_equipped[slot])
		if cosmetic_id != "":
			var cosmetic_item: Dictionary = Catalog.cosmetic(cosmetic_id)
			if cosmetic_item.is_empty() or str(cosmetic_item.get("slot", "")) != slot or cosmetic_id not in value.cosmetics_owned:
				return false
	for cosmetic_id in value.cosmetics_owned:
		if Catalog.cosmetic(str(cosmetic_id)).is_empty():
			return false
	if not value.potions.has("heal") or not value.potions.has("mana"):
		return false
	if not (value.potions.heal is int or value.potions.heal is float) or not (value.potions.mana is int or value.potions.mana is float):
		return false
	if int(value.potions.heal) < 0 or int(value.potions.mana) < 0:
		return false
	if value.mode not in ["camp", "road_end", "choice", "travel", "campfire", "fishing", "reward", "rest", "shrine", "traveler", "boss_intro", "boss", "victory", "defeat"]:
		return false
	if value.route not in Catalog.ROUTES or not value.last is String:
		return false
	if int(value.row) < 0 or int(value.row) > STAGE_STEPS or absi(int(value.lane)) > 1:
		return false
	if int(value.stage) < 0 or int(value.stage) > 6 or int(value.camp_level) < 0 or int(value.camp_level) > 3:
		return false
	if int(value.skin) < 0 or int(value.skin) >= Catalog.SKINS.size():
		return false
	for id in value.inventory:
		if Catalog.item(str(id)).is_empty():
			return false
	for slot in ["core", "shell", "charm"]:
		if not value.equipped.has(slot):
			return false
		var id: String = str(value.equipped[slot])
		if id != "" and (id not in value.inventory or Catalog.item(id).get("slot", "") != slot):
			return false
	if value.mode in ["travel", "campfire", "fishing"] and value.cells.size() != CELL_COUNT:
		return false
	var seen: Dictionary = {}
	for cell in value.cells:
		if not cell is Dictionary:
			return false
		for key in ["row", "lane", "kind", "cleared"]:
			if not cell.has(key):
				return false
		if not (cell.row is float or cell.row is int) or not (cell.lane is float or cell.lane is int) or not cell.cleared is bool:
			return false
		if cell.has("elite") and not cell.elite is bool:
			return false
		if int(cell.row) < 1 or int(cell.row) > GENERATED_ROWS or absi(int(cell.lane)) > 1 or cell.kind not in ["empty", "coin", "gem", "heal", "spike", "campfire", "fishing", "gear_cache", "gloomcap", "prismatic_pearl", "ember_shard", "skyfeather", "rare_event", "slime", "goblin", "kobold", "ogre"]:
			return false
		var cell_key: String = "%d:%d" % [int(cell.row), int(cell.lane)]
		if seen.has(cell_key):
			return false
		seen[cell_key] = true
	return true

func migrate_legacy_save(parsed: Dictionary) -> Dictionary:
	var migrated: Dictionary = parsed.duplicate(true)
	var old_version: int = int(migrated.get("version", 1))
	if old_version <= 1:
		migrated.class_id = "adventurer"
		migrated.popup = {}
	if old_version <= 2:
		migrated.mana = 3
		migrated.potions = {"heal":1, "mana":1}
	if not migrated.has("popup") or not migrated.popup is Dictionary:
		migrated.popup = {}
	if not migrated.has("mana"):
		migrated.mana = 3
	if not migrated.has("potions") or not migrated.potions is Dictionary:
		migrated.potions = {"heal":1, "mana":1}
	if not migrated.has("streak"):
		migrated.streak = 0
	if not migrated.has("relic_charge"):
		migrated.relic_charge = 0
	if not migrated.has("gems"):
		migrated.gems = 0
	if not migrated.has("fish_caught"):
		migrated.fish_caught = 0
	if not migrated.has("fish_stock"):
		migrated.fish_stock = 0
	if not migrated.has("cat_food_stock"):
		migrated.cat_food_stock = 0
	if not migrated.has("cat_owned") or not migrated.cat_owned is bool:
		migrated.cat_owned = false
	if not migrated.has("cat_design") or not migrated.cat_design is Dictionary:
		migrated.cat_design = {}
	if not migrated.has("cat_offer") or not migrated.cat_offer is Dictionary or not valid_cat_design(migrated.cat_offer):
		migrated.cat_offer = random_cat_design()
	if not migrated.has("cat_satiety"):
		migrated.cat_satiety = 0
		migrated.cat_bond_xp = 0
	if not migrated.has("cat_bond_xp"):
		migrated.cat_bond_xp = 0
	if not bool(migrated.cat_owned):
		migrated.cat_design = {}
		migrated.cat_satiety = 0
		migrated.cat_bond_xp = 0
		migrated.cat_food_stock = 0
	if not migrated.has("gloomcaps"):
		migrated.gloomcaps = 0
	if not migrated.has("prismatic_pearls"):
		migrated.prismatic_pearls = 0
	if not migrated.has("ember_shards"):
		migrated.ember_shards = 0
	if not migrated.has("skyfeathers"):
		migrated.skyfeathers = 0
	if not migrated.has("camp_renown"):
		migrated.camp_renown = 0
	if not migrated.has("road_objective") or not migrated.road_objective is Dictionary:
		migrated.road_objective = {}
	if not migrated.has("rare_events_seen"):
		migrated.rare_events_seen = 0
	migrated.camp_level = ProgressionService.camp_level_for_renown(int(migrated.camp_renown))
	if not migrated.has("level"):
		# Preserve veteran progress when migrating pre-level-system saves.
		migrated.level = clampi(1 + int(migrated.get("wins", 0)) * 2 + floori(float(migrated.get("kills", 0)) / 10.0), 1, LEVEL_CAP)
	if not migrated.has("xp"):
		migrated.xp = 0
	if migrated.has("pending_xp"):
		# Rollback migration: immediately credit XP earned under the temporary
		# pending-XP rule so no player loses progress in this update.
		var carry_xp: int = maxi(0, int(migrated.get("pending_xp", 0)))
		migrated.erase("pending_xp")
		while carry_xp > 0 and int(migrated.level) < LEVEL_CAP:
			var needed_xp: int = 30 + (int(migrated.level) - 1) * 8
			var room_xp: int = maxi(0, needed_xp - int(migrated.xp))
			if carry_xp < room_xp:
				migrated.xp = int(migrated.xp) + carry_xp
				carry_xp = 0
			else:
				carry_xp -= room_xp
				migrated.level = int(migrated.level) + 1
				migrated.xp = 0
	if not migrated.has("resolve"):
		migrated.resolve = 0
	if int(migrated.level) >= LEVEL_CAP:
		migrated.level = LEVEL_CAP
		migrated.xp = 0
	if not migrated.has("cosmetics_owned") or not migrated.cosmetics_owned is Array:
		migrated.cosmetics_owned = []
	if not migrated.has("cosmetics_equipped") or not migrated.cosmetics_equipped is Dictionary:
		migrated.cosmetics_equipped = {"skin":"", "head":"", "back":"", "face":""}
	else:
		for slot in ["skin", "head", "back", "face"]:
			if not migrated.cosmetics_equipped.has(slot):
				migrated.cosmetics_equipped[slot] = ""
	if not migrated.has("environment") or str(migrated.environment) not in Catalog.ENVIRONMENTS:
		migrated.environment = roll_environment(str(migrated.get("route", "moss")))
	# v0.4 lengthens a road from 10 to 18 hop decisions. Existing live rooms are extended with a gentle, readable finish.
	if str(migrated.get("mode", "")) == "travel" and migrated.get("cells") is Array and migrated.cells.size() == 27:
		for row in range(10, STAGE_STEPS):
			for lane in range(-1, 2):
				var kind: String = "empty"
				if lane == int(migrated.get("lane", 0)) and row % 2 == 0:
					kind = "coin"
				elif lane != int(migrated.get("lane", 0)) and (row + lane) % 4 == 0:
					kind = "coin"
				migrated.cells.append({"row":row, "lane":lane, "kind":kind, "cleared":false})
	migrated.version = 18
	return migrated

func load_game() -> bool:
	for path in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var parsed = parser.data
		if parsed is Dictionary and parsed.get("version") in [1, 1.0, 2, 2.0, 3, 3.0, 4, 4.0, 5, 5.0, 6, 6.0, 7, 7.0, 8, 8.0, 9, 9.0, 10, 10.0, 11, 11.0, 12, 12.0, 13, 13.0, 14, 14.0, 15, 15.0, 16, 16.0, 17, 17.0]:
			parsed = migrate_legacy_save(parsed)
		if valid_save(parsed):
			data = parsed
			notice = "Backup save recovered" if path.ends_with(".bak") else "Welcome back"
			return true
	if FileAccess.file_exists(save_path):
		notice = "Save could not be read. A new journey is available."
	return false
