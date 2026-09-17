extends Node
## Core UI normalization for desktop + Web.
##
## Godot Web can render fragile Unicode glyph-only controls as tofu/missing-glyph
## boxes depending on the browser/font stack. The game now uses explicit ASCII
## labels in main.gd, and this autoload is a defensive runtime layer for old
## saves/cached builds/dynamically rebuilt controls.

const TEXT_REPLACEMENTS := {
	"☀": {"text": "DAY", "width": 58.0, "font_size": 10},
	"◐": {"text": "DUSK", "width": 58.0, "font_size": 10},
	"●": {"text": "NIGHT", "width": 58.0, "font_size": 10},
	"←": {"text": "A", "width": 56.0, "font_size": 14},
	"↑": {"text": "W", "width": 56.0, "font_size": 14},
	"→": {"text": "D", "width": 56.0, "font_size": 14},
}

const TOOLTIP_REPLACEMENTS := {
	"Day brightness": {"text": "DAY", "width": 58.0, "font_size": 10},
	"Dusk brightness": {"text": "DUSK", "width": 58.0, "font_size": 10},
	"Night brightness": {"text": "NIGHT", "width": 58.0, "font_size": 10},
	"A / Walk left": {"text": "A", "width": 56.0, "font_size": 14},
	"W / Walk forward": {"text": "W", "width": 56.0, "font_size": 14},
	"D / Walk right": {"text": "D", "width": 56.0, "font_size": 14},
}

var _scan_timer: Timer

func _ready() -> void:
	call_deferred("_scan_tree")
	_scan_timer = Timer.new()
	_scan_timer.wait_time = 0.5
	_scan_timer.autostart = true
	_scan_timer.timeout.connect(_scan_tree)
	add_child(_scan_timer)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Button:
		call_deferred("_apply_button_fallback", node)

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
	if not is_instance_valid(button):
		return

	var cfg: Dictionary = {}
	if TOOLTIP_REPLACEMENTS.has(button.tooltip_text):
		cfg = TOOLTIP_REPLACEMENTS[button.tooltip_text]
	elif TEXT_REPLACEMENTS.has(button.text):
		cfg = TEXT_REPLACEMENTS[button.text]
	else:
		return

	button.text = str(cfg.get("text", button.text))
	button.custom_minimum_size.x = maxf(
		button.custom_minimum_size.x,
		float(cfg.get("width", button.custom_minimum_size.x))
	)
	button.add_theme_font_size_override("font_size", int(cfg.get("font_size", 12)))
