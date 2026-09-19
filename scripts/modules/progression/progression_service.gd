extends RefCounted
const ProgressionCatalog = preload("res://scripts/modules/progression/progression_catalog.gd")

const ENEMY_KINDS: Array[String] = ["slime", "goblin", "kobold", "ogre"]
const DISCOVERY_KINDS: Array[String] = [
	"campfire", "fishing", "gear_cache", "gloomcap",
	"prismatic_pearl", "ember_shard", "skyfeather", "rare_event"
]

static func empty_objective() -> Dictionary:
	return {}

static func _available_objective_templates(host) -> Array[Dictionary]:
	var coin_cells: int = 0
	var enemy_cells: int = 0
	var discovery_cells: int = 0
	for cell in host.data.cells:
		match str(cell.get("kind", "")):
			"coin":
				coin_cells += 1
			"slime", "goblin", "kobold", "ogre":
				enemy_cells += 1
			"campfire", "fishing", "gear_cache", "gloomcap", "prismatic_pearl", "ember_shard", "skyfeather", "rare_event":
				discovery_cells += 1
	var candidates: Array[Dictionary] = []
	for template in ProgressionCatalog.OBJECTIVES:
		var objective_type: String = str(template.type)
		if objective_type == "coin" and coin_cells >= int(template.target):
			candidates.append(template)
		elif objective_type == "enemy" and enemy_cells >= int(template.target):
			candidates.append(template)
		elif objective_type == "discovery" and discovery_cells >= int(template.target):
			candidates.append(template)
	return candidates

static func begin_road_objective(host) -> Dictionary:
	var candidates: Array[Dictionary] = _available_objective_templates(host)
	if candidates.is_empty():
		host.data.road_objective = {}
		return {}
	var signature: int = absi(int(host.data.seed) + str(host.data.route).hash() + int(host.data.stage) * 37)
	var template: Dictionary = candidates[signature % candidates.size()]
	host.data.road_objective = {
		"id":str(template.id),
		"type":str(template.type),
		"label":str(template.label),
		"description":str(template.description),
		"target":int(template.target),
		"progress":0,
		"complete":false,
		"claimed":false
	}
	return host.data.road_objective

static func valid_objective(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	for key in ["id", "type", "label", "description", "target", "progress", "complete", "claimed"]:
		if not value.has(key):
			return false
	if not value.id is String or not value.type is String or not value.label is String or not value.description is String:
		return false
	if str(value.type) not in ["coin", "enemy", "discovery"]:
		return false
	if not (value.target is int or value.target is float) or not (value.progress is int or value.progress is float):
		return false
	if int(value.target) <= 0 or int(value.progress) < 0 or int(value.progress) > int(value.target):
		return false
	if not value.complete is bool or not value.claimed is bool:
		return false
	if bool(value.complete) != (int(value.progress) >= int(value.target)):
		return false
	if bool(value.claimed) and not bool(value.complete):
		return false
	return true

static func record_progress(host, event_type: String, amount: int = 1) -> String:
	if amount <= 0 or not valid_objective(host.data.get("road_objective", {})):
		return ""
	var objective: Dictionary = host.data.road_objective
	if objective.is_empty() or bool(objective.claimed) or bool(objective.complete) or str(objective.type) != event_type:
		return ""
	objective.progress = mini(int(objective.target), int(objective.progress) + amount)
	objective.complete = int(objective.progress) >= int(objective.target)
	if bool(objective.complete):
		return "Objective complete: %s." % str(objective.label)
	return "Objective: %s %d/%d." % [str(objective.label), int(objective.progress), int(objective.target)]

static func record_cell_result(host, kind: String, result_text: String) -> String:
	if kind == "coin":
		return record_progress(host, "coin")
	if kind in ENEMY_KINDS and "defeated" in result_text.to_lower():
		return record_progress(host, "enemy")
	if kind in DISCOVERY_KINDS:
		return record_progress(host, "discovery")
	return ""

static func camp_level_for_renown(renown: int) -> int:
	var level: int = 0
	for i in range(ProgressionCatalog.CAMP_LEVEL_THRESHOLDS.size()):
		if renown >= int(ProgressionCatalog.CAMP_LEVEL_THRESHOLDS[i]):
			level = i
	return clampi(level, 0, ProgressionCatalog.CAMP_LEVEL_THRESHOLDS.size() - 1)

static func recalculate_camp_level(host) -> bool:
	var new_level: int = camp_level_for_renown(int(host.data.camp_renown))
	if new_level == int(host.data.camp_level):
		return false
	host.data.camp_level = new_level
	host.data.hp = mini(int(host.data.hp), host.max_hp())
	return true

static func claim_road_objective(host) -> String:
	var objective: Dictionary = host.data.get("road_objective", {})
	if not valid_objective(objective) or objective.is_empty() or bool(objective.claimed):
		return ""
	objective.claimed = true
	if not bool(objective.complete):
		return "Objective missed: %s." % str(objective.label)

	host.data.coins += ProgressionCatalog.OBJECTIVE_BANK_COINS
	host.data.camp_renown += 1
	var resolve_note: String = host.add_resolve(ProgressionCatalog.OBJECTIVE_RESOLVE)
	var camp_upgraded: bool = recalculate_camp_level(host)
	var result: String = "OBJECTIVE COMPLETE • %s  •  +%d banked coins  •  +1 Camp Renown" % [
		str(objective.label),
		ProgressionCatalog.OBJECTIVE_BANK_COINS
	]
	if resolve_note != "":
		result += "  •  " + resolve_note
	if camp_upgraded:
		result += "  •  LANTERN CAMP LEVEL %d" % int(host.data.camp_level)
	return result

static func objective_text(host) -> String:
	var objective: Dictionary = host.data.get("road_objective", {})
	if not valid_objective(objective) or objective.is_empty():
		return "No active road objective"
	var marker: String = "✓" if bool(objective.complete) else "•"
	return "%s %s  %d/%d" % [marker, str(objective.label), int(objective.progress), int(objective.target)]

static func camp_renown_text(host) -> String:
	var level: int = int(host.data.camp_level)
	var renown: int = int(host.data.camp_renown)
	var thresholds: Array[int] = ProgressionCatalog.CAMP_LEVEL_THRESHOLDS
	if level >= thresholds.size() - 1:
		return "CAMP LV %d  •  RENOWN %d  •  MAX" % [level, renown]
	return "CAMP LV %d  •  RENOWN %d/%d" % [level, renown, int(thresholds[level + 1])]

static func resolve_rare_event(host) -> String:
	host.data.rare_events_seen += 1
	var signature: int = absi(int(host.data.seed) + int(host.data.row) * 41 + int(host.data.lane) * 17 + int(host.data.rare_events_seen) * 7)
	match signature % 3:
		0:
			host.data.bag += 8
			return "Rare encounter — a passing wayfarer shares a trail satchel. +8 expedition coins."
		1:
			var before_hp: int = int(host.data.hp)
			host.data.hp = mini(host.max_hp(), int(host.data.hp) + 1)
			var resolve_note: String = host.add_resolve(8)
			var heal_note: String = " +1 heart." if int(host.data.hp) > before_hp else ""
			return "Rare encounter — a quiet lantern shrine steadies the journey.%s %s" % [heal_note, resolve_note]
		_:
			host.add_relic_charge(14)
			return "Rare encounter — an old relic marker hums beneath the moss. +14 relic charge."


static func maybe_place_rare_event(host, corridor_lanes: Dictionary, local_rng: RandomNumberGenerator) -> bool:
	if local_rng.randf() >= ProgressionCatalog.RARE_EVENT_CHANCE:
		return false
	var event_rows: Array[int] = [4, 8, 16]
	var row: int = event_rows[local_rng.randi_range(0, event_rows.size() - 1)]
	var safe_lane: int = int(corridor_lanes.get(row, 0))
	var candidates: Array[int] = []
	for lane in range(-1, 2):
		if lane != safe_lane:
			candidates.append(lane)
	if candidates.is_empty():
		return false
	var chosen_lane: int = candidates[local_rng.randi_range(0, candidates.size() - 1)]
	var cell: Dictionary = host.cell_at(row, chosen_lane)
	if cell.is_empty():
		return false
	cell.kind = "rare_event"
	cell.elite = false
	return true
