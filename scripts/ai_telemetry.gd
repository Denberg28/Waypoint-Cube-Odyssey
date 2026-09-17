extends RefCounted
## Append-only local gameplay telemetry for the AI Game Master.
## On Web builds, optionally mirrors a sanitized subset to Supabase for shared beta analytics.

const TELEMETRY_PATH: String = "user://waypoint_ai_gm_telemetry.jsonl"
const SESSION_PATH: String = "user://waypoint_ai_gm_session.json"
const REMOTE_CONFIG_PATH: String = "res://runtime/public_telemetry.json"
const MAX_FILE_BYTES: int = 2_000_000
const MAX_REMOTE_STRING: int = 120
var telemetry_path: String = TELEMETRY_PATH
var session_path: String = SESSION_PATH
var session_id: String = ""
var started_unix: int = 0
var event_count: int = 0
var remote_config: Dictionary = {}

func _init() -> void:
	started_unix = int(Time.get_unix_time_from_system())
	session_id = "session_%d_%d" % [started_unix, randi_range(100000, 999999)]
	load_session()
	load_remote_config()

func load_remote_config() -> void:
	remote_config = {}
	if not FileAccess.file_exists(REMOTE_CONFIG_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REMOTE_CONFIG_PATH))
	if parsed is Dictionary:
		remote_config = parsed.duplicate(true)

func web_opted_in() -> bool:
	if not OS.has_feature("web"):
		return bool(remote_config.get("allow_desktop_debug", false))
	if not bool(remote_config.get("require_opt_in", true)):
		return true
	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	var location = window.location
	if location == null:
		return false
	var search: String = str(location.search)
	return "telemetry=1" in search

func load_session() -> void:
	if not FileAccess.file_exists(session_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(session_path))
	if parsed is Dictionary and int(parsed.get("started_unix", 0)) > 0:
		var age: int = int(Time.get_unix_time_from_system()) - int(parsed.get("last_event_unix", 0))
		if age >= 0 and age <= 1800:
			session_id = str(parsed.get("session_id", session_id))
			started_unix = int(parsed.get("started_unix", started_unix))
			event_count = int(parsed.get("event_count", 0))

func compact_context(game) -> Dictionary:
	return {
		"mode": str(game.data.get("mode", "")),
		"class_id": str(game.data.get("class_id", "")),
		"route": str(game.data.get("route", "")),
		"stage": int(game.data.get("stage", 0)),
		"row": int(game.data.get("row", 0)),
		"hp": int(game.data.get("hp", 0)),
		"max_hp": game.max_hp(),
		"coins": int(game.data.get("coins", 0)),
		"bag": int(game.data.get("bag", 0)),
		"gems": int(game.data.get("gems", 0)),
		"streak": int(game.data.get("streak", 0)),
		"relic": int(game.data.get("relic_charge", 0)),
		"wins": int(game.data.get("wins", 0)),
		"runs": int(game.data.get("runs", 0)),
		"kills": int(game.data.get("kills", 0)),
		"fish_caught": int(game.data.get("fish_caught", 0))
	}

func record(event_type: String, game, details: Dictionary = {}) -> void:
	if event_type.strip_edges() == "":
		return
	rotate_if_needed()
	var now: int = int(Time.get_unix_time_from_system())
	var context: Dictionary = compact_context(game)
	var entry: Dictionary = {
		"schema": 1,
		"session_id": session_id,
		"created_unix": now,
		"event": event_type,
		"context": context,
		"details": details.duplicate(true)
	}
	var file = FileAccess.open(telemetry_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(telemetry_path, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(entry))
		file.flush()
		file.close()
	event_count += 1
	var sf = FileAccess.open(session_path, FileAccess.WRITE)
	if sf != null:
		sf.store_string(JSON.stringify({
			"schema": 1,
			"session_id": session_id,
			"started_unix": started_unix,
			"last_event_unix": now,
			"event_count": event_count
		}, "\t"))
		sf.close()
	mirror_remote(event_type, now, context, details)

func mirror_remote(event_type: String, created_unix: int, context: Dictionary, details: Dictionary) -> void:
	if not bool(remote_config.get("enabled", false)):
		return
	if not web_opted_in():
		return
	var base_url: String = str(remote_config.get("supabase_url", "")).strip_edges().trim_suffix("/")
	var publishable_key: String = str(remote_config.get("supabase_publishable_key", "")).strip_edges()
	if base_url == "" or publishable_key == "" or "REPLACE_" in publishable_key:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var payload: Dictionary = {
		"session_id": session_id.left(96),
		"created_unix": created_unix,
		"event": event_type.left(64),
		"mode": str(context.get("mode", "")).left(32),
		"class_id": str(context.get("class_id", "")).left(32),
		"route": str(context.get("route", "")).left(32),
		"stage": int(context.get("stage", 0)),
		"row_index": int(context.get("row", 0)),
		"hp": int(context.get("hp", 0)),
		"max_hp": int(context.get("max_hp", 0)),
		"coins": int(context.get("coins", 0)),
		"bag": int(context.get("bag", 0)),
		"gems": int(context.get("gems", 0)),
		"details": sanitize_details(details),
		"client_version": str(ProjectSettings.get_setting("application/config/version", "")).left(80)
	}
	var request_node = HTTPRequest.new()
	request_node.timeout = 8.0
	tree.root.add_child(request_node)
	request_node.request_completed.connect(func(_result, _response_code, _headers, _body):
		request_node.queue_free()
	)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Prefer: return=minimal",
		"apikey: " + publishable_key
	])
	var err := request_node.request(base_url + "/rest/v1/gameplay_events", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		request_node.queue_free()

func sanitize_details(details: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in details.keys():
		var clean_key: String = str(key).left(48)
		var value = details[key]
		if value is bool or value is int or value is float:
			out[clean_key] = value
		elif value is String:
			# Never mirror free-text player feedback; only metadata such as length is sent.
			if clean_key in ["result", "message", "feedback", "text"]:
				continue
			out[clean_key] = str(value).left(MAX_REMOTE_STRING)
	return out

func rotate_if_needed() -> void:
	if not FileAccess.file_exists(telemetry_path):
		return
	var file = FileAccess.open(telemetry_path, FileAccess.READ)
	if file == null:
		return
	var length: int = file.get_length()
	file.close()
	if length <= MAX_FILE_BYTES:
		return
	var lines: PackedStringArray = FileAccess.get_file_as_string(telemetry_path).split("\n", false)
	var keep_from: int = maxi(0, lines.size() / 2)
	var out = FileAccess.open(telemetry_path, FileAccess.WRITE)
	if out == null:
		return
	for i in range(keep_from, lines.size()):
		if lines[i].strip_edges() != "":
			out.store_line(lines[i])
	out.close()
