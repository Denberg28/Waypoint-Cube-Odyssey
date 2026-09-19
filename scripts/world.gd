extends Node3D
## Procedural low-poly diorama. No downloaded assets or external plugins.
signal route_clicked(route_id: String)
signal marketplace_clicked
signal cat_clicked
signal camp_clicked
signal continue_clicked
const Catalog = preload("res://scripts/catalog.gd")
const State = preload("res://scripts/state.gd")
const VisualKit = preload("res://scripts/visual_kit.gd")
const LANE_SPACING: float = 2.8
const ROW_SPACING: float = 2.55
const VISIBLE_ROWS_AHEAD: int = 5
var scenery: Node3D
var props: Node3D
var actor: Node3D
var face: Node3D
var camera: Camera3D
var world_env: WorldEnvironment
var env_settings: Environment
var sun_light: DirectionalLight3D
var weather_fx: Node3D
var state
var hopping: bool = false
var elapsed: float = 0.0
var camera_target = Vector3.ZERO
var visuals = VisualKit.new()
var showcase: bool = false
var entrance: bool = false
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
const ACTOR_LEFT_FOOT_NEUTRAL := Vector3(-0.21, -0.08, 0.04)
const ACTOR_RIGHT_FOOT_NEUTRAL := Vector3(0.21, -0.08, 0.04)
const ACTOR_FOOT_SIZE := Vector3(0.24, 0.16, 0.34)
var active_theme: Dictionary = {}
var brightness_scale: float = 1.0
var idle_anchor_position: Vector3 = Vector3.ZERO
var idle_base_yaw: float = PI
var camp_cat_root: Node3D
var camp_actor_roam_index: int = 0
var camp_cat_roam_index: int = 0
var camp_actor_pause: float = 7.0
var camp_cat_pause: float = 0.45
var camp_actor_moves_since_rest: int = 0
var camp_actor_heading_to_fire: bool = false
var camp_actor_resting_by_fire: bool = false
var camp_actor_fire_rest_target: Vector3 = Vector3(2.0, 0.16, -5.15)
var camp_cat_moves_since_rest: int = 0
var camp_cat_heading_to_fire: bool = false
var camp_cat_resting_by_fire: bool = false
var camp_cat_fire_rest_target: Vector3 = Vector3(1.18, 0.16, -5.15)
var camp_roam_rng := RandomNumberGenerator.new()
var camp_actor_roam_points: Array[Vector3] = [
	Vector3(-2.15, 0.16, -2.35),
	Vector3(-0.75, 0.16, -2.55),
	Vector3(1.55, 0.16, -3.10),
	Vector3(2.10, 0.16, -6.45),
	Vector3(-0.75, 0.16, -7.05),
	Vector3(-2.55, 0.16, -4.15)
]
var camp_actor_fire_rest_points: Array[Vector3] = [
	Vector3(2.0, 0.16, -5.15),
	Vector3(-2.0, 0.16, -5.15)
]
var camp_cat_roam_points: Array[Vector3] = [
	Vector3(-1.35, 0.16, -3.55),
	Vector3(-0.35, 0.16, -3.00),
	Vector3(1.25, 0.16, -3.65),
	Vector3(1.55, 0.16, -5.65),
	Vector3(0.65, 0.16, -6.55),
	Vector3(-1.10, 0.16, -6.30),
	Vector3(-1.55, 0.16, -5.10)
]
var camp_cat_fire_rest_points: Array[Vector3] = [
	Vector3(1.18, 0.16, -5.15),
	Vector3(-1.18, 0.16, -5.15)
]

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	return visuals.material(color, glow)

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	return visuals.box(parent, pos, size, color, glow)

func cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = 0.0) -> MeshInstance3D:
	return visuals.cone(parent, pos, radius, height, color, top)

func sphere(parent: Node3D, pos: Vector3, diameter: float, color: Color, glow: bool = false) -> MeshInstance3D:
	return visuals.sphere(parent, pos, diameter, color, glow)

func clickable_board(parent: Node3D, pos: Vector3, size: Vector3, color: Color, route_id: String = "", marketplace: bool = false, camp_return: bool = false, continue_adventure: bool = false) -> Area3D:
	var area = Area3D.new()
	area.position = pos
	area.input_ray_pickable = true
	parent.add_child(area)
	box(area, Vector3.ZERO, size, color)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(func(_camera, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
		var pressed: bool = false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed = true
		elif event is InputEventScreenTouch and event.pressed:
			pressed = true
		if not pressed:
			return
		if marketplace:
			marketplace_clicked.emit()
		elif camp_return:
			camp_clicked.emit()
		elif continue_adventure:
			continue_clicked.emit()
		elif route_id != "":
			route_clicked.emit(route_id)
	)
	return area

func route_options_for_stage() -> Array:
	return State.route_options_for_stage_index(int(state.data.stage))

func theme_for_environment(env_id: String) -> Dictionary:
	# Muted, low-contrast palettes keep long sessions readable and relaxing.
	match env_id:
		"cloudy":
			return {
				"sky": Color("334851"), "ambient": Color("9eafb0"), "ambient_energy": 0.31,
				"sun": Color("d1cec5"), "sun_energy": 0.48,
				"ground": Color("3c5853"), "shoulder": Color("586963"),
				"road_a": Color("827d6e"), "road_b": Color("736f62"), "road_finish": Color("a49a79"),
				"road_base": Color("4c4841"), "post": Color("8f795d"), "bark": Color("725f4f"),
				"leaf_a": Color("55756d"), "leaf_b": Color("6f8c82"), "shrub": Color("697b73"), "text": Color("e9dfb8")
			}
		"rainy":
			return {
				"sky": Color("2b4050"), "ambient": Color("8fa8b2"), "ambient_energy": 0.29,
				"sun": Color("b7c9cf"), "sun_energy": 0.40,
				"ground": Color("334b50"), "shoulder": Color("475d61"),
				"road_a": Color("73777a"), "road_b": Color("666b6e"), "road_finish": Color("899497"),
				"road_base": Color("464b4e"), "post": Color("806f60"), "bark": Color("65574c"),
				"leaf_a": Color("46685f"), "leaf_b": Color("5e8176"), "shrub": Color("60756c"), "text": Color("d9e6e8")
			}
		"sand":
			return {
				"sky": Color("6a5b4c"), "ambient": Color("c3b28f"), "ambient_energy": 0.28,
				"sun": Color("e8c99d"), "sun_energy": 0.55,
				"ground": Color("766a4f"), "shoulder": Color("947f60"),
				"road_a": Color("a79372"), "road_b": Color("98866a"), "road_finish": Color("bdab82"),
				"road_base": Color("74644f"), "post": Color("8b704f"), "bark": Color("705e49"),
				"leaf_a": Color("788451"), "leaf_b": Color("909760"), "shrub": Color("817f65"), "text": Color("ead9b2")
			}
		"winter":
			return {
				"sky": Color("596875"), "ambient": Color("aebcc5"), "ambient_energy": 0.24,
				"sun": Color("cbd5dc"), "sun_energy": 0.36,
				"ground": Color("66747b"), "shoulder": Color("87979f"),
				"road_a": Color("a9b1b5"), "road_b": Color("979fa4"), "road_finish": Color("bcc5c9"),
				"road_base": Color("747d81"), "post": Color("82796f"), "bark": Color("605650"),
				"leaf_a": Color("9fb5ba"), "leaf_b": Color("b5c7ca"), "shrub": Color("a3b2b6"), "text": Color("e3ecee")
			}
		_:
			return {
				"sky": Color("2d4c55"), "ambient": Color("a8c1b9"), "ambient_energy": 0.33,
				"sun": Color("e7cfaa"), "sun_energy": 0.56,
				"ground": Color("36584f"), "shoulder": Color("5c7867"),
				"road_a": Color("91876e"), "road_b": Color("827a65"), "road_finish": Color("b2a47a"),
				"road_base": Color("5b5549"), "post": Color("927758"), "bark": Color("735f4c"),
				"leaf_a": Color("47745e"), "leaf_b": Color("60886d"), "shrub": Color("688071"), "text": Color("eee1b8")
			}

func theme_for_route(route_id: String, base_theme: Dictionary) -> Dictionary:
	if route_id not in ["gloomwood", "sunken_grotto", "cinder_caldera", "galecrest_spire"]:
		return base_theme
	var theme: Dictionary = base_theme.duplicate(true)
	match route_id:
		"gloomwood":
			theme.sky = Color("242a3d")
			theme.ambient = Color("9aa0bd")
			theme.ambient_energy = 0.26
			theme.sun = Color("c7bad3")
			theme.sun_energy = 0.34
			theme.ground = Color("2f403f")
			theme.shoulder = Color("435350")
			theme.road_a = Color("68635f")
			theme.road_b = Color("5d5957")
			theme.road_finish = Color("827a76")
			theme.road_base = Color("413d3d")
			theme.post = Color("6d5d58")
			theme.bark = Color("51443f")
			theme.leaf_a = Color("3f625a")
			theme.leaf_b = Color("536e69")
			theme.shrub = Color("596860")
			theme.text = Color("e1d4ef")
		"sunken_grotto":
			theme.sky = Color("18343b")
			theme.ambient = Color("79b7b5")
			theme.ambient_energy = 0.24
			theme.sun = Color("9fd9d3")
			theme.sun_energy = 0.28
			theme.ground = Color("29494b")
			theme.shoulder = Color("365e5f")
			theme.road_a = Color("547775")
			theme.road_b = Color("466a69")
			theme.road_finish = Color("6b918c")
			theme.road_base = Color("304d4e")
			theme.post = Color("4f6666")
			theme.bark = Color("48615f")
			theme.leaf_a = Color("4f8881")
			theme.leaf_b = Color("69a49b")
			theme.shrub = Color("5d8b84")
			theme.text = Color("c8f0e8")
		"cinder_caldera":
			theme.sky = Color("3b2520")
			theme.ambient = Color("b2765e")
			theme.ambient_energy = 0.25
			theme.sun = Color("f0a063")
			theme.sun_energy = 0.58
			theme.ground = Color("4b3029")
			theme.shoulder = Color("654237")
			theme.road_a = Color("735044")
			theme.road_b = Color("64443b")
			theme.road_finish = Color("8a5b47")
			theme.road_base = Color("3e2b28")
			theme.post = Color("68483c")
			theme.bark = Color("503731")
			theme.leaf_a = Color("805342")
			theme.leaf_b = Color("9c6449")
			theme.shrub = Color("7a5548")
			theme.text = Color("ffd2a0")
		"galecrest_spire":
			theme.sky = Color("486477")
			theme.ambient = Color("b4c9d6")
			theme.ambient_energy = 0.27
			theme.sun = Color("dde9ef")
			theme.sun_energy = 0.48
			theme.ground = Color("5a696f")
			theme.shoulder = Color("76858b")
			theme.road_a = Color("8b9699")
			theme.road_b = Color("79878c")
			theme.road_finish = Color("aab8bc")
			theme.road_base = Color("586267")
			theme.post = Color("69767d")
			theme.bark = Color("5a6466")
			theme.leaf_a = Color("7f9295")
			theme.leaf_b = Color("98aaad")
			theme.shrub = Color("89999d")
			theme.text = Color("e8f2f6")
	return theme

func setup(game_state) -> void:
	state = game_state
	print("VISUAL_PROFILE=", visuals.profile_name())
	world_env = WorldEnvironment.new()
	env_settings = Environment.new()
	env_settings.background_mode = Environment.BG_COLOR
	env_settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_settings.tonemap_exposure = 0.82
	world_env.environment = env_settings
	add_child(world_env)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-50, -35, 0)
	sun_light.shadow_enabled = true
	add_child(sun_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 57.0
	camera.far = 160.0
	camera.current = true
	add_child(camera)
	actor = Node3D.new()
	add_child(actor)
	refresh_actor()
	build()

func refresh_actor(preview_class: String = "", preview_skin: int = -1) -> void:
	for child in actor.get_children():
		actor.remove_child(child)
		child.queue_free()
	var skin_index: int = int(state.data.skin) if preview_skin < 0 else preview_skin
	var skin: Color = Color(Catalog.SKINS[skin_index].color)
	if preview_skin < 0 and state.data.has("cosmetics_equipped"):
		var market_skin_id: String = str(state.data.cosmetics_equipped.get("skin", ""))
		var market_skin: Dictionary = Catalog.cosmetic(market_skin_id)
		if not market_skin.is_empty() and market_skin.has("color"):
			skin = Color(str(market_skin.color))
	# Cube-chibi proportions: oversized head, tiny body/feet, all built from voxel primitives.
	box(actor, Vector3(0, 0.62, 0), Vector3(0.92, 0.92, 0.92), skin)
	box(actor, Vector3(0, 1.09, 0), Vector3(0.78, 0.05, 0.78), skin.lightened(0.18))
	box(actor, Vector3(0, 0.08, 0), Vector3(0.62, 0.34, 0.52), skin.darkened(0.08))
	left_foot = box(actor, ACTOR_LEFT_FOOT_NEUTRAL, ACTOR_FOOT_SIZE, Color("355c58"))
	right_foot = box(actor, ACTOR_RIGHT_FOOT_NEUTRAL, ACTOR_FOOT_SIZE, Color("355c58"))
	left_arm = box(actor, Vector3(-0.55, 0.20, 0), Vector3(0.18, 0.46, 0.22), skin.darkened(0.12))
	right_arm = box(actor, Vector3(0.55, 0.20, 0), Vector3(0.18, 0.46, 0.22), skin.darkened(0.12))
	for x in [-0.19, 0.19]:
		box(actor, Vector3(x, 0.72, 0.467), Vector3(0.09, 0.13, 0.025), Color("17333a"))
		box(actor, Vector3(x + 0.016, 0.755, 0.483), Vector3(0.026, 0.032, 0.01), Color("fff6dc"))
	box(actor, Vector3(0, 0.49, 0.473), Vector3(0.17, 0.045, 0.022), Color("784f49"))
	box(actor, Vector3(0, 0.21, 0), Vector3(0.72, 0.12, 0.58), Color("397e7d"))
	if state.data.equipped.shell != "":
		box(actor, Vector3(0, 0.25, -0.02), Vector3(0.96, 0.23, 0.96), Color("778782"))
	if state.data.equipped.core != "":
		box(actor, Vector3(0, 0.62, -0.46), Vector3(0.26, 0.26, 0.08), Color("ffdf92"), true)
	if state.data.equipped.charm != "":
		cone(actor, Vector3(0.52, 0.45, 0.2), 0.1, 0.24, Color("f3d27c"), 0.06)
	var role: String = str(state.data.class_id) if preview_class == "" else preview_class
	match role:
		"knight":
			box(actor, Vector3(0, 0.98, 0), Vector3(1.03, 0.25, 0.97), Color("a1b8bd"))
			box(actor, Vector3(0, 1.17, 0), Vector3(0.12, 0.3, 0.65), Color("cb8071"))
			box(actor, Vector3(-0.6, 0.43, 0), Vector3(0.17, 0.7, 0.52), Color("7199a7"))
		"magician":
			cone(actor, Vector3(0, 0.99, 0), 0.63, 0.09, Color("78609c"), 0.63)
			cone(actor, Vector3(0, 1.37, 0), 0.39, 0.74, Color("9876ba"))
			box(actor, Vector3(0.58, 0.7, 0), Vector3(0.09, 1.25, 0.09), Color("b39371"))
			box(actor, Vector3(0.58, 1.4, 0), Vector3(0.23, 0.23, 0.23), Color("b2e8ef"), true)
		"merchant":
			box(actor, Vector3(0, 1.0, 0), Vector3(1.12, 0.10, 1.03), Color("c3a36b"))
			box(actor, Vector3(0, 1.18, 0), Vector3(0.65, 0.28, 0.65), Color("e3c48a"))
			box(actor, Vector3(0.6, 0.38, 0), Vector3(0.35, 0.45, 0.42), Color("aa7452"))
		"adventurer":
			cone(actor, Vector3(0, 1.03, 0), 0.47, 0.12, Color("638d6c"), 0.47)
			cone(actor, Vector3(0, 1.19, 0), 0.28, 0.27, Color("82ad80"), 0.2)
	if preview_skin < 0:
		apply_market_cosmetics()
	actor.rotation.y = PI

func apply_market_cosmetics() -> void:
	if not state.data.has("cosmetics_equipped"):
		return
	var equipped: Dictionary = state.data.cosmetics_equipped
	var head: Dictionary = Catalog.cosmetic(str(equipped.get("head", "")))
	if not head.is_empty():
		var c: Color = Color(str(head.get("color", "8b7a66")))
		match str(head.get("style", "")):
			"trail_cap":
				box(actor, Vector3(0, 1.18, 0), Vector3(1.08, 0.09, 0.86), c)
				box(actor, Vector3(0, 1.30, -0.03), Vector3(0.72, 0.20, 0.64), c.darkened(0.08))
			"moon_hood":
				cone(actor, Vector3(0, 1.30, 0), 0.53, 0.42, c, 0.34)
			"crown":
				box(actor, Vector3(0, 1.23, 0), Vector3(0.72, 0.12, 0.68), c)
				for x in [-0.24, 0.0, 0.24]:
					cone(actor, Vector3(x, 1.43, 0), 0.10, 0.30, c.lightened(0.08), 0.02)
	var back: Dictionary = Catalog.cosmetic(str(equipped.get("back", "")))
	if not back.is_empty():
		var c: Color = Color(str(back.get("color", "7c6954")))
		match str(back.get("style", "")):
			"pack":
				box(actor, Vector3(0, 0.43, -0.53), Vector3(0.68, 0.74, 0.22), c)
				box(actor, Vector3(0, 0.82, -0.56), Vector3(0.48, 0.10, 0.18), c.lightened(0.10))
			"lantern":
				box(actor, Vector3(0, 0.40, -0.53), Vector3(0.60, 0.66, 0.20), c.darkened(0.12))
				box(actor, Vector3(0, 0.74, -0.64), Vector3(0.34, 0.38, 0.20), Color("e8cb84"), true)
			"cape":
				box(actor, Vector3(0, 0.36, -0.54), Vector3(0.78, 0.96, 0.10), c)
	var face_item: Dictionary = Catalog.cosmetic(str(equipped.get("face", "")))
	if not face_item.is_empty():
		var c: Color = Color(str(face_item.get("color", "b8786c")))
		match str(face_item.get("style", "")):
			"scarf":
				box(actor, Vector3(0, 0.31, 0.47), Vector3(0.78, 0.18, 0.06), c)
			"goggles":
				for x in [-0.19, 0.19]:
					box(actor, Vector3(x, 0.73, 0.493), Vector3(0.18, 0.17, 0.03), c)
				box(actor, Vector3(0, 0.73, 0.495), Vector3(0.16, 0.04, 0.03), c.darkened(0.25))
			"star_mark":
				box(actor, Vector3(0.31, 0.55, 0.492), Vector3(0.10, 0.10, 0.03), c, true)

func clear_layer(layer: Node3D) -> void:
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()

func set_brightness(scale: float) -> void:
	brightness_scale = clampf(scale, 0.45, 1.0)
	apply_environment_lighting()

func apply_environment_lighting() -> void:
	if active_theme.is_empty() or env_settings == null or sun_light == null:
		return
	var darken_amount: float = (1.0 - brightness_scale) * 0.38
	var sky_color: Color = active_theme.sky
	env_settings.background_color = sky_color.darkened(darken_amount)
	env_settings.ambient_light_color = active_theme.ambient
	env_settings.ambient_light_energy = float(active_theme.ambient_energy) * brightness_scale
	sun_light.light_color = active_theme.sun
	sun_light.light_energy = float(active_theme.sun_energy) * brightness_scale

func apply_environment() -> void:
	var env_id: String = str(state.data.get("environment", "sunny"))
	active_theme = theme_for_route(str(state.data.get("route", "moss")), theme_for_environment(env_id))
	apply_environment_lighting()
	clear_layer(weather_fx)
	weather_fx = Node3D.new()
	add_child(weather_fx)
	if env_id == "rainy":
		add_precipitation(Color("a9d5ef"), 90, 11.0, 0.11)
	elif env_id == "winter":
		add_precipitation(Color("d7e1e4"), 48, 7.2, 0.16)
	elif env_id == "cloudy":
		add_cloud_strip(3.0)
	elif env_id == "sand":
		add_cloud_strip(2.6, Color("c9b07a"))
	else:
		add_cloud_strip(3.2, Color("f0e2b4"))

func add_cloud_strip(y: float, color: Color = Color("d9e0e4")) -> void:
	# Keep the forward lane visually open: cloud masses live on the shoulders only.
	var points: Array = [[-9.5, -13.0], [-7.2, -24.0], [7.4, -16.0], [10.2, -29.0]]
	if visuals.simple_mode:
		points = [[-8.5, -16.0], [8.5, -25.0]]
	for point in points:
		var x: float = float(point[0])
		var z: float = float(point[1])
		box(weather_fx, Vector3(x, y + absf(x) * 0.02, z), Vector3(2.8, 0.55, 1.15), color)
		box(weather_fx, Vector3(x + (0.8 if x < 0.0 else -0.8), y + 0.22, z - 0.2), Vector3(1.5, 0.48, 0.95), color.lightened(0.05))

func add_precipitation(color: Color, amount: int, speed_scale: float, size_y: float) -> void:
	var draw_amount: int = visuals.precipitation_budget(amount)
	for i in range(draw_amount):
		var x: float = randf_range(-7.0, 7.0)
		var z: float = randf_range(-42.0, 6.0)
		var y: float = randf_range(2.5, 9.5)
		var streak = box(weather_fx, Vector3(x, y, z), Vector3(0.04, size_y, 0.04), color, false)
		streak.rotation_degrees = Vector3(12, 0, 0)

func build() -> void:
	apply_environment()
	clear_layer(scenery)
	clear_layer(props)
	scenery = Node3D.new()
	props = Node3D.new()
	add_child(scenery)
	add_child(props)
	var is_trail: bool = not entrance and state.data.mode in ["travel", "campfire", "fishing", "reward", "shrine", "traveler"]
	var is_boss: bool = not entrance and state.data.mode in ["boss", "boss_intro", "victory"]
	var is_crossroads: bool = not entrance and state.data.mode == "choice"
	var is_road_end: bool = not entrance and state.data.mode == "road_end"
	var count: int = State.STAGE_STEPS + 1 if is_trail else (6 if is_crossroads else 5)
	var local_rng = RandomNumberGenerator.new()
	local_rng.seed = int(state.data.seed)
	var center_z: float = -float(count - 1) * ROW_SPACING * 0.5
	box(scenery, Vector3(0, -1.8, center_z), Vector3(16, 2.5, count * ROW_SPACING + 6), active_theme.ground)
	box(scenery, Vector3(0, -0.5, center_z), Vector3(16.4, 0.4, count * ROW_SPACING + 6.4), active_theme.shoulder)
	for row in range(count):
		for lane in range(-1, 2):
			var pos = Vector3(lane * LANE_SPACING, -0.05, -row * ROW_SPACING)
			var tint: Color = active_theme.road_a if (row + lane) % 2 == 0 else active_theme.road_b
			if row == count - 1:
				tint = active_theme.road_finish
			box(scenery, pos, Vector3(2.62, 0.36, 2.42), tint)
			box(scenery, pos + Vector3(0, -0.27, 0), Vector3(2.48, 0.18, 2.28), active_theme.road_base)
		var marker_stride: int = 4 if visuals.simple_mode else 2
		if row % marker_stride == 0:
			for side in [-1, 1]:
				var edge_x: float = side * 4.55
				var road_style: Dictionary = waypoint_style_for(str(state.data.get("route", "moss")))
				roadside_waymarker(
					scenery,
					Vector3(edge_x, 0.0, -row * ROW_SPACING),
					road_style,
					side,
					(not visuals.simple_mode) and row % 4 == 0
				)
		if row % (5 if visuals.simple_mode else 3) == 0:
			for side in [-1, 1]:
				var x: float = side * local_rng.randf_range(6.2, 7.7)
				var z: float = -row * ROW_SPACING + local_rng.randf_range(-0.6, 0.6)
				tree(Vector3(x, 0, z), local_rng.randf_range(0.82, 1.14))
		elif (not visuals.simple_mode) and row % 3 == 1:
			var shrub_side: int = -1 if row % 2 == 0 else 1
			cone(scenery, Vector3(shrub_side * 6.4, 0.35, -row * ROW_SPACING), 0.58, 0.75, active_theme.shrub, 0.3)
		if (not visuals.simple_mode or row % 8 == 2) and row % 4 == 2:
			for side in [-1, 1]:
				environment_side_prop(row, side, local_rng)
	if is_trail:
		var finish_z: float = -State.STAGE_STEPS * ROW_SPACING
		for lane in [-1, 1]:
			box(scenery, Vector3(lane * 4.15, 1.2, finish_z), Vector3(0.22, 2.7, 0.22), active_theme.post)
		box(scenery, Vector3(0, 2.6, finish_z), Vector3(8.5, 0.3, 0.35), active_theme.post)
		floating_text(scenery, "WAYPOINT", Vector3(0, 3.3, finish_z), active_theme.text, 42)
		match str(state.data.route):
			"gloomwood":
				gloomwood_landmark(finish_z)
			"sunken_grotto":
				sunken_grotto_landmark(finish_z)
			"cinder_caldera":
				cinder_caldera_landmark(finish_z)
			"galecrest_spire":
				galecrest_spire_landmark(finish_z)
	elif is_boss:
		guardian()
	elif is_road_end:
		var finish_z: float = -float(count - 1) * ROW_SPACING
		road_end_waypoint(finish_z)
	elif is_crossroads:
		var finish_z: float = -float(count - 1) * ROW_SPACING
		crossroads(finish_z)
	else:
		camp()
	actor.position = Vector3(int(state.data.lane) * LANE_SPACING, 0.16, -int(state.data.row) * ROW_SPACING) if is_trail else Vector3(0, 0.16, 0)
	if is_boss:
		actor.position = Vector3(int(state.data.lane) * LANE_SPACING, 0.16, 0)
	elif is_road_end:
		actor.position = Vector3(0, 0.16, -float(count - 1) * ROW_SPACING + ROW_SPACING * 1.35)
	elif is_crossroads:
		actor.position = Vector3(0, 0.16, -float(count - 1) * ROW_SPACING + ROW_SPACING * 1.35)
	elif not entrance and state.data.mode == "camp":
		pose_actor_at_camp()
	idle_anchor_position = actor.position
	idle_base_yaw = actor.rotation.y
	camera_target = Vector3(actor.position.x * 0.22, 0, actor.position.z)
	if not entrance and state.data.mode == "camp":
		# Keep the hub framed while the character and cat roam independently.
		camera_target = Vector3(0.0, 0.12, -4.80)
	update_camera()
	refresh_props()

func gloomwood_landmark(finish_z: float) -> void:
	var root_z: float = finish_z + 1.25
	for side in [-1, 1]:
		box(scenery, Vector3(side * 3.35, 1.65, root_z), Vector3(0.72, 3.30, 0.72), Color("4b3b38"))
		var arm = box(scenery, Vector3(side * 1.75, 3.05, root_z), Vector3(3.1, 0.42, 0.48), Color("56423d"))
		arm.rotation_degrees.z = float(side) * 12.0
	floating_text(scenery, "WHISPERING HOLLOW ROOT", Vector3(0, 4.18, root_z), Color("d9c8e9"), 24)

func sunken_grotto_landmark(finish_z: float) -> void:
	var z: float = finish_z + 1.15
	for side in [-1, 1]:
		cone(scenery, Vector3(side * 2.4, 1.20, z), 0.58, 2.45, Color("5faaa6"), 0.08)
		cone(scenery, Vector3(side * 3.15, 0.75, z + 0.5), 0.34, 1.55, Color("8ed0c8"), 0.03)
	box(scenery, Vector3(0, 0.02, z), Vector3(4.8, 0.08, 2.1), Color("3f7f84"), true)
	floating_text(scenery, "THE LUMINESCENT CASCADE", Vector3(0, 3.55, z), Color("c8f3ea"), 24)

func cinder_caldera_landmark(finish_z: float) -> void:
	var z: float = finish_z + 1.25
	for side in [-1, 1]:
		cone(scenery, Vector3(side * 2.7, 0.85, z), 0.9, 1.75, Color("4a3630"), 0.20)
		cone(scenery, Vector3(side * 2.7, 1.72, z), 0.46, 0.85, Color("d86f4f"), 0.05)
	box(scenery, Vector3(0, 0.10, z), Vector3(3.0, 0.14, 1.55), Color("b8533e"), true)
	floating_text(scenery, "THE OBSIDIAN HEARTH", Vector3(0, 3.35, z), Color("ffc28c"), 24)

func galecrest_spire_landmark(finish_z: float) -> void:
	var z: float = finish_z + 1.20
	for side in [-1, 1]:
		box(scenery, Vector3(side * 2.65, 1.55, z), Vector3(0.55, 3.1, 0.55), Color("78878e"))
		cone(scenery, Vector3(side * 2.65, 3.45, z), 0.42, 1.10, Color("aabac1"), 0.06)
	box(scenery, Vector3(0, 2.78, z), Vector3(5.6, 0.24, 0.42), Color("87969c"))
	floating_text(scenery, "THE WHISPERING SUMMIT GATE", Vector3(0, 4.20, z), Color("e3f0f5"), 24)

func environment_side_prop(row: int, side: int, local_rng: RandomNumberGenerator) -> void:
	var env_id: String = str(state.data.get("environment", "sunny"))
	var x: float = float(side) * local_rng.randf_range(5.8, 7.3)
	var z: float = -row * ROW_SPACING + local_rng.randf_range(-0.45, 0.45)
	var route_id: String = str(state.data.get("route", "moss"))
	if route_id == "fen" and row % 8 == 2:
		box(scenery, Vector3(x, 0.03, z), Vector3(1.8, 0.05, 1.15), Color("496f72"), true)
	elif route_id == "frost" and row % 8 == 2:
		cone(scenery, Vector3(x, 0.45, z), 0.24, 0.90, Color("91b5bd"), 0.03)
	elif route_id == "sunken_grotto":
		box(scenery, Vector3(x, 0.02, z), Vector3(1.65, 0.05, 1.1), Color("3e7478"), true)
		cone(scenery, Vector3(x + side * 0.55, 0.38, z), 0.18, 0.82, Color("72bdb4"), 0.02)
	elif route_id == "cinder_caldera":
		cone(scenery, Vector3(x, 0.30, z), 0.48, 0.68, Color("4b3832"), 0.18)
		box(scenery, Vector3(x + side * 0.48, 0.05, z + 0.18), Vector3(0.72, 0.06, 0.48), Color("b64f39"), true)
	elif route_id == "galecrest_spire":
		box(scenery, Vector3(x, 0.34, z), Vector3(0.46, 0.68, 0.46), Color("7c898f"))
		cone(scenery, Vector3(x + side * 0.42, 0.72, z), 0.18, 0.82, Color("afc0c6"), 0.04)
	match env_id:
		"rainy":
			box(scenery, Vector3(x, 0.02, z), Vector3(1.5, 0.035, 0.72), Color("557f91"), true)
			box(scenery, Vector3(x + side * 0.55, 0.14, z - 0.35), Vector3(0.32, 0.28, 0.42), Color("667477"))
		"winter":
			cone(scenery, Vector3(x, 0.24, z), 0.62, 0.48, Color("b8c6ca"), 0.42)
			box(scenery, Vector3(x + side * 0.72, 0.18, z + 0.18), Vector3(0.52, 0.36, 0.52), Color("8fa9b2"), true)
		"sand":
			cone(scenery, Vector3(x, 0.3, z), 0.55, 0.62, Color("9e865c"), 0.24)
			box(scenery, Vector3(x + side * 0.7, 0.12, z - 0.18), Vector3(0.55, 0.24, 0.42), Color("806d54"))
		"cloudy":
			box(scenery, Vector3(x, 0.2, z), Vector3(0.7, 0.4, 0.55), Color("68736e"))
			cone(scenery, Vector3(x + side * 0.65, 0.36, z), 0.42, 0.72, active_theme.shrub, 0.16)
		_:
			for offset in [-0.34, 0.0, 0.34]:
				cone(scenery, Vector3(x + offset, 0.20, z + absf(offset) * 0.25), 0.13, 0.38, Color("d9bf72"), 0.04)
			box(scenery, Vector3(x + side * 0.72, 0.16, z - 0.22), Vector3(0.46, 0.32, 0.42), Color("708273"))

func tree(pos: Vector3, factor: float) -> void:
	var env_id: String = str(state.data.get("environment", "sunny"))
	if env_id == "sand":
		box(scenery, pos + Vector3(0, 0.75, 0), Vector3(0.24, 1.4, 0.24), active_theme.bark)
		box(scenery, pos + Vector3(0.36, 1.0, 0), Vector3(0.68, 0.18, 0.18), active_theme.leaf_a)
		box(scenery, pos + Vector3(-0.34, 1.35, 0), Vector3(0.6, 0.18, 0.18), active_theme.leaf_b)
		box(scenery, pos + Vector3(0, 1.75, 0), Vector3(0.18, 0.52, 0.18), active_theme.leaf_a)
		return
	box(scenery, pos + Vector3(0, 0.9, 0), Vector3(0.3, 1.8, 0.3), active_theme.bark)
	cone(scenery, pos + Vector3(0, 2.1, 0) * factor, 1.3 * factor, 2.3 * factor, active_theme.leaf_a)
	cone(scenery, pos + Vector3(0, 3.0, 0) * factor, 0.93 * factor, 1.9 * factor, active_theme.leaf_b)
	if env_id == "winter":
		cone(scenery, pos + Vector3(0, 3.28, 0) * factor, 0.36 * factor, 0.65 * factor, Color("cbd7d9"))

func build_cat_companion() -> void:
	if not bool(state.data.get("cat_owned", false)):
		return
	var design: Dictionary = state.data.get("cat_design", {})
	if design.is_empty():
		return
	var root := Node3D.new()
	root.name = "CampCatCompanion"
	camp_cat_root = root
	camp_cat_roam_index = 0
	camp_cat_pause = 0.45
	root.position = camp_cat_roam_points[0]
	root.rotation.y = 0.35
	scenery.add_child(root)

	# One generous interaction hitbox wraps the whole low-poly cat so Web/mobile
	# clicks do not depend on touching a tiny individual mesh.
	var cat_area := Area3D.new()
	cat_area.name = "CatInteraction"
	cat_area.input_ray_pickable = true
	root.add_child(cat_area)
	var cat_collision := CollisionShape3D.new()
	var cat_shape := BoxShape3D.new()
	cat_shape.size = Vector3(1.25, 1.55, 1.15)
	cat_collision.shape = cat_shape
	cat_collision.position = Vector3(0, 0.62, 0)
	cat_area.add_child(cat_collision)
	cat_area.input_event.connect(func(_camera, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
		var pressed: bool = false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed = true
		elif event is InputEventScreenTouch and event.pressed:
			pressed = true
		if pressed:
			cat_clicked.emit()
	)
	var body_color := Color(str(design.get("body", "c99068")))
	var accent_color := Color(str(design.get("accent", "f0e1c0")))
	var eye_color := Color(str(design.get("eyes", "e7c96f")))
	var pattern: String = str(design.get("pattern", "solid"))

	# Compact voxel-cat silhouette: body, head, four paws, ears and tail.
	box(root, Vector3(0, 0.36, 0), Vector3(0.72, 0.52, 0.58), body_color)
	box(root, Vector3(0, 0.76, 0.15), Vector3(0.58, 0.56, 0.54), body_color)
	for x in [-0.19, 0.19]:
		cone(root, Vector3(x, 1.08, 0.14), 0.14, 0.28, body_color, 0.01)
		box(root, Vector3(x, 0.79, 0.43), Vector3(0.07, 0.10, 0.03), eye_color, true)
	box(root, Vector3(0, 0.68, 0.44), Vector3(0.08, 0.06, 0.03), Color("5a3c3c"))
	for x in [-0.24, 0.24]:
		box(root, Vector3(x, 0.06, 0.18), Vector3(0.18, 0.16, 0.26), body_color.darkened(0.08))
		box(root, Vector3(x, 0.06, -0.18), Vector3(0.18, 0.16, 0.26), body_color.darkened(0.08))
	# Tail uses three short segments so it reads clearly from the camp camera.
	box(root, Vector3(0.44, 0.42, -0.18), Vector3(0.18, 0.18, 0.52), body_color)
	box(root, Vector3(0.50, 0.62, -0.42), Vector3(0.16, 0.42, 0.16), body_color)
	box(root, Vector3(0.43, 0.86, -0.42), Vector3(0.16, 0.28, 0.16), body_color)

	match pattern:
		"tuxedo":
			box(root, Vector3(0, 0.78, 0.43), Vector3(0.30, 0.34, 0.035), accent_color)
			box(root, Vector3(0, 0.33, 0.30), Vector3(0.34, 0.36, 0.035), accent_color)
		"tabby":
			for y in [0.60, 0.76, 0.92]:
				box(root, Vector3(0, y, 0.435), Vector3(0.44, 0.045, 0.025), accent_color.darkened(0.12))
		"calico":
			box(root, Vector3(-0.17, 0.84, 0.43), Vector3(0.18, 0.20, 0.03), accent_color)
			box(root, Vector3(0.20, 0.46, 0.30), Vector3(0.24, 0.20, 0.03), Color("b96f52"))
		"point":
			box(root, Vector3(0, 0.80, 0.43), Vector3(0.44, 0.30, 0.03), accent_color.darkened(0.25))
			for x in [-0.24, 0.24]:
				box(root, Vector3(x, 0.06, 0.18), Vector3(0.18, 0.16, 0.26), accent_color.darkened(0.20))
		_:
			pass

	var mood: String = state.cat_mood()
	var satiety: int = int(state.data.get("cat_satiety", 0))
	floating_text(root, "%s  •  LV %d  •  %s" % [str(design.get("name", "CAT")), state.cat_level(), mood], Vector3(0, 1.45, 0), active_theme.text, 17)

func camp() -> void:
	camp_actor_roam_index = 0
	camp_actor_pause = 7.0
	camp_actor_moves_since_rest = 0
	camp_actor_heading_to_fire = false
	camp_actor_resting_by_fire = false
	camp_cat_root = null
	camp_cat_roam_index = 0
	camp_cat_pause = 0.45
	camp_cat_moves_since_rest = 0
	camp_cat_heading_to_fire = false
	camp_cat_resting_by_fire = false
	camp_roam_rng.seed = (
		int(state.data.get("seed", 1))
		+ int(state.data.get("wins", 0)) * 131
		+ int(state.data.get("camp_level", 0)) * 1009
		+ 90210
	)
	var tent = PrismMesh.new()
	tent.size = Vector3(2.8, 2.5, 3.0)
	var canvas = MeshInstance3D.new()
	canvas.mesh = tent
	canvas.material_override = material(active_theme.road_finish)
	canvas.position = Vector3(-3.8, 1.1, -5)
	scenery.add_child(canvas)
	box(scenery, Vector3(-3.8, 0.4, -3.49), Vector3(0.65, 1.0, 0.06), Color("344a42"))

	# The old crossroads location is now the camp's visual heart: a larger bonfire.
	var fire_z: float = -5.15
	for i in range(8):
		var angle: float = i * TAU / 8
		cone(scenery, Vector3(cos(angle) * 0.78, 0.15, fire_z + sin(angle) * 0.78), 0.24, 0.34, Color("7f857f"), 0.15)
	box(scenery, Vector3(-0.34, 0.24, fire_z), Vector3(1.15, 0.16, 0.22), Color("6f4a32"))
	box(scenery, Vector3(0.34, 0.24, fire_z), Vector3(1.15, 0.16, 0.22), Color("6f4a32"))
	cone(scenery, Vector3(0, 0.58, fire_z), 0.46, 1.28, Color("ffb65c"), 0.06)
	cone(scenery, Vector3(0, 0.82, fire_z), 0.26, 0.72, Color("ffe08a"), 0.03)

	# Side bench and seated cube share one facing direction toward the bonfire.
	var bench_root := Node3D.new()
	bench_root.position = Vector3(-3.15, 0.0, -3.05)
	scenery.add_child(bench_root)
	var bench_fire_target := Vector3(0.0, bench_root.global_position.y, fire_z)
	bench_root.look_at(bench_fire_target, Vector3.UP, true)
	box(bench_root, Vector3(0, 0.36, 0), Vector3(2.35, 0.22, 0.76), active_theme.post)
	# Local -Z is behind the seated character when local +Z faces the fire.
	box(bench_root, Vector3(0, 0.86, -0.34), Vector3(2.35, 0.82, 0.18), active_theme.post)
	for offset_x in [-0.85, 0.85]:
		box(bench_root, Vector3(offset_x, 0.16, 0), Vector3(0.18, 0.55, 0.18), active_theme.post)

	box(scenery, Vector3(3.8, 1.3, -7), Vector3(0.2, 2.8, 0.2), active_theme.post)
	box(scenery, Vector3(3.8, 2.7, -7), Vector3(0.7, 0.8, 0.7), active_theme.text, true)
	floating_text(scenery, "LANTERN CAMP", Vector3(0, 3.5, -8), active_theme.text, 48)

	# Camp presents the two persistent hub actions directly in the world:
	# continue the journey on the right, marketplace/companion care on the left.
	var continue_pos := Vector3(4.55, 1.95, -4.70)
	var continue_board := clickable_board(scenery, continue_pos, Vector3(3.05, 0.62, 0.24), Color("78906f"), "", false, false, true)
	continue_board.name = "CampContinueAdventure"
	floating_text(scenery, "CONTINUE ADVENTURE", continue_pos + Vector3(0, 0.03, 0.16), Color("fff0bd"), 20)

	var market_pos := Vector3(-4.55, 1.95, -4.70)
	var market_board := clickable_board(scenery, market_pos, Vector3(3.25, 0.62, 0.24), Color("8e7654"), "", true, false, false)
	market_board.name = "CampMarketplace"
	floating_text(scenery, "MARKETPLACE  •  CAT COMPANION", market_pos + Vector3(0, 0.03, 0.16), Color("fff0bd"), 18)

	# Small hanging lantern makes the market sign read as a camp service, while
	# staying within the lightweight visual budget.
	if not visuals.simple_mode:
		add_waypoint_lantern(scenery, market_pos + Vector3(1.25, -0.58, 0.08), 0.50)

	for i in range(int(state.data.camp_level)):
		box(scenery, Vector3(3.7 + i * 0.5, 0.3, -3), Vector3(0.38, 0.7, 0.38), Color("b2d58c"))
	build_cat_companion()

func pose_actor_at_camp() -> void:
	# Spawn on the ground beside the camp path, not on top of the bench. From
	# here the camp-only roaming loop takes over.
	reset_walk_pose()
	camp_actor_roam_index = 0
	camp_actor_pause = 7.0
	camp_actor_moves_since_rest = 0
	camp_actor_heading_to_fire = false
	camp_actor_resting_by_fire = false
	actor.position = camp_actor_roam_points[0]
	var next_target: Vector3 = camp_actor_roam_points[1]
	actor.look_at(Vector3(next_target.x, actor.position.y, next_target.z), Vector3.UP, true)
	idle_anchor_position = actor.position
	idle_base_yaw = actor.rotation.y

func waypoint_style_for(route_id: String) -> Dictionary:
	var style_data: Dictionary = Catalog.waypoint_style(route_id).duplicate(true)
	style_data["post_color"] = Color(str(style_data.get("post", "765f49")))
	style_data["trim_color"] = Color(str(style_data.get("trim", "879574")))
	style_data["accent_color"] = Color(str(style_data.get("accent", "eee1b8")))
	return style_data

func add_waypoint_motif(parent: Node3D, route_id: String, pos: Vector3, style_data: Dictionary) -> void:
	var accent: Color = style_data.accent_color
	var trim: Color = style_data.trim_color
	match str(style_data.get("motif", "")):
		"ember":
			cone(parent, pos + Vector3(0, 0.10, 0), 0.18, 0.42, accent, 0.03)
			box(parent, pos + Vector3(0, 0.34, 0), Vector3(0.16, 0.16, 0.16), accent, true)
		"moon":
			sphere(parent, pos + Vector3(0, 0.25, 0), 0.36, accent, true)
		"lantern":
			box(parent, pos + Vector3(0, 0.24, 0), Vector3(0.26, 0.34, 0.26), accent, true)
			box(parent, pos + Vector3(0, 0.46, 0), Vector3(0.18, 0.08, 0.18), trim)
		"frost":
			cone(parent, pos + Vector3(0, 0.20, 0), 0.24, 0.38, accent, 0.04)
			cone(parent, pos + Vector3(0, 0.40, 0), 0.14, 0.28, accent.lightened(0.10), 0.02)
		"reed":
			for x in [-0.16, 0.0, 0.16]:
				cone(parent, pos + Vector3(x, 0.18 + absf(x), 0), 0.05, 0.46 - absf(x), trim, 0.02)
		"root":
			for x in [-0.14, 0.14]:
				cone(parent, pos + Vector3(x, 0.14, 0), 0.07, 0.38, trim.darkened(0.10), 0.02)
		"crystal":
			cone(parent, pos + Vector3(-0.09, 0.18, 0), 0.10, 0.40, accent, 0.02)
			cone(parent, pos + Vector3(0.10, 0.13, 0), 0.08, 0.30, trim, 0.01)
		"spire":
			cone(parent, pos + Vector3(0, 0.20, 0), 0.12, 0.48, accent, 0.02)
			box(parent, pos + Vector3(0, 0.02, 0), Vector3(0.30, 0.08, 0.30), trim)
		_:
			cone(parent, pos + Vector3(-0.09, 0.18, 0), 0.10, 0.34, trim, 0.03)
			cone(parent, pos + Vector3(0.10, 0.14, 0), 0.09, 0.28, accent, 0.03)

func add_waypoint_lantern(parent: Node3D, pos: Vector3, scale: float = 1.0) -> void:
	var metal := Color("3f4448")
	var warm := Color("ffd36e")
	box(parent, pos + Vector3(0, 0.20 * scale, 0), Vector3(0.34, 0.08, 0.34) * scale, metal)
	box(parent, pos + Vector3(0, -0.20 * scale, 0), Vector3(0.34, 0.08, 0.34) * scale, metal)
	box(parent, pos, Vector3(0.24, 0.38, 0.24) * scale, warm, true)
	for x in [-0.15, 0.15]:
		box(parent, pos + Vector3(x * scale, 0, 0), Vector3(0.035, 0.42, 0.035) * scale, metal)
	box(parent, pos + Vector3(0, 0, 0.15 * scale), Vector3(0.32, 0.035, 0.035) * scale, metal)
	box(parent, pos + Vector3(0, 0.34 * scale, 0), Vector3(0.12, 0.18, 0.12) * scale, metal)

func add_rope_wrap(parent: Node3D, pos: Vector3, width: float, scale: float = 1.0) -> void:
	var rope := Color("b79a69")
	for offset_y in [-0.08, 0.0, 0.08]:
		box(parent, pos + Vector3(0, offset_y * scale, 0.19 * scale), Vector3(width, 0.045, 0.06) * scale, rope)

func add_waypoint_banner(parent: Node3D, pos: Vector3, style_data: Dictionary, scale: float = 1.0) -> void:
	var fabric: Color = style_data.trim_color.darkened(0.34)
	var accent: Color = style_data.accent_color
	box(parent, pos, Vector3(0.68, 0.92, 0.055) * scale, fabric)
	cone(parent, pos + Vector3(0, -0.55 * scale, 0), 0.34 * scale, 0.36 * scale, fabric, 0.02 * scale)
	box(parent, pos + Vector3(0, 0.34 * scale, 0.035 * scale), Vector3(0.52, 0.06, 0.045) * scale, accent)
	# Tiny geometric crest echoes the route-specific waypoint motif without
	# requiring an external texture.
	cone(parent, pos + Vector3(0, 0.08 * scale, 0.06 * scale), 0.13 * scale, 0.28 * scale, accent, 0.02 * scale)
	box(parent, pos + Vector3(0, -0.14 * scale, 0.06 * scale), Vector3(0.24, 0.055, 0.055) * scale, accent)

func add_waypoint_post(
	parent: Node3D,
	base_pos: Vector3,
	style_data: Dictionary,
	lantern_side: int = 0,
	scale: float = 1.0,
	with_banner: bool = false
) -> void:
	var wood: Color = style_data.post_color
	var trim: Color = style_data.trim_color
	var accent: Color = style_data.accent_color
	var stone: Color = Color(active_theme.shoulder).darkened(0.16)
	var metal := Color("46494d")

	# Stone footing + chunky timber shaft.
	box(parent, base_pos + Vector3(0, 0.18 * scale, 0), Vector3(0.92, 0.36, 0.80) * scale, stone)
	box(parent, base_pos + Vector3(0, 0.47 * scale, 0), Vector3(0.68, 0.24, 0.62) * scale, stone.lightened(0.06))
	box(parent, base_pos + Vector3(0, 1.42 * scale, 0), Vector3(0.50, 1.85, 0.50) * scale, wood)
	box(parent, base_pos + Vector3(0, 2.38 * scale, 0), Vector3(0.66, 0.18, 0.62) * scale, wood.lightened(0.08))
	cone(parent, base_pos + Vector3(0, 2.62 * scale, 0), 0.38 * scale, 0.34 * scale, accent.darkened(0.06), 0.08 * scale)

	# Web/light mode keeps one crest and skips rope micro-geometry.
	box(parent, base_pos + Vector3(0, 1.92 * scale, 0.29 * scale), Vector3(0.46, 0.46, 0.07) * scale, metal)
	var crest = box(parent, base_pos + Vector3(0, 1.92 * scale, 0.335 * scale), Vector3(0.18, 0.18, 0.035) * scale, accent)
	crest.rotation_degrees.z = 45.0
	if not visuals.simple_mode:
		add_rope_wrap(parent, base_pos + Vector3(0, 0.83 * scale, 0), 0.60, scale)

	if lantern_side != 0 and not visuals.simple_mode:
		var direction: float = float(lantern_side)
		box(parent, base_pos + Vector3(direction * 0.55 * scale, 2.18 * scale, 0), Vector3(0.95, 0.12, 0.14) * scale, wood.darkened(0.05))
		box(parent, base_pos + Vector3(direction * 0.95 * scale, 1.98 * scale, 0), Vector3(0.06, 0.42, 0.06) * scale, metal)
		add_waypoint_lantern(parent, base_pos + Vector3(direction * 0.95 * scale, 1.58 * scale, 0.02), 0.72 * scale)

	if with_banner and not visuals.simple_mode:
		var banner_side: float = -float(lantern_side) if lantern_side != 0 else 1.0
		add_waypoint_banner(parent, base_pos + Vector3(banner_side * 0.72 * scale, 1.45 * scale, 0.28 * scale), style_data, 0.72 * scale)

func roadside_waymarker(
	parent: Node3D,
	base_pos: Vector3,
	style_data: Dictionary,
	side: int,
	with_lantern: bool = false
) -> void:
	# Lightweight roadside variant keeps the recurring trail rhythm readable on
	# web builds while sharing the same stone/wood/metal language as the hub.
	var wood: Color = style_data.post_color
	var trim: Color = style_data.trim_color
	var accent: Color = style_data.accent_color
	var stone: Color = Color(active_theme.shoulder).darkened(0.14)
	var metal := Color("45494c")
	box(parent, base_pos + Vector3(0, 0.12, 0), Vector3(0.52, 0.24, 0.48), stone)
	box(parent, base_pos + Vector3(0, 0.72, 0), Vector3(0.24, 1.05, 0.24), wood)
	box(parent, base_pos + Vector3(0, 1.30, 0), Vector3(0.38, 0.12, 0.34), trim)
	var badge = box(parent, base_pos + Vector3(0, 0.94, 0.145), Vector3(0.13, 0.13, 0.025), accent, true)
	badge.rotation_degrees.z = 45.0
	if with_lantern:
		var inward: float = -float(side)
		box(parent, base_pos + Vector3(inward * 0.36, 1.18, 0), Vector3(0.62, 0.08, 0.10), wood)
		add_waypoint_lantern(parent, base_pos + Vector3(inward * 0.62, 0.80, 0), 0.42)

func add_gateway_brace(parent: Node3D, pos: Vector3, side: int, wood: Color) -> void:
	var brace = box(parent, pos, Vector3(0.18, 1.22, 0.22), wood.darkened(0.05))
	brace.rotation_degrees.z = 34.0 * float(side)

func add_gateway_title_board(
	parent: Node3D,
	pos: Vector3,
	style_data: Dictionary,
	location_name: String
) -> void:
	var wood: Color = style_data.post_color.darkened(0.10)
	var trim: Color = style_data.trim_color
	var accent: Color = style_data.accent_color
	box(parent, pos, Vector3(3.15, 0.76, 0.24), wood)
	box(parent, pos + Vector3(0, 0.32, 0.05), Vector3(2.72, 0.08, 0.08), trim)
	if not visuals.simple_mode:
		box(parent, pos + Vector3(0, -0.32, 0.05), Vector3(2.72, 0.08, 0.08), trim.darkened(0.08))
		for x in [-1.48, 1.48]:
			box(parent, pos + Vector3(x, 0, 0.02), Vector3(0.18, 0.58, 0.28), wood.lightened(0.06))
	floating_text(parent, "WAYPOINT", pos + Vector3(0, 0.02, 0.16), Color("fff0c7"), 31)
	if not visuals.simple_mode:
		floating_text(parent, location_name, pos + Vector3(0, -0.48, 0.14), accent, 14)

func waypoint_destination_board(
	parent: Node3D,
	pos: Vector3,
	size: Vector3,
	route_id: String,
	label_text: String,
	primary_color: Color,
	accent: Color,
	camp_return: bool = false
) -> void:
	# Click target remains the full board, while layered trim gives the simple
	# procedural geometry the carved-sign silhouette from the RPG concept.
	clickable_board(parent, pos, size, primary_color.darkened(0.08), route_id, false, camp_return)
	box(parent, pos + Vector3(0, 0, 0.055), Vector3(size.x * 0.92, size.y * 0.76, 0.075), primary_color)
	box(parent, pos + Vector3(0, size.y * 0.42, 0.075), Vector3(size.x * 0.90, 0.07, 0.08), accent)
	box(parent, pos + Vector3(0, -size.y * 0.42, 0.075), Vector3(size.x * 0.90, 0.07, 0.08), accent.darkened(0.14))
	if not visuals.simple_mode:
		for x in [-size.x * 0.44, size.x * 0.44]:
			var rivet = box(parent, pos + Vector3(x, 0, 0.12), Vector3(0.09, 0.09, 0.04), accent)
			rivet.rotation_degrees.z = 45.0
	floating_text(parent, label_text, pos + Vector3(0, 0.03, 0.18), Color("fff4d2"), 19)

func road_end_waypoint(finish_z: float) -> void:
	# Hero checkpoint inspired by classic RPG hubs: stone-footed timber gateway,
	# crest plates, rope/metal trim, hanging lanterns, banners, and carved route
	# boards. Geometry stays procedural so every biome inherits the same visual
	# language while keeping its own route palette.
	var current_route_id: String = str(state.data.get("route", "moss"))
	var current_route: Dictionary = Catalog.ROUTES.get(current_route_id, Catalog.ROUTES["moss"])
	var style_data: Dictionary = waypoint_style_for(current_route_id)
	var post_color: Color = style_data.post_color
	var trim_color: Color = style_data.trim_color
	var accent_color: Color = style_data.accent_color
	var z: float = finish_z + 0.05

	add_waypoint_post(scenery, Vector3(-2.48, 0, z), style_data, 1, 1.02, true)
	add_waypoint_post(scenery, Vector3(2.48, 0, z), style_data, -1, 1.02, true)

	# Heavy crossbeam and diagonal braces create a recognizable silhouette.
	box(scenery, Vector3(0, 3.18, z), Vector3(5.55, 0.38, 0.46), post_color)
	box(scenery, Vector3(0, 3.39, z + 0.02), Vector3(5.12, 0.09, 0.18), trim_color)
	if not visuals.simple_mode:
		for x in [-1.82, 1.82]:
			box(scenery, Vector3(x, 3.18, z + 0.24), Vector3(0.16, 0.54, 0.08), Color("45484b"))
		add_gateway_brace(scenery, Vector3(-1.95, 2.72, z), -1, post_color)
		add_gateway_brace(scenery, Vector3(1.95, 2.72, z), 1, post_color)

	add_gateway_title_board(
		scenery,
		Vector3(0, 2.86, z + 0.18),
		style_data,
		str(style_data.get("label", str(current_route.name).to_upper()))
	)

	# Central crest and two warm lanterns make the checkpoint readable at a
	# glance even before the text becomes legible.
	var crest_back = box(scenery, Vector3(0, 3.72, z + 0.06), Vector3(0.92, 0.62, 0.22), trim_color.darkened(0.28))
	crest_back.rotation_degrees.z = 0.0
	add_waypoint_motif(scenery, current_route_id, Vector3(0, 3.55, z + 0.22), style_data)
	if not visuals.simple_mode:
		add_waypoint_lantern(scenery, Vector3(-1.42, 2.70, z + 0.24), 0.74)
		add_waypoint_lantern(scenery, Vector3(1.42, 2.70, z + 0.24), 0.74)

	floating_text(
		scenery,
		"ROAD COMPLETE  •  CHOOSE YOUR NEXT ROAD OR CAMP",
		Vector3(0, 4.18, z + 0.10),
		accent_color,
		16
	)

	var options: Array = route_options_for_stage()
	var board_layout: Array = [
		{"pos":Vector3(-0.92, 2.02, z + 0.24), "size":Vector3(3.28, 0.54, 0.25)},
		{"pos":Vector3(0.92, 1.39, z + 0.24), "size":Vector3(3.28, 0.54, 0.25)},
		{"pos":Vector3(-0.92, 0.76, z + 0.24), "size":Vector3(3.28, 0.54, 0.25)}
	]
	for i in range(mini(options.size(), board_layout.size())):
		var route_id: String = str(options[i])
		var route: Dictionary = Catalog.ROUTES[route_id]
		var board: Dictionary = board_layout[i]
		var route_color: Color = Color(str(route.get("color", "c59b61")))
		waypoint_destination_board(
			scenery,
			board.pos,
			board.size,
			route_id,
			"→  %s  •  %s" % [str(route.name).to_upper(), str(route.get("difficulty_label", "ROAD"))],
			route_color.darkened(0.20),
			route_color.lightened(0.16)
		)

	var camp_pos := Vector3(0.92, 0.18, z + 0.26)
	waypoint_destination_board(
		scenery,
		camp_pos,
		Vector3(3.18, 0.52, 0.25),
		"",
		"↩  LANTERN CAMP  •  REST / SUPPLIES",
		Color("52685f"),
		Color("c6d8b4"),
		true
	)

	# Small stones/moss around the feet visually anchor the gateway instead of
	# leaving it floating on top of the road tiles.
	for side in [-1, 1]:
		var sx: float = float(side) * 3.00
		box(scenery, Vector3(sx, 0.16, z + 0.38), Vector3(0.56, 0.32, 0.48), active_theme.shoulder.darkened(0.08))
		cone(scenery, Vector3(sx + float(side) * 0.34, 0.16, z + 0.44), 0.18, 0.32, active_theme.shrub, 0.04)

	for x in [-2.25, 0.0, 2.25]:
		box(scenery, Vector3(x, 0.08, z + 1.38), Vector3(1.55, 0.12, 1.55), active_theme.shoulder)
	box(scenery, Vector3(0, 0.10, z + 0.72), Vector3(5.40, 0.08, 0.20), trim_color.darkened(0.12))

func crossroads(finish_z: float) -> void:
	# Smaller route-selection counterpart to the road-end gateway. It reuses the
	# same timber/stone/lantern language so players recognize navigation props
	# everywhere in the world.
	var current_route_id: String = str(state.data.get("route", "moss"))
	var style_data: Dictionary = waypoint_style_for(current_route_id)
	var post_color: Color = style_data.post_color
	var trim_color: Color = style_data.trim_color
	var z: float = finish_z + 0.04

	add_waypoint_post(scenery, Vector3(-2.12, 0, z), style_data, 1, 0.78, false)
	add_waypoint_post(scenery, Vector3(2.12, 0, z), style_data, -1, 0.78, false)
	box(scenery, Vector3(0, 2.43, z), Vector3(4.55, 0.30, 0.34), post_color)
	box(scenery, Vector3(0, 2.60, z + 0.02), Vector3(4.15, 0.08, 0.14), trim_color)
	add_waypoint_lantern(scenery, Vector3(-1.45, 2.10, z + 0.18), 0.55)
	add_waypoint_lantern(scenery, Vector3(1.45, 2.10, z + 0.18), 0.55)

	var options: Array = route_options_for_stage()
	var board_layout: Array = [
		{"pos":Vector3(-0.90, 1.82, z + 0.18), "size":Vector3(3.02, 0.50, 0.23)},
		{"pos":Vector3(0.90, 1.22, z + 0.18), "size":Vector3(3.02, 0.50, 0.23)},
		{"pos":Vector3(-0.90, 0.62, z + 0.18), "size":Vector3(3.02, 0.50, 0.23)}
	]
	for i in range(mini(options.size(), board_layout.size())):
		var route_id: String = str(options[i])
		var route: Dictionary = Catalog.ROUTES[route_id]
		var board: Dictionary = board_layout[i]
		var route_color: Color = Color(str(route.get("color", "c59b61")))
		waypoint_destination_board(
			scenery,
			board.pos,
			board.size,
			route_id,
			"→  %s  •  %s" % [str(route.name).to_upper(), str(route.get("difficulty_label", "ROAD"))],
			route_color.darkened(0.20),
			route_color.lightened(0.14)
		)

	floating_text(scenery, "CROSSROADS  •  CHOOSE YOUR NEXT ROAD", Vector3(0, 3.02, z + 0.10), active_theme.text, 19)
	for x in [-2.2, 0.0, 2.2]:
		box(scenery, Vector3(x, 0.08, z + 1.35), Vector3(1.6, 0.12, 1.6), active_theme.shoulder)

func guardian() -> void:
	var root = Node3D.new()
	root.position = Vector3(0, 0.1, -7)
	scenery.add_child(root)
	box(root, Vector3(0, 1.4, 0), Vector3(2.7, 2.8, 1.8), Color("857957"))
	box(root, Vector3(0, 2.7, 0), Vector3(3.0, 0.6, 2.0), Color("73996c"))
	for side in [-1, 1]:
		box(root, Vector3(side * 1.8, 0.8, 0), Vector3(0.75, 1.5, 0.9), Color("998460"))
		box(root, Vector3(side * 0.6, 1.7, 0.93), Vector3(0.28, 0.25, 0.08), Color("f3d881"), true)
		cone(root, Vector3(side * 0.85, 3.3, 0), 0.45, 1.4, Color("578764"))
	box(root, Vector3(0, 1.0, 0.95), Vector3(0.7, 0.15, 0.1), Color("354b3d"))
	floating_text(scenery, "THE HEARTWOOD KEEPER", Vector3(0, 4.5, -7), active_theme.text, 40)

func floating_text(parent: Node3D, text: String, pos: Vector3, color: Color, size: int = 32) -> void:
	visuals.text(parent, text, pos, color, size)

func enemy_colors(kind: String, active: bool) -> Color:
	if active:
		return Color("e48d69")
	match kind:
		"goblin":
			return Color("76b15f")
		"kobold":
			return Color("c78a67")
		"ogre":
			return Color("98a36a")
		_:
			return Color("84ccbd")

func build_enemy_loadout(parent: Node3D, pos: Vector3, kind: String, size: Vector3, cell: Dictionary, active: bool, elite: bool) -> Dictionary:
	var variant: Dictionary = state.enemy_visual_variant(kind, int(cell.row), int(cell.lane), elite)
	var body_color := Color(str(variant.get("body", "84ccbd")))
	if active:
		body_color = body_color.darkened(0.08)
	var armor_color := Color(str(variant.get("armor", "66706c")))
	var helmet_color := Color(str(variant.get("helmet", "545b60")))
	var weapon_color := Color(str(variant.get("weapon", "8b7658")))
	var rank_trim := Color(str(variant.get("rank_trim", "8aa49a")))
	var rank: int = int(variant.get("rank", 1))

	box(parent, pos + Vector3(0, size.y / 2, 0), size, body_color)
	if not visuals.simple_mode:
		for x in [-0.22, 0.22]:
			box(parent, pos + Vector3(x, min(0.72, size.y * 0.62), size.z / 2 + 0.02), Vector3(0.09, 0.1, 0.03), Color("233e3d"))

	# Armor silhouette scales by rank: common foes receive a chest piece,
	# veteran/champion variants add shoulder plating and brighter trim.
	var chest_y: float = maxf(0.36, size.y * 0.48)
	box(parent, pos + Vector3(0, chest_y, size.z * 0.43), Vector3(size.x * 0.72, size.y * 0.34, 0.10), armor_color)
	box(parent, pos + Vector3(0, chest_y + size.y * 0.12, size.z * 0.49), Vector3(size.x * 0.58, 0.06, 0.05), rank_trim, rank >= 3)
	if rank >= (3 if visuals.simple_mode else 2):
		for shoulder_x in [-size.x * 0.46, size.x * 0.46]:
			box(parent, pos + Vector3(shoulder_x, chest_y + 0.12, 0), Vector3(size.x * 0.20, 0.18, size.z * 0.72), armor_color.darkened(0.05))

	# Every enemy type now has a helmet/cap identity.
	match kind:
		"slime":
			cone(parent, pos + Vector3(0, size.y + 0.15, 0), size.x * 0.34, 0.28, helmet_color, 0.06)
		"goblin":
			box(parent, pos + Vector3(0, size.y + 0.12, 0), Vector3(size.x * 0.60, 0.22, size.z * 0.64), helmet_color)
			for ear_x in [-size.x * 0.42, size.x * 0.42]:
				cone(parent, pos + Vector3(ear_x, size.y + 0.06, 0), 0.11, 0.26, body_color.darkened(0.12), 0.02)
		"kobold":
			box(parent, pos + Vector3(0, size.y + 0.08, 0), Vector3(size.x * 0.60, 0.20, size.z * 0.62), helmet_color)
			for horn_x in [-0.24, 0.24]:
				cone(parent, pos + Vector3(horn_x, size.y + 0.27, 0), 0.08, 0.30, rank_trim, 0.01)
		"ogre":
			box(parent, pos + Vector3(0, size.y + 0.14, 0), Vector3(size.x * 0.62, 0.30, size.z * 0.70), helmet_color)
			box(parent, pos + Vector3(0, size.y + 0.04, size.z * 0.39), Vector3(size.x * 0.42, 0.12, 0.08), rank_trim)
		_:
			pass

	# Weapon silhouettes are distinct at a glance.
	match kind:
		"slime":
			var spike = cone(parent, pos + Vector3(size.x * 0.58, 0.45, 0), 0.09, 0.62, weapon_color, 0.015)
			spike.rotation_degrees.z = -26
		"goblin":
			var sword = box(parent, pos + Vector3(size.x * 0.72, 0.60, 0), Vector3(0.10, 0.86, 0.10), weapon_color)
			sword.rotation_degrees.z = -18
			box(parent, pos + Vector3(size.x * 0.66, 0.34, 0), Vector3(0.34, 0.08, 0.12), rank_trim)
		"kobold":
			var spear = box(parent, pos + Vector3(size.x * 0.72, 0.70, 0), Vector3(0.08, 1.42, 0.08), weapon_color)
			spear.rotation_degrees.z = -12
			cone(parent, pos + Vector3(size.x * 0.86, 1.30, 0), 0.10, 0.32, rank_trim, 0.01)
		"ogre":
			box(parent, pos + Vector3(size.x * 0.72, 0.76, 0), Vector3(0.14, 1.30, 0.14), weapon_color)
			box(parent, pos + Vector3(size.x * 0.72, 1.32, 0), Vector3(0.56, 0.34, 0.42), armor_color.lightened(0.05))
		_:
			pass

	if elite:
		box(parent, pos + Vector3(0, size.y + 0.40, 0), Vector3(0.68, 0.12, 0.56), rank_trim, true)
		for crown_x in [-0.24, 0.0, 0.24]:
			cone(parent, pos + Vector3(crown_x, size.y + 0.58, 0), 0.08, 0.24, rank_trim.lightened(0.12), 0.01)

	return {"color":body_color, "rank_name":str(variant.get("rank_name", "COMMON")), "rank_trim":rank_trim}

func update_camera() -> void:
	if showcase:
		camera.position = Vector3(0, 1.9, 4.4)
		camera.look_at(Vector3(0, 0.85, 0))
		return
	camera.position = camera_target + Vector3(0, 4.35, 7.5)
	camera.look_at(camera_target + Vector3(0, 0.72, -4.6))

func refresh_props() -> void:
	for child in props.get_children():
		props.remove_child(child)
		child.queue_free()
	if entrance:
		return
	if state.data.mode == "boss":
		for lane in range(-1, 2):
			var color = Color("899e8f")
			var word: String = "SAFE"
			if lane == int(state.data.danger):
				color = Color("ee9064")
				word = "! SLAM"
			elif lane == int(state.data.target):
				color = Color("85e5c5")
				word = "+ STRIKE"
			box(props, Vector3(lane * LANE_SPACING, 0.16, 0), Vector3(2.55, 0.04, 2.34), color, true)
			floating_text(props, word, Vector3(lane * LANE_SPACING, 0.3, 1.08), color, 30)
		return
	if state.data.mode not in ["travel", "campfire", "fishing"]:
		return
	var current_row: int = int(state.data.row)
	for cell in state.data.cells:
		var cell_row: int = int(cell.row)
		var keep_current_special: bool = bool(cell.cleared) and cell_row == current_row and str(cell.kind) in ["campfire", "fishing"]
		if (bool(cell.cleared) and not keep_current_special) or cell_row < current_row or cell_row > current_row + VISIBLE_ROWS_AHEAD:
			continue
		var pos = Vector3(int(cell.lane) * LANE_SPACING, 0.2, -cell_row * ROW_SPACING)
		match str(cell.kind):
			"coin":
				var coin = box(props, pos + Vector3(0, 0.5, 0), Vector3(0.32, 0.5, 0.16), Color("d8bb69"), true)
				coin.rotation_degrees.y = 25
			"gem":
				cone(props, pos + Vector3(0, 0.48, 0), 0.24, 0.72, Color("78b7b2"), 0.04)
				cone(props, pos + Vector3(0, 0.88, 0), 0.15, 0.38, Color("a3d2ca"), 0.0)
				floating_text(props, "GEM", pos + Vector3(0, 1.35, 0), Color("a8d9ce"), 24)
			"campfire":
				for angle_i in range(8):
					var a: float = float(angle_i) * TAU / 8.0
					cone(props, pos + Vector3(cos(a) * 0.58, 0.11, sin(a) * 0.58), 0.16, 0.22, Color("73716b"), 0.10)
				var log_a = box(props, pos + Vector3(0, 0.20, 0), Vector3(1.00, 0.16, 0.20), Color("765b45"))
				log_a.rotation_degrees.y = 28
				var log_b = box(props, pos + Vector3(0, 0.20, 0), Vector3(1.00, 0.16, 0.20), Color("684f40"))
				log_b.rotation_degrees.y = -28
				cone(props, pos + Vector3(0, 0.54, 0), 0.30, 0.78, Color("d98d52"), 0.06)
				cone(props, pos + Vector3(0, 0.66, 0), 0.18, 0.54, Color("e8b567"), 0.02)
				floating_text(props, "REST", pos + Vector3(0, 1.48, 0), Color("dfc28b"), 24)
			"fishing":
				box(props, pos + Vector3(0, 0.05, 0), Vector3(2.20, 0.08, 1.72), Color("456f78"), true)
				box(props, pos + Vector3(0, 0.11, 0), Vector3(1.64, 0.03, 1.14), Color("5c8b90"), true)
				box(props, pos + Vector3(0.84, 0.66, 0.22), Vector3(0.08, 1.12, 0.08), Color("806548"))
				box(props, pos + Vector3(0.52, 1.14, 0.22), Vector3(0.72, 0.06, 0.06), Color("806548"))
				floating_text(props, "FISH", pos + Vector3(0, 1.25, 0), Color("a7d2cf"), 24)
			"gear_cache":
				box(props, pos + Vector3(0, 0.34, 0), Vector3(0.92, 0.54, 0.72), Color("796044"))
				box(props, pos + Vector3(0, 0.66, 0), Vector3(0.98, 0.18, 0.76), Color("9a7a51"))
				box(props, pos + Vector3(0, 0.54, 0.38), Vector3(0.18, 0.24, 0.06), Color("d0b267"), true)
				floating_text(props, "GEAR?", pos + Vector3(0, 1.18, 0), Color("d7bf80"), 24)
			"gloomcap":
				cone(props, pos + Vector3(0, 0.24, 0), 0.12, 0.46, Color("667a69"), 0.07)
				cone(props, pos + Vector3(0, 0.55, 0), 0.42, 0.26, Color("8f7aaa"), 0.08)
				floating_text(props, "GLOOMCAP", pos + Vector3(0, 1.20, 0), Color("d8c6e8"), 23)
			"prismatic_pearl":
				sphere(props, pos + Vector3(0, 0.42, 0), 0.56, Color("9ce1d8"), true)
				floating_text(props, "PRISMATIC PEARL", pos + Vector3(0, 1.12, 0), Color("c9f4ed"), 20)
			"ember_shard":
				cone(props, pos + Vector3(0, 0.40, 0), 0.28, 0.82, Color("dd7651"), 0.03)
				cone(props, pos + Vector3(0, 0.80, 0), 0.14, 0.38, Color("ffb36d"), 0.01)
				floating_text(props, "EMBER SHARD", pos + Vector3(0, 1.32, 0), Color("ffc18b"), 21)
			"skyfeather":
				var feather = box(props, pos + Vector3(0, 0.52, 0), Vector3(0.16, 0.92, 0.10), Color("cbe3ec"), true)
				feather.rotation_degrees.z = 24
				box(props, pos + Vector3(0.16, 0.58, 0), Vector3(0.34, 0.12, 0.08), Color("91b8c9"), true)
				floating_text(props, "SKYFEATHER", pos + Vector3(0, 1.32, 0), Color("d9eef5"), 21)
			"heal":
				box(props, pos + Vector3(0, 0.35, 0), Vector3(0.2, 0.6, 0.2), Color("a7eac2"), true)
				box(props, pos + Vector3(0, 0.35, 0), Vector3(0.6, 0.2, 0.2), Color("a7eac2"), true)
			"spike":
				match str(state.data.route):
					"gloomwood":
						for x in [-0.52, -0.16, 0.20, 0.54]:
							cone(props, pos + Vector3(x, 0.28, 0), 0.18, 0.70, Color("78657c"), 0.03)
						floating_text(props, "JUMP  •  BRIARS", pos + Vector3(0, 1.05, 0), Color("d9c58e"), 22)
					"sunken_grotto":
						box(props, pos + Vector3(0, 0.08, 0), Vector3(2.15, 0.10, 1.30), Color("497a76"), true)
						for x in [-0.48, 0.0, 0.48]:
							cone(props, pos + Vector3(x, 0.22, 0), 0.16, 0.45, Color("68a78f"), 0.08)
						floating_text(props, "JUMP  •  SLICK ALGAE", pos + Vector3(0, 1.0, 0), Color("bfe8d9"), 20)
					"cinder_caldera":
						for x in [-0.50, 0.0, 0.50]:
							cone(props, pos + Vector3(x, 0.30, 0), 0.24, 0.70, Color("d45c3e"), 0.04)
						box(props, pos + Vector3(0, 0.04, 0), Vector3(2.0, 0.06, 0.85), Color("9f3f31"), true)
						floating_text(props, "JUMP  •  MAGMA VENT", pos + Vector3(0, 1.10, 0), Color("ffc087"), 20)
					"galecrest_spire":
						for x in [-0.58, -0.18, 0.22, 0.60]:
							var gust = box(props, pos + Vector3(x, 0.48, 0), Vector3(0.08, 0.88, 1.10), Color("b9d7e4"), true)
							gust.rotation_degrees.z = 18
						floating_text(props, "JUMP  •  GALE GUST", pos + Vector3(0, 1.18, 0), Color("e0f1f6"), 20)
					_:
						for x in [-0.48, 0.0, 0.48]:
							cone(props, pos + Vector3(x, 0.25, 0), 0.23, 0.6, Color("d69d86"))
						floating_text(props, "JUMP", pos + Vector3(0, 1.0, 0), Color("efd094"), 25)
			"slime", "goblin", "kobold", "ogre":
				var active: bool = state.enemy_active(cell)
				var elite: bool = state.enemy_elite(cell)
				var kind: String = str(cell.kind)
				var size = Vector3(1.0, 0.65, 0.8)
				match kind:
					"goblin":
						size = Vector3(0.92, 1.02, 0.82)
					"kobold":
						size = Vector3(0.96, 0.86, 1.05)
					"ogre":
						size = Vector3(1.38, 1.28, 1.08)
				var loadout: Dictionary = build_enemy_loadout(props, pos, kind, size, cell, active, elite)
				var telegraph: String = "!" if active else "STOMP"
				if elite:
					var behavior: Dictionary = state.elite_behavior(kind)
					telegraph = "%s  •  %s ELITE" % [str(behavior.get("telegraph", "ELITE")), str(loadout.get("rank_name", "CHAMPION"))]
				else:
					telegraph = "%s  •  %s" % [telegraph, str(loadout.get("rank_name", "COMMON"))]
				var telegraph_color: Color = Color("efd887") if elite else loadout.get("rank_trim", Color("8aa49a"))
				floating_text(
					props,
					telegraph,
					pos + Vector3(0, size.y + (1.02 if elite else 0.74), 0),
					telegraph_color,
					25
				)
	if current_row < State.STAGE_STEPS:
		for lane in range(-1, 2):
			if absi(lane - int(state.data.lane)) <= 1:
				box(props, Vector3(lane * LANE_SPACING, 0.15, -(current_row + 1) * ROW_SPACING + 1.12), Vector3(2.45, 0.04, 0.07), Color("ecdfb7"), true)

func reset_walk_pose() -> void:
	actor.scale = Vector3.ONE
	actor.rotation.x = 0.0
	actor.rotation.z = 0.0
	if is_instance_valid(left_foot):
		left_foot.position = ACTOR_LEFT_FOOT_NEUTRAL
		left_foot.rotation = Vector3.ZERO
	if is_instance_valid(right_foot):
		right_foot.position = ACTOR_RIGHT_FOOT_NEUTRAL
		right_foot.rotation = Vector3.ZERO
	if is_instance_valid(left_arm):
		left_arm.position = Vector3(-0.55, 0.20, 0)
		left_arm.rotation = Vector3.ZERO
	if is_instance_valid(right_arm):
		right_arm.position = Vector3(0.55, 0.20, 0)
		right_arm.rotation = Vector3.ZERO

func walk_to(pos: Vector3) -> void:
	hopping = true
	actor.position = idle_anchor_position
	reset_walk_pose()
	actor.rotation.y = PI
	var start: Vector3 = actor.position
	var travel: Vector3 = pos - start
	var duration: float = 0.44
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var gait: float = sin(t * TAU * 2.0)
		actor.position = start.lerp(pos, t) + Vector3(0, absf(gait) * 0.075, 0)
		actor.rotation.y = PI + clampf(travel.x * 0.05, -0.12, 0.12)
		actor.rotation.z = -gait * 0.025
		var left_lift: float = maxf(0.0, gait) * 0.045
		var right_lift: float = maxf(0.0, -gait) * 0.045
		if is_instance_valid(left_foot):
			left_foot.rotation = Vector3.ZERO
			left_foot.position = ACTOR_LEFT_FOOT_NEUTRAL + Vector3(0, left_lift, 0)
		if is_instance_valid(right_foot):
			right_foot.rotation = Vector3.ZERO
			right_foot.position = ACTOR_RIGHT_FOOT_NEUTRAL + Vector3(0, right_lift, 0)
		if is_instance_valid(left_arm):
			left_arm.rotation.x = -gait * 0.42
		if is_instance_valid(right_arm):
			right_arm.rotation.x = gait * 0.42
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	actor.position = pos
	actor.rotation = Vector3(0, PI, 0)
	actor.scale = Vector3.ONE
	reset_walk_pose()
	idle_anchor_position = pos
	idle_base_yaw = PI
	hopping = false

func jump_to(pos: Vector3) -> void:
	hopping = true
	actor.position = idle_anchor_position
	reset_walk_pose()
	actor.rotation.y = PI
	var start: Vector3 = actor.position
	var row_distance: float = maxf(1.0, absf(pos.z - start.z) / ROW_SPACING)
	var arc_height: float = 1.35 + maxf(0.0, row_distance - 1.0) * 0.65
	var duration: float = 0.34 + maxf(0.0, row_distance - 1.0) * 0.14
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var arc: float = sin(t * PI)
		actor.position = start.lerp(pos, t) + Vector3(0, arc * arc_height, 0)
		actor.rotation.z = -arc * (pos.x - start.x) * 0.08
		actor.scale = Vector3(1.0 - arc * 0.10, 1.0 + arc * 0.18, 1.0 - arc * 0.10)
		if is_instance_valid(left_arm):
			left_arm.rotation.x = -arc * 1.0
		if is_instance_valid(right_arm):
			right_arm.rotation.x = -arc * 1.0
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	actor.position = pos
	actor.rotation = Vector3(0, PI, 0)
	actor.scale = Vector3.ONE
	reset_walk_pose()
	idle_anchor_position = pos
	idle_base_yaw = PI
	hopping = false

func hop_to(pos: Vector3) -> void:
	# Backward-compatible alias for older tests and callers.
	await jump_to(pos)

func apply_camp_idle() -> void:
	# Very restrained standing idle. Feet stay in their neutral pose so the
	# lower half never inherits walk rotations while the character is resting.
	reset_walk_pose()
	var breath: float = sin(elapsed * 1.35)
	actor.position.y = idle_anchor_position.y + breath * 0.004
	actor.scale = Vector3.ONE
	actor.rotation.x = 0.0
	actor.rotation.z = 0.0
	if is_instance_valid(left_arm):
		left_arm.rotation.x = -breath * 0.018
	if is_instance_valid(right_arm):
		right_arm.rotation.x = breath * 0.018

func apply_camp_fire_rest() -> void:
	# Bonfire rest pose: feet remain grounded and stable while the arms move
	# forward slightly as if warming by the fire. No lower-body rotations.
	reset_walk_pose()
	var breath: float = sin(elapsed * 1.05)
	actor.position.y = idle_anchor_position.y + breath * 0.003
	actor.scale = Vector3.ONE
	actor.rotation.x = 0.0
	actor.rotation.z = 0.0
	actor.look_at(Vector3(0.0, actor.position.y, -5.15), Vector3.UP, true)
	if is_instance_valid(left_arm):
		left_arm.position = Vector3(-0.46, 0.24, 0.15)
		left_arm.rotation = Vector3(-0.30 + breath * 0.025, 0, 0)
	if is_instance_valid(right_arm):
		right_arm.position = Vector3(0.46, 0.24, 0.15)
		right_arm.rotation = Vector3(-0.30 - breath * 0.025, 0, 0)

func select_actor_fire_rest_target() -> void:
	var index: int = camp_roam_rng.randi_range(0, camp_actor_fire_rest_points.size() - 1)
	camp_actor_fire_rest_target = camp_actor_fire_rest_points[index]
	camp_actor_heading_to_fire = true

func update_camp_actor_roam(delta: float) -> void:
	if camp_actor_roam_points.is_empty():
		return

	if camp_actor_pause > 0.0:
		camp_actor_pause = maxf(0.0, camp_actor_pause - delta)
		idle_anchor_position = Vector3(actor.position.x, 0.16, actor.position.z)
		if camp_actor_resting_by_fire:
			apply_camp_fire_rest()
		else:
			apply_camp_idle()
		return

	if camp_actor_resting_by_fire:
		# Fire rest finished: return cleanly to the neutral rig before roaming.
		camp_actor_resting_by_fire = false
		camp_actor_heading_to_fire = false
		reset_walk_pose()

	var next_index: int = camp_actor_roam_index
	var target: Vector3
	if camp_actor_heading_to_fire:
		target = camp_actor_fire_rest_target
	else:
		next_index = (camp_actor_roam_index + 1) % camp_actor_roam_points.size()
		target = camp_actor_roam_points[next_index]

	var flat_delta := Vector3(target.x - actor.position.x, 0.0, target.z - actor.position.z)
	var distance: float = flat_delta.length()
	if distance <= 0.10:
		actor.position = target
		idle_anchor_position = target
		reset_walk_pose()
		if camp_actor_heading_to_fire:
			camp_actor_heading_to_fire = false
			camp_actor_resting_by_fire = true
			camp_actor_moves_since_rest = 0
			camp_actor_pause = camp_roam_rng.randf_range(8.0, 14.0)
			apply_camp_fire_rest()
		else:
			camp_actor_roam_index = next_index
			camp_actor_moves_since_rest += 1
			if camp_actor_moves_since_rest >= 2:
				# After a couple of ordinary camp positions, head to the fire
				# after a short settling pause. This stays much slower than cat activity.
				camp_actor_pause = camp_roam_rng.randf_range(2.0, 4.0)
				select_actor_fire_rest_target()
			else:
				camp_actor_pause = camp_roam_rng.randf_range(6.0, 11.0)
		return

	var direction: Vector3 = flat_delta / distance
	var step: float = minf(distance, 0.42 * delta)
	actor.position += direction * step
	actor.position.y = 0.16 + absf(sin(elapsed * 5.2)) * 0.006
	actor.scale = Vector3.ONE
	actor.rotation.z = 0.0
	actor.look_at(Vector3(target.x, actor.position.y, target.z), Vector3.UP, true)
	idle_base_yaw = actor.rotation.y

	# Stable low-amplitude positional gait. Boots never rotate independently.
	var gait: float = sin(elapsed * 5.2)
	var left_lift: float = maxf(0.0, gait) * 0.045
	var right_lift: float = maxf(0.0, -gait) * 0.045
	if is_instance_valid(left_foot):
		left_foot.rotation = Vector3.ZERO
		left_foot.position = ACTOR_LEFT_FOOT_NEUTRAL + Vector3(0, left_lift, 0)
	if is_instance_valid(right_foot):
		right_foot.rotation = Vector3.ZERO
		right_foot.position = ACTOR_RIGHT_FOOT_NEUTRAL + Vector3(0, right_lift, 0)
	if is_instance_valid(left_arm):
		left_arm.position = Vector3(-0.55, 0.20, 0)
		left_arm.rotation = Vector3(-gait * 0.12, 0, 0)
	if is_instance_valid(right_arm):
		right_arm.position = Vector3(0.55, 0.20, 0)
		right_arm.rotation = Vector3(gait * 0.12, 0, 0)

func select_cat_fire_rest_target() -> void:
	var index: int = camp_roam_rng.randi_range(0, camp_cat_fire_rest_points.size() - 1)
	camp_cat_fire_rest_target = camp_cat_fire_rest_points[index]
	camp_cat_heading_to_fire = true

func update_camp_cat_roam(delta: float) -> void:
	if not is_instance_valid(camp_cat_root) or camp_cat_roam_points.is_empty():
		return

	if camp_cat_pause > 0.0:
		camp_cat_pause = maxf(0.0, camp_cat_pause - delta)
		if camp_cat_resting_by_fire:
			camp_cat_root.position.y = 0.16
			camp_cat_root.look_at(Vector3(0.0, camp_cat_root.position.y, -5.15), Vector3.UP, true)
		else:
			camp_cat_root.position.y = 0.16 + sin(elapsed * 1.9) * 0.004
		return

	if camp_cat_resting_by_fire:
		# Rest finished: resume normal wandering.
		camp_cat_resting_by_fire = false
		camp_cat_heading_to_fire = false

	var target: Vector3
	var next_index: int = camp_cat_roam_index
	if camp_cat_heading_to_fire:
		target = camp_cat_fire_rest_target
	else:
		next_index = (camp_cat_roam_index + 1) % camp_cat_roam_points.size()
		target = camp_cat_roam_points[next_index]

	var flat_delta := Vector3(target.x - camp_cat_root.position.x, 0.0, target.z - camp_cat_root.position.z)
	var distance: float = flat_delta.length()
	if distance <= 0.08:
		camp_cat_root.position = target
		if camp_cat_heading_to_fire:
			camp_cat_heading_to_fire = false
			camp_cat_resting_by_fire = true
			camp_cat_moves_since_rest = 0
			camp_cat_pause = camp_roam_rng.randf_range(4.0, 8.0)
			camp_cat_root.look_at(Vector3(0.0, camp_cat_root.position.y, -5.15), Vector3.UP, true)
		else:
			camp_cat_roam_index = next_index
			camp_cat_moves_since_rest += 1
			camp_cat_pause = camp_roam_rng.randf_range(0.45, 1.35)
			if camp_cat_moves_since_rest >= 4 or (camp_cat_moves_since_rest >= 2 and camp_roam_rng.randf() < 0.45):
				select_cat_fire_rest_target()
		return

	var direction: Vector3 = flat_delta / distance
	var step: float = minf(distance, 0.56 * delta)
	camp_cat_root.position += direction * step
	camp_cat_root.position.y = 0.16 + absf(sin(elapsed * 8.8)) * 0.014
	camp_cat_root.look_at(Vector3(target.x, camp_cat_root.position.y, target.z), Vector3.UP, true)

func apply_idle_animation(delta: float) -> void:
	# Camp-only ambient life. Adventure/travel remains static between inputs so
	# movement there always communicates player intent.
	if entrance or showcase or str(state.data.mode) != "camp":
		return
	update_camp_actor_roam(delta)
	update_camp_cat_roam(delta)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(camera):
		return
	elapsed += delta
	var target: Vector3
	if str(state.data.mode) == "camp" and not entrance:
		target = Vector3(0.0, 0.12, -4.80)
	else:
		target = Vector3(actor.position.x * 0.22, 0, actor.position.z)
	camera_target = camera_target.lerp(target, 1.0 - exp(-delta * 5.0))
	update_camera()
	if showcase:
		actor.rotation.y = sin(elapsed * 0.8) * 0.4
	elif not hopping and str(state.data.mode) == "camp":
		apply_idle_animation(delta)
