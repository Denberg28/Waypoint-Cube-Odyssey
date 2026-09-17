extends Node
## Web-safe text/icon sanitizer for popups, message areas, and side rails.
## Replaces fragile symbol-font/emoji glyphs and strips Private Use Area icons
## that otherwise render as square tofu boxes in browser builds.

const DIRECT_REPLACEMENTS := {
	"☀": "DAY",
	"◐": "DUSK",
	"●": "NIGHT",
	"←": "<",
	"→": ">",
	"↑": "^",
	"↓": "v",
	"▶": "PLAY",
	"◀": "BACK",
	"▸": ">",
	"▾": "v",
	"✓": "OK",
	"✔": "OK",
	"✕": "X",
	"✖": "X",
	"⚙": "SETTINGS",
	"ℹ": "INFO",
	"⚠": "WARNING",
	"★": "*",
	"☆": "*",
	"♥": "HEART",
	"❤": "HEART",
	"⚔": "COMBAT",
	"🛡": "ARMOR",
	"🎒": "BAG",
	"💎": "GEM",
	"🪙": "COIN",
	"🎣": "FISH",
	"🔥": "FIRE",
	"🌙": "MOON",
	"🎵": "MUSIC",
	"♫": "MUSIC",
	"♪": "MUSIC",
	"🔊": "SOUND",
	"🔇": "MUTE",
	"☰": "MENU",
	"✦": "*",
	"✨": "*",
	"×": "x"
}

var scan_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_scan_tree")
	scan_timer = Timer.new()
	scan_timer.wait_time = 0.35
	scan_timer.autostart = true
	scan_timer.timeout.connect(_scan_tree)
	add_child(scan_timer)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Button or node is Label or node is RichTextLabel:
		call_deferred("_sanitize_node", node)

func _scan_tree() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_scan_node(scene)

func _scan_node(node: Node) -> void:
	_sanitize_node(node)
	for child in node.get_children():
		_scan_node(child)

func _sanitize_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Button:
		var button := node as Button
		var cleaned := _sanitize_text(button.text)
		if cleaned.strip_edges().is_empty() and not button.text.strip_edges().is_empty():
			cleaned = _fallback_from_tooltip(button.tooltip_text)
		if cleaned != button.text:
			button.text = cleaned
	elif node is Label:
		var label := node as Label
		var cleaned := _sanitize_text(label.text)
		if cleaned != label.text:
			label.text = cleaned
	elif node is RichTextLabel:
		var rich := node as RichTextLabel
		var cleaned := _sanitize_text(rich.text)
		if cleaned != rich.text:
			rich.text = cleaned

func _sanitize_text(value: String) -> String:
	var result := value
	# Remove emoji variation selectors before textual substitutions.
	result = result.replace("️", "")
	for key in DIRECT_REPLACEMENTS.keys():
		result = result.replace(str(key), str(DIRECT_REPLACEMENTS[key]))
	result = _strip_private_use(result)
	return result

func _strip_private_use(value: String) -> String:
	var out := ""
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0xE000 and code <= 0xF8FF:
			continue
		out += value.substr(i, 1)
	return out

func _fallback_from_tooltip(tooltip: String) -> String:
	var t := tooltip.to_lower()
	if "close" in t:
		return "CLOSE"
	if "back" in t:
		return "BACK"
	if "expand" in t:
		return "EXPAND"
	if "collapse" in t or "minimize" in t or "hide" in t:
		return "HIDE"
	if "setting" in t:
		return "SETTINGS"
	if "menu" in t:
		return "MENU"
	if "equipment" in t or "inventory" in t or "gear" in t:
		return "GEAR"
	if "message" in t or "chat" in t:
		return "CHAT"
	if "feedback" in t:
		return "FEEDBACK"
	if "info" in t or "help" in t:
		return "INFO"
	if "left" in t:
		return "LEFT"
	if "right" in t:
		return "RIGHT"
	if "up" in t or "forward" in t:
		return "UP"
	return "ACTION"
