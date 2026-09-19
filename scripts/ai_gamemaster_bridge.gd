extends RefCounted
## Safe bridge between the external Night Watch runner and the locked game baseline.
## AI output is validated twice: in Python, then again here before anything reaches gameplay.

const Catalog = preload("res://scripts/catalog.gd")
const INBOX_PATH: String = "user://waypoint_ai_gm_inbox.json"
const APPLIED_PATH: String = "user://waypoint_ai_gm_applied.json"
const WORLD_STATE_PATH: String = "user://waypoint_ai_gm_world_state.json"
const CHALLENGE_TYPES: Array[String] = ["route_complete", "featured_route_complete", "fishing_catch", "elite_defeat", "obstacle_jump"]

func clamp_int(value: Variant, low: int, high: int) -> int:
	if not (value is int or value is float):
		return low
	return clampi(int(value), low, high)

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func save_json(path: String, value: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()
	return true

func load_world_state() -> Dictionary:
	var state: Dictionary = load_json(WORLD_STATE_PATH)
	return state if int(state.get("schema", 0)) == 2 else {}

func sanitized_directives(inbox: Dictionary) -> Dictionary:
	var source: Dictionary = inbox.get("adaptive_directives", {}) if inbox.get("adaptive_directives", {}) is Dictionary else {}
	var route: String = str(source.get("featured_route", "moss"))
	if route not in Catalog.ROUTES:
		route = "moss"
	return {
		"featured_route": route,
		"difficulty_offset": clamp_int(source.get("difficulty_offset", 0), -1, 1),
		"difficulty_reason": str(source.get("difficulty_reason", "")).strip_edges().left(240),
		"expires_after_sessions": clamp_int(source.get("expires_after_sessions", 1), 1, 3)
	}

func sanitized_challenge(inbox: Dictionary, directives: Dictionary) -> Dictionary:
	var source: Dictionary = inbox.get("daily_challenge", {}) if inbox.get("daily_challenge", {}) is Dictionary else {}
	var kind: String = str(source.get("kind", "route_complete"))
	if kind not in CHALLENGE_TYPES:
		kind = "route_complete"
	var rewards: Dictionary = source.get("rewards", {}) if source.get("rewards", {}) is Dictionary else {}
	return {
		"kind": kind,
		"title": str(source.get("title", "Night Watch Challenge")).strip_edges().left(80),
		"description": str(source.get("description", "Complete the Night Watch objective.")).strip_edges().left(260),
		"target": clamp_int(source.get("target", 1), 1, 3),
		"progress": 0,
		"completed": false,
		"featured_route": str(directives.get("featured_route", "moss")),
		"rewards": {
			"coins": clamp_int(rewards.get("coins", 0), 0, 20),
			"gems": clamp_int(rewards.get("gems", 0), 0, 1),
			"relic_charge": clamp_int(rewards.get("relic_charge", 0), 0, 8)
		}
	}

func consume(game) -> Dictionary:
	var inbox: Dictionary = load_json(INBOX_PATH)
	if inbox.is_empty() or int(inbox.get("schema", 0)) not in [1, 2]:
		return {}
	var update_id: String = str(inbox.get("update_id", "")).strip_edges()
	if update_id == "":
		return {}
	var applied: Dictionary = load_json(APPLIED_PATH)
	if str(applied.get("last_update_id", "")) == update_id:
		return {}
	if game.data.get("popup", {}) is Dictionary and not game.data.popup.is_empty():
		return {}

	var rewards: Dictionary = inbox.get("rewards", {}) if inbox.get("rewards", {}) is Dictionary else {}
	var coins: int = clamp_int(rewards.get("coins", 0), 0, 25)
	var gems: int = clamp_int(rewards.get("gems", 0), 0, 2)
	var relic: int = clamp_int(rewards.get("relic_charge", 0), 0, 10)
	game.data.coins = maxi(0, int(game.data.get("coins", 0)) + coins)
	game.data.gems = maxi(0, int(game.data.get("gems", 0)) + gems)
	game.data.relic_charge = clampi(int(game.data.get("relic_charge", 0)) + relic, 0, 100)

	var directives: Dictionary = sanitized_directives(inbox)
	var challenge: Dictionary = sanitized_challenge(inbox, directives)
	var world_event: Dictionary = inbox.get("world_event", {}) if inbox.get("world_event", {}) is Dictionary else {}
	var world_state: Dictionary = {
		"schema": 2,
		"update_id": update_id,
		"created_at": str(inbox.get("created_at", "")),
		"model": str(inbox.get("model", "")),
		"featured_route": directives.featured_route,
		"difficulty_offset": directives.difficulty_offset,
		"difficulty_reason": directives.difficulty_reason,
		"expires_after_sessions": directives.expires_after_sessions,
		"sessions_seen": 0,
		"challenge": challenge,
		"world_event": world_event.duplicate(true)
	}
	save_json(WORLD_STATE_PATH, world_state)

	var title: String = str(world_event.get("title", "Night Watch")).strip_edges()
	var description: String = str(world_event.get("description", "The road changed a little while you were away.")).strip_edges()
	var player_message: String = str(inbox.get("player_message", "")).strip_edges()
	var reward_line: String = "Night reward: +%d banked coins" % coins
	if gems > 0:
		reward_line += "  •  +%d gems" % gems
	if relic > 0:
		reward_line += "  •  +%d%% relic" % relic
	var body: String = description
	if player_message != "":
		body += "\n" + player_message
	body += "\n" + reward_line
	body += "\nFeatured road: " + str(directives.featured_route).capitalize()
	body += "\nChallenge: " + str(challenge.title)
	game.data.popup = {"tag":"AI GAME MASTER / NIGHT WATCH", "heading": title if title != "" else "Night Watch", "body": body}
	game.data.last = "Night Watch returned. " + reward_line

	var result: Dictionary = {
		"update_id": update_id,
		"coins": coins,
		"gems": gems,
		"relic_charge": relic,
		"featured_route": directives.featured_route,
		"difficulty_offset": directives.difficulty_offset,
		"challenge": challenge.duplicate(true),
		"model": str(inbox.get("model", ""))
	}
	save_json(APPLIED_PATH, {"schema":2, "last_update_id":update_id, "applied_unix":int(Time.get_unix_time_from_system()), "result":result})
	return result

func apply_directives_to_game(game) -> Dictionary:
	var state: Dictionary = load_world_state()
	if state.is_empty():
		game.ai_difficulty_offset = 0
		game.ai_featured_route = ""
		return {}
	var seen: int = clamp_int(state.get("sessions_seen", 0), 0, 999)
	var lifespan: int = clamp_int(state.get("expires_after_sessions", 1), 1, 3)
	if seen >= lifespan:
		game.ai_difficulty_offset = 0
		game.ai_featured_route = ""
		state.difficulty_offset = 0
		state.featured_route = ""
		state.expired = true
		save_json(WORLD_STATE_PATH, state)
		return state
	game.ai_difficulty_offset = clamp_int(state.get("difficulty_offset", 0), -1, 1)
	game.ai_featured_route = str(state.get("featured_route", "")) if str(state.get("featured_route", "")) in Catalog.ROUTES else ""
	state.sessions_seen = seen + 1
	save_json(WORLD_STATE_PATH, state)
	return state

func event_matches_challenge(challenge: Dictionary, event_type: String, context: Dictionary) -> bool:
	var kind: String = str(challenge.get("kind", ""))
	if kind == "route_complete":
		return event_type == "route_complete"
	if kind == "featured_route_complete":
		return event_type == "route_complete" and str(context.get("route", "")) == str(challenge.get("featured_route", ""))
	if kind == "fishing_catch":
		return event_type == "fishing_catch"
	if kind == "elite_defeat":
		return event_type == "elite_defeat"
	if kind == "obstacle_jump":
		return event_type == "obstacle_jump"
	return false

func progress_challenge(game, event_type: String, context: Dictionary = {}) -> Dictionary:
	var state: Dictionary = load_world_state()
	if state.is_empty():
		return {}
	var challenge: Dictionary = state.get("challenge", {}) if state.get("challenge", {}) is Dictionary else {}
	if challenge.is_empty() or bool(challenge.get("completed", false)):
		return {}
	if not event_matches_challenge(challenge, event_type, context):
		return {}
	challenge.progress = mini(int(challenge.get("target", 1)), int(challenge.get("progress", 0)) + 1)
	var result: Dictionary = {"progress":int(challenge.progress), "target":int(challenge.target), "completed":false}
	if int(challenge.progress) >= int(challenge.target):
		challenge.completed = true
		var rewards: Dictionary = challenge.get("rewards", {}) if challenge.get("rewards", {}) is Dictionary else {}
		var coins: int = clamp_int(rewards.get("coins", 0), 0, 20)
		var gems: int = clamp_int(rewards.get("gems", 0), 0, 1)
		var relic: int = clamp_int(rewards.get("relic_charge", 0), 0, 8)
		game.data.coins += coins
		game.data.gems += gems
		game.data.relic_charge = clampi(int(game.data.relic_charge) + relic, 0, 100)
		var reward_text: String = "+%d coins" % coins
		if gems > 0:
			reward_text += " • +%d gem" % gems
		if relic > 0:
			reward_text += " • +%d%% relic" % relic
		game.data.last = "Night Watch challenge complete: %s. %s" % [str(challenge.get("title", "Challenge")), reward_text]
		if game.data.get("popup", {}) is Dictionary and game.data.popup.is_empty():
			game.data.popup = {"tag":"AI GAME MASTER / CHALLENGE", "heading":"Challenge complete", "body":str(game.data.last)}
		result.completed = true
		result.rewards = {"coins":coins, "gems":gems, "relic_charge":relic}
	state.challenge = challenge
	save_json(WORLD_STATE_PATH, state)
	return result
