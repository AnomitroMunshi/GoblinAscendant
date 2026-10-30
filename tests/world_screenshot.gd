extends Node
## Visual check (World agent): builds the world, renders composed viewpoints
## and saves PNGs to res://tests/screens/. Not headless:
##   "$G" --path . res://tests/world_screenshot.tscn
## Optional user args after "--": quality=<0|1|2> only=<name,name>

const VIEWS := [
	# name, camera position (y = metres above ground), look-at (y above ground)
	["glade", Vector3(-12, 1.8, 192), Vector3(-6, 1.5, 150)],
	["glade_wide", Vector3(-40, 9.0, 212), Vector3(0, 0.0, 160)],
	["woods", Vector3(-112, 1.8, 112), Vector3(-150, 2.0, 80)],
	["den", Vector3(-160, 2.5, 100), Vector3(-176, 1.0, 122)],
	["rescue", Vector3(-136, 3.0, 30), Vector3(-150, 0.5, 8)],
	["ruins", Vector3(-58, 3.0, -60), Vector3(-88, 2.0, -95)],
	["ford", Vector3(-6, 2.2, -24), Vector3(20, 0.0, -50)],
	["bridge", Vector3(30, 3.0, 175), Vector3(61, 1.0, 163)],
	["waterfall", Vector3(36, 3.0, -170), Vector3(30, 10.0, -212)],
	["overlook", Vector3(-25, 1.8, -5), Vector3(-90, 150, -620)],
	["overlook_back", Vector3(-30, 4.0, 12), Vector3(-25, 2.0, -12)],
	["camp", Vector3(100, 3.0, 138), Vector3(122, 1.0, 118)],
	["outpost", Vector3(132, 4.0, 22), Vector3(155, 2.0, -5)],
	["ogre", Vector3(70, 6.0, -122), Vector3(98, 1.0, -155)],
	["cave_mouth", Vector3(162, 2.2, -160), Vector3(180, 2.5, -181)],
	["cave_inside", Vector3(181, 1.6, -181), Vector3(196, 1.2, -199)],
	["aerial", Vector3(0, 230, 330), Vector3(0, 0, -40)],
]

var world: Node3D
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only: PackedStringArray = []
	for a in args:
		if a.begins_with("quality="):
			Settings.values[&"graphics_quality"] = int(a.substr(8))
		elif a.begins_with("only="):
			only = a.substr(5).split(",")
	get_window().size = Vector2i(1600, 900)
	world = load("res://scripts/world/world.gd").new()
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.current = true
	var q := Settings.quality()
	for v: Array in VIEWS:
		if not only.is_empty() and not only.has(v[0]):
			continue
		var p: Vector3 = v[1]
		var t: Vector3 = v[2]
		p.y += world.height_at(p.x, p.z)
		if t.y < 100.0:
			t.y += world.height_at(t.x, t.z)
		cam.global_position = p
		cam.look_at(t, Vector3.UP)
		for i in 24:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var fname := "res://tests/screens/%s_q%d.png" % [v[0], q]
		img.save_png(fname)
		print("saved %s  draw_calls=%d primitives=%d fps=%.0f" % [fname, dc, prims, Engine.get_frames_per_second()])
	get_tree().quit()
