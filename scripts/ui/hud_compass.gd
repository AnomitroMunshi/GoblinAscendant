class_name HudCompass
extends Control
## Thin compass strip: N/E/S/W ticks relative to the camera yaw, icons for
## discovered landmarks and a gold diamond (with distance) for the objective.
## Bearings: 0 = north (-Z), 90 = east (+X).

const HALF_FOV := 95.0          # degrees visible either side of centre
const CARDINALS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var _heading := 0.0
var _player_pos := Vector3.ZERO
var _has_pos := false
var _obj_pos: Variant = null
var _dist_m := -1
var _dist_text := ""
var _obj_timer := 0.0
var _bg_tex: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 34)


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.04, 0.03, 0.0))
	g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	g.add_point(0.18, Color(0.07, 0.055, 0.04, 0.62))
	g.add_point(0.82, Color(0.07, 0.055, 0.04, 0.62))
	_bg_tex = GradientTexture2D.new()
	_bg_tex.gradient = g
	_bg_tex.width = 256
	_bg_tex.height = 4
	_bg_tex.fill_from = Vector2(0, 0)
	_bg_tex.fill_to = Vector2(1, 0)


func refresh_objective() -> void:
	_obj_pos = Quests.get_objective_position() if Quests.has_method(&"get_objective_position") else null
	_obj_timer = 0.5


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cam: Camera3D = GameState.camera
	if not is_instance_valid(cam):
		cam = get_viewport().get_camera_3d()
	if cam and is_instance_valid(cam) and cam.is_inside_tree():
		var f := -cam.global_basis.z
		if Vector2(f.x, f.z).length_squared() > 0.0001:
			_heading = rad_to_deg(atan2(f.x, -f.z))
	var p: Node3D = GameState.player
	if is_instance_valid(p) and p.is_inside_tree():
		_player_pos = p.global_position
		_has_pos = true
	elif cam and is_instance_valid(cam) and cam.is_inside_tree():
		_player_pos = cam.global_position
		_has_pos = true
	# objective position can move (escort, NPC); poll it a few times a second
	_obj_timer -= delta
	if _obj_timer <= 0.0:
		refresh_objective()
	if _obj_pos is Vector3 and _has_pos:
		var d := roundi(Vector2(_obj_pos.x - _player_pos.x, _obj_pos.z - _player_pos.z).length())
		if d != _dist_m:
			_dist_m = d
			_dist_text = "%d m" % d
	queue_redraw()


func _x_for(bearing: float) -> float:
	var rel := wrapf(bearing - _heading, -180.0, 180.0)
	if absf(rel) > HALF_FOV:
		return INF
	return size.x * 0.5 + rel / HALF_FOV * (size.x * 0.5 - 14.0)


func _alpha_at(x: float) -> float:
	var t := absf(x - size.x * 0.5) / (size.x * 0.5)
	return clampf(1.2 - t * t * 1.3, 0.0, 1.0)


func _bearing_to(pos: Vector3) -> float:
	return rad_to_deg(atan2(pos.x - _player_pos.x, -(pos.z - _player_pos.z)))


func _draw() -> void:
	if _bg_tex == null:
		return
	var font := get_theme_default_font()
	var h := 26.0
	draw_texture_rect(_bg_tex, Rect2(0, 0, size.x, h), false)
	draw_line(Vector2(size.x * 0.12, h), Vector2(size.x * 0.88, h), Color(UiTheme.GOLD_DIM, 0.45), 1.0)
	# ticks
	for i in 24:
		var deg := i * 15.0
		var x := _x_for(deg)
		if x == INF:
			continue
		var a := _alpha_at(x)
		if i % 3 == 0:
			var label: String = CARDINALS[int(i / 3.0)]
			var major := i % 6 == 0
			var fs := 17 if major else 12
			var col := UiTheme.GOLD if i == 0 else (UiTheme.TEXT if major else UiTheme.TEXT_DIM)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(x - w * 0.5, 19.0 if major else 17.0)
			draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6 * a))
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		else:
			draw_line(Vector2(x, 9), Vector2(x, 17), Color(UiTheme.TEXT_DIM, 0.6 * a), 1.0)
	if not _has_pos:
		return
	# discovered landmarks
	var disc: Variant = Progression.get(&"discovered")
	if disc is Array:
		for id: StringName in WorldLayout.LANDMARKS:
			if not (disc as Array).has(id):
				continue
			var lm: Dictionary = WorldLayout.LANDMARKS[id]
			var lp: Vector3 = lm["pos"]
			var x := _x_for(_bearing_to(lp))
			if x == INF:
				continue
			var a := _alpha_at(x)
			var c := Vector2(x, h + 7.0)
			draw_circle(c, 4.5, Color(0.08, 0.06, 0.04, 0.8 * a))
			draw_circle(c, 3.2, Color(0.62, 0.86, 0.80, a))
			if absf(x - size.x * 0.5) < 22.0:
				var nm: String = lm["name"]
				var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var np := Vector2(x - w * 0.5, h + 24.0)
				draw_string_outline(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.7))
				draw_string(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.92, 0.86))
	# objective marker (clamped to the strip edge when behind)
	if _obj_pos is Vector3:
		var rel := wrapf(_bearing_to(_obj_pos) - _heading, -180.0, 180.0)
		var cl := clampf(rel, -HALF_FOV, HALF_FOV)
		var x := size.x * 0.5 + cl / HALF_FOV * (size.x * 0.5 - 14.0)
		var c := Vector2(x, 13.0)
		var s := 7.0
		var dia := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
		draw_colored_polygon(dia, Color(0.1, 0.07, 0.03, 0.9))
		var s2 := 5.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s2), c + Vector2(s2, 0), c + Vector2(0, s2), c + Vector2(-s2, 0)]), UiTheme.GOLD)
		var w := font.get_string_size(_dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var dp := Vector2(clampf(x - w * 0.5, 0.0, size.x - w), h + 13.0)
		draw_string_outline(font, dp, _dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.75))
		draw_string(font, dp, _dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.GOLD)
	# centre notch
	var cx := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, 0), Vector2(cx + 5, 0), Vector2(cx, 6)]), UiTheme.GOLD)
