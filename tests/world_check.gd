extends Node
## Headless world verification (World agent).
## Run: "$G" --headless --path . res://tests/world_check.tscn
## Checks: height_at vs collision raycasts, anchors dry + gentle, path walk
## step heights, build time. Prints PASS/FAIL lines and exits with code.

var world: Node3D
var failures := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	world = load("res://scripts/world/world.gd").new()
	add_child(world)
	var build_ms := Time.get_ticks_msec() - t0
	_check(build_ms < 4000, "build time %d ms (< 4000)" % build_ms)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_collision()
	_check_anchors()
	_check_paths()
	_report_counts()
	print("WORLD CHECK: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + msg)


func _check_collision() -> void:
	var space := world.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	print("  physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"), " diag_main=", world.terrain.diag_main)
	var worst := 0.0
	var worst_alt := 0.0
	var worst_p := Vector2.ZERO
	var n := 0
	for i in 600:
		var x := rng.randf_range(-250.0, 250.0)
		var z := rng.randf_range(-250.0, 250.0)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400, z), Vector3(x, -100, z), Layers.WORLD)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		if hit.collider.name != "TerrainBody":
			continue
		n += 1
		var err := absf(hit.position.y - world.height_at(x, z))
		world.terrain.diag_main = not world.terrain.diag_main
		worst_alt = maxf(worst_alt, absf(hit.position.y - world.height_at(x, z)))
		world.terrain.diag_main = not world.terrain.diag_main
		if err > worst:
			worst = err
			worst_p = Vector2(x, z)
	print("  (other diagonal max err %.4f)" % worst_alt)
	_check(n > 400 and worst < 0.02, "height_at matches terrain collision at %d rays (max err %.4f m at %s)" % [n, worst, worst_p])


func _check_anchors() -> void:
	var L := WorldLayout
	var pts := {
		"START_GLADE": L.START_GLADE, "PLAYER_START": L.PLAYER_START, "WOLF_WOODS": L.WOLF_WOODS,
		"ALPHA_WOLF_DEN": L.ALPHA_WOLF_DEN, "RESCUE_SITE": L.RESCUE_SITE, "RUINS": L.RUINS,
		"RUINS_SHRINE": L.RUINS_SHRINE, "OVERLOOK": L.OVERLOOK, "ADVENTURER_CAMP": L.ADVENTURER_CAMP,
		"RAIDER_OUTPOST": L.RAIDER_OUTPOST, "OGRE_CLEARING": L.OGRE_CLEARING,
		"CAVE_ENTRANCE": L.CAVE_ENTRANCE, "CAVE_INTERIOR": L.CAVE_INTERIOR,
	}
	for k: StringName in L.CHECKPOINTS:
		pts["checkpoint_%s" % k] = L.CHECKPOINTS[k]
	for k: String in pts:
		var p: Vector3 = pts[k]
		var h: float = world.height_at(p.x, p.z)
		var wet: bool = world.is_in_water(Vector3(p.x, h + 0.1, p.z))
		var max_slope := 0.0
		for a in 8:
			var ang := TAU * a / 8.0
			var q := Vector2(p.x, p.z) + Vector2(cos(ang), sin(ang)) * 3.0
			max_slope = maxf(max_slope, world.slope_at(q.x, q.y))
		max_slope = maxf(max_slope, world.slope_at(p.x, p.z))
		_check(not wet and max_slope < 35.0, "%s h=%.2f dry=%s slope=%.1f" % [k, h, not wet, max_slope])
	var top: float = world.height_at(L.OVERLOOK.x, L.OVERLOOK.z)
	var base: float = world.height_at(L.START_GLADE.x, L.START_GLADE.z)
	_check(top > base + 8.0, "overlook is elevated (%.1f vs glade %.1f)" % [top, base])


func _check_paths() -> void:
	var worst := 0.0
	var worst_p := Vector3.ZERO
	var max_slope := 0.0
	for path: Array in WorldLayout.PATHS:
		for i in path.size() - 1:
			var a: Vector3 = path[i]
			var b: Vector3 = path[i + 1]
			var len := a.distance_to(b)
			var prev := INF
			for s in int(len) + 1:
				var p := a.lerp(b, s / len)
				var h: float = world.height_at(p.x, p.z)
				if prev != INF and absf(h - prev) > worst:
					worst = absf(h - prev)
					worst_p = p
				prev = h
	_check(worst < 1.0, "paths: max step %.2f m per 1 m at %s" % [worst, worst_p])


func _report_counts() -> void:
	var counts := {"MeshInstance3D": 0, "MultiMeshInstance3D": 0, "instances": 0, "CollisionShape3D": 0, "GPUParticles3D": 0, "OmniLight3D": 0, "nodes": 0}
	_count(world, counts)
	print("  counts: %s" % counts)
	if "stats" in world:
		print("  stats: %s" % world.stats)


func _count(n: Node, c: Dictionary) -> void:
	c["nodes"] += 1
	if n is MultiMeshInstance3D:
		c["MultiMeshInstance3D"] += 1
		if n.multimesh:
			c["instances"] += n.multimesh.instance_count
	elif n is MeshInstance3D:
		c["MeshInstance3D"] += 1
	elif n is CollisionShape3D:
		c["CollisionShape3D"] += 1
	elif n is GPUParticles3D:
		c["GPUParticles3D"] += 1
	elif n is OmniLight3D:
		c["OmniLight3D"] += 1
	for ch in n.get_children():
		_count(ch, c)
