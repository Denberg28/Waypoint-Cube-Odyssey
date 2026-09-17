extends RefCounted
## Local feedback queue prepared for future AI Game Master integration.
## No network or AI service is used yet. Each entry stores the player's message
## together with a compact gameplay snapshot so future analysis has context.

const FEEDBACK_PATH: String = "user://waypoint_ai_gm_feedback.jsonl"
const MAX_STORED: int = 120
var feedback_path: String = FEEDBACK_PATH
var entries: Array[Dictionary] = []

func _init() -> void:
	load_queue()

func load_queue() -> void:
	entries.clear()
	if not FileAccess.file_exists(feedback_path):
		return
	var file = FileAccess.open(feedback_path, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary and parsed.get("message", "") is String:
			entries.append(parsed)
	file.close()
	while entries.size() > MAX_STORED:
		entries.pop_front()

func submit(message: String, context: Dictionary) -> Dictionary:
	var clean: String = message.strip_edges()
	if clean == "":
		return {}
	var unix_time: int = int(Time.get_unix_time_from_system())
	var entry: Dictionary = {
		"schema": 1,
		"id": "feedback_%d_%d" % [unix_time, entries.size() + 1],
		"created_unix": unix_time,
		"source": "player_feedback",
		"status": "queued_local",
		"message": clean,
		"context": context.duplicate(true)
	}
	entries.append(entry)
	if entries.size() > MAX_STORED:
		entries.pop_front()
	save_queue()
	return entry

func save_queue() -> bool:
	var file = FileAccess.open(feedback_path, FileAccess.WRITE)
	if file == null:
		return false
	for entry in entries:
		file.store_line(JSON.stringify(entry))
	file.flush()
	file.close()
	return true

func recent(limit: int = 8) -> Array[Dictionary]:
	var count: int = mini(limit, entries.size())
	var result: Array[Dictionary] = []
	for i in range(count):
		result.append(entries[entries.size() - 1 - i])
	return result

func queue_count() -> int:
	return entries.size()
