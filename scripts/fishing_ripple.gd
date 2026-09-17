extends Control
signal attempted(success: bool, accuracy: float)

var active: bool = false
var phase: float = 0.0
var speed: float = 1.25
var min_radius: float = 18.0
var max_radius: float = 62.0
var target_radius: float = 39.0
var tolerance: float = 7.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(138, 108)
	set_process(false)

func start() -> void:
	phase = 0.0
	active = true
	set_process(true)
	queue_redraw()

func stop() -> void:
	active = false
	set_process(false)
	queue_redraw()

func current_radius() -> float:
	var wave: float = (sin(phase) + 1.0) * 0.5
	return lerpf(min_radius, max_radius, wave)

func _process(delta: float) -> void:
	if not active:
		return
	phase += delta * speed * TAU
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	var pressed: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if not pressed:
		return
	var distance: float = absf(current_radius() - target_radius)
	var success: bool = distance <= tolerance
	var accuracy: float = clampf(1.0 - distance / max(tolerance * 2.0, 0.01), 0.0, 1.0) if success else 0.0
	active = false
	set_process(false)
	queue_redraw()
	attempted.emit(success, accuracy)
	accept_event()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var water: Color = Color(0.20, 0.39, 0.43, 0.85)
	var target: Color = Color(0.88, 0.73, 0.40, 0.88)
	var ripple: Color = Color(0.67, 0.87, 0.86, 0.96)
	draw_circle(center, 60.0, Color(0.08, 0.18, 0.20, 0.88))
	draw_circle(center, 53.0, water)
	draw_arc(center, target_radius - tolerance, 0.0, TAU, 72, Color(target.r, target.g, target.b, 0.40), 5.0)
	draw_arc(center, target_radius + tolerance, 0.0, TAU, 72, Color(target.r, target.g, target.b, 0.40), 5.0)
	draw_arc(center, target_radius, 0.0, TAU, 72, target, 2.0)
	if active:
		draw_arc(center, current_radius(), 0.0, TAU, 72, ripple, 4.0)
	else:
		draw_arc(center, target_radius, 0.0, TAU, 72, Color(0.56, 0.68, 0.67, 0.6), 3.0)
