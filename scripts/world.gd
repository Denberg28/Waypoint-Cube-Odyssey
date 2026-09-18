extends Node3D
## Procedural low-poly diorama. No downloaded assets or external plugins.
signal route_clicked(route_id: String)
signal marketplace_clicked
signal camp_clicked
signal continue_clicked
const Catalog = preload("res://scripts/catalog.gd")
const State = preload("res://scripts/state.gd")
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
var mat_cache: Dictionary = {}
var showcase: bool = false
var entrance: bool = false
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var active_theme: Dictionary = {}
var brightness_scale: float = 1.0

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if mat_cache.has(key):
		return mat_cache[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.14
	mat_cache[key] = mat
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, glow)
	node.position = pos
	parent.add_child(node)
	return node

func cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = 0.0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

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
	var sets: Array = [
		["moss", "forge", "fen"],
		["treasure", "shrine", "frost"],
		["moss", "frost", "fen"],
		["forge", "treasure", "frost"],
		["shrine", "fen", "forge"],
		["frost", "fen", "treasure"]
	]
	return sets[int(state.data.stage) % sets.size()]

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

func setup(game_state) -> void:
	state = game_state
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
	left_foot = box(actor, Vector3(-0.24, -0.13, 0.08), Vector3(0.26, 0.16, 0.38), Color("355c58"))
	right_foot = box(actor, Vector3(0.24, -0.13, 0.08), Vector3(0.26, 0.16, 0.38), Color("355c58"))
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
	active_theme = theme_for_environment(env_id)
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
	for point in [[-9.5, -13.0], [-7.2, -24.0], [7.4, -16.0], [10.2, -29.0]]:
		var x: float = float(point[0])
		var z: float = float(point[1])
		box(weather_fx, Vector3(x, y + absf(x) * 0.02, z), Vector3(2.8, 0.55, 1.15), color)
		box(weather_fx, Vector3(x + (0.8 if x < 0.0 else -0.8), y + 0.22, z - 0.2), Vector3(1.5, 0.48, 0.95), color.lightened(0.05))

func add_precipitation(color: Color, amount: int, speed_scale: float, size_y: float) -> void:
	for i in range(amount):
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
		if row % 2 == 0:
			for side in [-1, 1]:
				var edge_x: float = side * 4.55
				box(scenery, Vector3(edge_x, 0.28, -row * ROW_SPACING), Vector3(0.18, 0.72, 0.18), active_theme.post)
		if row % 3 == 0:
			for side in [-1, 1]:
				var x: float = side * local_rng.randf_range(6.2, 7.7)
				var z: float = -row * ROW_SPACING + local_rng.randf_range(-0.6, 0.6)
				tree(Vector3(x, 0, z), local_rng.randf_range(0.82, 1.14))
		elif row % 3 == 1:
			var shrub_side: int = -1 if row % 2 == 0 else 1
			cone(scenery, Vector3(shrub_side * 6.4, 0.35, -row * ROW_SPACING), 0.58, 0.75, active_theme.shrub, 0.3)
		if row % 4 == 2:
			for side in [-1, 1]:
				environment_side_prop(row, side, local_rng)
	if is_trail:
		var finish_z: float = -State.STAGE_STEPS * ROW_SPACING
		for lane in [-1, 1]:
			box(scenery, Vector3(lane * 4.15, 1.2, finish_z), Vector3(0.22, 2.7, 0.22), active_theme.post)
		box(scenery, Vector3(0, 2.6, finish_z), Vector3(8.5, 0.3, 0.35), active_theme.post)
		floating_text(scenery, "WAYPOINT", Vector3(0, 3.3, finish_z), active_theme.text, 42)
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
	camera_target = Vector3(actor.position.x * 0.22, 0, actor.position.z)
	if not entrance and state.data.mode == "camp":
		# Frame the side bench, seated character, and bonfire together.
		camera_target = Vector3(-1.35, 0.12, -3.95)
	update_camera()
	refresh_props()

func environment_side_prop(row: int, side: int, local_rng: RandomNumberGenerator) -> void:
	var env_id: String = str(state.data.get("environment", "sunny"))
	var x: float = float(side) * local_rng.randf_range(5.8, 7.3)
	var z: float = -row * ROW_SPACING + local_rng.randf_range(-0.45, 0.45)
	if str(state.data.get("route", "moss")) == "fen" and row % 8 == 2:
		box(scenery, Vector3(x, 0.03, z), Vector3(1.8, 0.05, 1.15), Color("496f72"), true)
	elif str(state.data.get("route", "moss")) == "frost" and row % 8 == 2:
		cone(scenery, Vector3(x, 0.45, z), 0.24, 0.90, Color("91b5bd"), 0.03)
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

func camp() -> void:
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

	# Keep camp navigation intentionally simple: one clear way back to the adventure.
	var continue_pos := Vector3(4.55, 1.95, -4.70)
	clickable_board(scenery, continue_pos, Vector3(3.05, 0.62, 0.24), Color("78906f"), "", false, false, true)
	floating_text(scenery, "CONTINUE ADVENTURE", continue_pos + Vector3(0, 0.03, 0.16), Color("fff0bd"), 20)
	for i in range(int(state.data.camp_level)):
		box(scenery, Vector3(3.7 + i * 0.5, 0.3, -3), Vector3(0.38, 0.7, 0.38), Color("b2d58c"))

func pose_actor_at_camp() -> void:
	actor.position = Vector3(-3.15, 0.52, -3.05)
	# The bench and cube both use local +Z as the direction toward the fire.
	var fire_look_target := Vector3(0.0, actor.position.y, -5.15)
	actor.look_at(fire_look_target, Vector3.UP, true)
	if is_instance_valid(left_foot):
		left_foot.position = Vector3(-0.24, -0.22, 0.34)
		left_foot.rotation.x = -0.48
	if is_instance_valid(right_foot):
		right_foot.position = Vector3(0.24, -0.22, 0.34)
		right_foot.rotation.x = -0.48
	if is_instance_valid(left_arm):
		left_arm.position.y = 0.20
		left_arm.rotation.x = -0.22
	if is_instance_valid(right_arm):
		right_arm.position.y = 0.20
		right_arm.rotation.x = -0.22

func road_end_waypoint(finish_z: float) -> void:
	# One signpost presents every decision after a completed road: three next roads
	# plus Lantern Camp. Route boards are clickable and open the normal preview.
	box(scenery, Vector3(0, 1.85, finish_z), Vector3(0.32, 4.25, 0.32), Color("8f6848"))
	var options: Array = route_options_for_stage()
	var board_layout: Array = [
		{"pos":Vector3(-1.25, 2.85, finish_z), "size":Vector3(3.05, 0.58, 0.26)},
		{"pos":Vector3(1.25, 2.12, finish_z), "size":Vector3(3.05, 0.58, 0.26)},
		{"pos":Vector3(-1.15, 1.39, finish_z), "size":Vector3(2.95, 0.58, 0.26)}
	]
	for i in range(options.size()):
		var route_id: String = str(options[i])
		var route: Dictionary = Catalog.ROUTES[route_id]
		var board: Dictionary = board_layout[i]
		var board_color: Color = Color(str(route.get("color", "c59b61"))).darkened(0.08)
		clickable_board(scenery, board.pos, board.size, board_color, route_id)
		floating_text(scenery, "NEXT  •  " + str(route.name).to_upper(), board.pos + Vector3(0, 0.03, 0.17), Color("fff0bd"), 21)

	var camp_pos := Vector3(1.20, 0.66, finish_z + 0.10)
	clickable_board(scenery, camp_pos, Vector3(2.85, 0.58, 0.26), Color("6b806b"), "", false, true)
	floating_text(scenery, "LANTERN CAMP", camp_pos + Vector3(0, 0.03, 0.17), Color("fff0bd"), 22)
	floating_text(scenery, "ROAD COMPLETE  •  CHOOSE NEXT ROAD OR CAMP", Vector3(0, 3.90, finish_z + 0.1), active_theme.text, 20)
	for x in [-2.2, 0.0, 2.2]:
		box(scenery, Vector3(x, 0.08, finish_z + 1.35), Vector3(1.6, 0.12, 1.6), active_theme.shoulder)

func crossroads(finish_z: float) -> void:
	# Route selection happens only after the player leaves Lantern Camp.
	box(scenery, Vector3(0, 1.55, finish_z), Vector3(0.30, 3.4, 0.30), Color("8f6848"))
	var options: Array = route_options_for_stage()
	var board_layout: Array = [
		{"pos":Vector3(-1.05, 2.45, finish_z), "size":Vector3(2.55, 0.52, 0.24)},
		{"pos":Vector3(1.05, 1.78, finish_z), "size":Vector3(2.55, 0.52, 0.24)},
		{"pos":Vector3(-0.85, 1.10, finish_z), "size":Vector3(2.35, 0.52, 0.24)}
	]
	for i in range(options.size()):
		var route_id: String = str(options[i])
		var route: Dictionary = Catalog.ROUTES[route_id]
		var board: Dictionary = board_layout[i]
		var board_color: Color = Color(str(route.get("color", "c59b61"))).darkened(0.12)
		clickable_board(scenery, board.pos, board.size, board_color, route_id)
		floating_text(scenery, str(route.name).to_upper(), board.pos + Vector3(0, 0.03, 0.16), Color("fff0bd"), 22)

	floating_text(scenery, "CROSSROADS  •  CHOOSE YOUR NEXT ROAD", Vector3(0, 3.25, finish_z + 0.1), active_theme.text, 20)
	for x in [-2.2, 0.0, 2.2]:
		box(scenery, Vector3(x, 0.08, finish_z + 1.35), Vector3(1.6, 0.12, 1.6), active_theme.shoulder)

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
	var label = Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.009
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)

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
			"heal":
				box(props, pos + Vector3(0, 0.35, 0), Vector3(0.2, 0.6, 0.2), Color("a7eac2"), true)
				box(props, pos + Vector3(0, 0.35, 0), Vector3(0.6, 0.2, 0.2), Color("a7eac2"), true)
			"spike":
				for x in [-0.48, 0.0, 0.48]:
					cone(props, pos + Vector3(x, 0.25, 0), 0.23, 0.6, Color("d69d86"))
				floating_text(props, "JUMP", pos + Vector3(0, 1.0, 0), Color("efd094"), 25)
			"slime", "goblin", "kobold", "ogre":
				var active: bool = state.enemy_active(cell)
				var elite: bool = state.enemy_elite(cell)
				var color: Color = enemy_colors(str(cell.kind), active)
				var size = Vector3(1.0, 0.65, 0.8)
				match str(cell.kind):
					"goblin":
						size = Vector3(0.92, 1.02, 0.82)
					"kobold":
						size = Vector3(0.96, 0.86, 1.05)
					"ogre":
						size = Vector3(1.38, 1.28, 1.08)
				box(props, pos + Vector3(0, size.y / 2, 0), size, color)
				for x in [-0.22, 0.22]:
					box(props, pos + Vector3(x, min(0.72, size.y * 0.62), size.z / 2 + 0.02), Vector3(0.09, 0.1, 0.03), Color("233e3d"))
				match str(cell.kind):
					"goblin":
						box(props, pos + Vector3(0, 1.18, 0), Vector3(0.52, 0.22, 0.52), color.darkened(0.12))
						cone(props, pos + Vector3(0.38, 1.02, 0), 0.12, 0.26, color.darkened(0.18), 0.02)
						cone(props, pos + Vector3(-0.38, 1.02, 0), 0.12, 0.26, color.darkened(0.18), 0.02)
						box(props, pos + Vector3(0.58, 0.58, 0), Vector3(0.12, 0.72, 0.12), Color("8c6742"))
						box(props, pos + Vector3(0.72, 0.42, 0), Vector3(0.22, 0.18, 0.52), Color("8c6742"))
					"kobold":
						cone(props, pos + Vector3(0.0, 0.86, 0.64), 0.18, 0.34, color.lightened(0.08), 0.02)
						cone(props, pos + Vector3(0.22, 0.98, 0.14), 0.08, 0.24, color.darkened(0.15), 0.01)
						cone(props, pos + Vector3(-0.22, 0.98, 0.14), 0.08, 0.24, color.darkened(0.15), 0.01)
						box(props, pos + Vector3(0, 0.38, -0.58), Vector3(0.14, 0.14, 0.56), color.darkened(0.10))
					"ogre":
						box(props, pos + Vector3(0, 1.48, 0), Vector3(0.74, 0.28, 0.68), color.darkened(0.15))
						box(props, pos + Vector3(-0.62, 0.64, 0), Vector3(0.26, 0.88, 0.26), color.darkened(0.12))
						box(props, pos + Vector3(0.62, 0.64, 0), Vector3(0.26, 0.88, 0.26), color.darkened(0.12))
						box(props, pos + Vector3(0.98, 0.82, 0), Vector3(0.16, 1.18, 0.16), Color("7f6648"))
						box(props, pos + Vector3(0.98, 1.28, 0), Vector3(0.44, 0.28, 0.44), Color("93806a"))
					_:
						box(props, pos + Vector3(0, 0.68, 0), Vector3(1.12, 0.16, 0.92), color.lightened(0.08))
				if elite:
					box(props, pos + Vector3(0, size.y + 0.28, 0), Vector3(0.62, 0.12, 0.52), Color("d8b85f"), true)
					for crown_x in [-0.22, 0.0, 0.22]:
						cone(props, pos + Vector3(crown_x, size.y + 0.46, 0), 0.08, 0.24, Color("efd887"), 0.01)
				var telegraph: String = "!" if active else "STOMP"
				if elite:
					var behavior: Dictionary = state.elite_behavior(str(cell.kind))
					telegraph = "%s  •  ELITE" % str(behavior.get("telegraph", "ELITE"))
				floating_text(props, telegraph, pos + Vector3(0, size.y + (0.88 if elite else 0.6), 0), Color("efd887") if elite else color, 30)
	if current_row < State.STAGE_STEPS:
		for lane in range(-1, 2):
			if absi(lane - int(state.data.lane)) <= 1:
				box(props, Vector3(lane * LANE_SPACING, 0.15, -(current_row + 1) * ROW_SPACING + 1.12), Vector3(2.45, 0.04, 0.07), Color("ecdfb7"), true)

func reset_walk_pose() -> void:
	if is_instance_valid(left_foot):
		left_foot.rotation = Vector3.ZERO
	if is_instance_valid(right_foot):
		right_foot.rotation = Vector3.ZERO
	if is_instance_valid(left_arm):
		left_arm.rotation = Vector3.ZERO
	if is_instance_valid(right_arm):
		right_arm.rotation = Vector3.ZERO

func walk_to(pos: Vector3) -> void:
	hopping = true
	var start: Vector3 = actor.position
	var travel: Vector3 = pos - start
	var duration: float = 0.44
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var gait: float = sin(t * TAU * 2.0)
		actor.position = start.lerp(pos, t) + Vector3(0, absf(gait) * 0.075, 0)
		actor.rotation.y = PI + clampf(travel.x * 0.05, -0.12, 0.12)
		actor.rotation.z = -gait * 0.025
		if is_instance_valid(left_foot):
			left_foot.rotation.x = gait * 0.55
		if is_instance_valid(right_foot):
			right_foot.rotation.x = -gait * 0.55
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
	hopping = false

func jump_to(pos: Vector3) -> void:
	hopping = true
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
	hopping = false

func hop_to(pos: Vector3) -> void:
	# Backward-compatible alias for older tests and callers.
	await jump_to(pos)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(camera):
		return
	elapsed += delta
	var target = Vector3(actor.position.x * 0.22, 0, actor.position.z)
	camera_target = camera_target.lerp(target, 1.0 - exp(-delta * 5.0))
	update_camera()
	if showcase:
		actor.rotation.y = sin(elapsed * 0.8) * 0.4
	if not hopping:
		actor.scale.y = 1.0 + sin(elapsed * 2.5) * 0.025
