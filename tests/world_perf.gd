extends Node
## World-only performance probe (World agent). Windowed:
##   "$G" --path . res://tests/world_perf.tscn [-- quality=0|1|2]
## Builds only the world, puts a camera at gameplay height (3.5 m behind and
## 2.2 m above a point near each area, looking ahead), lets it settle, then
## averages FPS / draw calls / primitives over 2 s.

const SPOTS := [
	["glade", WorldLayout.START_GLADE], ["woods", WorldLayout.WOLF_WOODS], ["rescue", WorldLayout.RESCUE_SITE],
	["ruins", WorldLayout.RUINS], ["overlook", WorldLayout.OVERLOOK], ["spring", WorldLayout.SPRING],
	["camp", WorldLayout.ADVENTURER_CAMP], ["outpost", WorldLayout.RAIDER_OUTPOST],
	["ogre", WorldLayout.OGRE_CLEARING], ["cave", WorldLayout.CAVE_ENTRANCE], ["marsh", WorldLayout.MARSH],
	["trail", Vector3(-55, 0, 125)], ["deep", Vector3(-140, 0, 60)], ["marsh_in", Vector3(-188, 0, -95)],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("quality="):
			Settings.values[&"graphics_quality"] = int(a.substr(8))
	get_window().size = Vector2i(1600, 900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world: Node3D = load("res://scripts/world/world.gd").new()
	add_child(world)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.current = true
	var worst := 1e9
	for s: Array in SPOTS:
		var p: Vector3 = s[1] + Vector3(0, 0, 9)
		var look := Vector3(p.x, 0, p.z - 10.0)
		var gp := Vector3(p.x, world.height_at(p.x, p.z), p.z)
		cam.global_position = gp + Vector3(0, 2.2, 3.5)
		cam.look_at(Vector3(look.x, world.height_at(look.x, look.z) + 1.0, look.z), Vector3.UP)
		for i in 60:
			await get_tree().process_frame
		var t := 0.0
		var frames := 0
		var dc := 0
		var prims := 0
		while t < 2.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			frames += 1
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var fps := frames / maxf(t, 0.001)
		worst = minf(worst, fps)
		print("WORLD PERF: %-9s fps=%6.1f draw_calls=%5d primitives=%8d" % [s[0], fps, dc / maxi(frames, 1), prims / maxi(frames, 1)])
	print("WORLD PERF: worst fps=%.1f (quality %d)" % [worst, Settings.quality()])
	get_tree().quit()
