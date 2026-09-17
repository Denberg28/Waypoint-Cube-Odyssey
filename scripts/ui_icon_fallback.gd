extends Node
## Web-safe UI icon fallback.
## Replaces fragile Unicode-only button glyphs with ASCII/text labels so the
## interface renders consistently in Godot desktop and Web exports without
## requiring an icon font.

const REPLACEMENTS := {
	"☀": {"text": "DAY", "width": 46.0, "font_size": 10},
	"◐": {"text": "DUSK", "width": 50.0, "font_size": 10},
	"●": {"text": "NIGHT", "width": 56.0, "font_size": 10},
	"←": {"text": "A", "width": 50.0, "font_size": 14},
	"↑": {"text": "W", "width": 50.0, "font_size": 14},
	"→": {"text": "D", "width": 50.0, "font_size": 14},
}

var _scan_timer: Timer

func _ready() -> void:
	# Main UI is constructed from script, so scan after the scene has had a frame
	# to build, then keep a lightweight periodic pass for dynamically rebuilt UI.
	call_deferred("_scan_tree")
	_scan_timer = Timer.new()
	_scan_timer.wait_time = 1.0
	_scan_timer.autostart = true
	_scan_timer.timeout.connect(_scan_tree)
	add_child(_scan_timer)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Button:
		_apply_button_fallback(node as Button)

func _scan_tree() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_scan_node(root)

func _scan_node(node: Node) -> void:
	if node is Button:
		_apply_button_fallback(node as Button)
	for child in node.get_children():
		_scan_node(child)

func _apply_button_fallback(button: Button) -> void:
	if not REPLACEMENTS.has(button.text):
		return
	var cfg: Dictionary = REPLACEMENTS[button.text]
	button.text = str(cfg.get("text", button.text))
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, float(cfg.get("width", button.custom_minimum_size.x)))
	button.add_theme_font_size_override("font_size", int(cfg.get("font_size", 12)))
