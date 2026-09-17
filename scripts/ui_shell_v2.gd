extends CanvasLayer
## Waypoint UI shell v2.
## Replaces header Equipment/Menu interception with explicit owned controls.
## Character inspection uses a dedicated SubViewport and visual-only clone so
## gameplay transforms and input remain untouched.

const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const MINT := Color("9bddc2")
const GOLD := Color("efd094")
const PANEL_BG := Color("183b3c")
const BORDER := Color("41645b")
const DRAG_SENSITIVITY := 0.012

var root: Control
var header_cover: PanelContainer
var character_button: Button
var menu_button: Button
var menu_panel: PanelContainer
var menu_body: VBoxContainer
var menu_status: Label

var modal_backdrop: ColorRect
var preview_holder: Control
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_root: Node3D
var preview_model: Node3D
var preview_drag_surface: Control
var dragging := false
var preview_yaw := PI

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_header()
	_build_menu()
	_build_preview_modal()

func _scene():
	return get_tree().current_scene

func _game():
	var scene = _scene()
	return scene.get("game") if scene != null else null

func _world():
	var scene = _scene()
	return scene.get("world") if scene != null else null

func _in_game() -> bool:
	var scene = _scene()
	return scene != null and not bool(scene.get("at_title"))

func _safe_camp() -> bool:
	if not _in_game():
		return false
	var game = _game()
	if game == null:
		return false
	var data = game.get("data")
	return data is Dictionary and str(data.get("mode", "")) in ["camp", "rest", "choice"]

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
	b.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), 10, GOLD))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func _build_header() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# This intentionally covers the legacy Equipment/Menu area. Equipment is removed
	# because the persistent right rail already exposes equipment details/actions.
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
	row.add_theme_constant_override("separation", 8)
	header_cover.add_child(row)

	character_button = _button("Character", func(): open_character_viewer())
	character_button.custom_minimum_size.x = 112
	row.add_child(character_button)

	menu_button = _button("Menu", func(): toggle_menu())
	menu_button.custom_minimum_size.x = 82
	row.add_child(menu_button)

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_panel.offset_left = -390
	menu_panel.offset_right = -20
	menu_panel.offset_top = 108
	menu_panel.offset_bottom = 450
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_theme_stylebox_override("panel", _style(Color("153334"), 14))
	menu_panel.hide()
	root.add_child(menu_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	menu_panel.add_child(outer)

	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := _label("MENU", 17, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Close", func(): close_menu())
	close.custom_minimum_size.x = 72
	head.add_child(close)

	outer.add_child(HSeparator.new())
	menu_body = VBoxContainer.new()
	menu_body.add_theme_constant_override("separation", 7)
	outer.add_child(menu_body)

	menu_status = _label("", 10, MUTED)
	outer.add_child(menu_status)

func toggle_menu() -> void:
	if menu_panel.visible:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	if not _in_game():
		return
	close_character_viewer()
	_set_builtin_side_panel(false)
	_render_menu()
	menu_panel.show()
	call_deferred("_fit_menu_to_content")

func close_menu() -> void:
	if is_instance_valid(menu_panel):
		menu_panel.hide()
	if _in_game():
		_set_builtin_side_panel(true)

func _fit_menu_to_content() -> void:
	if not is_instance_valid(menu_panel) or not menu_panel.visible:
		return
	var min_h := menu_panel.get_combined_minimum_size().y
	var viewport_h := get_viewport().get_visible_rect().size.y
	var max_h := maxf(260.0, viewport_h - 128.0)
	var fitted := clampf(min_h, 250.0, max_h)
	menu_panel.offset_bottom = menu_panel.offset_top + fitted

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
	if _safe_camp():
		menu_body.add_child(_button("Character Inspect", func(): open_character_viewer()))
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

func _build_preview_modal() -> void:
	modal_backdrop = ColorRect.new()
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.color = Color(0.01, 0.03, 0.04, 0.80)
	modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_backdrop.hide()
	root.add_child(modal_backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -260
	card.offset_right = 260
	card.offset_top = -285
	card.offset_bottom = 285
	card.add_theme_stylebox_override("panel", _style(Color("153334"), 18, Color("567e6d")))
	modal_backdrop.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)

	var head := HBoxContainer.new()
	stack.add_child(head)
	var title := _label("CHARACTER INSPECT", 18, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Close", func(): close_character_viewer())
	close.custom_minimum_size.x = 76
	head.add_child(close)

	var help := _label("Drag directly on the preview to rotate 360 degrees.", 11, MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(help)

	preview_holder = Control.new()
	preview_holder.custom_minimum_size = Vector2(460, 410)
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(preview_holder)

	preview_container = SubViewportContainer.new()
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(preview_container)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(460, 410)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.transparent_bg = false
	preview_container.add_child(preview_viewport)

	preview_root = Node3D.new()
	preview_viewport.add_child(preview_root)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("20383f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d1cc")
	env.ambient_light_energy = 0.78
	env_node.environment = env
	preview_root.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -30, 0)
	key.light_energy = 1.15
	preview_root.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.2, 2.8, 3.0)
	fill.light_energy = 2.2
	fill.omni_range = 9.0
	preview_root.add_child(fill)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, 4.8)
	camera.fov = 38
	preview_root.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0, 0.62, 0), Vector3.UP)

	# Ordinary Control overlay captures drag reliably on Web; it does not rely on
	# SubViewport input forwarding.
	preview_drag_surface = Control.new()
	preview_drag_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_drag_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_drag_surface.mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview_drag_surface.gui_input.connect(_on_preview_drag_input)
	preview_holder.add_child(preview_drag_surface)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)
	for spec in [["Left", 30.0], ["Reset", 0.0], ["Right", -30.0]]:
		var label_text := str(spec[0])
		var degrees := float(spec[1])
		var b: Button
		if label_text == "Reset":
			b = _button(label_text, func(): reset_preview())
		else:
			b = _button(label_text, func(): rotate_preview(deg_to_rad(degrees)))
		b.custom_minimum_size.x = 96
		actions.add_child(b)

func _clone_visuals(source: Node, parent: Node3D) -> void:
	for child in source.get_children():
		if child is MeshInstance3D:
			var src := child as MeshInstance3D
			var copy := MeshInstance3D.new()
			copy.transform = src.transform
			copy.mesh = src.mesh
			copy.material_override = src.material_override
			copy.cast_shadow = src.cast_shadow
			parent.add_child(copy)
		elif child is Node3D:
			var src3d := child as Node3D
			var pivot := Node3D.new()
			pivot.transform = src3d.transform
			parent.add_child(pivot)
			_clone_visuals(src3d, pivot)

func open_character_viewer() -> void:
	if not _safe_camp():
		return
	close_menu()
	_rebuild_preview()
	modal_backdrop.show()

func close_character_viewer() -> void:
	dragging = false
	if is_instance_valid(modal_backdrop):
		modal_backdrop.hide()

func _rebuild_preview() -> void:
	if is_instance_valid(preview_model):
		preview_model.queue_free()
	preview_model = Node3D.new()
	preview_root.add_child(preview_model)
	var world = _world()
	if world == null:
		return
	var actor = world.get("actor")
	if actor is Node3D:
		_clone_visuals(actor as Node3D, preview_model)
	preview_yaw = PI
	preview_model.rotation.y = preview_yaw

func rotate_preview(amount: float) -> void:
	preview_yaw = wrapf(preview_yaw + amount, -PI, PI)
	if is_instance_valid(preview_model):
		preview_model.rotation.y = preview_yaw

func reset_preview() -> void:
	preview_yaw = PI
	if is_instance_valid(preview_model):
		preview_model.rotation.y = preview_yaw

func _on_preview_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		preview_drag_surface.accept_event()
	elif event is InputEventMouseMotion and dragging:
		rotate_preview(event.relative.x * DRAG_SENSITIVITY)
		preview_drag_surface.accept_event()
	elif event is InputEventScreenTouch:
		dragging = event.pressed
		preview_drag_surface.accept_event()
	elif event is InputEventScreenDrag and dragging:
		rotate_preview(event.relative.x * DRAG_SENSITIVITY)
		preview_drag_surface.accept_event()

func _process(_delta: float) -> void:
	var active := _in_game()
	header_cover.visible = active
	character_button.visible = active and _safe_camp()
	if not active:
		close_menu()
		close_character_viewer()
	elif menu_panel.visible:
		_set_builtin_side_panel(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if modal_backdrop.visible:
			close_character_viewer()
			get_viewport().set_input_as_handled()
		elif menu_panel.visible:
			close_menu()
			get_viewport().set_input_as_handled()
