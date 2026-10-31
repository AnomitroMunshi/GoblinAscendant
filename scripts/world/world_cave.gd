class_name WorldCave
extends Node3D
## Hollow Cave: a lumpy rock dome over the flat chamber at CAVE_INTERIOR and
## an arched tunnel to the mouth at CAVE_ENTRANCE (facing south-west toward
## the clearing). The terrain supplies the flat floor and the surrounding
## massif; this module adds the roof/walls (trimesh collision on WORLD),
## framing rocks, stalactites, glowing fungi and a dim warm light.
## The centre (radius ~3.5 m) is left clear for the quest hearth.

const ROCK_IN := Color(0.36, 0.33, 0.30)
const ROCK_OUT := Color(0.44, 0.43, 0.41)

var world: Node3D
var terrain: WorldTerrain
var rng := RandomNumberGenerator.new()
var floor_y := 0.0


func build(w: Node3D) -> void:
	name = "Cave"
	world = w
	terrain = w.terrain
	rng.seed = 6060
	floor_y = terrain.cave_floor
	var e := WorldLayout.CAVE_ENTRANCE
	var i := WorldLayout.CAVE_INTERIOR
	var dir := Vector3(i.x - e.x, 0, i.z - e.z).normalized()
	var shell := WorldGeo.new()
	_dome(shell, Vector3(i.x, floor_y, i.z), dir)
	_tunnel(shell, Vector3(e.x, floor_y, e.z) - dir * 3.5, Vector3(i.x, floor_y, i.z) - dir * (WorldLayout.CAVE_RADIUS - 1.0), dir)
	var mi := shell.commit(self, "CaveShell", WorldGeo.vertex_mat(0.95, true), true)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(mi.mesh.get_faces())
	var body := StaticBody3D.new()
	body.name = "CaveBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_dressing(body, dir)
	# keep vegetation away from the whole cave footprint
	world.add_blocker(i.x, i.z, WorldLayout.CAVE_RADIUS + 6.0)
	world.add_blocker((e.x + i.x) * 0.5, (e.z + i.z) * 0.5, 12.0)


## Lumpy hemisphere, open toward the tunnel.
func _dome(geo: WorldGeo, c: Vector3, dir: Vector3) -> void:
	var R := WorldLayout.CAVE_RADIUS + 3.5
	var H := 7.5
	var rings := 9
	var segs := 28
	var open_ang := atan2(-dir.z, -dir.x)  # direction from chamber toward the entrance
	var pts: Array = []
	for r in rings + 1:
		var v := float(r) / rings  # 0 = base, 1 = top
		var el := v * PI * 0.5
		var row: Array = []
		for s in segs:
			var a := TAU * s / segs
			var bump := 1.0 + 0.09 * sin(a * 5.0 + r * 1.3) + 0.06 * sin(a * 11.0 - r * 2.1)
			var rad := cos(el) * R * bump
			var p := c + Vector3(cos(a) * rad, sin(el) * H * (1.0 + 0.05 * sin(a * 7.0)) - 1.2, sin(a) * rad)
			row.append(p)
		pts.append(row)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a_mid := TAU * (s + 0.5) / segs
			# leave a doorway where the tunnel joins (low rings only)
			if absf(wrapf(a_mid - open_ang, -PI, PI)) < 0.42 and r < 5:
				continue
			var p00: Vector3 = pts[r][s]
			var p01: Vector3 = pts[r][s2]
			var p10: Vector3 = pts[r + 1][s]
			var p11: Vector3 = pts[r + 1][s2]
			var shade := 0.85 + 0.15 * sin(s * 1.7 + r)
			var col := ROCK_IN.darkened(0.35 + 0.15 * (1.0 - float(r) / rings)) * shade
			col.a = 0.0
			# outward-facing (CCW from outside); interior seen via double-sided material
			geo.quad(p00, p01, p11, p10, col, col)


## Half-tube arch from a to b.
func _tunnel(geo: WorldGeo, a: Vector3, b: Vector3, dir: Vector3) -> void:
	var side := Vector3(-dir.z, 0, dir.x)
	var segs := 12
	var steps := 8
	var rad := 5.8
	var hgt := 5.6
	var rows: Array = []
	for k in steps + 1:
		var t := float(k) / steps
		var p := a.lerp(b, t)
		var row: Array = []
		for s in segs + 1:
			var ang := PI * s / segs
			var bump := 1.0 + 0.07 * sin(ang * 6.0 + k * 1.9)
			row.append(p + side * cos(ang) * rad * bump + Vector3(0, sin(ang) * hgt * bump - 0.8, 0))
		rows.append(row)
	for k in steps:
		for s in segs:
			var col := ROCK_OUT.darkened(0.08 + 0.1 * sin(k * 1.3 + s))
			col.a = 0.0
			geo.quad(rows[k][s], rows[k + 1][s], rows[k + 1][s + 1], rows[k][s + 1], col, col)


func _dressing(body: StaticBody3D, dir: Vector3) -> void:
	var geo := WorldGeo.new()
	var glow := WorldGeo.new()
	var e := WorldLayout.CAVE_ENTRANCE
	var i := WorldLayout.CAVE_INTERIOR
	var side := Vector3(-dir.z, 0, dir.x)
	var mouth := Vector3(e.x, floor_y, e.z) - dir * 3.0
	# framing rocks around the mouth (left, right, lintel, shoulders)
	# natural opening: one broad overhanging lip sunk into the slope, rock
	# shoulders merging into the cliff, and rubble at the threshold
	var frame := [
		[Vector3(0, 5.6, 0) + dir * 9.0, Vector3(8.0, 5.5, 9.0)],
		[side * 8.0 + Vector3(0, 0.6, 0) + dir * 5.0, Vector3(4.0, 4.0, 5.0)],
		[-side * 8.2 + Vector3(0, 0.4, 0) + dir * 5.0, Vector3(4.2, 3.8, 5.0)],
		[side * 5.5 + Vector3(0, 4.4, 0) + dir * 6.5, Vector3(4.5, 4.0, 5.0)],
		[-side * 5.8 + Vector3(0, 4.2, 0) + dir * 6.5, Vector3(4.5, 4.0, 5.0)],
	]
	for f: Array in frame:
		var p: Vector3 = mouth + f[0]
		var sz: Vector3 = f[1]
		geo.rock(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) + rng.randf_range(-0.3, 0.3)), p), sz, ROCK_OUT, rng.randf() * 40.0, 0.45, 2, 0.18)
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = minf(sz.x, minf(sz.y, sz.z)) * 0.9
		cs.shape = sp
		cs.position = p
		body.add_child(cs)
	# threshold rubble and hanging roots under the lip
	for k in 10:
		var o := side * rng.randf_range(-5.0, 5.0) + dir * rng.randf_range(-3.0, 1.0)
		if absf(o.dot(side)) < 2.2:
			o += side * 2.6 * signf(o.dot(side) + 0.01)
		var s := rng.randf_range(0.25, 0.8)
		var rp := mouth + o
		rp.y = floor_y + s * 0.2
		geo.rock(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), rp), Vector3(s * 1.3, s * 0.7, s), ROCK_OUT.darkened(0.1), k * 5.1, 0.1)
	for k in 9:
		var rp := mouth + side * rng.randf_range(-4.0, 4.0) + dir * rng.randf_range(0.0, 1.5) + Vector3(0, 5.2, 0)
		var end := rp + Vector3(rng.randf_range(-0.3, 0.3), -rng.randf_range(1.0, 2.6), rng.randf_range(-0.3, 0.3))
		geo.limb(rp, end, 0.06, 0.015, 4, Color(0.34, 0.27, 0.2))
	# rubble just inside the walls of the chamber (not in the centre)
	var c := Vector3(i.x, floor_y, i.z)
	var open_ang := atan2(-dir.z, -dir.x)
	for k in 14:
		var a := TAU * k / 14.0 + rng.randf() * 0.2
		if absf(wrapf(a - open_ang, -PI, PI)) < 0.6:
			continue
		var r := WorldLayout.CAVE_RADIUS + rng.randf_range(0.5, 2.0)
		var s := rng.randf_range(0.6, 1.4)
		var p := c + Vector3(cos(a) * r, s * 0.3, sin(a) * r)
		geo.rock(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(s * 1.3, s, s * 1.1), ROCK_IN, k * 3.3, 0.15)
	# stalactites hanging from the dome
	for k in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.0, WorldLayout.CAVE_RADIUS)
		var el := acos(clampf(r / (WorldLayout.CAVE_RADIUS + 3.5), 0.0, 1.0))
		var top := c + Vector3(cos(a) * r, sin(el) * 7.5 - 1.4, sin(a) * r)
		var h := rng.randf_range(0.6, 1.8)
		if top.y - h - floor_y < 3.0:
			continue
		geo.limb(top, top - Vector3(0, h, 0), rng.randf_range(0.15, 0.35), 0.0, 6, ROCK_IN.lightened(0.05))
	# glowing fungi clusters along the walls
	for k in 9:
		var a := TAU * k / 9.0 + 0.3
		if absf(wrapf(a - open_ang, -PI, PI)) < 0.6:
			continue
		var r := WorldLayout.CAVE_RADIUS - rng.randf_range(0.2, 1.2)
		var base := c + Vector3(cos(a) * r, 0, sin(a) * r)
		for m in 4:
			var p := base + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			var h := rng.randf_range(0.1, 0.3)
			glow.cylinder(Transform3D(Basis(), p), 0.03, 0.03, h, 4, Color(0.6, 0.85, 0.8))
			glow.blob(Transform3D(Basis(), p + Vector3(0, h, 0)), Vector3(0.12, 0.05, 0.12), Color(0.45, 0.95, 0.85), 0, 0.0, 0.0, 1.0)
	var mi := geo.commit(self, "CaveDressing", WorldGeo.vertex_mat(0.95), true)
	world.register_vis(mi, 300.0)
	var gm := glow.commit(self, "CaveFungi", Palette.glow(Color(0.45, 0.95, 0.85), 1.6), false)
	world.register_vis(gm, 120.0)
	# dim warm light + a faint cool fill near the fungi
	var l := OmniLight3D.new()
	l.name = "CaveLight"
	l.light_color = Color(1.0, 0.72, 0.45)
	l.light_energy = 1.1
	l.omni_range = 17.0
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.position = c + Vector3(0, 4.5, 0)
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 20.0
	add_child(l)
