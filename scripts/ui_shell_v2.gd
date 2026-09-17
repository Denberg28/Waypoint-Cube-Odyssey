extends CanvasLayer
## Waypoint menu-only UI shell v3.
## Owns only the replacement Menu surface and coordinates with the built-in
## persistent status rail. It does not create 3D nodes, lights, cameras, or viewports.

const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const MINT := Color("9bddc2")
const GOLD := Color("efd094")
const PANEL_BG := Color("183b3c")
const PANEL_SURFACE := Color("153334")
const BUTTON_BG := Color("294c49")
const BORDER := Color("41645b")
const OUTER_PAD := 8
const INNER_GAP := 6
const MENU_WIDTH := 370.0
const MENU_TOP := 108.0
const SCREEN_MARGIN := 20.0

var root: Control
var header_cover: PanelContainer
var menu_button: Button
var menu_panel: PanelContainer
var menu_outer: VBoxContainer
var menu_body: VBoxContainer
var menu_status: Label
var previous_side_minimized := false
var side_state_captured := false
var ui_policy_applied := false

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

func _style(bg: Color, radius := 10, border := BORDER, pad := OUTER_PAD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
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
	b.custom_minimum_size.y = 36
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color("173a37") if primary else INK)
	b.add_theme_color_override("font_hover_color", Color("173a37") if primary else Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(MINT if primary else BUTTON_BG, 9, BORDER, 7))
	b.add_theme_stylebox_override("hover", _style(Color("c0ecd4") if primary else Color("385f56"), 9, MINT, 7))
	b.add_theme_stylebox_override("pressed", _style(Color("8bcdb1") if primary else Color("1c3b38"), 9, GOLD, 7))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 9, GOLD, 7))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func _build_header() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The native Equipment button is hidden at runtime. This narrow cover masks only
	# the legacy Menu button and replaces it with the menu-only shell control.
	header_cover = PanelContainer.new()
	header_cover.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	header_cover.offset_left = -118
	header_cover.offset_right = -24
	header_cover.offset_top = 20
	header_cover.offset_bottom = 96
	header_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	header_cover.add_theme_stylebox_override("panel", _style(PANEL_BG, 14, Color("39605a"), 8))
	root.add_child(header_cover)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_cover.add_child(row)
	menu_button = _button("Menu", func(): toggle_menu())
	menu_button.custom_minimum_size = Vector2(78, 44)
	row.add_child(menu_button)

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_panel.offset_left = -MENU_WIDTH - SCREEN_MARGIN
	menu_panel.offset_right = -SCREEN_MARGIN
	menu_panel.offset_top = MENU_TOP
	menu_panel.offset_bottom = MENU_TOP + 1.0
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_theme_stylebox_override("panel", _style(PANEL_SURFACE, 14, BORDER, 10))
	menu_panel.hide()
	root.add_child(menu_panel)

	menu_outer = VBoxContainer.new()
	menu_outer.add_theme_constant_override("separation", INNER_GAP)
	menu_panel.add_child(menu_outer)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	menu_outer.add_child(head)
	var title := _label("MENU", 17, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close := _button("Close", func(): close_menu())
	close.custom_minimum_size = Vector2(68, 34)
	head.add_child(close)

	menu_outer.add_child(HSeparator.new())
	menu_body = VBoxContainer.new()
	menu_body.add_theme_constant_override("separation", INNER_GAP)
	menu_outer.add_child(menu_body)

	menu_status = _label("", 10, MUTED)
	menu_status.visible = false
	menu_outer.add_child(menu_status)

func toggle_menu() -> void:
	if menu_panel.visible:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	if not _in_game():
		return
	_capture_and_minimize_side_panel()
	_render_menu()
	menu_panel.offset_bottom = menu_panel.offset_top + 1.0
	menu_panel.show()
	call_deferred("_fit_menu_to_content")

func close_menu() -> void:
	if is_instance_valid(menu_panel):
		menu_panel.hide()
	_restore_side_panel_state()

func _capture_and_minimize_side_panel() -> void:
	var scene = _scene()
	if scene == null:
		return
	if not side_state_captured:
		previous_side_minimized = bool(scene.get("side_panel_minimized"))
		side_state_captured = true
	scene.set("side_panel_minimized", true)
	if scene.has_method("apply_side_panel_mode"):
		scene.call("apply_side_panel_mode")
	var side = scene.get("side_panel")
	if side is Control:
		(side as Control).visible = true

func _restore_side_panel_state() -> void:
	var scene = _scene()
	if scene == null:
		side_state_captured = false
		return
	if side_state_captured:
		scene.set("side_panel_minimized", previous_side_minimized)
		if scene.has_method("apply_side_panel_mode"):
			scene.call("apply_side_panel_mode")
		side_state_captured = false
	var side = scene.get("side_panel")
	if side is Control:
		(side as Control).visible = _in_game()

func _fit_menu_to_content() -> void:
	if not is_instance_valid(menu_panel) or not menu_panel.visible or not is_instance_valid(menu_outer):
		return
	# Fit exactly to content. Only clamp when the viewport itself is too short.
	var viewport_h := float(get_viewport().get_visible_rect().size.y)
	var content_h := ceilf(menu_outer.get_combined_minimum_size().y) + 2.0
	var max_h := maxf(180.0, viewport_h - MENU_TOP - SCREEN_MARGIN)
	var desired_h := minf(content_h, max_h)
	menu_panel.offset_bottom = menu_panel.offset_top + desired_h

func _clear_menu() -> void:
	for child in menu_body.get_children():
		menu_body.remove_child(child)
		child.queue_free()

func _render_menu() -> void:
	_clear_menu()
	menu_status.visible = false
	var scene = _scene()
	var game = _game()
	if scene == null or game == null:
		return
	var data = game.get("data")
	if data is Dictionary:
		var context := _label("%s  /  STAGE %d  /  ROW %d" % [str(data.get("mode", "camp")).replace("_", " ").to_upper(), int(data.get("stage", 0)) + 1, int(data.get("row", 0))], 11, MINT)
		context.clip_text = true
		menu_body.add_child(context)
	menu_body.add_child(_button("Resume / Close", func(): close_menu(), true))
	menu_body.add_child(_button("Save Now", func(): _save_now()))
	menu_body.add_child(_button("Settings", func(): _open_scene_panel("show_settings")))
	menu_body.add_child(_button("How to Play", func(): _open_scene_panel("show_help")))
	menu_body.add_child(_button("Save and Return to Title", func(): _return_to_title()))
	var controls := _label("A left   W forward   D right   SPACE jump", 10, MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_body.add_child(controls)

func _save_now() -> void:
	var game = _game()
	if game != null:
		var ok = game.call("save_game")
		menu_status.text = "Progress saved." if bool(ok) else "Save could not be confirmed."
		menu_status.visible = true
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

func _apply_known_panel_policy() -> void:
	if ui_policy_applied:
		return
	var scene = _scene()
	if scene == null or bool(scene.get("at_title")):
		return
	# Centralize visual rhythm for the known runtime panels without scanning the tree.
	for property_name in ["panel", "route_panel", "fight_card", "side_panel"]:
		var node = scene.get(property_name)
		if node is PanelContainer:
			var card := node as PanelContainer
			card.add_theme_stylebox_override("panel", _style(Color("112d30") if property_name != "side_panel" else PANEL_SURFACE, 14, BORDER, 9))
	var main_stack = scene.get("stack")
	if main_stack is BoxContainer:
		(main_stack as BoxContainer).add_theme_constant_override("separation", 6)
	var route_box = scene.get("route_box")
	if route_box is BoxContainer:
		(route_box as BoxContainer).add_theme_constant_override("separation", 6)
	ui_policy_applied = true

func _hide_redundant_native_equipment() -> void:
	var scene = _scene()
	if scene == null:
		return
	var native_equipment = scene.get("gear_button")
	if native_equipment is Control:
		(native_equipment as Control).visible = false

func _process(_delta: float) -> void:
	var active := _in_game()
	header_cover.visible = active
	if active:
		_hide_redundant_native_equipment()
		_apply_known_panel_policy()
	if not active:
		if menu_panel.visible:
			menu_panel.hide()
		_restore_side_panel_state()
	elif menu_panel.visible:
		# Keep the built-in rail visible and minimized while Menu is open.
		_capture_and_minimize_side_panel()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and menu_panel.visible:
		close_menu()
		get_viewport().set_input_as_handled()
