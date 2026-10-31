extends Node3D
## Windowed choreography preview. Run:
##   godot --path . res://tests/choreo_preview.tscn  [-- --only=sword]
## For every move of every Goblin moveset it simulates the real model timeline
## (60 Hz, same smoothing as runtime) and writes a contact sheet to
## tests/screens/choreo/<moveset>_<move>.png: rows = front / side / gameplay
## camera, columns = anticipation -> contact -> follow-through -> recovery.
## The move's hitbox is drawn (red) while the active window is live; the green
## ground line marks the floor so floating/sinking feet are visible.
## Also writes <moveset>_states.png (idle, guard, flame cast, stone cast,
## stagger, knockdown) per moveset.

const CELL := 300
const MOVESETS: Array[StringName] = [&"knife", &"sword", &"sling", &"unarmed"]
const PHASES := [0.55, 1.0, 1.3, 1.65, 2.05, 2.45, 2.95]
const DT := 1.0 / 60.0

var model: PlayerGoblinModel
var views: Array[SubViewport] = []
var hit_mesh: MeshInstance3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens/choreo"))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.85)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.15
	add_child(light)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	ground.mesh = pm
	ground.material_override = Palette.mat(Color(0.28, 0.33, 0.24), 0.95)
	add_child(ground)
	for i in 9:
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.006, 0.004, 3.0)
		line.mesh = bm
		line.material_override = Palette.mat(Color(0.4, 0.46, 0.34), 0.9)
		line.position = Vector3(-1.0 + 0.25 * i, 0.002, -0.5)
		add_child(line)
	hit_mesh = MeshInstance3D.new()
	hit_mesh.mesh = BoxMesh.new()
	var hm := StandardMaterial3D.new()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(1, 0.15, 0.1, 0.07)
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hit_mesh.material_override = hm
	hit_mesh.visible = false
	add_child(hit_mesh)
	_add_view(_ortho(Vector3(0, 0.62, -3.0), Vector3(0, 0.62, 0), 1.7))      # front
	_add_view(_ortho(Vector3(3.0, 0.62, -0.35), Vector3(0, 0.62, -0.35), 1.7)) # right side
	var gp := Camera3D.new()                                                   # gameplay: behind, over the right shoulder
	gp.fov = 60.0
	gp.position = Vector3(0.32, 1.15, 2.0)
	_add_view(gp, Vector3(0.0, 0.62, -0.45))
	model = PlayerGoblinModel.new()
	model.footsteps_enabled = false
	add_child(model)
	model.set_process(false)
	model._next_blink = 1000.0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for ms_id: StringName in MOVESETS:
		if only != "" and String(ms_id) != only:
			continue
		var ms := ChoreoLibrary.moveset(ms_id)
		var moves: Array = ms["light"].duplicate()
		moves.append(ms["heavy"])
		for mv: Dictionary in moves:
			await _render_move(ms_id, mv)
		await _render_states(ms_id)
	get_tree().quit()


func _ortho(pos: Vector3, look: Vector3, size: float) -> Camera3D:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = size
	c.position = pos
	c.set_meta(&"look", look)
	return c


func _add_view(cam: Camera3D, look: Vector3 = Vector3.INF) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	vp.add_child(cam)
	var target: Vector3 = look if look != Vector3.INF else cam.get_meta(&"look")
	cam.look_at(target, Vector3.UP)
	cam.current = true
	views.append(vp)


func _equip(ms_id: StringName) -> void:
	model.reset_pose()
	if ms_id == &"unarmed":
		model.set_weapon(&"knife")
		model.set_weapon_drawn(false)
	else:
		model.set_weapon(ms_id)
		model.set_weapon_drawn(true)
	model.anim_grounded = true
	model.anim_state = &"idle"
	model.anim_move = {}
	for i in 40:
		model._process(DT)


func _render_move(ms_id: StringName, mv: Dictionary) -> void:
	_equip(ms_id)
	var dur := [float(mv["windup"]), float(mv["active"]), float(mv["recovery"])]
	var total: float = dur[0] + dur[1] + dur[2]
	var sheet := Image.create(CELL * PHASES.size(), CELL * views.size(), false, Image.FORMAT_RGBA8)
	model.anim_state = &"attack"
	model.anim_move = mv
	model.anim_action = mv["anim"]
	var t := 0.0
	var col := 0
	while col < PHASES.size() and t <= total + DT:
		var ph := _phase_at(t, dur)
		model.anim_phase = ph
		model._process(DT)
		if ph >= float(PHASES[col]) - 0.0001:
			_show_hitbox(mv, ph)
			await _grab(sheet, col)
			col += 1
		t += DT
	hit_mesh.visible = false
	sheet.save_png("res://tests/screens/choreo/%s_%s.png" % [ms_id, mv["id"]])
	print("choreo sheet: %s/%s  reach %.2f m (+%.2f lunge)" % [ms_id, mv["id"], ChoreoLibrary.reach(mv), ChoreoLibrary.lunge_distance(mv)])


func _phase_at(t: float, dur: Array) -> float:
	var acc := 0.0
	for i in 3:
		var d: float = dur[i]
		if t < acc + d:
			return float(i) + (t - acc) / d
		acc += d
	return 3.0


func _show_hitbox(mv: Dictionary, ph: float) -> void:
	hit_mesh.visible = ph >= 1.0 and ph < 2.0 and mv.has("hitbox")
	if hit_mesh.visible:
		(hit_mesh.mesh as BoxMesh).size = mv["hitbox"]["size"]
		hit_mesh.position = mv["hitbox"]["offset"]


func _grab(sheet: Image, col: int, row_offset: int = 0) -> void:
	await RenderingServer.frame_post_draw
	for r in views.size():
		var img := views[r].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, (r + row_offset) * CELL))


func _render_states(ms_id: StringName) -> void:
	var states := [
		[&"idle", &"", &"", 0.0],
		[&"block", &"", &"", 0.0],
		[&"cast", &"flame_burst", &"", 0.5],
		[&"cast", &"stone_guard", &"", 0.6],
		[&"hurt", &"", &"stagger", 0.25],
		[&"hurt", &"", &"knockdown", 0.5],
	]
	var sheet := Image.create(CELL * states.size(), CELL * views.size(), false, Image.FORMAT_RGBA8)
	for i in states.size():
		var st: Array = states[i]
		_equip(ms_id)
		model.anim_state = st[0]
		model.cast_skill = st[1]
		model.hurt_kind = st[2] if st[2] != &"" else &"stagger"
		model.hurt_dir = Vector2(0.3, 1.0).normalized()
		var steps := 30
		for f in steps:
			model.anim_t = float(st[3]) * float(f + 1) / steps
			model._process(DT)
		await _grab(sheet, i)
	sheet.save_png("res://tests/screens/choreo/%s_states.png" % ms_id)
	print("choreo sheet: %s/states" % ms_id)
