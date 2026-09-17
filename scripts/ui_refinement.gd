extends Node
## UI refinement layer for the legacy programmatic HUD.
##
## This script does not create a second menu/window system. Instead it refines the
## existing UI owned by scripts/main.gd so there is one source of truth for input,
## modal state, save flow, and gameplay state. It is intentionally presentation-only.

const PANEL_BG := Color("153334")
const PANEL_BG_ALT := Color("173b3b")
const BORDER := Color("41645b")
const BORDER_SOFT := Color("39605a")
const GOLD := Color("efd094")
const MENU_KICKERS := [
	"PAUSED / JOURNEY SAVED",
	"SETTINGS",
	"HOW TO PLAY",
	"RETURN HOME?",
]

var scene: Node = null
var menu_button: Button = null
var menu_session_active := false
var last_kicker := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	call_deferred("_bind_scene")

func _process(_delta: float) -> void:
	var current := get_tree().current_scene
	if current != scene:
		_bind_scene()
	if scene == null:
		return
	_refine_header()
	_refine_surfaces()
	_update_menu_side_rail()

func _bind_scene() -> void:
	scene = get_tree().current_scene
	menu_button = null
	menu_session_active = false
	last_kicker = ""
	if scene == null:
		return
	_refine_header()
	_refine_surfaces()

func _get_control(property_name: String) -> Control:
	if scene == null:
		return null
	var node = scene.get(property_name)
	return node as Control if node is Control else null

func _style(bg: Color, radius: int = 12, border: Color = BORDER, padding: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func _refine_header() -> void:
	if scene == null:
		return
	# Equipment already exists in the persistent status rail. Remove the duplicate
	# top-level action without deleting the legacy Button object that main.gd updates.
	var gear = scene.get("gear_button")
	if gear is Button:
		var gear_button := gear as Button
		gear_button.hide()
		var row := gear_button.get_parent()
		if row is HBoxContainer:
			(row as HBoxContainer).add_theme_constant_override("separation", 18)
			if not is_instance_valid(menu_button):
				for child in row.get_children():
					if child is Button and child != gear_button and str((child as Button).text).to_lower() == "menu":
						menu_button = child as Button
						break
	if is_instance_valid(menu_button):
		menu_button.custom_minimum_size = Vector2(78, 38)
		menu_button.add_theme_font_size_override("font_size", 12)

func _refine_surfaces() -> void:
	# One coherent surface language: subtle border, 12px radius, compact padding.
	var modal_panel := _get_control("panel")
	if modal_panel is PanelContainer:
		(modal_panel as PanelContainer).add_theme_stylebox_override("panel", _style(PANEL_BG_ALT, 14, Color("567e6d"), 12))
	var route_panel := _get_control("route_panel")
	if route_panel is PanelContainer:
		(route_panel as PanelContainer).add_theme_stylebox_override("panel", _style(Color("122f30"), 12, Color("6c8d7f"), 10))
	var fight_card := _get_control("fight_card")
	if fight_card is PanelContainer:
		(fight_card as PanelContainer).add_theme_stylebox_override("panel", _style(Color("112d30"), 12, Color("c9ad70"), 10))
	var side_panel := _get_control("side_panel")
	if side_panel is PanelContainer:
		(side_panel as PanelContainer).add_theme_stylebox_override("panel", _style(PANEL_BG, 12, BORDER, 9))

func _current_kicker() -> String:
	if scene == null:
		return ""
	var overlay = scene.get("overlay")
	var stack = scene.get("stack")
	if not (overlay is Control) or not (stack is VBoxContainer):
		return ""
	if not (overlay as Control).visible:
		return ""
	for child in (stack as VBoxContainer).get_children():
		if child is Label:
			return str((child as Label).text).strip_edges()
	return ""

func _update_menu_side_rail() -> void:
	var kicker := _current_kicker()
	if kicker == last_kicker and not menu_session_active:
		return
	last_kicker = kicker
	if kicker == "PAUSED / JOURNEY SAVED":
		menu_session_active = true
	if menu_session_active:
		if kicker in MENU_KICKERS:
			_apply_temporary_compact_rail()
		elif kicker != "":
			# A gameplay/camp modal replaced the menu flow; restore the user's rail mode.
			menu_session_active = false
			_restore_user_rail_mode()
		else:
			# Travel mode hides the modal completely when Resume is chosen.
			menu_session_active = false
			_restore_user_rail_mode()

func _apply_temporary_compact_rail() -> void:
	var side_panel := _get_control("side_panel")
	var full_body := _get_control("side_full_body")
	var compact_body := _get_control("side_compact_body")
	var heading := _get_control("side_heading")
	var toggle := _get_control("side_toggle_button")
	if side_panel == null or full_body == null or compact_body == null:
		return
	# Compact rail remains visible next to the menu instead of disappearing.
	side_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	side_panel.offset_left = -338
	side_panel.offset_right = -20
	side_panel.offset_top = -116
	side_panel.offset_bottom = -20
	full_body.hide()
	compact_body.show()
	if heading != null:
		heading.hide()
	if toggle is Button:
		(toggle as Button).text = "Expand"
	# Menu is a modal surface, so the compact rail is informational/quick-action only.
	side_panel.show()

func _restore_user_rail_mode() -> void:
	if scene != null and scene.has_method("apply_side_panel_mode"):
		scene.call("apply_side_panel_mode")
