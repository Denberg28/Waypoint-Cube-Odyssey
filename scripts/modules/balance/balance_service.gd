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

# Late progression pressure keeps high-rank gear meaningful without making
# low-level roads unfair. These bonuses activate only after the player has
# already earned substantial permanent power.
static func enemy_progression_toughness(level: int, danger: int) -> int:
	var bonus: int = 0
	if level >= 13:
		bonus += 1
	if level >= 17:
		bonus += 1
	if danger >= 5:
		bonus += 1
	return bonus

static func enemy_progression_damage(level: int, danger: int, elite: bool = false) -> int:
	var bonus: int = 0
	if level >= 13 and danger >= 4:
		bonus += 1
	if elite and level >= 17 and danger >= 5:
		bonus += 1
	return bonus

static func equipment_power_score(item: Dictionary) -> int:
	return (
		int(item.get("attack", 0)) * 5
		+ int(item.get("health", 0)) * 4
		+ int(item.get("coins", 0)) * 2
		+ int(item.get("heal", 0)) * 3
	)
