extends Node3D
const State = preload("res://scripts/state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const World = preload("res://scripts/world.gd")
const FishingRipple = preload("res://scripts/fishing_ripple.gd")
const AIFeedback = preload("res://scripts/ai_feedback.gd")
const AIGameMasterBridge = preload("res://scripts/ai_gamemaster_bridge.gd")
const AITelemetry = preload("res://scripts/ai_telemetry.gd")
const INK = Color("ecf0dd")
const MUTED = Color("a5bcb5")
const MINT = Color("9bddc2")
const GOLD = Color("efd094")
const FONT_CAPTION: int = 10
const FONT_BODY: int = 12
const FONT_BUTTON: int = 14
const FONT_HEADING: int = 18
const FONT_TITLE: int = 28

# Shared UI window geometry. All transient cards use these rules so controls stay on-screen.
const WINDOW_BOTTOM_MARGIN: float = 20.0
const WINDOW_SAFE_TOP: float = 170.0
const WINDOW_MIN_HEIGHT: float = 118.0
const WINDOW_STANDARD_WIDTH: float = 430.0
const WINDOW_MAX_HEIGHT_FALLBACK: float = 590.0
const WINDOW_ROUTE_WIDTH: float = 420.0
const WINDOW_FIGHT_WIDTH: float = 360.0
const WINDOW_FISH_WIDTH: float = 400.0
var game = State.new()
var ai_feedback_store = AIFeedback.new()
var ai_gm_bridge = AIGameMasterBridge.new()
var ai_telemetry = AITelemetry.new()
var ai_world_state: Dictionary = {}
var ai_gm_last_applied: Dictionary = {}
var world
var ui: Control
var overlay: ColorRect
var panel: PanelContainer
var stack: VBoxContainer
var health: Label
var economy: Label
var title: Label
var subtitle: Label
var message: Label
var progress: Label
var stage_bar: ProgressBar
var boss_label: Label
var save_label: Label
var gear_button: Button
var hop_buttons: Array = []
var busy: bool = false
var muted: bool = false
var audio: AudioStreamPlayer
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var music_muted: bool = false
var current_music_context: String = ""
var current_music_variant: int = -1
var swipe_start = Vector2.ZERO
var swipe_tracking: bool = false
var at_title: bool = true
var has_save: bool = false
var spinning: bool = false
var selected_class: String = "adventurer"
var selected_skin: int = 0
var selector_stats: Label
var preview_world
var selector_buttons: Array = []
var settings_path: String = "user://waypoint_settings.cfg"
var side_panel: PanelContainer
var side_full_body: ScrollContainer
var side_compact_body: VBoxContainer
var side_toggle_button: Button
var side_heading: Label
var compact_message: Label
var side_panel_minimized: bool = false
var side_stats: Label
var side_equipment: Label
var side_potions: Label
var chat_log: RichTextLabel
var ai_feedback_log: RichTextLabel
var ai_feedback_input: TextEdit
var ai_feedback_status: Label
var route_panel: PanelContainer
var route_box: VBoxContainer
var event_history: Array[String] = []
var fight_layer: Control
var fight_card: PanelContainer
var fight_title: Label
var fight_status: Label
var fight_player: ColorRect
var fight_enemy: ColorRect
var side_challenge: Label
var brightness_mode: int = 0
var brightness_buttons: Array = []
var fishing_layer: Control
var fishing_ripple
var fishing_status: Label
var fishing_leave_button: Button


func _ready() -> void:
	has_save = game.load_game()
	if has_save:
		ai_gm_last_applied = ai_gm_bridge.consume(game)
		if not ai_gm_last_applied.is_empty():
			has_save = game.save_game() or has_save
	ai_world_state = ai_gm_bridge.apply_directives_to_game(game)
	ai_telemetry.record("session_start", game, {"ai_world_state": ai_world_state.duplicate(true)})
	var settings = ConfigFile.new()
	if settings.load(settings_path) == OK:
		muted = bool(settings.get_value("audio", "muted", false))
		music_muted = bool(settings.get_value("audio", "music_muted", false))
		brightness_mode = clampi(int(settings.get_value("display", "brightness_mode", 0)), 0, 2)
		side_panel_minimized = bool(settings.get_value("ui", "status_minimized", false))
	world = World.new()
	add_child(world)
	world.setup(game)
	world.route_clicked.connect(func(route_id: String): preview_route(route_id))
	world.marketplace_clicked.connect(func():
		if not at_title and not busy and game.data.mode in ["camp", "rest", "choice"]:
			show_marketplace("skin")
	)
	world.set_brightness(brightness_factor())
	build_ui()
	apply_side_panel_mode()
	refresh_ai_feedback_feed()
	update_brightness_buttons()
	audio = AudioStreamPlayer.new()
	audio.volume_db = -15
	add_child(audio)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -23
	add_child(music_player)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -25
	add_child(ambient_player)
	update_music(true)
	update_ambient()
	update_hud()
	show_title()
	get_tree().auto_accept_quit = false

func style(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = border
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func compact_style(color: Color, radius: int = 10, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s = style(color, radius, border)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func label(text: String, size: int, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", FONT_BUTTON)
	b.add_theme_color_override("font_color", Color("173a37") if primary else INK)
	b.add_theme_color_override("font_hover_color", Color("173a37") if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("173a37") if primary else INK)
	b.add_theme_stylebox_override("normal", style(MINT if primary else Color("294c49"), 10, Color("41645b")))
	b.add_theme_stylebox_override("hover", style(Color("c0ecd4") if primary else Color("385f56"), 10, MINT))
	b.add_theme_stylebox_override("pressed", style(Color("8bcdb1") if primary else Color("1c3b38"), 10, GOLD))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), 10, GOLD))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b

func small_icon_button(text_value: String, callback: Callable, tooltip: String) -> Button:
	var b = Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(34, 32)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_stylebox_override("normal", compact_style(Color("244747"), 8, Color("41645b")))
	b.add_theme_stylebox_override("hover", compact_style(Color("385f56"), 8, MINT))
	b.add_theme_stylebox_override("pressed", compact_style(Color("1c3b38"), 8, GOLD))
	b.add_theme_stylebox_override("focus", compact_style(Color(0, 0, 0, 0), 8, GOLD))
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func current_character_color() -> Color:
	var color: Color = Color(Catalog.SKINS[int(game.data.skin)].color)
	if game.data.has("cosmetics_equipped"):
		var cosmetic_skin: Dictionary = Catalog.cosmetic(str(game.data.cosmetics_equipped.get("skin", "")))
		if not cosmetic_skin.is_empty() and cosmetic_skin.has("color"):
			color = Color(str(cosmetic_skin.color))
	return color

func brightness_factor() -> float:
	# Sun = full daylight; half moon is dimmest; full moon keeps a readable night level.
	return [0.90, 0.55, 0.72][brightness_mode]

func set_brightness_mode(index: int) -> void:
	brightness_mode = clampi(index, 0, 2)
	if is_instance_valid(world):
		world.set_brightness(brightness_factor())
	var settings = ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("audio", "muted", muted)
	settings.set_value("audio", "music_muted", music_muted)
	settings.set_value("display", "brightness_mode", brightness_mode)
	settings.save(settings_path)
	update_brightness_buttons()

func update_brightness_buttons() -> void:
	for i in range(brightness_buttons.size()):
		brightness_buttons[i].modulate = Color.WHITE if i == brightness_mode else Color(1, 1, 1, 0.58)

func schedule_modal_fit() -> void:
	call_deferred("fit_modal_to_content")

func viewport_safe_bottom_height() -> float:
	var viewport_height: float = float(get_viewport().get_visible_rect().size.y)
	if viewport_height <= 0.0:
		return WINDOW_MAX_HEIGHT_FALLBACK
	return maxf(WINDOW_MIN_HEIGHT, viewport_height - WINDOW_SAFE_TOP - WINDOW_BOTTOM_MARGIN)

func place_bottom_card(card: Control, width: float, height: float, bottom_margin: float = WINDOW_BOTTOM_MARGIN) -> void:
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.offset_left = -width * 0.5
	card.offset_right = width * 0.5
	card.offset_bottom = -bottom_margin
	card.offset_top = card.offset_bottom - height

func fit_modal_to_content() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(stack):
		return
	# Re-evaluate after the container has completed its minimum-size pass.
	var content_h: float = stack.get_combined_minimum_size().y + 28.0
	if at_title:
		var viewport_height: float = float(get_viewport().get_visible_rect().size.y)
		var title_max: float = maxf(300.0, viewport_height - 80.0) if viewport_height > 0.0 else 700.0
		var desired_h: float = clampf(content_h, 220.0, title_max)
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -310.0
		panel.offset_right = 310.0
		panel.offset_top = -desired_h * 0.5
		panel.offset_bottom = desired_h * 0.5
	else:
		var desired_h: float = clampf(content_h, WINDOW_MIN_HEIGHT, viewport_safe_bottom_height())
		place_bottom_card(panel, WINDOW_STANDARD_WIDTH, desired_h)

func place_modal() -> void:
	if at_title:
		overlay.color = Color(0.025, 0.07, 0.075, 0.72)
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -310.0
		panel.offset_right = 310.0
		panel.offset_top = -235.0
		panel.offset_bottom = 235.0
	else:
		overlay.color = Color(0.025, 0.07, 0.075, 0.045)
		place_bottom_card(panel, WINDOW_STANDARD_WIDTH, 220.0)

func build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var header = PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24
	header.offset_right = -24
	header.offset_top = 20
	header.offset_bottom = 96
	header.add_theme_stylebox_override("panel", style(Color("183b3c"), 14, Color("39605a")))
	ui.add_child(header)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	header.add_child(row)
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	var brand_top = HBoxContainer.new()
	brand_top.add_theme_constant_override("separation", 7)
	brand.add_child(brand_top)
	brand_top.add_child(label("W A Y P O I N T", 24, GOLD))
	var brightness_box = HBoxContainer.new()
	brightness_box.add_theme_constant_override("separation", 3)
	brand_top.add_child(brightness_box)
	brightness_buttons = []
	for entry in [["DAY", 0, "Day brightness"], ["DUSK", 1, "Dusk brightness"], ["NIGHT", 2, "Night brightness"]]:
		var brightness_index: int = int(entry[1])
		var brightness_button = small_icon_button(str(entry[0]), func(): set_brightness_mode(brightness_index), str(entry[2]))
		brightness_button.custom_minimum_size.x = 58.0
		brightness_button.add_theme_font_size_override("font_size", 10)
		brightness_box.add_child(brightness_button)
		brightness_buttons.append(brightness_button)
	brand.add_child(label("CUBE ODYSSEY   /   THE FREE ADVENTURE", 11, MUTED))
	health = label("", 20, MINT)
	health.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(health)
	economy = label("", 17, GOLD)
	economy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(economy)
	gear_button = button("Equipment", func(): show_inventory())
	row.add_child(gear_button)
	row.add_child(button("Menu", func(): show_pause()))
	var info = VBoxContainer.new()
	info.position = Vector2(36, 124)
	info.add_theme_constant_override("separation", 7)
	ui.add_child(info)
	title = label("", 30)
	info.add_child(title)
	subtitle = label("", 14, MUTED)
	info.add_child(subtitle)
	progress = label("", 16, GOLD)
	info.add_child(progress)
	stage_bar = ProgressBar.new()
	stage_bar.custom_minimum_size = Vector2(330, 10)
	stage_bar.max_value = State.STAGE_STEPS
	stage_bar.show_percentage = false
	stage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage_bg = StyleBoxFlat.new()
	stage_bg.bg_color = Color("1a3c3b")
	stage_bg.set_corner_radius_all(5)
	var stage_fill = StyleBoxFlat.new()
	stage_fill.bg_color = MINT
	stage_fill.set_corner_radius_all(5)
	stage_bar.add_theme_stylebox_override("background", stage_bg)
	stage_bar.add_theme_stylebox_override("fill", stage_fill)
	info.add_child(stage_bar)
	boss_label = label("", 21, MINT)
	info.add_child(boss_label)
	# Compact left-hand movement dock keeps the central road unobstructed.
	var footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 24
	footer.offset_right = 326
	footer.offset_top = -96
	footer.offset_bottom = -20
	footer.add_theme_stylebox_override("panel", compact_style(Color("183b3c"), 12, Color("39605a")))
	ui.add_child(footer)
	var bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 5)
	footer.add_child(bottom)
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	bottom.add_child(controls)
	for entry in [["A", -1, "A / Walk left"], ["W", 0, "W / Walk forward"], ["D", 1, "D / Walk right"]]:
		var direction: int = int(entry[1])
		var b = button(str(entry[0]), func(): do_move(direction, false), direction == 0)
		b.custom_minimum_size = Vector2(56, 42)
		b.add_theme_stylebox_override("normal", compact_style(MINT if direction == 0 else Color("294c49"), 9, Color("41645b")))
		b.add_theme_stylebox_override("hover", compact_style(Color("c0ecd4") if direction == 0 else Color("385f56"), 9, MINT))
		b.add_theme_stylebox_override("pressed", compact_style(Color("8bcdb1") if direction == 0 else Color("1c3b38"), 9, GOLD))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = str(entry[2])
		controls.add_child(b)
		hop_buttons.append(b)
	var jump_button = button("JUMP", func(): do_move(0, true))
	jump_button.custom_minimum_size = Vector2(66, 42)
	jump_button.add_theme_font_size_override("font_size", 11)
	jump_button.tooltip_text = "Space / Jump forward"
	controls.add_child(jump_button)
	hop_buttons.append(jump_button)
	var help_button = button("?", func(): show_help())
	help_button.custom_minimum_size = Vector2(42, 42)
	help_button.add_theme_stylebox_override("normal", compact_style(Color("294c49"), 9, Color("41645b")))
	help_button.add_theme_stylebox_override("hover", compact_style(Color("385f56"), 9, MINT))
	help_button.add_theme_stylebox_override("pressed", compact_style(Color("1c3b38"), 9, GOLD))
	controls.add_child(help_button)
	save_label = label("AUTOSAVE  /  OFFLINE", 10, MUTED)
	bottom.add_child(save_label)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.07, 0.075, 0.72)
	# The dimmer itself does not swallow world clicks; modal cards/buttons still receive input.
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.add_theme_stylebox_override("panel", style(Color("173b3b"), 22, Color("567e6d")))
	overlay.add_child(panel)
	stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)

	# Persistent adventure status rail. It can collapse into a minimal quick-action dock.
	side_panel = PanelContainer.new()
	side_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -390
	side_panel.offset_right = -20
	side_panel.offset_top = 108
	side_panel.offset_bottom = -20
	side_panel.add_theme_stylebox_override("panel", style(Color("153334"), 14, Color("41645b")))
	ui.add_child(side_panel)
	var side_root = VBoxContainer.new()
	side_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_root.add_theme_constant_override("separation", 4)
	side_panel.add_child(side_root)
	var side_header = HBoxContainer.new()
	side_header.add_theme_constant_override("separation", 6)
	side_root.add_child(side_header)
	side_heading = label("STATUS", FONT_CAPTION, GOLD)
	side_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	side_header.add_child(side_heading)
	side_toggle_button = button("Minimize", func(): set_side_panel_minimized(not side_panel_minimized))
	side_toggle_button.custom_minimum_size = Vector2(86, 30)
	side_toggle_button.add_theme_font_size_override("font_size", 11)
	side_header.add_child(side_toggle_button)

	side_full_body = ScrollContainer.new()
	side_full_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_full_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_full_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_root.add_child(side_full_body)
	var side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 7)
	side_full_body.add_child(side)
	side.add_child(label("CHARACTER", FONT_CAPTION, GOLD))
	side_stats = label("", FONT_BODY, INK)
	side_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(side_stats)
	side.add_child(label("EQUIPMENT", FONT_CAPTION, GOLD))
	side_equipment = label("", FONT_BODY, MUTED)
	side_equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(side_equipment)
	var quick = HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	side.add_child(quick)
	var best = button("Equip Best", func(): equip_best_quick())
	best.custom_minimum_size.y = 38
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.add_child(best)
	side_potions = label("", FONT_BODY, MINT)
	side.add_child(side_potions)
	side_challenge = label("", 11, GOLD)
	side_challenge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(side_challenge)
	message = label("", 11, MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(message)
	var potions = HBoxContainer.new()
	potions.add_theme_constant_override("separation", 6)
	side.add_child(potions)
	var heal_b = button("Use Heal", func(): use_quick_potion("heal"))
	heal_b.custom_minimum_size.y = 38
	heal_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potions.add_child(heal_b)
	var mana_b = button("Use Mana", func(): use_quick_potion("mana"))
	mana_b.custom_minimum_size.y = 38
	mana_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potions.add_child(mana_b)
	side.add_child(label("MESSAGES", FONT_CAPTION, GOLD))
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.fit_content = false
	chat_log.scroll_active = true
	chat_log.custom_minimum_size = Vector2(0, 68)
	chat_log.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chat_log.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(chat_log)

	# Future-facing AI Game Master feedback queue. It is local-only for now.
	side.add_child(label("AI GAME MASTER FEEDBACK", FONT_CAPTION, GOLD))
	var ai_hint = label("Future AI integration • local queue with gameplay context.", 10, MUTED)
	ai_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(ai_hint)
	ai_feedback_log = RichTextLabel.new()
	ai_feedback_log.bbcode_enabled = false
	ai_feedback_log.fit_content = false
	ai_feedback_log.scroll_active = true
	ai_feedback_log.custom_minimum_size = Vector2(0, 78)
	ai_feedback_log.add_theme_font_size_override("normal_font_size", 11)
	side.add_child(ai_feedback_log)
	ai_feedback_input = TextEdit.new()
	ai_feedback_input.custom_minimum_size = Vector2(0, 54)
	ai_feedback_input.placeholder_text = "Tell the future Game Master what felt fun, unfair, boring, confusing, or worth expanding…"
	ai_feedback_input.add_theme_font_size_override("font_size", 11)
	ai_feedback_input.add_theme_color_override("font_color", INK)
	ai_feedback_input.add_theme_color_override("font_placeholder_color", Color(0.65, 0.74, 0.71, 0.72))
	ai_feedback_input.add_theme_stylebox_override("normal", compact_style(Color("102b2c"), 9, Color("41645b")))
	ai_feedback_input.add_theme_stylebox_override("focus", compact_style(Color("102b2c"), 9, MINT))
	side.add_child(ai_feedback_input)
	var ai_actions = HBoxContainer.new()
	ai_actions.add_theme_constant_override("separation", 6)
	side.add_child(ai_actions)
	var feedback_send = button("Send Feedback", func(): submit_ai_feedback(), true)
	feedback_send.custom_minimum_size.y = 36
	feedback_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_actions.add_child(feedback_send)
	ai_feedback_status = label("LOCAL QUEUE", 9, MUTED)
	ai_feedback_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai_actions.add_child(ai_feedback_status)

	# Minimal state: only quick equipment/potions and one latest-message line remain visible.
	side_compact_body = VBoxContainer.new()
	side_compact_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_compact_body.add_theme_constant_override("separation", 4)
	side_root.add_child(side_compact_body)
	var compact_actions = HBoxContainer.new()
	compact_actions.add_theme_constant_override("separation", 5)
	side_compact_body.add_child(compact_actions)
	var compact_best = button("Equip Best", func(): equip_best_quick(), true)
	compact_best.custom_minimum_size = Vector2(96, 34)
	compact_best.add_theme_font_size_override("font_size", 11)
	compact_best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_actions.add_child(compact_best)
	var compact_heal = button("Use Heal", func(): use_quick_potion("heal"))
	compact_heal.custom_minimum_size = Vector2(78, 34)
	compact_heal.add_theme_font_size_override("font_size", 11)
	compact_heal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_actions.add_child(compact_heal)
	var compact_mana = button("Use Mana", func(): use_quick_potion("mana"))
	compact_mana.custom_minimum_size = Vector2(78, 34)
	compact_mana.add_theme_font_size_override("font_size", 11)
	compact_mana.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_actions.add_child(compact_mana)
	compact_message = label("", 10, MUTED)
	compact_message.custom_minimum_size.y = 18
	compact_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	compact_message.clip_text = true
	side_compact_body.add_child(compact_message)
	side_compact_body.hide()

	# Crossroads uses the same compact centered popup lane as gameplay dialogs.
	route_panel = PanelContainer.new()
	place_bottom_card(route_panel, WINDOW_ROUTE_WIDTH, 205.0)
	route_panel.add_theme_stylebox_override("panel", style(Color(0.07, 0.16, 0.16, 0.96), 16, Color("7d9b76")))
	ui.add_child(route_panel)
	route_box = VBoxContainer.new()
	route_box.add_theme_constant_override("separation", 7)
	route_panel.add_child(route_box)
	route_panel.hide()

	# Automatic combat beat: short, readable, and never asks for an extra confirmation.
	fight_layer = Control.new()
	fight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fight_layer)
	var fight_scrim = ColorRect.new()
	fight_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_scrim.color = Color(0.02, 0.06, 0.06, 0.04)
	fight_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_layer.add_child(fight_scrim)
	fight_card = PanelContainer.new()
	place_bottom_card(fight_card, WINDOW_FIGHT_WIDTH, 138.0)
	fight_card.pivot_offset = Vector2(185, 80)
	fight_card.add_theme_stylebox_override("panel", style(Color("112d30"), 18, Color("e8c77f")))
	fight_layer.add_child(fight_card)
	var fight_stack = VBoxContainer.new()
	fight_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	fight_stack.add_theme_constant_override("separation", 6)
	fight_card.add_child(fight_stack)
	fight_title = label("FIGHT!", 16, GOLD)
	fight_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fight_stack.add_child(fight_title)
	var arena = HBoxContainer.new()
	arena.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_theme_constant_override("separation", 18)
	fight_stack.add_child(arena)
	var player_box = VBoxContainer.new()
	player_box.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_child(player_box)
	fight_player = ColorRect.new()
	fight_player.custom_minimum_size = Vector2(52, 52)
	fight_player.color = MINT
	fight_player.pivot_offset = Vector2(26, 26)
	player_box.add_child(fight_player)
	for eye_x in [12.0, 32.0]:
		var eye = ColorRect.new()
		eye.position = Vector2(eye_x, 17)
		eye.size = Vector2(7, 9)
		eye.color = Color("17333a")
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fight_player.add_child(eye)
	var you = label("YOU", 12, MINT)
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_box.add_child(you)
	var clash = label("✦  VS  ✦", 20, GOLD)
	clash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena.add_child(clash)
	var enemy_box = VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_child(enemy_box)
	fight_enemy = ColorRect.new()
	fight_enemy.custom_minimum_size = Vector2(52, 52)
	fight_enemy.color = Color("84ccbd")
	fight_enemy.pivot_offset = Vector2(26, 26)
	enemy_box.add_child(fight_enemy)
	for eye_x in [12.0, 32.0]:
		var foe_eye = ColorRect.new()
		foe_eye.position = Vector2(eye_x, 18)
		foe_eye.size = Vector2(7, 7)
		foe_eye.color = Color("233e3d")
		foe_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fight_enemy.add_child(foe_eye)
	var foe = label("FOE", 12, Color("e5b08e"))
	foe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(foe)
	fight_status = label("", 12, INK)
	fight_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fight_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fight_stack.add_child(fight_status)
	fight_layer.hide()

	# Bottom-center fishing skill check. The play space remains visible above it.
	fishing_layer = Control.new()
	fishing_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fishing_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(fishing_layer)
	var fishing_card = PanelContainer.new()
	place_bottom_card(fishing_card, WINDOW_FISH_WIDTH, 205.0)
	fishing_card.add_theme_stylebox_override("panel", style(Color("112d30"), 16, Color("6f9588")))
	fishing_layer.add_child(fishing_card)
	var fish_stack = VBoxContainer.new()
	fish_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	fish_stack.add_theme_constant_override("separation", 5)
	fishing_card.add_child(fish_stack)
	var fish_title = label("FISHING  /  TIME THE RIPPLE", 14, GOLD)
	fish_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fish_stack.add_child(fish_title)
	fishing_status = label("Click when the moving ripple enters the gold ring.", 12, MUTED)
	fishing_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fishing_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fish_stack.add_child(fishing_status)
	fishing_ripple = FishingRipple.new()
	fishing_ripple.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fishing_ripple.attempted.connect(func(success: bool, accuracy: float): finish_fishing_attempt(success, accuracy))
	fish_stack.add_child(fishing_ripple)
	fishing_leave_button = button("Leave the pool", func(): cancel_fishing())
	fishing_leave_button.custom_minimum_size.y = 32
	fish_stack.add_child(fishing_leave_button)
	fishing_layer.hide()

func push_chat(text: String) -> void:
	if text.strip_edges() == "":
		return
	event_history.push_front(text.replace("\n", " "))
	if event_history.size() > 8:
		event_history.resize(8)
	if is_instance_valid(chat_log):
		chat_log.text = ""
		for entry in event_history:
			chat_log.append_text("• " + entry + "\n")
	if is_instance_valid(compact_message):
		compact_message.text = event_history[0] if not event_history.is_empty() else text.replace("\n", " ")

func feedback_context() -> Dictionary:
	return {
		"mode": str(game.data.get("mode", "")),
		"class_id": str(game.data.get("class_id", "")),
		"route": str(game.data.get("route", "")),
		"environment": str(game.data.get("environment", "")),
		"stage": int(game.data.get("stage", 0)),
		"row": int(game.data.get("row", 0)),
		"hp": int(game.data.get("hp", 0)),
		"max_hp": game.max_hp(),
		"mana": int(game.data.get("mana", 0)),
		"attack": game.attack(),
		"threat": game.danger_level(),
		"streak": int(game.data.get("streak", 0)),
		"relic_charge": int(game.data.get("relic_charge", 0)),
		"coins_banked": int(game.data.get("coins", 0)),
		"coins_bag": int(game.data.get("bag", 0)),
		"gems": int(game.data.get("gems", 0)),
		"fish_caught": int(game.data.get("fish_caught", 0)),
		"equipped": game.data.get("equipped", {}).duplicate(true),
		"owned_gear_count": game.data.get("inventory", []).size(),
		"owned_cosmetics_count": game.data.get("cosmetics_owned", []).size(),
		"cosmetics_equipped": game.data.get("cosmetics_equipped", {}).duplicate(true)
	}

func refresh_ai_feedback_feed() -> void:
	if not is_instance_valid(ai_feedback_log) or not is_instance_valid(ai_feedback_status):
		return
	ai_feedback_log.text = ""
	var recent_entries: Array[Dictionary] = ai_feedback_store.recent(5)
	if recent_entries.is_empty():
		ai_feedback_log.append_text("No feedback yet. Your notes will appear here.\n")
	else:
		for entry in recent_entries:
			var context: Dictionary = entry.get("context", {})
			var stage_num: int = int(context.get("stage", 0)) + 1
			var threat_num: int = int(context.get("threat", 1))
			ai_feedback_log.append_text("YOU › " + str(entry.get("message", "")) + "\n")
			ai_feedback_log.append_text("QUEUE › Stage %d • Threat %d • %s\n\n" % [stage_num, threat_num, str(context.get("mode", "unknown")).capitalize()])
	ai_feedback_status.text = "%d QUEUED" % ai_feedback_store.queue_count()

func submit_ai_feedback() -> void:
	if not is_instance_valid(ai_feedback_input):
		return
	var text_value: String = ai_feedback_input.text.strip_edges()
	if text_value == "":
		ai_feedback_status.text = "TYPE FEEDBACK FIRST"
		return
	var saved: Dictionary = ai_feedback_store.submit(text_value, feedback_context())
	ai_telemetry.record("player_feedback", game, {"length": text_value.length()})
	if saved.is_empty():
		ai_feedback_status.text = "SAVE FAILED"
		return
	ai_feedback_input.text = ""
	refresh_ai_feedback_feed()
	play_chime([523.25, 659.25, 783.99], 0.16, 0.025)

func equip_best_quick() -> void:
	if at_title or busy:
		return
	game.equip_best()
	game.save_game()
	world.refresh_actor()
	push_chat(str(game.data.last))
	update_hud()

func set_side_panel_minimized(value: bool) -> void:
	side_panel_minimized = value
	var settings = ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("ui", "status_minimized", side_panel_minimized)
	settings.save(settings_path)
	apply_side_panel_mode()

func apply_side_panel_mode() -> void:
	if not is_instance_valid(side_panel) or not is_instance_valid(side_full_body) or not is_instance_valid(side_compact_body):
		return
	if side_panel_minimized:
		# Compact quick-actions dock sits in the lower-right so the upper HUD space stays open.
		side_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		side_panel.offset_left = -360
		side_panel.offset_right = -20
		side_panel.offset_top = -122
		side_panel.offset_bottom = -20
		side_full_body.hide()
		side_compact_body.show()
		if is_instance_valid(side_heading):
			side_heading.hide()
		if is_instance_valid(side_toggle_button):
			side_toggle_button.text = "Expand"
		if is_instance_valid(compact_message):
			compact_message.text = str(game.data.last).replace("\n", " ")
	else:
		side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		side_panel.offset_left = -390
		side_panel.offset_right = -20
		side_panel.offset_top = 108
		side_panel.offset_bottom = -20
		side_full_body.show()
		side_compact_body.hide()
		if is_instance_valid(side_heading):
			side_heading.show()
		if is_instance_valid(side_toggle_button):
			side_toggle_button.text = "Minimize"

func use_quick_potion(kind: String) -> void:
	if at_title or busy:
		return
	game.use_potion(kind)
	game.save_game()
	push_chat(str(game.data.last))
	update_hud()

func listen_campfire() -> void:
	if busy or game.data.mode != "campfire":
		return
	busy = true
	overlay.hide()
	update_hud()
	await get_tree().create_timer(3.8).timeout
	busy = false
	if game.data.mode == "campfire":
		show_mode()

func show_fishing_game() -> void:
	if not is_instance_valid(fishing_layer) or game.data.mode != "fishing":
		return
	busy = true
	fishing_status.text = "Click when the moving ripple enters the gold ring."
	fishing_layer.show()
	fishing_ripple.start()
	play_splash(false)
	update_hud()

func finish_fishing_attempt(success: bool, accuracy: float) -> void:
	if game.data.mode != "fishing":
		return
	fishing_ripple.stop()
	if success:
		fishing_status.text = "HOOKED!"
		play_splash(true)
	else:
		fishing_status.text = "MISSED"
		play_splash(false)
	await get_tree().create_timer(0.24).timeout
	game.resolve_fishing(accuracy if success else 0.0)
	ai_telemetry.record("fishing_result", game, {"success":success, "accuracy":accuracy, "result":str(game.data.last)})
	if success:
		ai_gm_bridge.progress_challenge(game, "fishing_catch", {"route":str(game.data.route)})
	busy = false
	fishing_layer.hide()
	push_chat(str(game.data.last))
	if int(game.data.gems) > 0 and ("gem" in str(game.data.last).to_lower()):
		play_chime([659.25, 830.61, 1046.5], 0.22, 0.03)
	elif "treasure" in str(game.data.last).to_lower() or "gear" in str(game.data.last).to_lower():
		play_chime([523.25, 659.25, 783.99, 1046.5], 0.24, 0.03)
	commit(false)

func cancel_fishing() -> void:
	if game.data.mode != "fishing":
		return
	fishing_ripple.stop()
	fishing_layer.hide()
	busy = false
	game.leave_fishing()
	push_chat(str(game.data.last))
	commit(false)

func route_options_for_stage() -> Array:
	var sets: Array = [
		["moss", "forge", "fen"],
		["treasure", "shrine", "frost"],
		["moss", "frost", "fen"],
		["forge", "treasure", "frost"],
		["shrine", "fen", "forge"],
		["frost", "fen", "treasure"]
	]
	return sets[int(game.data.stage) % sets.size()]

func route_difficulty_text(route: Dictionary) -> String:
	var level: int = int(route.get("difficulty", 0))
	var label_text: String = str(route.get("difficulty_label", "EASY"))
	return "%s  •  %d / 3" % [label_text, clampi(level + 1, 1, 3)]

func preview_route(route_key: String) -> void:
	if at_title or busy or game.data.mode != "choice" or route_key not in Catalog.ROUTES:
		return
	if route_key not in route_options_for_stage():
		return
	var route: Dictionary = Catalog.ROUTES[route_key]
	var body: String = "%s\n\nDIFFICULTY  •  %s\nENCOUNTERS  •  %s\nCOLLECTIBLES  •  %s" % [
		str(route.get("text", "")),
		route_difficulty_text(route),
		str(route.get("encounters", "Varied trail encounters")),
		str(route.get("collectibles", "Coins and gear"))
	]
	if str(ai_world_state.get("featured_route", "")) == route_key:
		body += "\n\nNIGHT WATCH  •  FEATURED ROAD"
		var reason: String = str(ai_world_state.get("difficulty_reason", "")).strip_edges()
		if reason != "":
			body += "\n" + reason
	ai_telemetry.record("route_preview", game, {"route":route_key, "featured":str(ai_world_state.get("featured_route", "")) == route_key})
	modal("ROUTE PREVIEW  /  %s" % str(route.get("tag", "TRAIL")), str(route.get("name", "Unknown Road")), body)
	action("Start Adventure   →", func(): choose_route(route_key), true)
	action("Back to Crossroads", func(): show_mode())

func choose_route(route_key: String) -> void:
	if at_title or busy or game.data.mode != "choice" or route_key not in Catalog.ROUTES:
		return
	if route_key not in route_options_for_stage():
		return
	var route: Dictionary = Catalog.ROUTES[route_key]
	ai_telemetry.record("route_selected", game, {"route":route_key, "featured":str(ai_world_state.get("featured_route", "")) == route_key})
	game.make_room(route_key)
	current_music_variant = -1
	update_music(true)
	play_chime([392.0, 523.25, 659.25], 0.18, 0.05)
	push_chat("Route chosen: " + str(route.name))
	commit()

func show_routes() -> void:
	# Keyboard/UI fallback. The 3D signboards are the primary route selector.
	for child in route_box.get_children():
		route_box.remove_child(child)
		child.queue_free()
	route_box.add_child(label("CROSSROADS  /  CHOOSE A SIGN", 13, GOLD))
	for key in route_options_for_stage():
		var route_key: String = str(key)
		var route: Dictionary = Catalog.ROUTES[route_key]
		var b = button("%s  →  %s" % [route.name, route.tag], func(): preview_route(route_key), route_key == "moss")
		b.tooltip_text = str(route.text)
		route_box.add_child(b)
	route_panel.show()

func modal(kicker: String, heading: String, body: String) -> void:
	place_modal()
	for child in stack.get_children():
		stack.remove_child(child)
		child.queue_free()
	overlay.show()
	stack.add_child(label(kicker, FONT_CAPTION, GOLD))
	var h = label(heading, FONT_TITLE if at_title else FONT_HEADING)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(h)
	var p = label(body, FONT_BODY, MUTED)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(p)
	schedule_modal_fit()

func action(text: String, callback: Callable, primary: bool = false) -> void:
	stack.add_child(button(text, callback, primary))
	schedule_modal_fit()

func update_hud() -> void:
	health.text = "HEARTS  %d / %d" % [maxi(0, int(game.data.hp)), game.max_hp()]
	economy.text = "BANK %d  •  BAG %d  •  GEMS %d" % [int(game.data.coins), int(game.data.bag), int(game.data.gems)]
	var route: Dictionary = Catalog.ROUTES[str(game.data.route)]
	title.text = str(route.name) if game.data.mode in ["travel", "campfire", "fishing"] else "Lantern Camp"
	if game.data.mode in ["boss", "boss_intro"]:
		title.text = "The Heartwood Keeper"
	subtitle.text = "MOSSWOOD   /   A LITTLE CUBE. A LONG WAY HOME."
	var stage_step: int = clampi(int(game.data.row), 0, State.STAGE_STEPS)
	var phase: String = "OPENING"
	if stage_step >= State.STAGE_STEPS - 4:
		phase = "FINAL STRETCH"
	elif stage_step >= int(State.STAGE_STEPS * 0.45):
		phase = "MIDROAD"
	if game.data.mode == "boss":
		progress.text = "%s  ·  BOSS FIGHT  ·  ATTACK %d" % [str(game.class_info().name).to_upper(), game.attack()]
	else:
		progress.text = "%s  ·  TRAIL %d / 6  ·  %d / %d  ·  %s" % [str(game.class_info().name).to_upper(), mini(6, int(game.data.stage) + 1), stage_step, State.STAGE_STEPS, phase]
	stage_bar.value = stage_step
	stage_bar.visible = game.data.mode in ["travel", "campfire", "fishing"]
	boss_label.text = "GUARDIAN  %d / 12  •  ORANGE = SLAM  /  MINT = STRIKE" % maxi(0, int(game.data.boss_hp)) if game.data.mode == "boss" else ""
	message.text = str(game.data.last).replace("\n", "  ")
	gear_button.disabled = busy or game.data.mode not in ["camp", "rest", "choice"]
	for b in hop_buttons:
		b.disabled = busy or game.data.mode not in ["travel", "boss"]
	if is_instance_valid(side_panel):
		side_panel.visible = not at_title
		side_stats.text = "%s\nHP %d/%d   MP %d/%d\nAttack %d   Bank %d   Bag %d   Gems %d" % [game.class_info().name, maxi(0, int(game.data.hp)), game.max_hp(), int(game.data.mana), game.max_mana(), game.attack(), int(game.data.coins), int(game.data.bag), int(game.data.gems)]
		var eq: Array[String] = []
		for slot in ["core", "shell", "charm"]:
			var item: Dictionary = Catalog.item(str(game.data.equipped[slot]))
			eq.append("%s: %s" % [str(slot).capitalize(), str(item.get("name", "—"))])
		side_equipment.text = "\n".join(eq) + "\nOwned gear: %d / %d" % [game.data.inventory.size(), Catalog.GEAR.size()]
		side_potions.text = "Healing ×%d    Mana ×%d" % [int(game.data.potions.heal), int(game.data.potions.mana)]
		var relic_text: String = "READY — NEXT GEAR RARE+" if int(game.data.relic_charge) >= 100 else "%d%%" % int(game.data.relic_charge)
		side_challenge.text = "THREAT %d / 5   •   STREAK ×%d\nRELIC %s   •   FISH %d" % [game.danger_level(), int(game.data.streak), relic_text, int(game.data.fish_caught)]
		if is_instance_valid(compact_message):
			compact_message.text = str(game.data.last).replace("\n", " ")

func commit(rebuild: bool = true) -> void:
	has_save = game.save_game() or has_save
	if rebuild:
		world.refresh_actor()
		world.build()
	update_hud()
	save_label.text = game.notice + "  /  OFFLINE"
	show_mode()

func start_adventure() -> void:
	if at_title or busy or game.data.mode != "camp":
		return
	game.begin(str(game.data.class_id))
	current_music_variant = -1
	push_chat("Adventure started. Click a crossroads sign to choose your road.")
	commit()

func show_mode() -> void:
	if at_title:
		show_title()
		return
	update_music()
	update_ambient()
	route_panel.hide()
	if not game.data.popup.is_empty():
		var popup_info: Dictionary = game.data.popup.duplicate(true)
		push_chat(str(popup_info.heading) + ": " + str(popup_info.body))
		game.data.popup = {}
		game.save_game()
		show_loot_popup(popup_info)
		return
	match str(game.data.mode):
		"travel", "boss":
			overlay.hide()
			if is_instance_valid(fishing_layer):
				fishing_layer.hide()
		"campfire":
			if is_instance_valid(fishing_layer):
				fishing_layer.hide()
			modal("ROADSIDE CAMPFIRE", "A quiet pause by the road.", "Crickets call beyond the trees while the fire settles into a soft crackle. This stop costs nothing and does not advance the road.")
			action("Sit and listen for a moment", func(): listen_campfire(), true)
			action("Continue down the road", func(): game.leave_campfire(); update_ambient(); commit(false))
		"fishing":
			overlay.hide()
			show_fishing_game()
		"camp":
			modal("01 / LANTERN CAMP", "Ready for the road?", "Start with your current cube, shop cosmetics, or choose a new character before leaving camp.")
			action("Start Adventure   →", func(): start_adventure(), true)
			action("Marketplace / Wardrobe", func(): show_marketplace("skin"))
			action("Equipment", func(): show_inventory())
			action("Choose New Character", func(): show_selector())
			var cost: int = 40 * (int(game.data.camp_level) + 1)
			if int(game.data.camp_level) < 3:
				action("Restore camp  •  %d banked coins  •  +1 maximum heart" % cost, func():
					if int(game.data.coins) >= cost:
						game.data.coins -= cost
						game.data.camp_level += 1
						game.data.hp = game.max_hp()
						game.data.last = "Another lantern lit. Your camp has grown."
						commit()
					else:
						game.data.last = "You need %d more banked coins." % (cost - int(game.data.coins))
						update_hud()
				)
			else:
				stack.add_child(label("CAMP FULLY RESTORED  /  +3 maximum hearts", 17, GOLD))
			stack.add_child(label("Expeditions %d    ·    Guardians defeated %d    ·    Gear %d / %d" % [int(game.data.runs), int(game.data.wins), game.data.inventory.size(), Catalog.GEAR.size()], 15, MUTED))
			action("How to play", func(): show_help())
		"choice":
			overlay.hide()
			route_panel.hide()
			push_chat("Crossroads: click a wooden sign to preview its difficulty and rewards.")
		"reward":
			modal("03 / TRAIL COMPLETE", "Something worth keeping.", str(game.data.last))
			action("Continue   →", func(): game.after_reward(); commit(), true)
		"shrine":
			modal("EVENT / THE MOON SHRINE", "The old stones remember.", "A single gift, freely given. Choose one blessing for this expedition.")
			action("Warm light  •  Restore all hearts", func(): game.data.hp = game.max_hp(); game.next_stage(); commit(), true)
			action("Falling star  •  +1 stomp damage for this expedition", func(): game.data.blessing += 1; game.next_stage(); commit())
		"traveler":
			modal("EVENT / A FELLOW TRAVELER", "A lantern beside the road.", "A traveling merchant offers a gift. You may instead buy equipment with banked coins.")
			action("Accept the gift  •  10 expedition coins", func(): game.data.bag += 10; game.next_stage(); commit(), true)
			action("Trade %d banked coins for a random piece of gear" % int(game.class_info().trade_cost), func():
				if int(game.data.coins) >= int(game.class_info().trade_cost):
					game.data.coins -= int(game.class_info().trade_cost)
					game.data.last = "Traveler's trade: " + game.award_gear()
					if game.data.popup.is_empty():
						game.data.popup = {"tag":"TRADE COMPLETE", "heading":"A new find", "body":game.data.last}
					game.next_stage()
					commit()
				else:
					game.data.last = "Not enough banked coins. The free gift is still yours."
					update_hud()
			)
		"rest":
			modal("04 / HALFWAY WAYPOINT", "Take a breath.", "All expedition coins are banked. Your hearts are restored. Equip your new finds before the next three trails.")
			action("Equipment", func(): show_inventory(), true)
			action("Marketplace / Wardrobe", func(): show_marketplace("skin"))
			action("Continue the expedition   →", func(): game.data.mode = "choice"; commit())
			action("Return home with your banked rewards", func(): game.return_camp(); commit())
		"boss_intro":
			modal("05 / THE HEARTWOOD KEEPER", "The forest has one last question.", "Three lanes. One warning. Hop away from the ORANGE slam lane. Land on the MINT strike rune to damage the guardian. Every hop advances one turn; take your time.")
			action("Face the guardian   →", func(): game.start_boss(); commit(), true)
		"victory":
			var unlock: String = "Your collection is growing."
			if int(game.data.wins) < Catalog.SKINS.size():
				unlock = "New cube color: %s. Your class outfit stays with your cube." % Catalog.SKINS[int(game.data.wins)].name
			modal("06 / A NEW WAYPOINT", "Mosswood remembers you.", str(game.data.last) + "\n\n" + unlock)
			action("Return to Lantern Camp   →", func(): game.return_camp(); commit(), true)
		"defeat":
			modal("THE LANTERN GUIDES YOU HOME", "Every journey teaches.", str(game.data.last))
			action("Rest at camp   →", func(): game.return_camp(); commit(), true)

func gear_score(gear: Dictionary) -> int:
	var score: int = int(gear.get("attack", 0)) * 5 + int(gear.get("health", 0)) * 4 + int(gear.get("coins", 0)) * 2 + int(gear.get("heal", 0)) * 3
	if str(gear.get("rarity", "")) == "LEGENDARY":
		score += 2
	elif str(gear.get("rarity", "")) == "UNIQUE":
		score += 4
	return score

func top_slot_choices(slot: String) -> Array[String]:
	var ids: Array[String] = []
	var best_score: int = -99999
	for raw_id in game.data.inventory:
		var gear_id: String = str(raw_id)
		var gear: Dictionary = Catalog.item(gear_id)
		if str(gear.get("slot", "")) != slot:
			continue
		var score: int = gear_score(gear)
		if score > best_score:
			best_score = score
			ids = [gear_id]
		elif score == best_score:
			ids.append(gear_id)
	return ids

func cycle_unlocked_skin() -> void:
	var unlocked: Array[int] = []
	for i in range(Catalog.SKINS.size()):
		if int(game.data.wins) >= int(Catalog.SKINS[i].wins):
			unlocked.append(i)
	if unlocked.size() <= 1:
		return
	var current_pos: int = unlocked.find(int(game.data.skin))
	game.data.skin = unlocked[(current_pos + 1) % unlocked.size()]
	game.save_game()
	world.refresh_actor()
	show_inventory()

func show_inventory() -> void:
	if at_title or busy or game.data.mode not in ["camp", "rest", "choice"]:
		return
	# Collection is summary-first: best loadout is equipped automatically and lower-tier gear stays hidden.
	game.equip_best()
	game.save_game()
	world.refresh_actor()
	modal("COLLECTION", "Best loadout equipped.", "Strongest gear is equipped automatically. Lower-tier gear stays stored.")
	stack.add_child(label("%s  •  HP %d  •  ATK %d  •  GEMS %d" % [game.class_info().name, game.max_hp(), game.attack(), int(game.data.gems)], FONT_BODY, MINT))
	stack.add_child(label("BEST GEAR", FONT_CAPTION, GOLD))
	for slot in ["core", "shell", "charm"]:
		var item: Dictionary = Catalog.item(str(game.data.equipped.get(slot, "")))
		if item.is_empty():
			stack.add_child(label("%s  •  none yet" % str(slot).capitalize(), FONT_BODY, MUTED))
		else:
			stack.add_child(label("%s  •  [%s] %s  •  %s" % [str(slot).capitalize(), str(item.get("rarity", "")), str(item.get("name", "")), str(item.get("text", ""))], FONT_BODY, GOLD))
	stack.add_child(label("6 gems = one Rare+ forge", FONT_CAPTION, MUTED))
	action("Gem Forge  •  Spend 6 gems", func():
		game.forge_with_gems()
		game.save_game()
		push_chat(str(game.data.last))
		play_chime([523.25, 659.25, 880.0, 1046.5], 0.24, 0.03)
		update_hud()
		if not game.data.popup.is_empty():
			show_mode()
		else:
			show_inventory()
	)
	stack.add_child(label("POTIONS  •  Heal ×%d   Mana ×%d" % [int(game.data.potions.heal), int(game.data.potions.mana)], FONT_BODY, MINT))
	var potion_row = HBoxContainer.new()
	potion_row.add_theme_constant_override("separation", 6)
	stack.add_child(potion_row)
	var heal_btn = button("Use Heal", func(): game.use_potion("heal"); game.save_game(); push_chat(str(game.data.last)); update_hud(); show_inventory())
	heal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(heal_btn)
	var mana_btn = button("Use Mana", func(): game.use_potion("mana"); game.save_game(); push_chat(str(game.data.last)); update_hud(); show_inventory())
	mana_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(mana_btn)
	stack.add_child(label("BASE CUBE COLOR  •  %s" % str(Catalog.SKINS[int(game.data.skin)].name), FONT_BODY, GOLD))
	var unlocked_count: int = 0
	var next_unlock: String = "All colors unlocked"
	for skin in Catalog.SKINS:
		if int(game.data.wins) >= int(skin.wins):
			unlocked_count += 1
		elif next_unlock == "All colors unlocked":
			next_unlock = "Next: %s at %d wins" % [str(skin.name), int(skin.wins)]
	if unlocked_count > 1:
		action("Cycle unlocked color", func(): cycle_unlocked_skin())
	stack.add_child(label(next_unlock, FONT_CAPTION, MUTED))
	action("Marketplace / Wardrobe", func(): show_marketplace("skin"))
	action("Done", func(): show_mode(), true)
	schedule_modal_fit()

func cosmetic_slot_name(slot: String) -> String:
	match slot:
		"skin":
			return "SKINS"
		"head":
			return "HEAD"
		"back":
			return "BACK"
		"face":
			return "FACE"
		_:
			return slot.to_upper()

func show_marketplace(slot: String = "skin") -> void:
	if at_title or busy or game.data.mode not in ["camp", "rest", "choice"]:
		return
	if slot not in ["skin", "head", "back", "face"]:
		slot = "skin"
	modal("MARKETPLACE / WARDROBE", "Customize your cube.", "Cosmetics are permanent, use banked coins, and never change combat stats.")
	stack.add_child(label("BANK  %d COINS   •   OWNED %d / %d" % [int(game.data.coins), game.data.cosmetics_owned.size(), Catalog.COSMETICS.size()], FONT_BODY, GOLD))
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	stack.add_child(tabs)
	for category in ["skin", "head", "back", "face"]:
		var category_id: String = category
		var tab = button(cosmetic_slot_name(category_id), func(): show_marketplace(category_id), category_id == slot)
		tab.custom_minimum_size.y = 34
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", FONT_CAPTION)
		tabs.add_child(tab)
	var equipped_id: String = str(game.data.cosmetics_equipped.get(slot, ""))
	var equipped_item: Dictionary = Catalog.cosmetic(equipped_id)
	stack.add_child(label("%s  •  %s" % [cosmetic_slot_name(slot), str(equipped_item.get("name", "Default"))], FONT_CAPTION, MINT))
	if equipped_id != "":
		action("Use default %s" % slot, func():
			game.clear_cosmetic(slot)
			game.save_game()
			world.refresh_actor()
			push_chat(str(game.data.last))
			update_hud()
			show_marketplace(slot)
		)
	for raw_item in Catalog.cosmetics_for_slot(slot):
		var item: Dictionary = raw_item
		var cosmetic_id: String = str(item.id)
		var owned: bool = game.owns_cosmetic(cosmetic_id)
		var equipped_now: bool = equipped_id == cosmetic_id
		var text_value: String = ""
		if equipped_now:
			text_value = "EQUIPPED  •  %s" % str(item.name)
		elif owned:
			text_value = "Equip  •  %s" % str(item.name)
		else:
			text_value = "Buy %d  •  %s" % [int(item.price), str(item.name)]
		var item_button = button(text_value, func():
			var already_owned: bool = game.owns_cosmetic(cosmetic_id)
			if already_owned:
				game.equip_cosmetic(cosmetic_id)
			else:
				game.buy_cosmetic(cosmetic_id)
			ai_telemetry.record("cosmetic_equipped" if already_owned else "cosmetic_purchased", game, {"cosmetic_id":cosmetic_id, "slot":slot, "price":int(item.price)})
			game.save_game()
			world.refresh_actor()
			push_chat(str(game.data.last))
			update_hud()
			play_chime([523.25, 659.25, 783.99], 0.16, 0.03)
			show_marketplace(slot)
		, equipped_now)
		item_button.tooltip_text = str(item.text)
		if equipped_now:
			item_button.disabled = true
		stack.add_child(item_button)
	stack.add_child(label("Tip: hover an item for its description.", FONT_CAPTION, MUTED))
	action("Back to Equipment", func(): show_inventory())
	action("Done", func(): show_mode(), true)
	schedule_modal_fit()

func show_help() -> void:
	if busy:
		return
	modal("HOW TO PLAY", "Walk. Jump. Explore.", "A / LEFT = walk left   •   W / UP = walk forward   •   D / RIGHT = walk right   •   SPACE = jump\n\nJump directly toward a thorn tile to vault over that entire row and land two tiles ahead. Without a jumpable obstacle, Jump moves one tile as normal.\n\nFIRE = rest   •   FISH = timing catch   •   CHEST = gear   •   CRYSTAL = gem\n\nClean wins build Streak and Relic charge. At 100% Relic, the next normal gear drop is Rare+. Harder routes raise hazards and Elite enemies, but improve rewards.\n\nAt Lantern Camp, open Marketplace / Wardrobe from the camp menu or click the MARKET stall. Press Start Adventure, then click a wooden crossroads sign to choose your route. Cosmetics never affect stats.\n\nBrightness presets are beside WAYPOINT. Progress autosaves after every move.")
	action("Got it", func(): show_mode(), true)

func show_pause() -> void:
	if at_title:
		show_title()
		return
	if busy:
		return
	game.save_game()
	modal("PAUSED / JOURNEY SAVED", "Stay a little. Wander again.", "There is no clock to race. Your next hop can wait.")
	action("Resume   →", func(): show_mode(), true)
	action("Settings", func(): show_settings())
	action("How to play", func(): show_help())
	if game.data.mode not in ["camp", "defeat", "victory"]:
		action("Abandon expedition…", func():
			modal("RETURN HOME?", "Keep your finds. Leave the loose coins.", "This ends the current expedition and loses %d unbanked coins. Your permanent equipment and banked coins remain." % int(game.data.bag))
			action("Keep adventuring", func(): show_mode(), true)
			action("Abandon and return to camp", func(): game.data.bag = 0; game.return_camp(); commit())
		)
	action("Save & return to title", func(): game.save_game(); show_title())
	action("Save and quit", func(): game.save_game(); get_tree().quit())

func do_move(direction: int, jump_move: bool = false) -> void:
	if at_title or busy or game.data.mode not in ["travel", "boss"]:
		return
	busy = true
	var boss: bool = game.data.mode == "boss"
	var old_mode: String = str(game.data.mode)
	var old_stage: int = int(game.data.stage)
	var old_hp: int = int(game.data.hp)
	var old_bag: int = int(game.data.bag)
	var old_gems: int = int(game.data.gems)
	var landing_kind: String = ""
	var lane: int = clampi(int(game.data.lane) + direction, -1, 1)
	var move_rows: int = 1
	if jump_move and not boss:
		move_rows = game.jump_distance(direction)
	var next_row: int = 0 if boss else mini(State.STAGE_STEPS, int(game.data.row) + move_rows)
	var enemy_kind: String = ""
	var enemy_was_active: bool = false
	var enemy_was_elite: bool = false
	var boss_clash: bool = false
	if boss:
		boss_clash = lane == int(game.data.danger) or lane == int(game.data.target)
		enemy_was_active = lane == int(game.data.danger)
	elif next_row < State.STAGE_STEPS:
		var landing: Dictionary = game.cell_at(next_row, lane)
		if not landing.is_empty() and not bool(landing.cleared):
			landing_kind = str(landing.kind)
		if not landing.is_empty() and not bool(landing.cleared) and str(landing.kind) in ["slime", "goblin", "kobold", "ogre"]:
			enemy_kind = str(landing.kind)
			enemy_was_active = game.enemy_active(landing)
			enemy_was_elite = game.enemy_elite(landing)
	update_hud()
	play_tone(470 if move_rows == 2 else (420 if jump_move else 300), 0.06)
	var destination := Vector3(lane * World.LANE_SPACING, 0.16, -next_row * World.ROW_SPACING)
	if jump_move:
		await world.jump_to(destination)
	else:
		await world.walk_to(destination)
	if boss:
		game.boss_hop(direction)
	elif jump_move:
		game.jump_hop(direction)
	else:
		game.hop(direction)
	ai_telemetry.record("movement", game, {"direction":direction, "jump":jump_move, "rows":move_rows, "landing_kind":landing_kind, "hp_delta":int(game.data.hp)-old_hp})
	if move_rows == 2:
		ai_telemetry.record("obstacle_jump", game, {"route":str(game.data.route)})
		ai_gm_bridge.progress_challenge(game, "obstacle_jump", {"route":str(game.data.route)})
	if enemy_kind != "":
		var defeated: bool = "defeated" in str(game.data.last).to_lower()
		ai_telemetry.record("enemy_encounter", game, {"enemy":enemy_kind, "elite":enemy_was_elite, "active":enemy_was_active, "defeated":defeated, "hp_delta":int(game.data.hp)-old_hp})
		if defeated and enemy_was_elite:
			ai_gm_bridge.progress_challenge(game, "elite_defeat", {"route":str(game.data.route), "enemy":enemy_kind})
	if enemy_kind != "":
		await show_fight_animation(enemy_kind, enemy_was_active, int(game.data.hp) < old_hp, str(game.data.last), enemy_was_elite)
	elif boss and boss_clash:
		await show_fight_animation("guardian", enemy_was_active, int(game.data.hp) < old_hp, str(game.data.last))
	if move_rows == 2:
		play_chime([392.0, 523.25, 659.25], 0.16, 0.035)
	elif landing_kind == "campfire":
		play_chime([293.66, 392.0], 0.18, 0.06)
	elif landing_kind == "fishing":
		play_splash(false)
	elif landing_kind == "gear_cache":
		play_chime([440.0, 659.25, 880.0], 0.20, 0.035)
	elif int(game.data.gems) > old_gems:
		play_chime([659.25, 830.61, 1046.5], 0.22, 0.03)
	elif int(game.data.hp) < old_hp:
		play_chime([155.56, 116.54], 0.22, 0.02)
	elif int(game.data.bag) > old_bag:
		play_chime([659.25, 783.99, 987.77], 0.16, 0.04)
	else:
		play_tone(420, 0.06)
	if old_mode == "travel" and str(game.data.mode) == "reward" and int(game.data.stage) > old_stage:
		ai_telemetry.record("route_complete", game, {"route":str(game.data.route), "hp_remaining":int(game.data.hp), "bag":int(game.data.bag)})
		ai_gm_bridge.progress_challenge(game, "route_complete", {"route":str(game.data.route)})
	busy = false
	push_chat(str(game.data.last))
	if game.data.mode in ["travel", "boss"]:
		world.refresh_props()
		commit(false)
	else:
		commit()

func play_tone(frequency: float, duration: float) -> void:
	if muted:
		return
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples: int = int(duration * 22050)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var envelope: float = sin(PI * float(i) / float(samples))
		var value: int = int(sin(TAU * frequency * float(i) / 22050.0) * envelope * 10000)
		bytes.encode_s16(i * 2, value)
	stream.data = bytes
	audio.stream = stream
	audio.play()


func play_chime(frequencies: Array, duration: float = 0.18, stagger: float = 0.04) -> void:
	if muted or frequencies.is_empty():
		return
	var rate: int = 22050
	var total_duration: float = duration + stagger * max(0, frequencies.size() - 1)
	var samples: int = int(total_duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(rate)
		var sample_value: float = 0.0
		for n in range(frequencies.size()):
			var local_t: float = t - float(n) * stagger
			if local_t < 0.0 or local_t > duration:
				continue
			var env: float = sin(PI * local_t / duration)
			var freq: float = float(frequencies[n])
			sample_value += (sin(TAU * freq * local_t) + 0.28 * sin(TAU * freq * 2.0 * local_t)) * env
		var value: int = int(clampf(sample_value * 4300.0, -30000.0, 30000.0))
		bytes.encode_s16(i * 2, value)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	audio.stream = stream
	audio.play()

func play_splash(caught: bool) -> void:
	if muted:
		return
	var rate: int = 22050
	var duration: float = 0.24 if caught else 0.16
	var samples: int = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = int(Time.get_ticks_msec()) + (17 if caught else 3)
	var filtered: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(rate)
		filtered = filtered * 0.86 + noise.randf_range(-1.0, 1.0) * 0.14
		var env: float = exp(-8.0 * t / duration)
		var tone: float = sin(TAU * (520.0 if caught else 260.0) * t) * (0.45 if caught else 0.18)
		var value: int = int(clampf((filtered * 0.7 + tone) * env * 9000.0, -28000.0, 28000.0))
		bytes.encode_s16(i * 2, value)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	audio.stream = stream
	audio.play()

func music_context() -> String:
	if game.data.mode == "fishing":
		return "fishing"
	if game.data.mode == "campfire":
		return "campfire"
	if at_title or game.data.mode in ["camp", "choice", "rest", "reward", "shrine", "traveler"]:
		return "camp"
	if game.data.mode in ["boss", "boss_intro"]:
		return "boss"
	return "road"

func update_music(force: bool = false) -> void:
	if not is_instance_valid(music_player):
		return
	if music_muted:
		music_player.stop()
		return
	var context: String = music_context()
	music_player.volume_db = -20 if context == "boss" else (-29 if context == "campfire" else (-26 if context == "fishing" else -23))
	if not force and context == current_music_context and music_player.playing:
		return
	var variants: int = 5
	var next_variant: int = game.rng.randi_range(0, variants - 1)
	if next_variant == current_music_variant and variants > 1:
		next_variant = (next_variant + 1) % variants
	current_music_context = context
	current_music_variant = next_variant
	music_player.stream = build_bard_track(context, next_variant)
	music_player.play()

func update_ambient() -> void:
	if not is_instance_valid(ambient_player):
		return
	if muted or at_title or game.data.mode != "campfire":
		ambient_player.stop()
		return
	if ambient_player.playing:
		return
	ambient_player.stream = build_campfire_ambience()
	ambient_player.play()

func note_frequency(note: int) -> float:
	return 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)

func build_bard_track(context: String, variant: int) -> AudioStreamWAV:
	# Original procedural lute/flute-style loops. These are generated melodies, not copied game music.
	var rate: int = 22050
	var bpm: float = 92.0
	var root: int = 50
	var patterns: Array = []
	var bass: Array = []
	match context:
		"boss":
			bpm = 118.0
			root = 45
			patterns = [[0,3,5,7,5,3,2,3], [0,2,3,7,5,3,0,-2], [0,3,7,8,7,5,3,2], [0,5,3,7,8,7,3,2], [0,2,5,7,10,7,5,3]]
			bass = [0,0,-2,-2,3,3,-2,-2]
		"road":
			bpm = 102.0
			root = 50
			patterns = [[0,2,4,7,4,2,0,2], [0,4,5,7,9,7,5,4], [0,2,5,4,7,5,2,0], [0,4,7,5,9,7,4,2], [0,2,4,5,7,9,7,4]]
			bass = [0,0,5,5,3,3,5,5]
		"fishing":
			bpm = 80.0
			root = 52
			patterns = [[0,4,7,11,7,4,2,4], [0,2,7,9,7,5,4,2], [0,5,9,7,4,5,2,0], [0,4,9,11,9,7,4,2], [0,2,5,9,7,5,2,4]]
			bass = [0,0,5,5,7,7,5,5]
		"campfire":
			bpm = 76.0
			root = 48
			patterns = [[0,4,7,4,2,4,5,4], [0,2,4,7,5,4,2,0], [0,5,4,2,0,2,4,5], [0,4,5,7,4,2,0,2], [0,2,5,7,5,4,2,4]]
			bass = [0,0,5,5,0,0,7,7]
		_:
			bpm = 86.0
			root = 48
			patterns = [[0,4,7,9,7,4,2,4], [0,2,4,7,9,7,4,2], [0,4,5,9,7,5,4,2], [0,5,7,9,7,4,5,2], [0,2,5,4,7,9,7,5]]
			bass = [0,0,5,5,7,7,5,5]
	var melody: Array = patterns[variant % patterns.size()]
	var beat: float = 60.0 / bpm
	var bars: int = 4
	var steps: int = melody.size() * bars
	var total_duration: float = float(steps) * beat * 0.5
	var samples: int = int(total_duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(rate)
		var step: int = int(t / (beat * 0.5)) % melody.size()
		var local_t: float = fmod(t, beat * 0.5)
		var note_len: float = beat * 0.46
		var pluck_env: float = exp(-5.0 * local_t / max(note_len, 0.01)) if local_t <= note_len else 0.0
		var mf: float = note_frequency(root + 12 + int(melody[step]))
		var lute: float = (sin(TAU * mf * local_t) + 0.34 * sin(TAU * mf * 2.0 * local_t) + 0.12 * sin(TAU * mf * 3.0 * local_t)) * pluck_env
		var bass_step: int = int(t / beat) % bass.size()
		var bass_local: float = fmod(t, beat)
		var bf: float = note_frequency(root - 12 + int(bass[bass_step]))
		var bass_env: float = exp(-2.8 * bass_local / beat)
		var drone: float = sin(TAU * bf * bass_local) * bass_env * 0.40
		var air_note: int = root + 24 + int(melody[(step + 2) % melody.size()])
		var air: float = sin(TAU * note_frequency(air_note) * t) * 0.065 * (0.5 + 0.5 * sin(TAU * 0.10 * t))
		var sample_value: float = lute * 0.60 + drone + air
		var value: int = int(clampf(sample_value * 5000.0, -27000.0, 27000.0))
		bytes.encode_s16(i * 2, value)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream

func build_campfire_ambience() -> AudioStreamWAV:
	# Procedural crackle + cricket bed, synthesized locally so no external audio is required.
	var rate: int = 22050
	var duration: float = 8.0
	var samples: int = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = 731947
	var filtered: float = 0.0
	var pop_env: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(rate)
		filtered = filtered * 0.94 + noise.randf_range(-1.0, 1.0) * 0.06
		if noise.randf() < 0.00028:
			pop_env = 1.0
		pop_env *= 0.985
		var crackle: float = filtered * 0.46 + noise.randf_range(-1.0, 1.0) * pop_env * 0.52
		var cricket_gate: float = 0.0
		var cricket_phase: float = fmod(t, 2.4)
		if (cricket_phase > 0.15 and cricket_phase < 0.32) or (cricket_phase > 0.48 and cricket_phase < 0.61):
			cricket_gate = sin(PI * clampf((cricket_phase - 0.15) / 0.17, 0.0, 1.0))
		var cricket: float = sin(TAU * 3100.0 * t + sin(TAU * 18.0 * t) * 0.5) * cricket_gate * 0.18
		var low_fire: float = sin(TAU * 62.0 * t) * 0.025 + sin(TAU * 91.0 * t) * 0.018
		var value: int = int(clampf((crackle + cricket + low_fire) * 7200.0, -25000.0, 25000.0))
		bytes.encode_s16(i * 2, value)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream

func do_hop(direction: int, confirmed: bool = false) -> void:
	# Compatibility alias: legacy callers still perform the original jump-style move.
	do_move(direction, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if spinning:
				return
			if is_instance_valid(fishing_layer) and fishing_layer.visible:
				cancel_fishing()
				return
			if overlay.visible:
				show_mode()
			else:
				show_pause()
		elif event.keycode in [KEY_A, KEY_LEFT]:
			do_move(-1, false)
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			do_move(1, false)
		elif event.keycode in [KEY_W, KEY_UP]:
			do_move(0, false)
		elif event.keycode == KEY_SPACE:
			do_move(0, true)
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
			swipe_tracking = true
		elif swipe_tracking:
			swipe_tracking = false
			var diff: Vector2 = event.position - swipe_start
			if diff.length() > 35:
				do_move(-1 if diff.x < -40 else (1 if diff.x > 40 else 0), false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ai_telemetry.record("session_end", game, {"reason":"window_close"})
		if has_save:
			game.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and has_save:
		ai_telemetry.record("session_pause", game, {})
		game.save_game()


func show_title() -> void:
	at_title = true
	world.entrance = true
	world.build()
	for child in ui.get_children():
		if child != overlay:
			child.hide()
	if is_instance_valid(route_panel):
		route_panel.hide()
	update_music(true)
	update_ambient()
	modal("WAYPOINT  /  FREE EDITION", "Cube Odyssey", "A compact voxel adventure. Choose a cube, follow the signs, and keep moving.")
	action("PLAY  /  New expedition", func(): request_play(), not has_save)
	var resume = button("CONTINUE" if has_save else "CONTINUE  /  No saved journey", func(): continue_game(), has_save)
	resume.disabled = not has_save
	stack.add_child(resume)
	if has_save:
		stack.add_child(label("%s  •  %d hearts  •  %d banked coins  •  %s" % [game.class_info().name, int(game.data.hp), int(game.data.coins), str(game.data.mode).replace("_", " ").capitalize()], 15, MUTED))
	action("Settings", func(): show_settings())
	action("How to play", func(): show_help())
	action("Credits", func():
		modal("CREDITS", "A small adventure, made with Godot.", "Waypoint: Cube Odyssey\nOriginal procedural art, synthesized effects, and procedural bard-style music.\nGodot Engine — MIT license.\nProject source — MIT license (included in the download).")
		action("Back", func(): show_title(), true)
	)
	action("Quit", func(): get_tree().quit())

func continue_game() -> void:
	if not has_save:
		return
	enter_game()
	world.build()
	update_music(true)
	update_hud()
	show_mode()

func enter_game() -> void:
	at_title = false
	world.entrance = false
	for child in ui.get_children():
		if child != overlay:
			child.show()
	if is_instance_valid(route_panel):
		route_panel.hide()
	if is_instance_valid(fight_layer):
		fight_layer.hide()
	if is_instance_valid(fishing_layer):
		fishing_layer.hide()
	update_music(true)
	update_ambient()

func request_play() -> void:
	if has_save and game.data.mode not in ["camp", "defeat", "victory"]:
		modal("NEW EXPEDITION", "Start a new road?", "Confirming a new character will replace your current expedition and its %d unbanked coins. Your gear, camp upgrades, colors, and banked coins remain. You can cancel the selector without changing your save." % int(game.data.bag))
		action("Choose a new character", func(): show_selector(), true)
		action("Back", func(): show_title())
	else:
		show_selector()

func show_selector() -> void:
	modal("CHARACTER SELECT", "Choose your wanderer.", "Roll one of four trades, then confirm. Each trade has an equal chance.")
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)
	var container = SubViewportContainer.new()
	container.custom_minimum_size = Vector2(170, 132)
	container.stretch = true
	row.add_child(container)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(170, 132)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	preview_world = World.new()
	viewport.add_child(preview_world)
	var preview_state = State.new()
	preview_world.setup(preview_state)
	preview_world.showcase = true
	preview_world.scenery.hide()
	preview_world.props.hide()
	selector_stats = label("Rolling…", FONT_BODY)
	selector_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selector_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector_stats)
	selector_buttons = []
	var confirm = button("Start with this cube", func(): confirm_character(), true)
	stack.add_child(confirm)
	selector_buttons.append(confirm)
	var secondary = HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 6)
	stack.add_child(secondary)
	var reroll = button("Roll again", func(): roll_character())
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_child(reroll)
	selector_buttons.append(reroll)
	var back = button("Cancel", func(): show_mode())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_child(back)
	selector_buttons.append(back)
	roll_character()
	schedule_modal_fit()

func roll_character() -> void:
	if spinning:
		return
	spinning = true
	for b in selector_buttons:
		b.disabled = true
	# Presentation cycles independently; final draw is uniform across four classes.
	for i in range(12):
		selected_class = str(Catalog.CLASS_IDS[i % 4])
		selected_skin = game.rng.randi_range(0, mini(int(game.data.wins), Catalog.SKINS.size() - 1))
		update_selector(true)
		play_tone(260 + i * 24, 0.045)
		await get_tree().create_timer(0.045 + i * 0.009).timeout
	selected_class = str(Catalog.CLASS_IDS[game.rng.randi_range(0, 3)])
	update_selector(false)
	play_tone(700, 0.14)
	spinning = false
	for b in selector_buttons:
		b.disabled = false

func update_selector(rolling: bool) -> void:
	var role: Dictionary = Catalog.CLASSES[selected_class]
	preview_world.refresh_actor(selected_class, selected_skin)
	var extra_hp: int = game.stat("health") + int(game.data.camp_level)
	var extra_attack: int = game.stat("attack") - int(game.class_info().attack)
	selector_stats.text = ("ROLLING…\n" if rolling else "READY\n") + str(role.name).to_upper() + "\n\nHP %d   •   ATK %d\nWith gear: HP %d   •   ATK %d\nCoins +%d\n\n%s" % [int(role.hp), int(role.attack), int(role.hp) + extra_hp, int(role.attack) + extra_attack, int(role.coins), str(role.perk)]
	selector_stats.add_theme_color_override("font_color", Color(role.color))

func confirm_character() -> void:
	if spinning:
		return
	game.data.skin = selected_skin
	game.begin(selected_class)
	enter_game()
	commit()

func show_settings() -> void:
	modal("SETTINGS", "Comfort & sound.", "No time limit. Brightness presets are beside WAYPOINT. Music, effects, and ambience are controlled separately below.")
	action("Sound effects: " + ("OFF" if muted else "ON"), func():
		muted = not muted
		save_audio_settings()
		update_ambient()
		show_settings()
	, true)
	action("Bard music: " + ("OFF" if music_muted else "ON"), func():
		music_muted = not music_muted
		save_audio_settings()
		update_music(true)
		show_settings()
	)
	action("Shuffle bard tune", func():
		current_music_variant = -1
		update_music(true)
		play_chime([440.0, 554.37, 659.25], 0.18, 0.05)
	)
	action("Back", func():
		if at_title:
			show_title()
		else:
			show_pause()
	)

func save_audio_settings() -> void:
	var settings = ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("audio", "muted", muted)
	settings.set_value("audio", "music_muted", music_muted)
	settings.set_value("display", "brightness_mode", brightness_mode)
	settings.save(settings_path)

func enemy_display_name(kind: String) -> String:
	match kind:
		"goblin":
			return "ROAD GOBLIN"
		"kobold":
			return "TRAIL KOBOLD"
		"ogre":
			return "WAYSTONE OGRE"
		"guardian":
			return "HEARTWOOD KEEPER"
		_:
			return "MOSS SLIME"

func show_loot_popup(info: Dictionary) -> void:
	play_chime([523.25, 659.25, 783.99, 1046.50], 0.26, 0.035)
	modal(str(info.get("tag", "SPECIAL FIND")), str(info.get("heading", "A rare discovery")), str(info.get("body", "This item is now part of your permanent collection.")))
	action("Continue   →", func(): show_mode(), true)

func show_fight_animation(kind: String, enemy_was_active: bool, player_hit: bool, result: String, elite: bool = false) -> void:
	if not is_instance_valid(fight_layer):
		return
	var action_word: String = "ELITE FIGHT" if elite else "FIGHT"
	if kind == "guardian":
		action_word = "BOSS FIGHT"
	fight_title.text = action_word + "  /  " + enemy_display_name(kind)
	fight_title.add_theme_color_override("font_color", GOLD if elite else (Color("ef9974") if enemy_was_active else MINT))
	fight_status.text = "ELITE FIGHT" if elite else "FIGHT"
	fight_player.color = current_character_color()
	match kind:
		"goblin":
			fight_enemy.color = Color("7fb76b")
		"kobold":
			fight_enemy.color = Color("c8896b")
		"ogre":
			fight_enemy.color = Color("9aa56b")
		_:
			fight_enemy.color = Color("e7926f") if enemy_was_active else Color("84ccbd")
	if enemy_was_active:
		fight_enemy.color = fight_enemy.color.darkened(0.08)
	fight_player.scale = Vector2.ONE
	fight_enemy.scale = Vector2.ONE
	fight_player.rotation = 0.0
	fight_enemy.rotation = 0.0
	fight_player.modulate = Color.WHITE
	fight_enemy.modulate = Color.WHITE
	fight_card.scale = Vector2(0.84, 0.84)
	fight_card.rotation = 0.0
	fight_layer.modulate = Color(1, 1, 1, 0)
	fight_layer.show()
	play_chime([220.0, 293.66], 0.11, 0.02)
	var enter = create_tween()
	enter.set_parallel(true)
	enter.tween_property(fight_layer, "modulate:a", 1.0, 0.10)
	enter.tween_property(fight_card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(fight_player, "scale", Vector2(1.12, 0.90), 0.14)
	enter.tween_property(fight_enemy, "scale", Vector2(1.12, 0.90), 0.14)
	await enter.finished
	var impact = create_tween()
	impact.set_parallel(true)
	if player_hit:
		fight_status.text = "LOSS"
		play_chime([196.0, 146.83, 110.0], 0.23, 0.025)
		impact.tween_property(fight_player, "scale", Vector2(0.76, 1.18), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		impact.tween_property(fight_player, "modulate", Color("ff9e86"), 0.10)
		impact.tween_property(fight_card, "rotation", deg_to_rad(-1.2), 0.05)
	else:
		fight_status.text = "WIN"
		play_chime([392.0, 523.25, 659.25], 0.19, 0.035)
		impact.tween_property(fight_enemy, "scale", Vector2(0.28, 1.28), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		impact.tween_property(fight_enemy, "modulate", Color("fff0a8"), 0.10)
		impact.tween_property(fight_card, "rotation", deg_to_rad(1.0), 0.05)
	await impact.finished
	fight_card.rotation = 0.0
	await get_tree().create_timer(0.14).timeout
	fight_status.text = result.replace("\n", "  ")
	await get_tree().create_timer(0.46).timeout
	var leave = create_tween()
	leave.set_parallel(true)
	leave.tween_property(fight_layer, "modulate:a", 0.0, 0.16)
	leave.tween_property(fight_card, "scale", Vector2(1.04, 1.04), 0.16)
	await leave.finished
	fight_layer.hide()
	fight_layer.modulate = Color.WHITE
