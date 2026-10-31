extends Node3D
## Character Art debug scene (temporary).

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.5, 0.2)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	add_child(l)
	var args := OS.get_cmdline_user_args()
	var plain := Node3D.new()
	add_child(plain)
	CharHumanoid.build(plain, CharDefs.human_raider(0))
	plain.position = Vector3(-0.3, 0, 0)
	plain.rotation_degrees.y = 180
	var e: EnemyBase = load("res://scripts/enemies/enemy_humanoid.gd").new()
	e.configure(EnemyStats.create(&"human_raider"), Vector3.ZERO, [])
	if args.has("--nointerp"):
		e.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(e)
	e.set_physics_process(false)
	e.position = Vector3(0.3, 0, 0)
	e.rotation_degrees.y = 180
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.62, 1.1), Vector3(0, 1.62, 0))
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/ANOMITRO/AppData/Local/Temp/claude/d--Goblin-Ascendant/71afc29a-3dc5-432a-9123-f41913fe6073/scratchpad/dbg.png")
	get_tree().quit()
