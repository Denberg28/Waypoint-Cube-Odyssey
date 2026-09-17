extends Node
## Lantern Camp 360-degree character viewer.
## Desktop/Web: drag horizontally across the center of the game view or tap Q/E.
## Touch: drag horizontally across the center of the game view.
## The feature is intentionally restricted to Lantern Camp so travel controls and
## crossroads clicks keep their existing behavior.

const WORLD_SCRIPT_PATH := "res://scripts/world.gd"
const ROTATE_SENSITIVITY := 0.010
const KEY_STEP_RADIANS := deg_to_rad(18.0)

var _world: Node = null
var _actor: Node3D = null
var _active := false
var _dragging := false
var _touch_index := -1
var _yaw := 0.0
var _hint_layer: CanvasLayer
var _hint_panel: PanelContainer

func _ready() -> void:
	_build_hint()
	set_process(true)

func _process(_delta: float) -> void:
	_resolve_world()
	var should_be_active := _is_lantern_camp()
	if should_be_active != _active:
		_active = should_be_active
		_hint_panel.visible = _active
		_dragging = false
		_touch_index = -1
		if _active:
			_sync_from_actor()
		else:
			_reset_actor_heading()
	if _active:
		_resolve_actor()
		_apply_yaw()

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_rotate_by(-KEY_STEP_RADIANS)
		elif event.keycode == KEY_E:
			_rotate_by(KEY_STEP_RADIANS)
		elif event.keycode == KEY_R:
			_yaw = 0.0
			_apply_yaw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click and _in_character_drag_zone(event.position):
				_yaw = 0.0
				_apply_yaw()
				_dragging = false
			elif _in_character_drag_zone(event.position):
				_dragging = true
		else:
			_dragging = false
		return

	if event is InputEventMouseMotion and _dragging:
		_rotate_by(event.relative.x * ROTATE_SENSITIVITY)
		return

	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0 and _in_character_drag_zone(event.position):
			_touch_index = event.index
			_dragging = true
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_dragging = false
		return

	if event is InputEventScreenDrag and _dragging and event.index == _touch_index:
		_rotate_by(event.relative.x * ROTATE_SENSITIVITY)

func _rotate_by(amount: float) -> void:
	_yaw = wrapf(_yaw + amount, -PI, PI)
	_apply_yaw()

func _apply_yaw() -> void:
	_resolve_actor()
	if is_instance_valid(_actor):
		_actor.rotation.y = _yaw

func _sync_from_actor() -> void:
	_resolve_actor()
	if is_instance_valid(_actor):
		_yaw = wrapf(_actor.rotation.y, -PI, PI)
	else:
		_yaw = 0.0

func _reset_actor_heading() -> void:
	_resolve_actor()
	if is_instance_valid(_actor):
		_actor.rotation.y = 0.0
	_yaw = 0.0

func _resolve_world() -> void:
	if is_instance_valid(_world):
		return
	_world = null
	_actor = null
	var scene := get_tree().current_scene
	if scene != null:
		_world = _find_world(scene)

func _find_world(node: Node) -> Node:
	var script = node.get_script()
	if script != null and str(script.resource_path) == WORLD_SCRIPT_PATH:
		return node
	for child in node.get_children():
		var found := _find_world(child)
		if found != null:
			return found
	return null

func _resolve_actor() -> void:
	if not is_instance_valid(_world):
		_actor = null
		return
	var candidate = _world.get("actor")
	if candidate is Node3D:
		_actor = candidate as Node3D
	else:
		_actor = null

func _is_lantern_camp() -> bool:
	if not is_instance_valid(_world):
		return false
	if bool(_world.get("entrance")):
		return false
	var state_obj = _world.get("state")
	if state_obj == null:
		return false
	var data = state_obj.get("data")
	return data is Dictionary and str(data.get("mode", "")) == "camp"

func _in_character_drag_zone(position: Vector2) -> bool:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	# Keep header, side controls, and bottom action docks outside the drag zone.
	return position.x >= size.x * 0.24 and position.x <= size.x * 0.76 \
		and position.y >= size.y * 0.20 and position.y <= size.y * 0.82

func _build_hint() -> void:
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 20
	add_child(_hint_layer)

	_hint_panel = PanelContainer.new()
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left = -155.0
	_hint_panel.offset_right = 155.0
	_hint_panel.offset_top = -58.0
	_hint_panel.offset_bottom = -20.0
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("183b3c")
	bg.border_color = Color("41645b")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 7
	bg.content_margin_bottom = 7
	_hint_panel.add_theme_stylebox_override("panel", bg)
	_hint_layer.add_child(_hint_panel)

	var hint := Label.new()
	hint.text = "360 VIEW  |  DRAG CUBE  |  Q / E  |  R RESET"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("a5bcb5"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(hint)
