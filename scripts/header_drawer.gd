extends CanvasLayer
## Header Equipment/Menu drawer for the right-side panel space.
## Rebinds only the two top-header buttons, leaving in-world/other Equipment buttons alone.

const Catalog = preload("res://scripts/catalog.gd")
const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const MINT := Color("9bddc2")
const GOLD := Color("efd094")

var root: Control
var panel: PanelContainer
var body: VBoxContainer
var title_label: Label
var status_label: Label
var active_mode: String = ""
var scan_accum: float = 0.0

func _ready() -> void:
	layer = 34
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_drawer()

func _build_drawer() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -390.0
	panel.offset_right = -20.0
	panel.offset_top = 108.0
	panel.offset_bottom = -20.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.hide()
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	outer.add_child(top)

	title_label = _label("PANEL", 17, GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	top.add_child(_button("CLOSE", func(): close_drawer(), false, 62.0))

	var divider := HSeparator.new()
	outer.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	scroll.add_child(body)

	status_label = _label("", 10, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status_label)

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("183b3c")
	s.border_color = Color("39605a")
	s.set_border_width_all(1)
	s.set_corner_radius_all(14)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(9)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s

func _label(text_value: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text_value: String, callback: Callable, primary: bool = false, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size.y = 36.0
	if min_width > 0.0:
		b.custom_minimum_size.x = min_width
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color("173a37") if primary else INK)
	b.add_theme_stylebox_override("normal", _button_style(MINT if primary else Color("294c49"), Color("41645b")))
	b.add_theme_stylebox_override("hover", _button_style(Color("c0ecd4") if primary else Color("385f56"), MINT))
	b.add_theme_stylebox_override("pressed", _button_style(Color("8bcdb1") if primary else Color("1c3b38"), GOLD))
	b.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), GOLD))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func _process(delta: float) -> void:
	scan_accum += delta
	if scan_accum >= 0.4:
		scan_accum = 0.0
		_bind_header_buttons()
		var scene := get_tree().current_scene
		if scene == null or bool(scene.get("at_title")):
			close_drawer()

func _bind_header_buttons() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_scan_for_header_buttons(scene)

func _scan_for_header_buttons(node: Node) -> void:
	if node is Button:
		var b := node as Button
		if not b.has_meta("waypoint_header_drawer_bound"):
			var label_text := b.text.strip_edges().to_lower()
			if label_text in ["equipment", "menu"] and b.get_global_rect().position.y < 110.0:
				_rebind_header_button(b, label_text)
	for child in node.get_children():
		_scan_for_header_buttons(child)

func _rebind_header_button(button: Button, mode: String) -> void:
	for connection in button.get_signal_connection_list("pressed"):
		var cb: Callable = connection.get("callable", Callable())
		if cb.is_valid() and button.pressed.is_connected(cb):
			button.pressed.disconnect(cb)
	button.pressed.connect(func(): toggle_drawer(mode))
	button.set_meta("waypoint_header_drawer_bound", true)

func toggle_drawer(mode: String) -> void:
	if panel.visible and active_mode == mode:
		close_drawer()
		return
	active_mode = mode
	panel.show()
	_render_active()

func close_drawer() -> void:
	active_mode = ""
	if is_instance_valid(panel):
		panel.hide()

func _clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _scene():
	return get_tree().current_scene

func _game():
	var scene = _scene()
	return scene.get("game") if scene != null else null

func _render_active() -> void:
	_clear_body()
	status_label.text = ""
	if active_mode == "equipment":
		_render_equipment()
	elif active_mode == "menu":
		_render_menu()

func _render_equipment() -> void:
	title_label.text = "EQUIPMENT"
	var game = _game()
	if game == null:
		body.add_child(_label("Game state unavailable.", 12, MUTED))
		return
	var data = game.get("data")
	if not (data is Dictionary):
		body.add_child(_label("Game state unavailable.", 12, MUTED))
		return
	var mode := str(data.get("mode", ""))
	if mode not in ["camp", "rest", "choice"]:
		body.add_child(_label("Equipment can be changed at Lantern Camp or a safe waypoint.", 13, MUTED))
		return

	var class_info: Dictionary = game.call("class_info")
	body.add_child(_label("%s  /  HP %d  /  ATK %d" % [str(class_info.get("name", "Wanderer")).to_upper(), int(game.call("max_hp")), int(game.call("attack"))], 15, MINT))
	body.add_child(_label("BANK %d   GEMS %d" % [int(data.get("coins", 0)), int(data.get("gems", 0))], 12, GOLD))
	body.add_child(_label("BEST GEAR", 11, GOLD))

	var equipped: Dictionary = data.get("equipped", {})
	for slot in ["core", "shell", "charm"]:
		var item: Dictionary = Catalog.item(str(equipped.get(slot, "")))
		if item.is_empty():
			body.add_child(_label("%s  /  none" % str(slot).to_upper(), 12, MUTED))
		else:
			body.add_child(_label("%s  /  [%s] %s" % [str(slot).to_upper(), str(item.get("rarity", "")), str(item.get("name", ""))], 12, INK))
			body.add_child(_label(str(item.get("text", "")), 10, MUTED))

	body.add_child(_button("EQUIP BEST", func(): _equip_best(), true))

	var potions: Dictionary = data.get("potions", {})
	body.add_child(_label("POTIONS  /  HEAL x%d  /  MANA x%d" % [int(potions.get("heal", 0)), int(potions.get("mana", 0))], 11, GOLD))
	var potion_row := HBoxContainer.new()
	potion_row.add_theme_constant_override("separation", 6)
	var heal := _button("USE HEAL", func(): _use_potion("heal"))
	heal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(heal)
	var mana := _button("USE MANA", func(): _use_potion("mana"))
	mana.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(mana)
	body.add_child(potion_row)

	body.add_child(_button("MARKETPLACE / WARDROBE", func(): _open_marketplace()))
	status_label.text = "Re-click Equipment to hide this panel."

func _render_menu() -> void:
	title_label.text = "MENU"
	var game = _game()
	var scene = _scene()
	if game == null or scene == null:
		body.add_child(_label("Menu unavailable.", 12, MUTED))
		return
	var data = game.get("data")
	if data is Dictionary:
		body.add_child(_label("%s  /  STAGE %d  /  ROW %d" % [str(data.get("mode", "camp")).replace("_", " ").to_upper(), int(data.get("stage", 0)) + 1, int(data.get("row", 0))], 13, MINT))
	body.add_child(_button("RESUME / CLOSE", func(): close_drawer(), true))
	body.add_child(_button("SAVE NOW", func(): _save_now()))
	body.add_child(_button("SETTINGS", func(): _open_scene_panel("show_settings")))
	body.add_child(_button("HOW TO PLAY", func(): _open_scene_panel("show_help")))
	body.add_child(_button("SAVE AND RETURN TO TITLE", func(): _return_to_title()))
	body.add_child(_label("CONTROLS", 11, GOLD))
	body.add_child(_label("A = left   W = forward   D = right   SPACE = jump", 11, MUTED))
	body.add_child(_label("Lantern Camp: drag character or use Q / E for 360 view.", 11, MUTED))
	status_label.text = "Re-click Menu to hide this panel."

func _refresh_main_game() -> void:
	var scene = _scene()
	if scene == null:
		return
	var world = scene.get("world")
	if world != null and world.has_method("refresh_actor"):
		world.call("refresh_actor")
	if scene.has_method("update_hud"):
		scene.call("update_hud")

func _equip_best() -> void:
	var game = _game()
	if game == null:
		return
	game.call("equip_best")
	game.call("save_game")
	_refresh_main_game()
	_render_active()
	status_label.text = "Best available loadout equipped."

func _use_potion(kind: String) -> void:
	var game = _game()
	if game == null:
		return
	game.call("use_potion", kind)
	game.call("save_game")
	_refresh_main_game()
	_render_active()
	var data = game.get("data")
	if data is Dictionary:
		status_label.text = str(data.get("last", "Potion used."))

func _open_marketplace() -> void:
	var scene = _scene()
	close_drawer()
	if scene != null and scene.has_method("show_marketplace"):
		scene.call("show_marketplace", "skin")

func _save_now() -> void:
	var game = _game()
	if game != null:
		var ok = game.call("save_game")
		status_label.text = "Progress saved." if bool(ok) else "Save could not be confirmed."

func _open_scene_panel(method_name: String) -> void:
	var scene = _scene()
	close_drawer()
	if scene != null and scene.has_method(method_name):
		scene.call(method_name)

func _return_to_title() -> void:
	var game = _game()
	var scene = _scene()
	if game != null:
		game.call("save_game")
	close_drawer()
	if scene != null and scene.has_method("show_title"):
		scene.call("show_title")

func _input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_drawer()
		get_viewport().set_input_as_handled()
