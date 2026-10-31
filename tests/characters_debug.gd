extends Node3D
## Character Art debug: one ellipsoid flat vs smooth, one head.

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
	for i in 3:
		var g := CharGeo.new()
		if i < 2:
			g.ellipsoid(Transform3D(), Vector3(0.4, 0.5, 0.4), Color(0.8, 0.6, 0.5), 16, 10, i == 1, CharGeo.SKIN)
		else:
			CharParts.head(g, Transform3D(Basis().scaled(Vector3.ONE), Vector3(0, -0.5, 0)), {}, Color(0.8, 0.6, 0.5))
		var mi := g.instance(self)
		mi.position = Vector3(-1.2 + 1.2 * i, 0, 0)
		mi.rotation_degrees.y = 180
	var e: EnemyBase = load("res://scripts/enemies/enemy_humanoid.gd").new()
	e.configure(EnemyStats.create(&"human_raider"), Vector3.ZERO, [])
	add_child(e)
	e.set_physics_process(false)
	e.position = Vector3(2.2, -1.6, 0)
	e.rotation_degrees.y = 180
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 28
	cam.look_at_from_position(Vector3(1.2, 0.0, 2.0), Vector3(1.2, 0.0, 0))
	cam.make_current()
	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/ANOMITRO/AppData/Local/Temp/claude/d--Goblin-Ascendant/71afc29a-3dc5-432a-9123-f41913fe6073/scratchpad/dbg.png")
	get_tree().quit()
