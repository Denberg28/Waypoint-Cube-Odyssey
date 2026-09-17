extends SceneTree
const AIFeedback = preload("res://scripts/ai_feedback.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)

func _initialize() -> void:
	var test_path: String = "user://waypoint_AI_FEEDBACK_TEST.jsonl"
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	var store = AIFeedback.new()
	store.feedback_path = test_path
	store.load_queue()
	check(store.queue_count() == 0, "feedback queue starts empty")
	var context: Dictionary = {"stage":2, "threat":4, "mode":"travel", "hp":5}
	var saved: Dictionary = store.submit("The ogre felt fair but exciting.", context)
	check(not saved.is_empty(), "feedback submission succeeds")
	check(store.queue_count() == 1, "feedback queue increments")
	check(str(saved.message) == "The ogre felt fair but exciting.", "feedback text preserved")
	check(int(saved.context.threat) == 4, "gameplay context preserved")
	var restored = AIFeedback.new()
	restored.feedback_path = test_path
	restored.load_queue()
	check(restored.queue_count() == 1, "feedback queue persists")
	check(str(restored.recent(1)[0].context.mode) == "travel", "recent feedback returns context")
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	print("AI FEEDBACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
