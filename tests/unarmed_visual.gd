extends Node3D
## Render actual unarmed poses from useful inspection angles.

func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.19, 0.21, 0.22)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.2
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	camera.position = Vector3(0, 0.6, 3)
	add_child(camera)
	camera.make_current()
	var model := PlayerGoblinModel.new()
	model.footsteps_enabled = false
	add_child(model)
	model.set_weapon_drawn(false)
	model.set_process(false)
	model._next_blink = 100.0
	for pose: Array in [
		["unarmed_rest", &"idle", &"", 0.0, 180.0],
		["unarmed_boxing_guard", &"block", &"", 0.0, 180.0],
		["unarmed_punch_side", &"attack", &"punch1", 1.9, 90.0],
		["unarmed_kick_side", &"attack", &"kick", 1.9, 90.0],
	]:
		model.reset_pose()
		model.rotation_degrees.y = pose[4]
		model.anim_state = pose[1]
		model.anim_action = pose[2]
		model.anim_phase = pose[3]
		model._process(0.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/screens/%s.png" % pose[0])
	get_tree().quit()
