extends CanvasLayer
## Stable UI shell for header actions, side sheets, and 360 character inspection.
## - explicit controls (no signal rebinding / tree scans)
## - isolated SubViewport character preview (never rotates the live gameplay actor)
## - only explicit shell controls consume input

const Catalog = preload("res://scripts/catalog.gd")
const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const MINT := Color("9bddc2")
const GOLD := Color("efd094")
const PANEL_BG := Color("183b3c")
const BORDER := Color("41645b")
const VIEW_DRAG_SENSITIVITY := 0.012

var root: Control
var header_cover: PanelContainer
var character_button: Button
var equipment_button: Button
var menu_button: Button
var sheet: PanelContainer
var sheet_title: Label
var sheet_body: VBoxContainer
var sheet_status: Label
var active_sheet := ""
var modal_backdrop: ColorRect
var viewport_container: SubViewportContainer
var viewport: SubViewport
var viewer_root: Node3D
var viewer_model: Node3D
var viewer_dragging := false
var viewer_yaw := PI

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_shell()
	_build_viewer_modal()

func _scene():
	return get_tree().current_scene

func _game():
	var scene = _scene()
	return scene.get("game") if scene != null else null

func _world():
	var scene = _scene()
	return scene.get("world") if scene != null else null

func _safe_camp_mode() -> bool:
	var scene = _scene()
	if scene == null or bool(scene.get("at_title")):
		return false
	var game = _game()
	if game == null:
		return false
	var data = game.get("data")
	return data is Dictionary and str(data.get("mode", "")) in ["camp", "rest", "choice"]

func _style(bg: Color = PANEL_BG, radius: int = 10, border: Color = BORDER) -> StyleBoxFlat:
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

func _label(text_value: String, size: int, color: Color = INK) -> Label:
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
	b.add_theme_stylebox_override("normal", _style(MINT if primary else Color("294c49"), 9))
	b.add_theme_stylebox_override("hover", _style(Color("c0ecd4") if primary else Color("385f56"), 9, MINT))
	b.add_theme_stylebox_override("pressed", _style(Color("8bcdb1") if primary else Color("1c3b38"), 9, GOLD))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 9, GOLD))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func _build_shell() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	header_cover = PanelContainer.new()
	header_cover.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	header_cover.offset_left = -350
	header_cover.offset_right = -24
	header_cover.offset_top = 20
	header_cover.offset_bottom = 96
	header_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	header_cover.add_theme_stylebox_override("panel", _style(PANEL_BG, 14, Color("39605a")))
	root.add_child(header_cover)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_cover.add_child(header_row)
	character_button = _button("Character", func(): open_character_viewer())
	character_button.custom_minimum_size.x = 98
	header_row.add_child(character_button)
	equipment_button = _button("Equipment", func(): toggle_sheet("equipment"))
	equipment_button.custom_minimum_size.x = 105
	header_row.add_child(equipment_button)
	menu_button = _button("Menu", func(): toggle_sheet("menu"))
	menu_button.custom_minimum_size.x = 82
	header_row.add_child(menu_button)

	sheet = PanelContainer.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sheet.offset_left = -390
	sheet.offset_right = -20
	sheet.offset_top = 108
	sheet.offset_bottom = -20
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.add_theme_stylebox_override("panel", _style(Color("153334"), 14))
	sheet.hide()
	root.add_child(sheet)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	sheet.add_child(outer)
	var sheet_header := HBoxContainer.new()
	outer.add_child(sheet_header)
	sheet_title = _label("PANEL", 17, GOLD)
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_header.add_child(sheet_title)
	var close_button := _button("Close", func(): close_sheet())
	close_button.custom_minimum_size.x = 72
	sheet_header.add_child(close_button)
	outer.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	sheet_body = VBoxContainer.new()
	sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_body.add_theme_constant_override("separation", 7)
	scroll.add_child(sheet_body)
	sheet_status = _label("", 10, MUTED)
	outer.add_child(sheet_status)

func _build_viewer_modal() -> void:
	modal_backdrop = ColorRect.new()
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.color = Color(0.01, 0.03, 0.04, 0.78)
	modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_backdrop.hide()
	root.add_child(modal_backdrop)

	var modal_card := PanelContainer.new()
	modal_card.set_anchors_preset(Control.PRESET_CENTER)
	modal_card.offset_left = -255
	modal_card.offset_right = 255
	modal_card.offset_top = -300
	modal_card.offset_bottom = 300
	modal_card.add_theme_stylebox_override("panel", _style(Color("153334"), 18, Color("567e6d")))
	modal_backdrop.add_child(modal_card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	modal_card.add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	var title := _label("CHARACTER INSPECT", 18, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Close", func(): close_character_viewer())
	close.custom_minimum_size.x = 76
	head.add_child(close)
	var help := _label("Drag inside the preview to rotate. Gameplay remains untouched.", 11, MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(help)

	viewport_container = SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(450, 430)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_container.gui_input.connect(_on_viewer_gui_input)
	stack.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.size = Vector2i(450, 430)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	viewer_root = Node3D.new()
	viewport.add_child(viewer_root)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("20383f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c7c2")
	env.ambient_light_energy = 0.7
	env_node.environment = env
	viewer_root.add_child(env_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.1
	viewer_root.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 2.5, 3)
	fill.light_energy = 2.0
	fill.omni_range = 8.0
	viewer_root.add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.2, 4.6)
	camera.fov = 40
	camera.current = true
	camera.look_at(Vector3(0, 0.65, 0), Vector3.UP)
	viewer_root.add_child(camera)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)
	var left := _button("Left", func(): rotate_preview(deg_to_rad(30.0)))
	var reset := _button("Reset", func(): reset_preview())
	var right := _button("Right", func(): rotate_preview(deg_to_rad(-30.0)))
	for b in [left, reset, right]:
		b.custom_minimum_size.x = 92
		actions.add_child(b)

func _process(_delta: float) -> void:
	var scene = _scene()
	var gameplay_visible := scene != null and not bool(scene.get("at_title"))
	header_cover.visible = gameplay_visible
	character_button.visible = gameplay_visible and _safe_camp_mode()
	if not gameplay_visible:
		close_sheet()
		close_character_viewer()
	if sheet.visible and active_sheet == "equipment" and not _safe_camp_mode():
		close_sheet()

func _set_builtin_side_panel_visible(value: bool) -> void:
	var scene = _scene()
	if scene == null:
		return
	var builtin = scene.get("side_panel")
	if builtin is Control:
		(builtin as Control).visible = value

func toggle_sheet(mode: String) -> void:
	if sheet.visible and active_sheet == mode:
		close_sheet()
		return
	active_sheet = mode
	sheet.show()
	_set_builtin_side_panel_visible(false)
	_render_sheet()

func close_sheet() -> void:
	active_sheet = ""
	if is_instance_valid(sheet):
		sheet.hide()
	var scene = _scene()
	if scene != null and not bool(scene.get("at_title")):
		_set_builtin_side_panel_visible(true)

func _clear_sheet() -> void:
	for child in sheet_body.get_children():
		sheet_body.remove_child(child)
		child.queue_free()

func _render_sheet() -> void:
	_clear_sheet()
	sheet_status.text = ""
	if active_sheet == "equipment":
		_render_equipment()
	elif active_sheet == "menu":
		_render_menu()

func _render_equipment() -> void:
	sheet_title.text = "EQUIPMENT"
	var game = _game()
	if game == null or not _safe_camp_mode():
		sheet_body.add_child(_label("Equipment is available at Lantern Camp and safe waypoints.", 12, MUTED))
		return
	var data = game.get("data")
	if not (data is Dictionary):
		return
	var class_info: Dictionary = game.call("class_info")
	sheet_body.add_child(_label("%s  /  HP %d  /  ATK %d" % [str(class_info.get("name", "Wanderer")).to_upper(), int(game.call("max_hp")), int(game.call("attack"))], 15, MINT))
	sheet_body.add_child(_label("BANK %d   GEMS %d" % [int(data.get("coins", 0)), int(data.get("gems", 0))], 12, GOLD))
	sheet_body.add_child(_label("LOADOUT", 11, GOLD))
	var equipped: Dictionary = data.get("equipped", {})
	for slot in ["core", "shell", "charm"]:
		var item: Dictionary = Catalog.item(str(equipped.get(slot, "")))
		if item.is_empty():
			sheet_body.add_child(_label("%s  /  none" % str(slot).to_upper(), 12, MUTED))
		else:
			sheet_body.add_child(_label("%s  /  [%s] %s" % [str(slot).to_upper(), str(item.get("rarity", "")), str(item.get("name", ""))], 12, INK))
			sheet_body.add_child(_label(str(item.get("text", "")), 10, MUTED))
	sheet_body.add_child(_button("Equip Best", func(): _equip_best(), true))
	sheet_body.add_child(_button("Inspect Character 360", func(): open_character_viewer()))
	sheet_body.add_child(_button("Marketplace / Wardrobe", func(): _open_marketplace()))
	sheet_status.text = "Click Equipment again or Close to return to the normal status rail."

func _render_menu() -> void:
	sheet_title.text = "MENU"
	var scene = _scene()
	var game = _game()
	if scene == null or game == null:
		return
	sheet_body.add_child(_button("Resume / Close", func(): close_sheet(), true))
	sheet_body.add_child(_button("Save Now", func(): _save_now()))
	sheet_body.add_child(_button("Settings", func(): _open_scene_panel("show_settings")))
	sheet_body.add_child(_button("How to Play", func(): _open_scene_panel("show_help")))
	if _safe_camp_mode():
		sheet_body.add_child(_button("Character Inspect", func(): open_character_viewer()))
	sheet_body.add_child(_button("Save and Return to Title", func(): _return_to_title()))
	sheet_status.text = "Click Menu again or Close to hide this sheet."

func _refresh_game() -> void:
	var scene = _scene()
	var world = _world()
	if world != null and world.has_method("refresh_actor"):
		world.call("refresh_actor")
	if scene != null and scene.has_method("update_hud"):
		scene.call("update_hud")

func _equip_best() -> void:
	var game = _game()
	if game == null:
		return
	game.call("equip_best")
	game.call("save_game")
	_refresh_game()
	_render_sheet()

func _save_now() -> void:
	var game = _game()
	if game != null:
		var ok = game.call("save_game")
		sheet_status.text = "Progress saved." if bool(ok) else "Save could not be confirmed."

func _open_marketplace() -> void:
	var scene = _scene()
	close_sheet()
	if scene != null and scene.has_method("show_marketplace"):
		scene.call("show_marketplace", "skin")

func _open_scene_panel(method_name: String) -> void:
	var scene = _scene()
	close_sheet()
	if scene != null and scene.has_method(method_name):
		scene.call(method_name)

func _return_to_title() -> void:
	var game = _game()
	var scene = _scene()
	if game != null:
		game.call("save_game")
	close_sheet()
	if scene != null and scene.has_method("show_title"):
		scene.call("show_title")

func open_character_viewer() -> void:
	if not _safe_camp_mode():
		return
	close_sheet()
	_rebuild_preview_model()
	viewer_dragging = false
	modal_backdrop.show()

func close_character_viewer() -> void:
	viewer_dragging = false
	if is_instance_valid(modal_backdrop):
		modal_backdrop.hide()

func _rebuild_preview_model() -> void:
	if is_instance_valid(viewer_model):
		viewer_model.queue_free()
		viewer_model = null
	var world = _world()
	if world == null:
		return
	var source = world.get("actor")
	if not (source is Node3D):
		return
	var duplicate = (source as Node3D).duplicate(Node.DUPLICATE_USE_INSTANTIATION)
	if not (duplicate is Node3D):
		return
	viewer_model = duplicate as Node3D
	viewer_model.position = Vector3.ZERO
	viewer_model.scale = Vector3.ONE
	viewer_yaw = PI
	viewer_model.rotation = Vector3(0, viewer_yaw, 0)
	viewer_root.add_child(viewer_model)

func rotate_preview(amount: float) -> void:
	viewer_yaw = wrapf(viewer_yaw + amount, -PI, PI)
	if is_instance_valid(viewer_model):
		viewer_model.rotation.y = viewer_yaw

func reset_preview() -> void:
	viewer_yaw = PI
	if is_instance_valid(viewer_model):
		viewer_model.rotation.y = viewer_yaw

func _on_viewer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		viewer_dragging = event.pressed
		viewport_container.accept_event()
	elif event is InputEventMouseMotion and viewer_dragging:
		rotate_preview(event.relative.x * VIEW_DRAG_SENSITIVITY)
		viewport_container.accept_event()
	elif event is InputEventScreenTouch:
		viewer_dragging = event.pressed
		viewport_container.accept_event()
	elif event is InputEventScreenDrag and viewer_dragging:
		rotate_preview(event.relative.x * VIEW_DRAG_SENSITIVITY)
		viewport_container.accept_event()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if modal_backdrop.visible:
			close_character_viewer()
			get_viewport().set_input_as_handled()
		elif sheet.visible:
			close_sheet()
			get_viewport().set_input_as_handled()
