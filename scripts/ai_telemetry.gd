extends RefCounted
## Append-only local gameplay telemetry for the AI Game Master.
## Stores compact events only; it never sends network requests from Godot.

const TELEMETRY_PATH: String = "user://waypoint_ai_gm_telemetry.jsonl"
const SESSION_PATH: String = "user://waypoint_ai_gm_session.json"
const MAX_FILE_BYTES: int = 2_000_000
var telemetry_path: String = TELEMETRY_PATH
var session_path: String = SESSION_PATH
var session_id: String = ""
var started_unix: int = 0
var event_count: int = 0

func _init() -> void:
	started_unix = int(Time.get_unix_time_from_system())
	session_id = "session_%d" % started_unix
	load_session()

func load_session() -> void:
	if not FileAccess.file_exists(session_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(session_path))
	if parsed is Dictionary and int(parsed.get("started_unix", 0)) > 0:
		# Continue the same logical session after a short restart only if it is recent.
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
	var entry: Dictionary = {
		"schema": 1,
		"session_id": session_id,
		"created_unix": now,
		"event": event_type,
		"context": compact_context(game),
		"details": details.duplicate(true)
	}
	var file = FileAccess.open(telemetry_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(telemetry_path, FileAccess.WRITE)
	if file == null:
		return
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
	# Keep the newest half of the lines. This avoids unbounded telemetry growth.
	var lines: PackedStringArray = FileAccess.get_file_as_string(telemetry_path).split("\n", false)
	var keep_from: int = maxi(0, lines.size() / 2)
	var out = FileAccess.open(telemetry_path, FileAccess.WRITE)
	if out == null:
		return
	for i in range(keep_from, lines.size()):
		if lines[i].strip_edges() != "":
			out.store_line(lines[i])
	out.close()
