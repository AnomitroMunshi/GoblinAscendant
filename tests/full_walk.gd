extends Node
## Lead smoke test of the integrated full game, run windowed with the --full user arg:
##   godot --path . res://tests/full_walk.tscn -- --full
## Boots main.tscn, then drives the player through each area: it teleports near an
## anchor, runs forward for a while, samples FPS, saves a gameplay-camera
## screenshot, and checks the player stays on the ground (no falling through,
## no stuck spawn).

const AREAS := [
	["glade", WorldLayout.START_GLADE],
	["woods", WorldLayout.WOLF_WOODS],
	["rescue", WorldLayout.RESCUE_SITE],
	["ruins", WorldLayout.RUINS],
	["overlook", WorldLayout.OVERLOOK],
	["spring", WorldLayout.SPRING],
	["camp", WorldLayout.ADVENTURER_CAMP],
	["outpost", WorldLayout.RAIDER_OUTPOST],
	["ogre", WorldLayout.OGRE_CLEARING],
	["cave", WorldLayout.CAVE_ENTRANCE],
	["marsh", WorldLayout.MARSH],
]

var _results: Array[String] = []


func _ready() -> void:
	# Autosaves fire while walking: keep the player's real save intact.
	var backup := FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else PackedByteArray()
	GameState.show_title = false
	add_child(load("res://scenes/main.tscn").instantiate())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens/walk"))
	await _wait(2.0)
	var p := GameState.player as CharacterBody3D
	if p == null:
		print("FULL WALK: FAIL no player")
		get_tree().quit(1)
		return
	for entry: Array in AREAS:
		var area_name: String = entry[0]
		var anchor: Vector3 = entry[1]
		# Start a few metres off the anchor and run toward it.
		var start := GameState.ground_point(anchor + Vector3(0, 0, 9)) + Vector3.UP * 1.0
		p.global_position = start
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		await _wait(0.6)
		Input.action_press(&"move_forward")
		var fps_sum := 0.0
		var frames := 0
		var t := 0.0
		while t < 2.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			fps_sum += Engine.get_frames_per_second()
			frames += 1
		Input.action_release(&"move_forward")
		await _wait(0.4)
		var ground := GameState.ground_height(p.global_position.x, p.global_position.z)
		var moved := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
		var ok := p.global_position.y > ground - 0.5 and p.global_position.y < ground + 3.0
		var line := "%-9s fps=%5.1f moved=%4.1fm on_ground=%s y=%.1f ground=%.1f" % [area_name, fps_sum / maxi(frames, 1), moved, ok, p.global_position.y, ground]
		print("FULL WALK: ", line)
		_results.append(line)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/screens/walk/%s.png" % area_name)
	print("FULL WALK: done")
	await _wait(1.0)  # let pending autosaves land before restoring
	if backup.is_empty():
		SaveManager.delete_save()
	else:
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
