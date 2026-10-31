extends Node3D
## Character Art lineup (windowed):
##   godot --path . res://tests/characters_lineup.tscn [-- --only=<name>]
## For every character: a turnaround sheet (front / side / back / 3-4 face close-up)
## rendered from the REAL in-game classes (enemies, adventurers, Nib), saved to
## tests/screens/characters/<name>.png, plus an in-game-scale lineup beside the
## player goblin (lineup_scale.png).

const OUT := "res://tests/screens/characters"
const BG := Color(0.62, 0.62, 0.6)

## name, script path (or "nib"), enemy type, variant
const CAST := [
	["human_raider_sword", "res://scripts/enemies/enemy_humanoid.gd", "human_raider", 0],
	["human_raider_axe", "res://scripts/enemies/enemy_humanoid.gd", "human_raider", 1],
	["raider_captain", "res://scripts/enemies/enemy_humanoid.gd", "raider_captain", 0],
	["goblin_raider_club", "res://scripts/enemies/enemy_humanoid.gd", "goblin_raider", 0],
	["goblin_raider_spear", "res://scripts/enemies/enemy_humanoid.gd", "goblin_raider", 1],
	["adventurer_bram_mage", "res://scripts/enemies/enemy_adventurer.gd", "adventurer", 0],
	["adventurer_mira_knight", "res://scripts/enemies/enemy_adventurer.gd", "adventurer", 1],
	["adventurer_thalen_ranger", "res://scripts/enemies/enemy_adventurer.gd", "adventurer", 2],
	["ogre", "res://scripts/enemies/enemy_ogre.gd", "ogre", 0],
	["wolf", "res://scripts/enemies/enemy_wolf.gd", "wolf", 0],
	["alpha_wolf", "res://scripts/enemies/enemy_wolf.gd", "alpha_wolf", 0],
	["nib_injured", "nib", "", 1],
	["nib", "nib", "", 0],
]

var cam: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_setup_env()
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var skip_scale := OS.get_cmdline_user_args().has("--no-scale")
	for entry: Array in CAST:
		if only != "" and not String(entry[0]).contains(only):
			continue
		await _sheet(entry)
	if not skip_scale and only == "":
		await _scale_lineup()
	get_tree().quit()


func _spawn(entry: Array) -> Node3D:
	if entry[1] == "nib":
		var n: Node3D = load("res://scripts/quests/quest_friend.gd").new()
		n.set("injured", entry[3] == 1)
		add_child(n)
		n.set_process(false)
		return n
	var e: EnemyBase = load(entry[1]).new()
	e.configure(EnemyStats.create(StringName(entry[2])), Vector3.ZERO, [])
	e.variant = entry[3]
	add_child(e)
	e.set_physics_process(false)
	if e.health_bar:
		e.health_bar.visible = false
	return e


func _height_of(entry: Array) -> float:
	if entry[1] == "nib":
		return 1.1
	var st := EnemyStats.create(StringName(entry[2]))
	return st.body_height * (st.model_scale if entry[2] != "raider_captain" else 1.0) * (1.0 if not String(entry[2]).contains("wolf") else 1.0)


func _sheet(entry: Array) -> void:
	var views := [0.0, -90.0, 180.0]
	var nodes: Array[Node3D] = []
	var h := _height_of(entry)
	var is_wolf := String(entry[2]).contains("wolf")
	var spacing := h * 0.75 if not is_wolf else 2.2 * (1.4 if entry[2] == "alpha_wolf" else 1.0)
	for i in views.size():
		var n := _spawn(entry)
		n.position = Vector3((float(i) - 1.0) * spacing, 0, 0)
		n.rotation_degrees.y = 180.0 + views[i]
		nodes.append(n)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(h * 1.25, spacing * 3.4 * 9.0 / 16.0 * 1.0)
	if is_wolf:
		cam.size = spacing * 2.0
	cam.position = Vector3(0, h * 0.52 if not is_wolf else h * 0.5, 10)
	cam.rotation = Vector3.ZERO
	await _frames(6)
	await _shot("%s" % entry[0])
	# 3/4 face close-up
	for i in nodes.size():
		nodes[i].visible = i == 0
	nodes[0].position = Vector3.ZERO
	nodes[0].rotation_degrees.y = 180.0 + 30.0
	await _frames(2)
	var fy := h * 0.9 if not is_wolf else h * 0.62
	var fz := 0.0
	if is_wolf:
		fz = 0.0
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28
	var dist := maxf(h * 0.55, 0.6) if not is_wolf else 1.8 * (1.4 if entry[2] == "alpha_wolf" else 1.0)
	if entry[2] == "ogre":
		fy = 2.95
		dist = 2.4
	if is_wolf:
		var hk := 1.4 if entry[2] == "alpha_wolf" else 1.0
		cam.look_at_from_position(Vector3(dist * 0.3, fy + 0.1, dist * 1.0), Vector3(0.25 * hk, fy, 0.45 * hk))
	else:
		cam.look_at_from_position(Vector3(dist * 0.25, fy + 0.02, dist), Vector3(0, fy - 0.02, fz))
	await _frames(3)
	await _shot("%s_face" % entry[0])
	for n in nodes:
		n.queue_free()
	await _frames(1)


func _scale_lineup() -> void:
	var x := -6.0
	var placed: Array[Node3D] = []
	var p: Node3D = PlayerGoblinModel.new()
	p.set("footsteps_enabled", false)
	add_child(p)
	p.position = Vector3(x, 0, 0)
	p.rotation_degrees.y = 180.0
	placed.append(p)
	x += 0.9
	for entry: Array in CAST:
		if String(entry[0]) in ["human_raider_axe", "goblin_raider_spear", "nib_injured"]:
			continue
		var n := _spawn(entry)
		var w := 0.9
		if entry[2] == "ogre":
			w = 2.2
		elif String(entry[2]).contains("wolf"):
			w = 1.6
		x += w * 0.5
		n.position = Vector3(x, 0, 0)
		n.rotation_degrees.y = 180.0 + (-30.0 if String(entry[2]).contains("wolf") else 0.0)
		x += w * 0.5
		placed.append(n)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2
	cam.position = Vector3((x - 6.0) * 0.5 - 3.0, 1.7, 12)
	cam.rotation = Vector3.ZERO
	cam.size = (x + 6.0) * 9.0 / 16.0 + 0.4
	await _frames(6)
	await _shot("lineup_scale")


func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.86)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = not OS.get_cmdline_user_args().has("--noshadow")
	key.shadow_normal_bias = 2.5
	key.shadow_bias = 0.06
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.8, 0.86, 1.0)
	if not OS.get_cmdline_user_args().has("--nofill"):
		add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	floor_mi.material_override = Palette.mat(BG.darkened(0.05))
	if not OS.get_cmdline_user_args().has("--nofloor"):
		add_child(floor_mi)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, n]))
	print("saved ", n)
