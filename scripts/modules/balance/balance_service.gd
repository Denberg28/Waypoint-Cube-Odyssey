extends RefCounted
const BalanceCatalog = preload("res://scripts/modules/balance/balance_catalog.gd")

static func player_rank_info(level: int) -> Dictionary:
	var info: Dictionary = BalanceCatalog.PLAYER_RANKS[0]
	for rank in BalanceCatalog.PLAYER_RANKS:
		if level >= int(rank.min_level):
			info = rank
	return info

static func player_rank_name(level: int) -> String:
	return str(player_rank_info(level).name)

static func player_rank_bonus(level: int, key: String) -> int:
	return int(player_rank_info(level).get(key, 0))

static func enemy_rank_modifier(rank: int, key: String) -> int:
	var info: Dictionary = BalanceCatalog.ENEMY_RANK_COMBAT.get(clampi(rank, 1, 4), {})
	return int(info.get(key, 0))

static func equipment_power_score(item: Dictionary) -> int:
	return (
		int(item.get("attack", 0)) * 5
		+ int(item.get("health", 0)) * 4
		+ int(item.get("coins", 0)) * 2
		+ int(item.get("heal", 0)) * 3
	)
