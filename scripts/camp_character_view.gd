extends CanvasLayer
## Lantern Camp 360-degree character viewer.
## Players can drag directly on the cube, use Q/E, or use compact on-screen controls.
## Rotation is view-only and resets automatically when leaving Lantern Camp.

const ROTATE_STEP: float = PI / 6.0
const DRAG_SENSITIVITY: float = 0.012
const PICK_RADIUS_PX: float = 115.0
const INK := Color("ecf0dd")
const MUTED := Color("a5bcb5")
const GOLD := Color("efd094")

var panel: PanelContainer
var hint: Label
var dragging_mouse: bool = false
var dragging_touch_id: int = -1
var was_camp_active: bool = false

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_controls()

func _build_controls() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -205.0
	panel.offset_right = 205.0
	panel.offset_top = 106.0
	panel.offset_bottom = 148.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.hide()
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	hint = Label.new()
	hint.text = "CHARACTER VIEW  /  DRAG CUBE"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	row.add_child(_viewer_button("LEFT", func(): rotate_by(-ROTATE_STEP), "Rotate character left"))
	row.add_child(_viewer_button("RESET", func(): reset_rotation(), "Face character forward"))
	row.add_child(_viewer_button("RIGHT", func(): rotate_by(ROTATE_STEP), "Rotate character right"))

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
	button.add_theme_stylebox_override("hover", _button_style(Color("385f56"), Color("9bddc2")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1c3b38"), GOLD))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), GOLD))
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func _process(_delta: float) -> void:
	var active := camp_view_active()
	if is_instance_valid(panel):
		panel.visible = active
	if active != was_camp_active:
		reset_rotation()
		dragging_mouse = false
		dragging_touch_id = -1
		was_camp_active = active

func current_scene_root() -> Node:
	return get_tree().current_scene

func camp_view_active() -> bool:
	var scene := current_scene_root()
	if scene == null:
		return false
	if bool(scene.get("at_title")):
		return false
	var game = scene.get("game")
	if game == null or not game.data is Dictionary:
		return false
	return str(game.data.get("mode", "")) == "camp"

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

func camera_node() -> Camera3D:
	var world = world_node()
	if world == null:
		return null
	var camera = world.get("camera")
	return camera as Camera3D if camera is Camera3D else null

func rotate_by(delta_radians: float) -> void:
	if not camp_view_active():
		return
	var actor := actor_node()
	if actor == null:
		return
	actor.rotation.y = wrapf(actor.rotation.y + delta_radians, -PI, PI)

func reset_rotation() -> void:
	var actor := actor_node()
	if actor != null:
		actor.rotation.y = 0.0

func pointer_hits_character(screen_position: Vector2) -> bool:
	if not camp_view_active():
		return false
	var actor := actor_node()
	var camera := camera_node()
	if actor == null or camera == null:
		return false
	var target := actor.global_position + Vector3(0, 0.55, 0)
	if camera.is_position_behind(target):
		return false
	var projected := camera.unproject_position(target)
	return projected.distance_to(screen_position) <= PICK_RADIUS_PX

func pointer_over_view_controls(screen_position: Vector2) -> bool:
	return is_instance_valid(panel) and panel.visible and panel.get_global_rect().has_point(screen_position)

func _input(event: InputEvent) -> void:
	if not camp_view_active():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			rotate_by(-ROTATE_STEP)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			rotate_by(ROTATE_STEP)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			reset_rotation()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not pointer_over_view_controls(event.position) and pointer_hits_character(event.position):
				dragging_mouse = true
				get_viewport().set_input_as_handled()
		else:
			if dragging_mouse:
				dragging_mouse = false
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and dragging_mouse:
		rotate_by(-event.relative.x * DRAG_SENSITIVITY)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if not pointer_over_view_controls(event.position) and pointer_hits_character(event.position):
				dragging_touch_id = event.index
				get_viewport().set_input_as_handled()
		elif dragging_touch_id == event.index:
			dragging_touch_id = -1
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag and dragging_touch_id == event.index:
		rotate_by(-event.relative.x * DRAG_SENSITIVITY)
		get_viewport().set_input_as_handled()
