extends CanvasLayer
## Lantern Camp 360-degree character viewer.
## The viewer is opt-in so normal camp clicks (route signs, market, header, side
## drawer) remain untouched. Dragging only captures input after a real drag begins.

const ROTATE_STEP: float = PI / 6.0
const DRAG_SENSITIVITY: float = 0.012
const DRAG_START_THRESHOLD: float = 5.0
const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const GOLD := Color("efd094")
const MINT := Color("9bddc2")
const CAMP_VIEW_MODES := ["camp", "choice", "rest"]

var root: Control
var launcher_panel: PanelContainer
var panel: PanelContainer
var hint: Label
var viewer_enabled: bool = false
var pending_mouse_drag: bool = false
var dragging_mouse: bool = false
var mouse_drag_distance: float = 0.0
var pending_touch_id: int = -1
var dragging_touch_id: int = -1
var touch_drag_distance: float = 0.0
var was_camp_available: bool = false
var target_yaw: float = 0.0

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_controls()

func _build_controls() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Small launcher shown while normal Lantern Camp interaction is active.
	launcher_panel = PanelContainer.new()
	launcher_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	launcher_panel.offset_left = -58.0
	launcher_panel.offset_right = 58.0
	launcher_panel.offset_top = 108.0
	launcher_panel.offset_bottom = 144.0
	launcher_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	launcher_panel.add_theme_stylebox_override("panel", _panel_style())
	launcher_panel.hide()
	root.add_child(launcher_panel)
	var launch_button := _viewer_button("360 VIEW", func(): enter_viewer(), "Open 360 character viewer")
	launch_button.custom_minimum_size = Vector2(102, 28)
	launcher_panel.add_child(launch_button)

	# Expanded viewer controls only appear after the player explicitly enters it.
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -250.0
	panel.offset_right = 250.0
	panel.offset_top = 108.0
	panel.offset_bottom = 151.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.hide()
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	hint = Label.new()
	hint.text = "360 VIEW  /  DRAG CHARACTER"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	row.add_child(_viewer_button("LEFT", func(): rotate_by(ROTATE_STEP), "Rotate character left"))
	row.add_child(_viewer_button("RESET", func(): reset_rotation(), "Face character forward"))
	row.add_child(_viewer_button("RIGHT", func(): rotate_by(-ROTATE_STEP), "Rotate character right"))
	var exit_button := _viewer_button("EXIT", func(): exit_viewer(), "Exit 360 character viewer")
	exit_button.add_theme_color_override("font_color", GOLD)
	row.add_child(exit_button)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("183b3c")
	style.border_color = Color("39605a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _viewer_button(text_value: String, callback: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(58, 28)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color("244747"), Color("41645b")))
	button.add_theme_stylebox_override("hover", _button_style(Color("385f56"), MINT))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1c3b38"), GOLD))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), GOLD))
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func current_scene_root() -> Node:
	return get_tree().current_scene

func _scene_game():
	var scene := current_scene_root()
	if scene == null:
		return null
	return scene.get("game")

func camp_available() -> bool:
	var scene := current_scene_root()
	if scene == null:
		return false
	if bool(scene.get("at_title")):
		return false
	var game = _scene_game()
	if game == null:
		return false
	var data = game.get("data")
	if not (data is Dictionary):
		return false
	return str(data.get("mode", "")) in CAMP_VIEW_MODES

func viewer_active() -> bool:
	return viewer_enabled and camp_available()

func world_node():
	var scene := current_scene_root()
	if scene == null:
		return null
	return scene.get("world")

func actor_node() -> Node3D:
	var world = world_node()
	if world == null:
		return null
	var actor = world.get("actor")
	return actor as Node3D if actor is Node3D else null

func enter_viewer() -> void:
	if not camp_available():
		return
	viewer_enabled = true
	var actor := actor_node()
	if actor != null:
		target_yaw = actor.rotation.y
	_cancel_drag_state()
	_refresh_visibility()

func exit_viewer() -> void:
	viewer_enabled = false
	_cancel_drag_state()
	_refresh_visibility()

func _cancel_drag_state() -> void:
	pending_mouse_drag = false
	dragging_mouse = false
	mouse_drag_distance = 0.0
	pending_touch_id = -1
	dragging_touch_id = -1
	touch_drag_distance = 0.0

func _refresh_visibility() -> void:
	var available := camp_available()
	if is_instance_valid(launcher_panel):
		launcher_panel.visible = available and not viewer_enabled
	if is_instance_valid(panel):
		panel.visible = available and viewer_enabled

func apply_rotation() -> void:
	var actor := actor_node()
	if actor != null:
		actor.rotation.y = target_yaw

func rotate_by(delta_radians: float) -> void:
	if not viewer_active():
		return
	target_yaw = wrapf(target_yaw + delta_radians, -PI, PI)
	apply_rotation()

func reset_rotation() -> void:
	if not viewer_active():
		return
	target_yaw = 0.0
	apply_rotation()

func pointer_over_view_controls(screen_position: Vector2) -> bool:
	if is_instance_valid(panel) and panel.visible and panel.get_global_rect().has_point(screen_position):
		return true
	if is_instance_valid(launcher_panel) and launcher_panel.visible and launcher_panel.get_global_rect().has_point(screen_position):
		return true
	return false

func pointer_in_character_view_zone(screen_position: Vector2) -> bool:
	# Limit drag capture to the visible character area rather than the whole center
	# of the camp. This keeps crossroads, Market, header and side-panel clicks free.
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	return screen_position.x >= size.x * 0.36 and screen_position.x <= size.x * 0.64 \
		and screen_position.y >= size.y * 0.40 and screen_position.y <= size.y * 0.80

func _process(_delta: float) -> void:
	var available := camp_available()
	if not available and viewer_enabled:
		viewer_enabled = false
		_cancel_drag_state()
	if available != was_camp_available:
		if available:
			var actor := actor_node()
			if actor != null:
				target_yaw = actor.rotation.y
		else:
			viewer_enabled = false
			target_yaw = 0.0
			_cancel_drag_state()
		was_camp_available = available
	_refresh_visibility()
	if viewer_active():
		# Re-apply only while viewer mode is explicitly active.
		apply_rotation()

func _input(event: InputEvent) -> void:
	if not camp_available():
		return

	# V toggles the viewer. Escape always exits it.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			if viewer_enabled:
				exit_viewer()
			else:
				enter_viewer()
			get_viewport().set_input_as_handled()
			return
		if viewer_enabled and event.keycode == KEY_ESCAPE:
			exit_viewer()
			get_viewport().set_input_as_handled()
			return
		if not viewer_enabled:
			return
		if event.keycode == KEY_Q:
			rotate_by(ROTATE_STEP)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			rotate_by(-ROTATE_STEP)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			reset_rotation()
			get_viewport().set_input_as_handled()
		return

	if not viewer_enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not pointer_over_view_controls(event.position) and pointer_in_character_view_zone(event.position):
				# Do not consume the press. A normal click can still reach other game UI.
				pending_mouse_drag = true
				mouse_drag_distance = 0.0
		else:
			pending_mouse_drag = false
		elif pending_mouse_drag or dragging_mouse:
			pending_mouse_drag = false
			dragging_mouse = false
			mouse_drag_distance = 0.0
		return

	if event is InputEventMouseMotion and (pending_mouse_drag or dragging_mouse):
		mouse_drag_distance += absf(event.relative.x) + absf(event.relative.y)
		if not dragging_mouse and mouse_drag_distance >= DRAG_START_THRESHOLD:
			dragging_mouse = true
			pending_mouse_drag = false
		if dragging_mouse:
			# Direct-manipulation convention: dragging right turns character right.
			rotate_by(event.relative.x * DRAG_SENSITIVITY)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if not pointer_over_view_controls(event.position) and pointer_in_character_view_zone(event.position):
				pending_touch_id = event.index
				touch_drag_distance = 0.0
		else:
			pending_touch_id = -1
		elif pending_touch_id == event.index or dragging_touch_id == event.index:
			pending_touch_id = -1
			dragging_touch_id = -1
			touch_drag_distance = 0.0
		return

	if event is InputEventScreenDrag and (pending_touch_id == event.index or dragging_touch_id == event.index):
		touch_drag_distance += absf(event.relative.x) + absf(event.relative.y)
		if dragging_touch_id < 0 and touch_drag_distance >= DRAG_START_THRESHOLD:
			dragging_touch_id = event.index
			pending_touch_id = -1
		if dragging_touch_id == event.index:
			rotate_by(event.relative.x * DRAG_SENSITIVITY)
			get_viewport().set_input_as_handled()
