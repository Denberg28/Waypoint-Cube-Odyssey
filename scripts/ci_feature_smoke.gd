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
		_fail("fresh reset state is not a valid v16 save", 2)
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
	if game.cat_buff_coins() <= 0 or "ROAD LUCK" not in game.cat_buff_text():
		_fail("cat Road Luck buff did not activate", 8)
		return
	if not game.buy_cosmetic(str(cosmetic.id)) or not game.owns_cosmetic(str(cosmetic.id)):
		_fail("market cosmetic purchase failed", 6)
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
		if not game.valid_save(game.data):
			_fail("generated route is not save-valid: " + str(route_id), 9)
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
