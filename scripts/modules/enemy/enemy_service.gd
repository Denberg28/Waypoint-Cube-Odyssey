extends RefCounted
const EnemyCatalog = preload("res://scripts/modules/enemy/enemy_catalog.gd")

static func enemy_profile(kind: String) -> Dictionary:
	return EnemyCatalog.ENEMIES.get(kind, EnemyCatalog.ENEMIES.get("slime", {}))

static func enemy_rank(host, kind: String, elite: bool = false) -> int:
	if elite:
		return 4
	var base: int = 1 + floori(float(int(host.data.stage)) / 2.0)
	if kind == "ogre":
		base += 1
	elif kind in ["goblin", "kobold"] and host.danger_level() >= 4:
		base += 1

	# Experienced characters can now meet Champion normal mobs on dangerous
	# late-expedition roads. Early characters keep the original rank curve.
	var player_level: int = int(host.data.get("level", 1))
	if player_level >= 9 and host.danger_level() >= 3:
		base += 1
	if player_level >= 17 and host.danger_level() >= 4:
		base += 1
	return clampi(base, 1, 4)

static func enemy_rank_name(host, kind: String, elite: bool = false) -> String:
	var rank: int = enemy_rank(host, kind, elite)
	return str(EnemyCatalog.ENEMY_RANKS.get(rank, {"name":"COMMON"}).get("name", "COMMON"))

static func enemy_visual_variant(host, kind: String, row: int = -1, lane: int = 0, elite: bool = false) -> Dictionary:
	var visual: Dictionary = EnemyCatalog.ENEMY_VISUALS.get(kind, EnemyCatalog.ENEMY_VISUALS.get("slime", {}))
	var palettes: Array = visual.get("palettes", [])
	var variant: Dictionary = {}
	if not palettes.is_empty():
		var row_value: int = int(host.data.row) if row < 0 else row
		var signature: int = absi(int(host.data.seed) + row_value * 31 + lane * 17 + kind.hash() + (97 if elite else 0))
		variant = palettes[signature % palettes.size()].duplicate(true)
	variant["armor_style"] = str(visual.get("armor", "none"))
	variant["helmet_style"] = str(visual.get("helmet", "none"))
	variant["weapon_style"] = str(visual.get("weapon", "none"))
	var rank: int = enemy_rank(host, kind, elite)
	variant["rank"] = rank
	variant["rank_name"] = enemy_rank_name(host, kind, elite)
	variant["rank_trim"] = str(EnemyCatalog.ENEMY_RANKS.get(rank, {"trim":"8aa49a"}).get("trim", "8aa49a"))
	return variant

static func elite_behavior(kind: String) -> Dictionary:
	return EnemyCatalog.ELITE_BEHAVIORS.get(kind, EnemyCatalog.ELITE_BEHAVIORS.get("slime", {}))

static func enemy_kind_for_route(host, route: String, local_rng: RandomNumberGenerator) -> String:
	var stage_bonus: float = min(0.12, float(int(host.data.stage)) * 0.02)
	var roll: float = local_rng.randf()
	match route:
		"frost":
			if roll < 0.30 + stage_bonus: return "ogre"
			elif roll < 0.68: return "kobold"
			return "goblin"
		"fen":
			if roll < 0.16 + stage_bonus: return "ogre"
			elif roll < 0.44: return "goblin"
			elif roll < 0.70: return "kobold"
			return "slime"
		"forge":
			if roll < 0.08 + stage_bonus: return "ogre"
			elif roll < 0.34: return "kobold"
			return "goblin"
		"gloomwood":
			if roll < 0.08 + stage_bonus: return "ogre"
			elif roll < 0.38: return "kobold"
			elif roll < 0.70: return "goblin"
			return "slime"
		"sunken_grotto":
			if roll < 0.10 + stage_bonus: return "ogre"
			elif roll < 0.46: return "kobold"
			elif roll < 0.70: return "slime"
			return "goblin"
		"cinder_caldera":
			if roll < 0.34 + stage_bonus: return "ogre"
			elif roll < 0.68: return "goblin"
			return "kobold"
		"galecrest_spire":
			if roll < 0.30 + stage_bonus: return "ogre"
			elif roll < 0.72: return "kobold"
			return "goblin"
		"shrine":
			if roll < 0.16 + stage_bonus: return "kobold"
			return "slime"
		"treasure":
			if roll < 0.10 + stage_bonus: return "ogre"
			elif roll < 0.28: return "goblin"
			return "slime"
		_:
			if roll < 0.08 + stage_bonus: return "goblin"
			return "slime"
