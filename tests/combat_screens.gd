extends Node3D
## Visual lineup of every enemy model (Combat agent). Run NON-headless:
##   Godot --path . res://tests/combat_screens.tscn
## Saves user://combat_screens.png (+ a close-up) and quits.

const LINEUP := [
	["wolf", "res://scripts/enemies/enemy_wolf.gd", 0],
	["alpha_wolf", "res://scripts/enemies/enemy_wolf.gd", 0],
	["goblin_raider", "res://scripts/enemies/enemy_humanoid.gd", 0],
	["goblin_raider", "res://scripts/enemies/enemy_humanoid.gd", 1],
	["human_raider", "res://scripts/enemies/enemy_humanoid.gd", 0],
	["human_raider", "res://scripts/enemies/enemy_humanoid.gd", 1],
	["raider_captain", "res://scripts/enemies/enemy_humanoid.gd", 0],
	["adventurer", "res://scripts/enemies/enemy_adventurer.gd", 0],
	["adventurer", "res://scripts/enemies/enemy_adventurer.gd", 1],
	["adventurer", "res://scripts/enemies/enemy_adventurer.gd", 2],
	["ogre", "res://scripts/enemies/enemy_ogre.gd", 0],
]

var cam: Camera3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	floor_mi.material_override = Palette.mat(Palette.GRASS)
	add_child(floor_mi)
	var x := -13.0
	for entry: Array in LINEUP:
		var en: EnemyBase = load(entry[1]).new()
		en.configure(EnemyStats.create(StringName(entry[0])), Vector3(x, 0, 0), [])
		en.variant = entry[2]
		en.position = Vector3(x, 0, 0)
		add_child(en)
		en.rotation.y = PI + deg_to_rad(-25.0)
		en.set_physics_process(false)
		x += 2.4 if entry[0] != "ogre" else 0.0
		if entry[0] == "alpha_wolf" or entry[0] == "raider_captain":
			x += 0.6
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.0, 17), Vector3(0, 1.0, 0))
	_shoot()


func _shoot() -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://combat_screens.png")
	cam.look_at_from_position(Vector3(-6.5, 1.3, 3.2), Vector3(-6.5, 0.7, 0))
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://combat_screens_close.png")
	print("SCREENSHOT ", ProjectSettings.globalize_path("user://combat_screens.png"))
	get_tree().quit()
