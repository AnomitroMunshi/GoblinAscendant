extends Node3D
## Non-headless visual check of the goblin. Run (windowed):
##   "$G" --path . res://tests/player_screens.tscn -- <out_dir>
## Saves PNGs: gameplay camera, front close-up, attack pose, hobgoblin.

var player: Player
var out_dir := "user://player_screens"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.set_menu_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_env()
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	await _run()
	get_tree().quit()


func _build_env() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	mi.mesh = plane
	mi.material_override = Palette.mat(Palette.GRASS)
	body.add_child(mi)
	add_child(body)
	for i in 6:
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.8
		sm.height = 1.2
		rock.mesh = sm
		rock.material_override = Palette.mat(Palette.ROCK)
		rock.position = Vector3(-6 + i * 2.5, 0.2, -8 - (i % 2) * 3)
		add_child(rock)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.72, 0.8)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", out_dir.path_join(file))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	await _wait(0.8)
	# 1) gameplay camera, idle, slightly rotated so the side profile shows
	player.camera_rig.yaw = deg_to_rad(-35.0)
	player.camera_rig._apply_rotation()
	await _wait(0.5)
	await _shot("1_gameplay.png")
	# 2) front close-up with a temporary camera
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(player.global_position + Vector3(0.9, 1.0, -2.2), player.global_position + Vector3(0, 0.62, 0))
	cam.current = true
	await _wait(0.3)
	await _shot("2_front.png")
	# 3) heavy attack windup -> strike, side view
	cam.look_at_from_position(player.global_position + Vector3(2.8, 1.1, -0.6), player.global_position + Vector3(0, 0.7, -0.4))
	Input.action_press(&"attack_heavy")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack_heavy")
	await _wait(0.36)
	await _shot("3_heavy_windup.png")
	await _wait(0.12)
	await _shot("4_heavy_strike.png")
	await _wait(0.8)
	# 4) light attack in gameplay view
	player.camera_rig.camera.current = true
	Input.action_press(&"attack_light")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack_light")
	await _wait(0.2)
	await _shot("5_light_gameplay.png")
	await _wait(0.8)
	# 5) hobgoblin front
	Events.evolution_changed.emit(&"hobgoblin")
	await _wait(1.5)
	cam.look_at_from_position(player.global_position + Vector3(1.1, 1.3, -2.8), player.global_position + Vector3(0, 0.8, 0))
	cam.current = true
	await _wait(0.2)
	await _shot("6_hobgoblin.png")
