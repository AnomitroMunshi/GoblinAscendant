extends Node3D
## Renders the player goblin model as a concept-style turnaround sheet
## (3/4 hero view, front, side, back) plus a face close-up, and a Hobgoblin
## comparison. Saves PNGs to tests/screens/. Run windowed:
##   godot --path . res://tests/goblin_turnaround.tscn

const BG := Color(0.95, 0.92, 0.85)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens"))
	_setup_env()
	var yaws := [35.0, 0.0, -90.0, 180.0]  # 3/4 hero, front, side (facing left), back
	for i in yaws.size():
		var m := PlayerGoblinModel.new()
		m.footsteps_enabled = false
		add_child(m)
		m.position = Vector3(-2.4 + 1.6 * i, 0, 0)
		# model faces -Z; rotate so it faces the camera (+Z) at yaw 0
		m.rotation_degrees.y = 180.0 + yaws[i]
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.9
	cam.position = Vector3(0, 0.62, 6)
	add_child(cam)
	cam.make_current()
	await _frames(20)
	await _shot("goblin_turnaround")
	# face close-up
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 30
	cam.position = Vector3(-0.8, 0.95, 1.25)
	cam.look_at(Vector3(-0.8, 0.92, 0))
	await _frames(5)
	await _shot("goblin_face")
	# 3/4 hero close-up
	cam.position = Vector3(-2.0, 0.75, 2.2)
	cam.look_at(Vector3(-2.4, 0.55, 0))
	await _frames(5)
	await _shot("goblin_hero")
	# hobgoblin next to goblin
	for c in get_children():
		if c is PlayerGoblinModel:
			c.visible = false
	var g := PlayerGoblinModel.new()
	g.footsteps_enabled = false
	add_child(g)
	g.position = Vector3(-0.6, 0, 0)
	g.rotation_degrees.y = 180 + 20
	var h := PlayerGoblinModel.new()
	h.footsteps_enabled = false
	add_child(h)
	h.position = Vector3(0.6, 0, 0)
	h.rotation_degrees.y = 180 - 20
	await _frames(2)
	h.set_stage(&"hobgoblin", false)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0, 0.8, 6)
	cam.rotation = Vector3.ZERO
	await _frames(10)
	await _shot("goblin_vs_hobgoblin")
	get_tree().quit()


func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.92, 0.88)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.35
	add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = BG
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mi.material_override = fm
	add_child(floor_mi)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/screens/%s.png" % shot_name)
