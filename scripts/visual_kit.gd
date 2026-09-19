extends RefCounted
## Lightweight visual wrapper for Cube Odyssey.
##
## All procedural geometry goes through this class so Web can use one reliable,
## low-cost rendering path. Mesh resources and materials are reused instead of
## recreated for every prop.
##
## Profiles:
##   full  - desktop/editor fidelity
##   light - Web default: CORE + ACCENT, reduced DECOR

var simple_mode: bool = false
var material_cache: Dictionary = {}
var cone_mesh_cache: Dictionary = {}
var unit_box: BoxMesh

func _init() -> void:
	var forced: String = OS.get_environment("CUBE_VISUAL_PROFILE").strip_edges().to_lower()
	simple_mode = forced == "light" or (forced == "" and OS.has_feature("web"))
	unit_box = BoxMesh.new()
	unit_box.size = Vector3.ONE

func profile_name() -> String:
	return "light" if simple_mode else "full"

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + ("_g" if glow else "_m")
	if material_cache.has(key):
		return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.14
	material_cache[key] = mat
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = unit_box
	node.material_override = material(color, glow)
	node.position = pos
	node.scale = size
	parent.add_child(node)
	return node

func cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = 0.0) -> MeshInstance3D:
	var safe_radius: float = maxf(radius, 0.001)
	var ratio: float = clampf(top / safe_radius, 0.0, 1.0)
	var ratio_key: String = "%.2f" % ratio
	var mesh: CylinderMesh
	if cone_mesh_cache.has(ratio_key):
		mesh = cone_mesh_cache[ratio_key]
	else:
		mesh = CylinderMesh.new()
		mesh.top_radius = ratio
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 6
		cone_mesh_cache[ratio_key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.scale = Vector3(radius, height, radius)
	parent.add_child(node)
	return node

func text(parent: Node3D, value: String, pos: Vector3, color: Color, size: int = 32) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.009
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	return label

func allow_decor(index: int = 0) -> bool:
	# Full mode keeps authored decoration. Light/Web mode preserves only every
	# third decorative beat; core navigation and interaction geometry is never
	# filtered through this method.
	return not simple_mode or posmod(index, 3) == 0

func precipitation_budget(full_amount: int) -> int:
	if not simple_mode:
		return full_amount
	return maxi(10, int(round(float(full_amount) * 0.34)))
