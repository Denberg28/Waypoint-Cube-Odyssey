extends SceneTree
const State = preload("res://scripts/state.gd")
const Catalog = preload("res://scripts/catalog.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + text)

func _initialize() -> void:
	var s = State.new()
	check(s.max_hp() == 6 and s.attack() == 1, "starting stats")
	s.begin()
	check(s.data.mode == "choice" and s.data.runs == 1, "begin expedition")
	# Verify generated rooms have a fully reachable hazard-free corridor.
	for route in Catalog.ROUTES:
		for seed_index in range(30):
			s.make_room(route)
			check(s.data.cells.size() == State.CELL_COUNT, "room size")
			var reachable: Array = [0]
			for row in range(1, State.STAGE_STEPS):
				var next: Array = []
				for lane in range(-1, 2):
					var cell: Dictionary = s.cell_at(row, lane)
					if cell.kind not in ["empty", "coin", "heal"]:
						continue
					for previous in reachable:
						if absi(lane - int(previous)) <= 1:
							next.append(lane)
							break
				reachable = next
			check(not reachable.is_empty(), "safe corridor " + str(route))
	s.make_room("moss")
	s.data.cells = []
	s.data.lane = -1
	s.hop(-1)
	check(s.data.lane == -1 and s.data.row == 1, "lane clamp")
	s.data.cells = [{"row":2,"lane":-1,"kind":"coin","cleared":false}]
	s.hop(0)
	check(s.data.bag == 2, "coin reward")
	var heals_before: int = int(s.data.potions.heal)
	s.data.hp = 3
	s.data.cells = [{"row":3,"lane":-1,"kind":"heal","cleared":false}]
	s.hop(0)
	check(int(s.data.potions.heal) == heals_before + 1 and s.data.hp == 3, "healing potion pickup")
	s.data.cells = [{"row":4,"lane":-1,"kind":"spike","cleared":false}]
	s.hop(0)
	check(s.data.hp == 4, "thorn damage")
	# Crossing a live telegraph deals damage; the next phase permits a stomp.
	s.make_room("moss")
	s.data.cells = [{"row":1,"lane":0,"kind":"slime","cleared":false}]
	s.data.hp = 6
	s.hop(0)
	check(s.data.hp == 5, "active monster damages player")
	s.make_room("moss")
	s.data.cells = [{"row":1,"lane":0,"kind":"slime","cleared":false}]
	s.data.turn = 1
	s.data.hp = 6
	s.hop(0)
	check(s.data.hp == 6 and s.data.kills == 1, "safe stomp kills monster")
	# Equipment restrictions and stat effects.
	s.data.inventory = ["storm", "moon", "star"]
	s.equip("storm")
	check(s.data.equipped.core == "", "cannot equip on trail")
	s.return_camp()
	s.equip("storm")
	s.equip("moon")
	s.equip("star")
	check(s.attack() == 3 and s.max_hp() == 9 and s.stat("coins") == 3, "equipment stats")
	s.data.coins = 17
	s.data.bag = 22
	s.defeat()
	check(s.data.bag == 0 and s.data.coins == 17 and s.data.inventory.size() == 3, "defeat preserves permanent progress")
	s.return_camp()
	s.data.stage = 3
	s.data.bag = 14
	s.next_stage()
	check(s.data.mode == "rest" and s.data.coins == 31 and s.data.hp == 9, "halfway camp banks and heals")
	# Simulate complete expedition to victory with reachable safe corridors.
	var run = State.new()
	run.begin()
	for stage in range(6):
		run.make_room("moss")
		var path: Array = find_path(run, 1, 0)
		check(path.size() == State.GENERATED_ROWS, "complete safe path")
		for lane in path:
			run.hop(int(lane) - int(run.data.lane))
		run.hop(0)
		check(run.data.mode == "reward", "trail reward")
		run.after_reward()
		if stage == 2:
			check(run.data.mode == "rest", "expedition midpoint")
			run.data.mode = "choice"
	check(run.data.mode == "boss_intro", "six trails unlock guardian")
	run.start_boss()
	var rounds: int = 0
	while run.data.mode == "boss" and rounds < 30:
		var target: int = int(run.data.target)
		check(absi(target - int(run.data.lane)) <= 1 and target != int(run.data.danger), "boss strike reachable and safe")
		run.boss_hop(target - int(run.data.lane))
		rounds += 1
	check(run.data.mode == "victory" and run.data.wins == 1 and run.data.bag == 0, "guardian victory banks rewards")
	check(run.data.inventory.size() > 0, "expedition grants equipment")
	# Challenge / collection loop: clean wins build streak and relic charge; charge guarantees rare+ gear.
	var challenge = State.new()
	challenge.begin("knight")
	challenge.make_room("forge")
	challenge.data.row = 7
	challenge.data.turn = 1
	challenge.data.cells = [{"row":8,"lane":0,"kind":"goblin","cleared":false}]
	challenge.hop(0)
	check(int(challenge.data.relic_charge) > 0, "combat charges relic meter")
	challenge.data.relic_charge = 100
	var before_gear: int = challenge.data.inventory.size()
	var loot_text: String = challenge.award_gear()
	check(challenge.data.inventory.size() == before_gear + 1 or loot_text.contains("duplicate"), "charged gear reward resolves")
	check(int(challenge.data.relic_charge) < 100, "charged reward consumes relic meter")
	# Cosmetic marketplace: banked coins purchase permanent visual customization only.
	var market = State.new()
	market.data.mode = "camp"
	market.data.coins = 500
	check(market.buy_cosmetic("skin_sage"), "cosmetic purchase succeeds")
	check("skin_sage" in market.data.cosmetics_owned and market.data.cosmetics_equipped.skin == "skin_sage", "purchased cosmetic owned and equipped")
	check(int(market.data.coins) == 380, "cosmetic price deducted from bank")
	check(market.equip_cosmetic("skin_sage"), "owned cosmetic equips")
	check(market.clear_cosmetic("skin") and market.data.cosmetics_equipped.skin == "", "cosmetic slot clears to default")
	var before_attack: int = market.attack()
	market.buy_cosmetic("head_trail_cap")
	check(market.attack() == before_attack, "cosmetics do not alter combat stats")

	# Save round trip, malformed input, and recovery from previous save.
	var original = State.new()
	original.save_path = "user://waypoint_TEST_ONLY.json"
	original.begin()
	original.make_room("forge")
	original.data.coins = 81
	check(original.save_game(), "save write")
	var restored = State.new()
	restored.save_path = original.save_path
	check(restored.load_game(), "save load")
	check(restored.data == JSON.parse_string(JSON.stringify(original.data)), "full state round trip")
	original.data.coins = 99
	check(original.save_game(), "second save creates backup")
	var f = FileAccess.open(original.save_path, FileAccess.WRITE)
	f.store_string("broken save")
	f.close()
	check(restored.load_game() and int(restored.data.coins) == 81, "backup recovery")
	var invalid: Dictionary = original.data.duplicate(true)
	invalid.inventory = 42
	check(not original.valid_save(invalid), "reject malformed inventory")
	invalid = original.data.duplicate(true)
	invalid.cells[0].row = "bad"
	check(not original.valid_save(invalid), "reject malformed cell")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(original.save_path + suffix):
			DirAccess.remove_absolute(original.save_path + suffix)
	print("STATE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func find_path(s, row: int, lane: int) -> Array:
	if row == State.STAGE_STEPS:
		return []
	for next in range(maxi(-1, lane - 1), mini(1, lane + 1) + 1):
		if s.cell_at(row, next).kind in ["empty", "coin", "heal"]:
			var tail: Array = find_path(s, row + 1, next)
			if tail.size() == State.GENERATED_ROWS - row:
				tail.push_front(next)
				return tail
	return []
