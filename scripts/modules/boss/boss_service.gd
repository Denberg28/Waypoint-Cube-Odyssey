extends RefCounted
const BossCatalog = preload("res://scripts/modules/boss/boss_catalog.gd")

static func boss_id_for_route(route_id: String) -> String:
	match route_id:
		"cinder_caldera", "forge":
			return "ember_colossus"
		"sunken_grotto", "fen":
			return "tide_warden"
		"galecrest_spire", "frost":
			return "gale_sentinel"
		_:
			return BossCatalog.DEFAULT_BOSS_ID

static func profile_for_route(route_id: String) -> Dictionary:
	return BossCatalog.BOSSES[boss_id_for_route(route_id)]

static func boss_name(route_id: String) -> String:
	return str(profile_for_route(route_id).name)

static func _pick_target(host, danger_lane: int) -> int:
	var choices: Array[int] = []
	for lane in range(-1, 2):
		if lane != danger_lane and absi(lane - int(host.data.lane)) <= 1:
			choices.append(lane)
	if choices.is_empty():
		for lane in range(-1, 2):
			if lane != danger_lane:
				choices.append(lane)
	var signature: int = absi(int(host.data.seed) + int(host.data.turn) * 31 + str(host.data.route).hash())
	return choices[signature % choices.size()]

static func advance_pattern(host) -> void:
	var boss: Dictionary = profile_for_route(str(host.data.route))
	var pattern: Array = boss.pattern
	host.data.danger = int(pattern[int(host.data.turn) % pattern.size()])
	host.data.target = _pick_target(host, int(host.data.danger))

static func start(host) -> void:
	var boss: Dictionary = profile_for_route(str(host.data.route))
	host.data.mode = "boss"
	host.data.row = 0
	host.data.lane = 0
	host.data.turn = 0
	host.data.boss_hp = int(boss.hp)
	host.data.danger = int(boss.pattern[0])
	host.data.target = _pick_target(host, int(host.data.danger))
	host.data.last = "%s awakens. Avoid %s and land on the mint rune." % [str(boss.name), str(boss.telegraph)]

static func resolve_hop(host, direction: int) -> String:
	if host.data.mode != "boss":
		return ""
	var boss: Dictionary = profile_for_route(str(host.data.route))
	host.data.lane = clampi(int(host.data.lane) + direction, -1, 1)
	if int(host.data.lane) == int(host.data.danger):
		var damage: int = host.enemy_damage(int(boss.damage))
		host.data.hp -= damage
		host.data.streak = 0
		host.data.last = "%s! Lost %d heart%s." % [str(boss.telegraph), damage, "" if damage == 1 else "s"]
	elif int(host.data.lane) == int(host.data.target):
		host.data.boss_hp -= host.attack()
		host.data.streak += 1
		host.add_relic_charge(8)
		host.data.last = "Rune strike! %d damage to %s." % [host.attack(), str(boss.name)]
	else:
		host.data.last = "Safe landing. Reach the mint rune to attack."

	host.data.turn += 1
	if int(host.data.hp) <= 0:
		host.defeat()
	elif int(host.data.boss_hp) <= 0:
		host.data.wins += 1
		host.add_relic_charge(int(boss.relic))
		host.data.bag += int(boss.reward)
		var boss_xp: String = host.award_xp(int(boss.xp))
		var boss_resolve: String = host.add_resolve(int(boss.resolve))
		host.bank()
		host.data.mode = "victory"
		host.data.last = "%s falls. +%d coins, all expedition coins banked." % [str(boss.name), int(boss.reward)]
		if boss_xp != "":
			host.data.last += "\n" + boss_xp
		if boss_resolve != "":
			host.data.last += "\n" + boss_resolve
		host.data.last += "\nFound: " + host.award_gear()
	else:
		advance_pattern(host)
	return str(host.data.last)
