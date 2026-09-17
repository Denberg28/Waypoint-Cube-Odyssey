extends Node
## Bounded AI music profile applicator. The AI never supplies code or audio files;
## it only selects safe musical parameters that shape the existing procedural score.

const PROFILE_PATH := "res://runtime/music_profile.json"
var profile: Dictionary = {}
var last_context := ""
var last_muted = null
var last_variant: int = -999

func _ready() -> void:
	load_profile()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(apply_to_game)
	add_child(timer)

func load_profile() -> void:
	profile = {}
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if parsed is Dictionary:
		profile = parsed.duplicate(true)

func context_config(context: String) -> Dictionary:
	var contexts = profile.get("contexts", {})
	if contexts is Dictionary and contexts.has(context) and contexts[context] is Dictionary:
		return contexts[context]
	return {}

func emit_music_event(scene, event_name: String, details: Dictionary) -> void:
	var telemetry = scene.get("ai_telemetry")
	var game = scene.get("game")
	if telemetry != null and game != null and telemetry.has_method("record"):
		telemetry.call("record", event_name, game, details)

func apply_to_game() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("music_context"):
		return
	var player = scene.get("music_player")
	if player == null or not is_instance_valid(player):
		return
	var context: String = str(scene.call("music_context"))
	var cfg := context_config(context)
	var pitch := clampf(float(cfg.get("pitch_scale", 1.0)), 0.88, 1.12)
	var volume_delta := clampf(float(cfg.get("volume_delta_db", 0.0)), -4.0, 4.0)
	player.pitch_scale = pitch
	var base_volume := -20.0 if context == "boss" else (-29.0 if context == "campfire" else (-26.0 if context == "fishing" else -23.0))
	player.volume_db = base_volume + volume_delta

	var muted := bool(scene.get("music_muted"))
	var variant := int(scene.get("current_music_variant"))
	if context != last_context:
		last_context = context
		emit_music_event(scene, "music_context", {"context":context, "pitch_scale":pitch, "volume_delta_db":volume_delta})
		if scene.has_method("update_music"):
			scene.call("update_music", true)
	if last_muted == null or muted != bool(last_muted):
		if last_muted != null:
			emit_music_event(scene, "music_muted", {"muted":muted, "context":context})
		last_muted = muted
	if last_variant != -999 and variant != last_variant and context == last_context:
		emit_music_event(scene, "music_shuffle", {"context":context, "variant":variant})
	last_variant = variant
