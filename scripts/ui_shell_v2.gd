extends CanvasLayer
## Waypoint menu-only UI shell.
## The removed character/360 inspector previously introduced extra 3D lighting and
## viewport state. This shell now owns only the Menu surface and never creates
## cameras, lights, WorldEnvironment nodes, SubViewports, or actor transforms.

const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const MINT := Color("9bddc2")
const GOLD := Color("efd094")
const PANEL_BG := Color("183b3c")
const BORDER := Color("41645b")

var root: Control
var header_cover: PanelContainer
var menu_button: Button
var menu_panel: PanelContainer
var menu_outer: VBoxContainer
var menu_body: VBoxContainer
var menu_status: Label

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_header()
	_build_menu()

func _scene():
	return get_tree().current_scene

func _game():
	var scene = _scene()
	return scene.get("game") if scene != null else null

func _in_game() -> bool:
	var scene = _scene()
	return scene != null and not bool(scene.get("at_title"))

func _style(bg: Color, radius := 10, border := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _label(text_value: String, size := 12, color := INK) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text_value: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color("173a37") if primary else INK)
	b.add_theme_stylebox_override("normal", _style(MINT if primary else Color("294c49")))
	b.add_theme_stylebox_override("hover", _style(Color("c0ecd4") if primary else Color("385f56"), 10, MINT))
	b.add_theme_stylebox_override("pressed", _style(Color("8bcdb1") if primary else Color("1c3b38"), 10, GOLD))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 10, GOLD))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func _build_header() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Covers the legacy Equipment/Menu buttons. Only the replacement Menu button is
	# exposed; equipment remains in the persistent right status rail.
	header_cover = PanelContainer.new()
	header_cover.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	header_cover.offset_left = -245
	header_cover.offset_right = -24
	header_cover.offset_top = 20
	header_cover.offset_bottom = 96
	header_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	header_cover.add_theme_stylebox_override("panel", _style(PANEL_BG, 14, Color("39605a")))
	root.add_child(header_cover)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	header_cover.add_child(row)
	menu_button = _button("Menu", func(): toggle_menu())
	menu_button.custom_minimum_size.x = 82
	row.add_child(menu_button)

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_panel.offset_left = -390
	menu_panel.offset_right = -20
	menu_panel.offset_top = 108
	menu_panel.offset_bottom = 109
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_theme_stylebox_override("panel", _style(Color("153334"), 14))
	menu_panel.hide()
	root.add_child(menu_panel)

	menu_outer = VBoxContainer.new()
	menu_outer.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu_outer)

	var head := HBoxContainer.new()
	menu_outer.add_child(head)
	var title := _label("MENU", 17, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Close", func(): close_menu())
	close.custom_minimum_size.x = 72
	head.add_child(close)

	menu_outer.add_child(HSeparator.new())
	menu_body = VBoxContainer.new()
	menu_body.add_theme_constant_override("separation", 7)
	menu_outer.add_child(menu_body)

	menu_status = _label("", 10, MUTED)
	menu_outer.add_child(menu_status)

func toggle_menu() -> void:
	if menu_panel.visible:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	if not _in_game():
		return
	_set_builtin_side_panel(false)
	_render_menu()
	menu_panel.offset_bottom = menu_panel.offset_top + 1.0
	menu_panel.show()
	call_deferred("_fit_menu_to_content")

func close_menu() -> void:
	if is_instance_valid(menu_panel):
		menu_panel.hide()
	if _in_game():
		_set_builtin_side_panel(true)

func _fit_menu_to_content() -> void:
	if not is_instance_valid(menu_panel) or not menu_panel.visible or not is_instance_valid(menu_outer):
		return
	var viewport_h := float(get_viewport().get_visible_rect().size.y)
	var max_h := maxf(250.0, viewport_h - menu_panel.offset_top - 20.0)
	var desired_h := clampf(menu_outer.get_combined_minimum_size().y + 18.0, 220.0, max_h)
	menu_panel.offset_bottom = menu_panel.offset_top + desired_h

func _clear_menu() -> void:
	for child in menu_body.get_children():
		menu_body.remove_child(child)
		child.queue_free()

func _render_menu() -> void:
	_clear_menu()
	var scene = _scene()
	var game = _game()
	if scene == null or game == null:
		return
	var data = game.get("data")
	if data is Dictionary:
		menu_body.add_child(_label("%s  /  STAGE %d  /  ROW %d" % [str(data.get("mode", "camp")).replace("_", " ").to_upper(), int(data.get("stage", 0)) + 1, int(data.get("row", 0))], 12, MINT))
	menu_body.add_child(_button("Resume / Close", func(): close_menu(), true))
	menu_body.add_child(_button("Save Now", func(): _save_now()))
	menu_body.add_child(_button("Settings", func(): _open_scene_panel("show_settings")))
	menu_body.add_child(_button("How to Play", func(): _open_scene_panel("show_help")))
	menu_body.add_child(_button("Save and Return to Title", func(): _return_to_title()))
	menu_body.add_child(_label("A = left   W = forward   D = right   SPACE = jump", 10, MUTED))
	menu_status.text = "Click Menu again or Close to hide this panel."

func _set_builtin_side_panel(value: bool) -> void:
	var scene = _scene()
	if scene == null:
		return
	var side = scene.get("side_panel")
	if side is Control:
		(side as Control).visible = value

func _save_now() -> void:
	var game = _game()
	if game != null:
		var ok = game.call("save_game")
		menu_status.text = "Progress saved." if bool(ok) else "Save could not be confirmed."
		call_deferred("_fit_menu_to_content")

func _open_scene_panel(method_name: String) -> void:
	var scene = _scene()
	close_menu()
	if scene != null and scene.has_method(method_name):
		scene.call(method_name)

func _return_to_title() -> void:
	var game = _game()
	var scene = _scene()
	if game != null:
		game.call("save_game")
	close_menu()
	if scene != null and scene.has_method("show_title"):
		scene.call("show_title")

func _process(_delta: float) -> void:
	var active := _in_game()
	header_cover.visible = active
	if not active:
		close_menu()
	elif menu_panel.visible:
		_set_builtin_side_panel(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and menu_panel.visible:
		close_menu()
		get_viewport().set_input_as_handled()
