extends SceneTree

const State = preload("res://scripts/state.gd")
const Catalog = preload("res://scripts/catalog.gd")

var finished: bool = false

func _init() -> void:
	create_timer(12.0).timeout.connect(_watchdog)
	call_deferred("_run")

func _run() -> void:
	var game = State.new()
	if not game.valid_save(game.data):
		_fail("fresh reset state is not a valid v18 save", 2)
		return

	# Marketplace + cat companion.
	game.data.mode = "camp"
	var cosmetic: Dictionary = Catalog.COSMETICS[0]
	game.data.coins = Catalog.CAT_PRICE + int(cosmetic.price) + 100
	if not game.refresh_cat_offer() or not game.valid_cat_design(game.data.cat_offer):
		_fail("cat market offer refresh invalid", 3)
		return
	if not game.adopt_cat() or not bool(game.data.cat_owned):
		_fail("cat adoption failed", 4)
		return
	game.data.cat_satiety = 50
	game.data.fish_stock = 1
	if game.cat_level() != 1 or game.cat_rank_name() != "FAMILIAR":
		_fail("cat initial level/rank invariant failed", 5)
		return
	if not game.feed_cat() or int(game.data.fish_stock) != 0 or int(game.data.cat_satiety) != 80:
		_fail("cat feeding/satiety invariant failed", 6)
		return
	if int(game.data.cat_bond_xp) != Catalog.CAT_BOND_XP_PER_FEED:
		_fail("cat feed did not award Bond XP", 7)
		return

	# Marketplace cat food restores satiety only; it must never advance level/rank.
	game.data.cat_satiety = 40
	game.data.coins = 100
	var bond_before_food: int = int(game.data.cat_bond_xp)
	if not game.buy_cat_food(1):
		_fail("cat food purchase failed", 17)
		return
	if int(game.data.cat_food_stock) != 1:
		_fail("cat food pantry did not increment", 18)
		return
	if not game.feed_cat_food():
		_fail("cat food feeding failed", 19)
		return
	if int(game.data.cat_satiety) != 60:
		_fail("cat food satiety gain incorrect", 20)
		return
	if int(game.data.cat_bond_xp) != bond_before_food:
		_fail("cat food incorrectly awarded Bond XP", 21)
		return

	if game.cat_buff_coins() <= 0 or "ROAD LUCK" not in game.cat_buff_text():
		_fail("cat Road Luck buff did not activate", 8)
		return
	game.data.coins = maxi(int(game.data.coins), int(cosmetic.price))
	if not game.buy_cosmetic(str(cosmetic.id)) or not game.owns_cosmetic(str(cosmetic.id)):
		_fail("market cosmetic purchase failed", 6)
		return

	# Reproduce the status-panel regression: owned gear exists while all slots
	# are empty. Best-owned lookup must still work, and Equip Best must repair it.
	game.data.inventory = ["ember", "bark", "clover", "storm", "stone", "bell"]
	game.data.equipped = {"core":"", "shell":"", "charm":""}
	for slot in ["core", "shell", "charm"]:
		if game.best_owned_gear_id(slot) == "":
			_fail("best-owned gear lookup failed for " + slot, 15)
			return
	game.equip_best()
	for slot in ["core", "shell", "charm"]:
		if game.sanitized_equipped_id(slot) == "":
			_fail("Equip Best left an owned equipment slot empty: " + slot, 16)
			return

	# Every route must generate a complete, save-valid 18-step road.
	for route_id in Catalog.ROUTES:
		game.make_room(str(route_id))
		if str(game.data.route) != str(route_id):
			_fail("route selection mismatch for " + str(route_id), 7)
			return
		if game.data.cells.size() != State.CELL_COUNT:
			_fail("cell count mismatch for " + str(route_id), 8)
			return
		if game.data.road_objective.is_empty():
			_fail("road objective missing for " + str(route_id), 22)
			return
		if "No active road objective" in game.objective_text():
			_fail("road objective text invalid for " + str(route_id), 23)
			return
		if not game.valid_save(game.data):
			_fail("generated route is not save-valid: " + str(route_id), 9)
			return

	# Retention progression: completed road objectives grant permanent Camp Renown.
	game.data.mode = "travel"
	game.data.road_objective = {
		"id":"smoke_coin",
		"type":"coin",
		"label":"SMOKE OBJECTIVE",
		"description":"Collect 1 coin",
		"target":1,
		"progress":0,
		"complete":false,
		"claimed":false
	}
	var objective_note: String = game.progression_record_cell("coin", "+2 expedition coins")
	if "Objective complete" not in objective_note or not bool(game.data.road_objective.complete):
		_fail("objective progress/complete invariant failed", 24)
		return
	game.data.camp_renown = 1
	game.data.camp_level = 0
	var claim_text: String = game.claim_road_objective()
	if int(game.data.camp_renown) != 2 or int(game.data.camp_level) != 1:
		_fail("Camp Renown level-up invariant failed", 25)
		return
	if "OBJECTIVE COMPLETE" not in claim_text or "LANTERN CAMP LEVEL 1" not in claim_text:
		_fail("objective reward text missing progression feedback", 26)
		return

	# Rare road events remain bounded and save-safe.
	var seen_before: int = int(game.data.rare_events_seen)
	var rare_text: String = game.resolve_rare_event()
	if int(game.data.rare_events_seen) != seen_before + 1 or "Rare encounter" not in rare_text:
		_fail("rare road event resolution failed", 27)
		return
	if not game.valid_save(game.data):
		_fail("progression feature state is not save-valid", 28)
		return

	# Invalid external route input must degrade safely.
	game.make_room("__invalid_route__")
	if str(game.data.route) != "moss" or game.data.cells.size() != State.CELL_COUNT:
		_fail("invalid route fallback failed", 10)
		return

	# Expansion collectible state and ranked enemy visual data.
	game.collect_region_collectible("prismatic_pearl")
	game.collect_region_collectible("ember_shard")
	game.collect_region_collectible("skyfeather")
	if int(game.data.prismatic_pearls) != 1 or int(game.data.ember_shards) != 1 or int(game.data.skyfeathers) != 1:
		_fail("expansion collectible counters failed", 11)
		return
	for kind in ["slime", "goblin", "kobold", "ogre"]:
		var variant: Dictionary = game.enemy_visual_variant(kind, 5, 0, false)
		for key in ["body", "armor", "helmet", "weapon", "rank", "rank_name"]:
			if not variant.has(key):
				_fail("enemy visual variant missing %s for %s" % [key, kind], 12)
				return

	if not game.valid_save(game.data):
		_fail("combined feature state is not save-valid", 13)
		return

	finished = true
	print("FEATURE_SMOKE_OK routes=", Catalog.ROUTES.size(), " cat=", game.data.cat_design.get("name", ""), " cosmetic=", cosmetic.id)
	quit(0)

func _fail(message: String, code: int) -> void:
	finished = true
	push_error("FEATURE_SMOKE: " + message)
	quit(code)

func _watchdog() -> void:
	if finished:
		return
	push_error("FEATURE_SMOKE_TIMEOUT")
	quit(14)
