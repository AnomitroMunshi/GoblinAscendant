class_name WorldLandmarks
extends Node3D
## Hand-composed areas: Sunlit Glade, Howling Woods den, rescue camp, Mossy
## Ruins, Adventurers' Camp, Raider Outpost, Ogre's Clearing, the overlook
## and small secret nooks. Static geometry is merged per area (one mesh +
## one StaticBody with simple shapes each). Openings are sized for a 1.1 m
## goblin and a future 1.5 m hobgoblin; steps are <= 0.25 m.

const STONE := Color(0.52, 0.50, 0.45)
const STONE_DARK := Color(0.40, 0.39, 0.36)
const MOSS := Color(0.30, 0.38, 0.18)
const WOOD := Color(0.40, 0.28, 0.18)
const WOOD_DARK := Color(0.28, 0.20, 0.14)
const BONE := Color(0.86, 0.82, 0.70)
const HIDE := Color(0.50, 0.40, 0.28)

var world: Node3D
var terrain: WorldTerrain
var rng := RandomNumberGenerator.new()
var stats := {"areas": 0, "secrets": 0}
var _secrets: Array = []  # [id, pos, radius]
var spring_interactable: Interactable
var _spring_ready := true
const SPRING_COOLDOWN := 60.0
const SPRING_PROMPT := "Drink from the spring"
const SPRING_WAIT_PROMPT := "The water is still settling"


func build(w: Node3D) -> void:
	name = "Landmarks"
	world = w
	terrain = w.terrain
	rng.seed = 1234
	_glade()
	_den()
	_rescue()
	_ruins()
	_camp()
	_outpost()
	_ogre()
	_overlook()
	_secret_spots()
	_still_waters()


# ------------------------------------------------------------------ helpers
func gy(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func gp(x: float, z: float, up: float = 0.0) -> Vector3:
	return Vector3(x, terrain.height_at(x, z) + up, z)


var _tree_body: StaticBody3D


## Shared body for dead trees / snags placed by the areas (Layers.TREES).
func tree_body() -> StaticBody3D:
	if _tree_body == null:
		_tree_body = StaticBody3D.new()
		_tree_body.name = "AreaTreesBody"
		_tree_body.collision_layer = Layers.TREES
		_tree_body.collision_mask = 0
		add_child(_tree_body)
	return _tree_body


func _body(n: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = Layers.WORLD
	b.collision_mask = 0
	add_child(b)
	return b


func _box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = xf
	body.add_child(cs)


func _cyl(body: StaticBody3D, base: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = base + Vector3(0, h * 0.5, 0)
	body.add_child(cs)


func _sphere(body: StaticBody3D, c: Vector3, r: float) -> void:
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	cs.shape = s
	cs.position = c
	body.add_child(cs)


func yaw_xf(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## Boulder: rendered in geo, sphere-ish collision (scaled down a bit).
func boulder(geo: WorldGeo, body: StaticBody3D, x: float, z: float, size: Vector3, moss: float = 0.5, col: Color = Palette.ROCK) -> void:
	var p := gp(x, z, size.y * 0.25)
	geo.rock(yaw_xf(p, rng.randf() * TAU), size, col.darkened(rng.randf() * 0.12), rng.randf() * 50.0, moss)
	if body and size.y > 0.5:
		var r := minf(size.x, size.z) * 0.85
		var cs := CollisionShape3D.new()
		var s := CapsuleShape3D.new()
		s.radius = r
		s.height = maxf(size.y * 2.0, r * 2.0)
		cs.shape = s
		cs.position = p
		body.add_child(cs)
	world.add_blocker(x, z, maxf(size.x, size.z) + 0.6)


func _commit(geo: WorldGeo, n: String, double_sided: bool = false) -> MeshInstance3D:
	var mi := geo.commit(self, n, WorldGeo.vertex_mat(0.9, double_sided), true)
	world.register_vis(mi, 450.0)
	return mi


func _foliage_commit(geo: WorldGeo, n: String) -> void:
	var mi := geo.commit(self, n, WorldTextures.leaf_mat("props", 0.8), true)
	world.register_vis(mi, 300.0)


## Ring of stones + charred logs (+ optional fire).
func campfire(geo: WorldGeo, c: Vector3, lit: bool, light: bool, scale_f: float = 1.0) -> void:
	for k in 9:
		var a := TAU * k / 9.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 0.85 * scale_f
		geo.rock(yaw_xf(Vector3(p.x, gy(p.x, p.z) + 0.08, p.z), rng.randf() * TAU), Vector3(0.28, 0.2, 0.24) * scale_f, STONE_DARK, k * 3.1, 0.0)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a)) * 0.55 * scale_f
		geo.limb(c + d + Vector3(0, 0.1, 0), c - d * 0.3 + Vector3(0, 0.35 * scale_f, 0), 0.09 * scale_f, 0.07 * scale_f, 5, Color(0.16, 0.12, 0.1))
	geo.cylinder(yaw_xf(c, 0.0), 0.6 * scale_f, 0.55 * scale_f, 0.04, 8, Color(0.12, 0.1, 0.09))
	if lit:
		world.atmosphere.add_fire(self, c + Vector3(0, 0.15, 0), scale_f, light)
	if lit:
		Audio.create_loop(&"fire_loop", _sound_node(c))
	world.add_blocker(c.x, c.z, 1.6 * scale_f)


func _sound_node(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p + Vector3.UP * 0.5
	add_child(n)
	return n


func tent(geo: WorldGeo, body: StaticBody3D, c: Vector3, yaw: float, length: float, width: float, height: float, col: Color) -> void:
	var xf := yaw_xf(c + Vector3(0, -0.05, 0), yaw)
	geo.tent(xf, length, width, height, col, col.darkened(0.25))
	# poles
	for s: float in [-1.0, 1.0]:
		var p := xf * Vector3(s * (length * 0.5 + 0.05), 0, 0)
		geo.limb(p, p + Vector3(0, height + 0.25, 0), 0.05, 0.04, 5, WOOD_DARK)
	_box(body, yaw_xf(c + Vector3(0, height * 0.35, 0), yaw), Vector3(length, height * 0.7, width * 0.75))
	world.add_blocker(c.x, c.z, maxf(length, width) * 0.6)


func crate(geo: WorldGeo, body: StaticBody3D, p: Vector3, s: float, yaw: float) -> void:
	var xf := yaw_xf(p + Vector3(0, s * 0.5 - 0.03, 0), yaw)
	geo.box(xf, Vector3(s, s, s), WOOD.lightened(0.05))
	# slats
	for k in 2:
		geo.box(xf.translated_local(Vector3(0, (k - 0.5) * s * 0.6, s * 0.5)), Vector3(s * 1.02, s * 0.12, 0.04), WOOD_DARK)
	if body:
		_box(body, xf, Vector3(s, s, s))


func barrel(geo: WorldGeo, body: StaticBody3D, p: Vector3) -> void:
	geo.cylinder(yaw_xf(p, 0.0), 0.32, 0.36, 0.45, 10, WOOD, WOOD.lightened(0.05), false)
	geo.cylinder(yaw_xf(p + Vector3(0, 0.45, 0), 0.0), 0.36, 0.32, 0.45, 10, WOOD.lightened(0.05), WOOD.lightened(0.1))
	for y: float in [0.12, 0.45, 0.78]:
		geo.cylinder(yaw_xf(p + Vector3(0, y, 0), 0.0), 0.37, 0.37, 0.05, 10, Color(0.3, 0.3, 0.3), Color(0.3, 0.3, 0.3), false)
	if body:
		_cyl(body, p, 0.36, 0.9)


func bones(geo: WorldGeo, c: Vector3, n: int, spread: float, big: float = 1.0) -> void:
	for k in n:
		var a := rng.randf() * TAU
		var r := rng.randf() * spread
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = gy(p.x, p.z) + 0.06 * big
		var d := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)) * rng.randf_range(0.3, 0.7) * big
		geo.limb(p - d, p + d, 0.05 * big, 0.04 * big, 5, BONE)
		geo.blob(yaw_xf(p - d, 0.0), Vector3(0.08, 0.07, 0.08) * big, BONE, 0, 0.0, 0.0, 0.85)
		geo.blob(yaw_xf(p + d, 0.0), Vector3(0.08, 0.07, 0.08) * big, BONE, 0, 0.0, 0.0, 0.85)
	# a skull
	var sp := c + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * spread * 0.5
	sp.y = gy(sp.x, sp.z) + 0.12 * big
	geo.blob(yaw_xf(sp, 0.0), Vector3(0.16, 0.14, 0.2) * big, BONE, 1, 0.05, 1.0, 0.8)


func stake(geo: WorldGeo, p: Vector3, h: float, r: float, lean: Vector3 = Vector3.ZERO) -> void:
	var top := p + Vector3(0, h, 0) + lean
	geo.limb(p + Vector3(0, -0.3, 0), top, r, r * 0.9, 6, WOOD.darkened(rng.randf() * 0.2))
	geo.limb(top, top + (top - p).normalized() * r * 2.2, r * 0.9, 0.0, 6, WOOD.lightened(0.1))


func bush_cluster(fgeo: WorldGeo, x: float, z: float, s: float) -> void:
	var start := fgeo.cols.size()
	var base := gp(x, z, 0.0)
	var tint := Color(0.85, 0.9, 0.8).lerp(Color(1.0, 1.0, 0.85), rng.randf())
	for k in 6:
		var o := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.3, 0.9), rng.randf_range(-0.7, 0.7)) * s
		WorldFlora._cluster(fgeo, rng, base + o, base - Vector3(0, 0.5, 0), 0.9 * s, 3, WorldTextures.CELL_BROAD if k % 3 else WorldTextures.CELL_SMALL, tint)
	for i in range(start, fgeo.cols.size()):
		fgeo.cols[i].a = 0.35


# ------------------------------------------------------------------ areas
func _glade() -> void:
	var geo := WorldGeo.new()
	var fgeo := WorldGeo.new()
	var body := _body("GladeBody")
	# Large mossy fallen log on the west side of the glade.
	var a := gp(-34, 166, 0.55)
	var b := gp(-25, 160, 0.5)
	geo.limb(a, b, 0.72, 0.62, 12, WOOD.darkened(0.1), WOOD)
	# pale end-grain rings on the snapped ends
	var axis := (b - a).normalized()
	for e2: Array in [[a, -axis, 0.72], [b, axis, 0.62]]:
		var ep: Vector3 = e2[0]
		var en: Vector3 = e2[1]
		var er: float = e2[2]
		var eside := en.cross(Vector3.UP).normalized()
		var eup := eside.cross(en).normalized()
		for k in 12:
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			var c0 := ep + en * 0.02
			geo.tri(c0, c0 + (eside * cos(a1) + eup * sin(a1)) * er * 0.97, c0 + (eside * cos(a0) + eup * sin(a0)) * er * 0.97, Color(0.62, 0.55, 0.46))
			geo.tri(c0, c0 + (eside * cos(a1) + eup * sin(a1)) * er * 0.6, c0 + (eside * cos(a0) + eup * sin(a0)) * er * 0.6, Color(0.5, 0.43, 0.35))
	# broken stub branches + exposed roots at the base end
	geo.limb(a + Vector3(0, 0.2, 0), a + Vector3(-1.2, 1.6, -0.6), 0.25, 0.08, 6, WOOD)
	for k in 5:
		var ang := TAU * k / 5.0
		geo.limb(a, a + Vector3(cos(ang) * 1.2, sin(ang) * 1.0, sin(ang * 2.0) * 0.6) + (a - b).normalized() * 0.6, 0.18, 0.05, 5, WOOD_DARK)
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var lb := Basis.looking_at((b - a).normalized(), Vector3.UP)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.7
	cap.height = len + 1.4
	cs.shape = cap
	cs.transform = Transform3D(lb * Basis(Vector3.RIGHT, PI * 0.5), mid)
	tree_body().add_child(cs)
	world.add_blocker(mid.x, mid.z, 5.5)
	# mushrooms along the log
	for k in 7:
		var t := rng.randf()
		var p := a.lerp(b, t) + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
		p.y = gy(p.x, p.z)
		var h := rng.randf_range(0.12, 0.28)
		geo.cylinder(yaw_xf(p, 0.0), 0.03, 0.025, h, 5, Color(0.9, 0.86, 0.76))
		geo.blob(yaw_xf(p + Vector3(0, h, 0), 0.0), Vector3(0.1, 0.05, 0.1) * (1.0 + h * 2.0), Color(0.72, 0.32, 0.2), 0, 0.0, 0.0, 0.8)
	# pond rim stones + reeds
	var pc := WorldTerrain.POND
	for k in 16:
		var ang := TAU * k / 16.0 + rng.randf() * 0.2
		var r := WorldTerrain.POND_RADIUS + rng.randf_range(0.3, 1.3)
		var s := rng.randf_range(0.25, 0.6)
		boulder(geo, null, pc.x + cos(ang) * r, pc.z + sin(ang) * r, Vector3(s * 1.3, s * 0.6, s), 0.6)
	for k in 30:
		var ang := rng.randf() * TAU
		var r := WorldTerrain.POND_RADIUS + rng.randf_range(-0.6, 0.6)
		var p := gp(pc.x + cos(ang) * r, pc.z + sin(ang) * r)
		var h := rng.randf_range(0.5, 1.0)
		fgeo.limb(p, p + Vector3(rng.randf_range(-0.1, 0.1), h, rng.randf_range(-0.1, 0.1)), 0.025, 0.01, 4, Color(0.42, 0.52, 0.24), Color(0.55, 0.58, 0.3), 0.0, 0.8)
	# a pair of old standing stones framing the view north
	for p: Vector3 in [Vector3(-30, 0, 148), Vector3(8, 0, 146)]:
		var g := gp(p.x, p.z)
		var yaw := rng.randf() * TAU
		geo.box(Transform3D(Basis(Vector3.UP, yaw).rotated(Vector3(1, 0, 0), 0.05), g + Vector3(0, 1.1, 0)), Vector3(0.8, 2.6, 0.55), STONE.darkened(0.08), MOSS)
		_box(body, yaw_xf(g + Vector3(0, 1.1, 0), yaw), Vector3(0.8, 2.6, 0.55))
		world.add_blocker(p.x, p.z, 1.5)
	# flower bushes at the glade edge
	for k in 10:
		var ang := TAU * k / 10.0 + 0.3
		bush_cluster(fgeo, WorldLayout.START_GLADE.x + cos(ang) * 30.0, WorldLayout.START_GLADE.z + sin(ang) * 26.0, rng.randf_range(0.8, 1.3))
	_commit(geo, "GladeProps")
	_foliage_commit(fgeo, "GladeFoliage")
	stats["areas"] += 1


func _den() -> void:
	var geo := WorldGeo.new()
	var body := _body("DenBody")
	var c := WorldLayout.ALPHA_WOLF_DEN
	var open_dir := atan2(WorldLayout.WOLF_WOODS.z - c.z, WorldLayout.WOLF_WOODS.x - c.x)
	for k in 9:
		var ang := open_dir + PI * 0.45 + (PI * 1.1) * k / 8.0
		var r := rng.randf_range(10.0, 12.5)
		var s := rng.randf_range(2.2, 3.8)
		boulder(geo, body, c.x + cos(ang) * r, c.z + sin(ang) * r, Vector3(s * 1.2, s * 0.9, s), 0.3, Palette.ROCK_DARK.lerp(Palette.ROCK, 0.4))
	# overhanging slab across two rocks at the back = the den mouth
	var back := Vector3(c.x - cos(open_dir) * 9.0, 0, c.z - sin(open_dir) * 9.0)
	var slab_p := gp(back.x, back.z, 2.7)
	geo.rock(yaw_xf(slab_p, open_dir), Vector3(3.6, 0.8, 2.6), Palette.ROCK_DARK, 7.0, 0.5)
	_box(body, yaw_xf(slab_p, open_dir), Vector3(2.4, 1.0, 5.0))
	for s: float in [-1.0, 1.0]:
		var side := Vector3(-sin(open_dir), 0, cos(open_dir)) * s * 2.6
		boulder(geo, body, back.x + side.x, back.z + side.z, Vector3(1.6, 2.0, 1.6), 0.2, Palette.ROCK_DARK)
	bones(geo, Vector3(c.x, 0, c.z), 14, 7.0)
	bones(geo, back + Vector3(cos(open_dir), 0, sin(open_dir)) * 2.0, 6, 1.5)
	# scratched dead tree
	var dt := gp(c.x + cos(open_dir + 1.9) * 7.0, c.z + sin(open_dir + 1.9) * 7.0)
	geo.limb(dt, dt + Vector3(0.3, 6.0, 0.2), 0.32, 0.12, 7, Color(0.32, 0.27, 0.22))
	geo.limb(dt + Vector3(0.2, 3.8, 0.1), dt + Vector3(1.8, 5.5, 0.6), 0.12, 0.04, 5, Color(0.32, 0.27, 0.22))
	geo.limb(dt + Vector3(0.25, 4.6, 0.1), dt + Vector3(-1.2, 6.4, -0.8), 0.1, 0.03, 5, Color(0.32, 0.27, 0.22))
	_cyl(tree_body(), dt, 0.32, 6.0)
	world.add_blocker(dt.x, dt.z, 1.0)
	_commit(geo, "WolfDen")
	stats["areas"] += 1


func _rescue() -> void:
	var geo := WorldGeo.new()
	var body := _body("RescueBody")
	var c := WorldLayout.RESCUE_SITE
	# ragged stake ring with gaps toward the paths
	var gaps := [atan2(85.0 - c.z, -130.0 - c.x), atan2(-40.0 - c.z, -120.0 - c.x)]
	for k in 34:
		var ang := TAU * k / 34.0
		var skip := false
		for g: float in gaps:
			if absf(wrapf(ang - g, -PI, PI)) < 0.3:
				skip = true
		if skip or rng.randf() < 0.15:
			continue
		var r := 14.0 + rng.randf_range(-0.4, 0.4)
		var p := gp(c.x + cos(ang) * r, c.z + sin(ang) * r)
		var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.2, 0.6)
		stake(geo, p, rng.randf_range(1.5, 2.3), 0.12, lean)
		_cyl(body, p, 0.18, 2.0)
	# wooden cage / pen (door open) east of the centre
	var cage := gp(c.x + 6.0, c.z - 3.0)
	var yaw := 0.4
	var cx := yaw_xf(cage, yaw)
	var cs := 2.6
	geo.box(cx.translated_local(Vector3(0, 0.08, 0)), Vector3(cs, 0.16, cs), WOOD_DARK)
	geo.box(cx.translated_local(Vector3(0, 2.0, 0)), Vector3(cs + 0.2, 0.14, cs + 0.2), WOOD_DARK)
	for i in 6:
		var u := -cs * 0.5 + cs * i / 5.0
		for side in 4:
			if side == 3 and i > 0 and i < 5:
				continue  # open door side
			var p: Vector3
			match side:
				0: p = Vector3(u, 0, -cs * 0.5)
				1: p = Vector3(u, 0, cs * 0.5)
				2: p = Vector3(-cs * 0.5, 0, u)
				_: p = Vector3(cs * 0.5, 0, u)
			geo.limb(cx * p, cx * (p + Vector3(0, 2.0, 0)), 0.05, 0.05, 5, WOOD)
	# door hanging open
	var hinge := cx * Vector3(cs * 0.5, 0, cs * 0.5)
	for i in 4:
		var d := Vector3(cos(yaw + 0.9), 0, -sin(yaw + 0.9)) * (0.35 + i * 0.55)
		geo.limb(hinge + d, hinge + d + Vector3(0, 1.9, 0), 0.04, 0.04, 4, WOOD)
	_box(body, cx.translated_local(Vector3(0, 1.0, -cs * 0.5)), Vector3(cs, 2.0, 0.15))
	_box(body, cx.translated_local(Vector3(0, 1.0, cs * 0.5)), Vector3(cs, 2.0, 0.15))
	_box(body, cx.translated_local(Vector3(-cs * 0.5, 1.0, 0)), Vector3(0.15, 2.0, cs))
	world.add_blocker(cage.x, cage.z, 2.5)
	# smouldering campfire, lean-to, sacks, a crude totem
	campfire(geo, gp(c.x - 4.0, c.z + 4.5), true, false, 0.8)
	tent(geo, body, gp(c.x - 8.0, c.z - 5.0), 0.8, 3.4, 2.8, 1.6, HIDE.darkened(0.1))
	for k in 4:
		var p := gp(c.x - 9.5 + k * 0.7, c.z + 0.5 + rng.randf())
		geo.blob(yaw_xf(p + Vector3(0, 0.25, 0), rng.randf()), Vector3(0.3, 0.28, 0.25), Color(0.55, 0.47, 0.33), 1, 0.1, k, 0.75)
	crate(geo, body, gp(c.x + 3.0, c.z + 8.0), 0.8, 0.3)
	crate(geo, body, gp(c.x + 3.9, c.z + 8.4), 0.6, 0.9)
	var tp := gp(c.x + 1.0, c.z - 9.0)
	geo.limb(tp, tp + Vector3(0, 3.2, 0), 0.16, 0.13, 6, WOOD_DARK)
	geo.box(yaw_xf(tp + Vector3(0, 2.6, 0), 0.0), Vector3(1.6, 0.12, 0.12), WOOD_DARK)
	geo.blob(yaw_xf(tp + Vector3(0, 3.35, 0), 0.0), Vector3(0.22, 0.2, 0.26), BONE, 1, 0.05, 2.0, 0.8)
	for s: float in [-0.7, 0.7]:
		geo.limb(tp + Vector3(s, 2.6, 0), tp + Vector3(s * 1.1, 2.0, 0.1), 0.02, 0.02, 3, Color(0.6, 0.15, 0.1))
	_cyl(body, tp, 0.2, 3.2)
	world.add_blocker(tp.x, tp.z, 1.0)
	_commit(geo, "RescueCamp")
	stats["areas"] += 1


func _ruins() -> void:
	var geo := WorldGeo.new()
	var fgeo := WorldGeo.new()
	var body := _body("RuinsBody")
	var c := WorldLayout.RUINS
	var sh := WorldLayout.RUINS_SHRINE
	# flagstone court around the shrine (flush, no collision)
	var fy := gy(sh.x, sh.z)
	for i in range(-4, 5):
		for j in range(-4, 5):
			if Vector2(i, j).length() > 4.6 or rng.randf() < 0.12:
				continue
			var p := Vector3(sh.x + i * 1.2 + rng.randf_range(-0.08, 0.08), 0, sh.z + j * 1.2 + rng.randf_range(-0.08, 0.08))
			p.y = maxf(gy(p.x, p.z), fy) + 0.02
			geo.box(yaw_xf(p, rng.randf_range(-0.05, 0.05)), Vector3(1.1, 0.06, 1.1), STONE.darkened(rng.randf() * 0.15), STONE.lerp(MOSS, rng.randf() * 0.4))
	# colonnade ring around the shrine court (some broken / fallen)
	for k in 10:
		var ang := TAU * k / 10.0 + 0.15
		var p := gp(sh.x + cos(ang) * 8.5, sh.z + sin(ang) * 8.5)
		if k == 3 or k == 7:
			# fallen column: drums lying on the ground
			var d := Vector3(cos(ang + 1.2), 0, sin(ang + 1.2))
			for m in 3:
				var q := p + d * (m * 1.05 + 0.6)
				q.y = gy(q.x, q.z) + 0.4
				geo.limb(q - d * 0.48, q + d * 0.48, 0.4, 0.4, 10, STONE.darkened(0.05), STONE)
			_box(body, Transform3D(Basis.looking_at(d, Vector3.UP), p + d * 1.65 + Vector3(0, 0.4, 0)), Vector3(0.8, 0.8, 3.2))
			continue
		var h := 5.5 if k % 3 != 1 else rng.randf_range(1.2, 3.0)
		geo.box(yaw_xf(p + Vector3(0, 0.2, 0), ang), Vector3(1.3, 0.4, 1.3), STONE_DARK, MOSS)
		geo.cylinder(yaw_xf(p + Vector3(0, 0.4, 0), ang), 0.42, 0.38, h - 0.4, 10, STONE, STONE.lerp(MOSS, 0.3 if h < 5.0 else 0.0), true, 0.0, 0.0, 0.06 if h < 5.0 else 0.0, k)
		if h >= 5.0:
			geo.box(yaw_xf(p + Vector3(0, h + 0.15, 0), ang), Vector3(1.1, 0.3, 1.1), STONE.lightened(0.04), MOSS)
		_cyl(body, p, 0.5, h)
		world.add_blocker(p.x, p.z, 1.0)
	# two arches on the approach from the overlook path
	for e: Array in [[Vector3(-64, 0, -70), 0.65], [Vector3(-104, 0, -78), -0.3]]:
		var ap: Vector3 = e[0]
		var yaw: float = e[1]
		var base := gp(ap.x, ap.z)
		var xf := yaw_xf(base, yaw)
		# piers built from irregular courses, slightly offset and weathered
		for s: float in [-1.0, 1.0]:
			var pier := xf * Vector3(s * 2.1, 0, 0)
			var ph := 4.4 if s < 0.0 else 3.6
			var cy := -0.3
			while cy < ph:
				var bh := rng.randf_range(0.45, 0.7)
				var off := Vector3(rng.randf_range(-0.08, 0.08), cy + bh * 0.5, rng.randf_range(-0.08, 0.08))
				var bb2 := Basis(Vector3.UP, yaw + rng.randf_range(-0.06, 0.06)).rotated(Vector3(0, 0, 1), rng.randf_range(-0.03, 0.03))
				geo.box(Transform3D(bb2, pier + off), Vector3(1.0 + rng.randf_range(-0.1, 0.1), bh - 0.03, 1.2 + rng.randf_range(-0.1, 0.1)), STONE.darkened(rng.randf() * 0.18))
				cy += bh
			_box(body, yaw_xf(pier + Vector3(0, ph * 0.5, 0), yaw), Vector3(1.0, ph, 1.2))
		# voussoirs: the arch is broken - the right-hand third has collapsed
		for m in 9:
			if m <= 2:
				continue
			var t := PI * m / 8.0
			var q := xf * Vector3(cos(t) * 2.1, 4.2 + sin(t) * 1.6, 0)
			var bb := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), t - PI * 0.5 + rng.randf_range(-0.05, 0.05))
			geo.box(Transform3D(bb, q), Vector3(0.85, 0.52, 1.1), STONE.darkened(rng.randf() * 0.15))
		# fallen voussoirs and rubble, half buried at the foot of the broken side
		for m in 7:
			var rp := xf * Vector3(rng.randf_range(1.5, 4.5), 0, rng.randf_range(-1.8, 1.8))
			rp.y = gy(rp.x, rp.z) + rng.randf_range(-0.15, 0.1)
			geo.box(Transform3D(Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU), rp), Vector3(0.85, 0.5, 1.0) * rng.randf_range(0.5, 1.0), STONE.darkened(0.1))
		_box(body, yaw_xf(xf * Vector3(-1.0, 5.3, 0), yaw), Vector3(3.0, 1.0, 1.2))
		# ferns and grass growing at the base
		for k in 3:
			var fp := xf * Vector3(rng.randf_range(-2.8, 2.8), 0.0, rng.randf_range(-1.0, 1.0))
			fp.y = gy(fp.x, fp.z) + 0.3
			WorldFlora._cluster(fgeo, rng, fp, fp - Vector3(0, 0.6, 0), 0.9, 3, WorldTextures.CELL_FERN, Color(0.85, 0.9, 0.78))
		world.add_blocker(base.x, base.z, 3.2)
		for k in 2:
			bush_cluster(fgeo, base.x + rng.randf_range(-3, 3), base.z + rng.randf_range(-2, 2), 0.8)
	# broken perimeter walls (block courses with gaps)
	var walls := [[Vector3(-112, 0, -110), Vector3(-100, 0, -118)], [Vector3(-60, 0, -112), Vector3(-72, 0, -120)],
		[Vector3(-118, 0, -92), Vector3(-116, 0, -104)], [Vector3(-52, 0, -92), Vector3(-50, 0, -102)]]
	for wseg: Array in walls:
		var a: Vector3 = wseg[0]
		var b: Vector3 = wseg[1]
		var len := Vector2(b.x - a.x, b.z - a.z).length()
		var yaw := atan2(b.x - a.x, b.z - a.z)
		var n := int(len / 1.3)
		for k in n:
			var t := (k + 0.5) / n
			var p := a.lerp(b, t)
			var courses := int(clampf(3.0 - absf(t - 0.4) * 5.0 + rng.randf_range(-0.6, 1.2), 1.0, 4.0))
			for m in courses:
				var q := gp(p.x, p.z, 0.3 + m * 0.6)
				geo.box(yaw_xf(q, yaw + rng.randf_range(-0.04, 0.04)), Vector3(0.9, 0.58, 1.25), STONE.darkened(rng.randf() * 0.12), MOSS if m == courses - 1 else Color(0, 0, 0, 0))
			_box(body, yaw_xf(gp(p.x, p.z, courses * 0.3), yaw), Vector3(0.9, courses * 0.6, 1.3))
		world.add_blocker((a.x + b.x) * 0.5, (a.z + b.z) * 0.5, len * 0.55)
		# fallen blocks
		for k in 3:
			var q := a.lerp(b, rng.randf()) + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0))
			geo.box(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3(1, 0, 0), rng.randf_range(-0.2, 0.2)), gp(q.x, q.z, 0.22)), Vector3(0.9, 0.5, 1.2), STONE.darkened(0.1), MOSS)
	# raised terrace with gentle steps (0.22 m rise each)
	var tc := gp(-68, -96)
	var tyaw := 0.5
	var txf := yaw_xf(tc, tyaw)
	var top_h := 0.88
	geo.box(txf.translated_local(Vector3(0, top_h * 0.5 - 0.3, 0)), Vector3(7.0, top_h + 0.6, 6.0), STONE_DARK, STONE.lerp(MOSS, 0.25))
	_box(body, txf.translated_local(Vector3(0, top_h * 0.5 - 0.3, 0)), Vector3(7.0, top_h + 0.6, 6.0))
	for st in 4:
		var h := top_h - (st + 1) * 0.22
		if h <= 0.0:
			break
		var off := 3.0 + 0.4 + st * 0.5
		geo.box(txf.translated_local(Vector3(0, h * 0.5 - 0.15, off)), Vector3(4.0, h + 0.3, 0.6), STONE.darkened(0.05 * st), STONE.lerp(MOSS, 0.2))
		_box(body, txf.translated_local(Vector3(0, h * 0.5 - 0.15, off)), Vector3(4.0, h + 0.3, 0.6))
	# a toppled statue on the terrace
	var head := txf * Vector3(1.5, top_h + 0.45, -1.0)
	geo.blob(yaw_xf(head, 0.3), Vector3(0.5, 0.55, 0.5), STONE.lightened(0.05), 1, 0.06, 4.0, 0.8, STONE.lerp(MOSS, 0.5))
	geo.box(Transform3D(Basis(Vector3.UP, tyaw).rotated(Vector3(0, 0, 1), 1.45), txf * Vector3(-0.8, top_h + 0.45, -1.0)), Vector3(0.9, 2.6, 0.7), STONE, MOSS)
	world.add_blocker(tc.x, tc.z, 5.5)
	# overgrowth: ivy blobs on stones + a couple of trees growing in the ruins
	for k in 14:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(10.0, 32.0)
		var x := c.x + cos(ang) * r
		var z := c.z + sin(ang) * r
		if Vector2(x - sh.x, z - sh.z).length() < 7.0 or world.is_blocked(x, z, 0.5):
			continue
		bush_cluster(fgeo, x, z, rng.randf_range(0.7, 1.2))
	world.extra_trees.append([Vector3(-74, 0, -110), 1, 1.2])
	world.extra_trees.append([Vector3(-98, 0, -72), 0, 1.35])
	world.extra_trees.append([Vector3(-110, 0, -98), 3, 1.1])
	_commit(geo, "MossyRuins")
	_foliage_commit(fgeo, "RuinsFoliage")
	stats["areas"] += 1


func _camp() -> void:
	var geo := WorldGeo.new()
	var body := _body("CampBody")
	var c := WorldLayout.ADVENTURER_CAMP
	var fire := gp(c.x, c.z)
	campfire(geo, fire, true, true, 1.0)
	# log benches around the fire
	for k in 3:
		var ang := TAU * k / 3.0 + 0.5
		var p := gp(c.x + cos(ang) * 3.0, c.z + sin(ang) * 3.0, 0.25)
		var d := Vector3(-sin(ang), 0, cos(ang)) * 1.1
		geo.limb(p - d, p + d, 0.24, 0.22, 8, WOOD, WOOD.lightened(0.08))
		_box(body, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), p), Vector3(0.45, 0.45, 2.2))
	# tents in a loose arc on the north side (muted cloth)
	var cols := [Color(0.36, 0.42, 0.52), Color(0.56, 0.30, 0.24), Color(0.62, 0.56, 0.44)]
	for k in 3:
		var ang := -PI * 0.5 + (k - 1) * 0.9
		var p := gp(c.x + cos(ang) * 10.0, c.z + sin(ang) * 10.0)
		tent(geo, body, p, ang + PI * 0.5, 3.6, 3.0, 2.1, cols[k])
		# bedroll in front
		var br := gp(c.x + cos(ang) * 7.4, c.z + sin(ang) * 7.4, 0.08)
		geo.limb(br - Vector3(cos(ang + 1.57), 0, sin(ang + 1.57)) * 0.8, br + Vector3(cos(ang + 1.57), 0, sin(ang + 1.57)) * 0.8, 0.14, 0.14, 7, cols[k].darkened(0.2))
	# supplies
	crate(geo, body, gp(c.x + 7.0, c.z + 4.0), 0.9, 0.2)
	crate(geo, body, gp(c.x + 7.9, c.z + 4.6), 0.7, 0.7)
	crate(geo, body, gp(c.x + 7.3, c.z + 4.3) + Vector3(0, 0.88, 0), 0.6, 0.4)
	barrel(geo, body, gp(c.x + 6.0, c.z + 6.2))
	barrel(geo, body, gp(c.x - 7.5, c.z + 5.0))
	world.add_blocker(c.x + 7.2, c.z + 4.8, 2.4)
	# banner pole
	var bp := gp(c.x - 5.0, c.z - 4.0)
	geo.limb(bp, bp + Vector3(0, 5.0, 0), 0.07, 0.06, 6, WOOD_DARK)
	geo.box(yaw_xf(bp + Vector3(0.0, 4.9, 0.0), 0.0), Vector3(0.05, 0.05, 1.6), WOOD_DARK)
	geo.box(yaw_xf(bp + Vector3(0.0, 4.1, 0.55), 0.0), Vector3(0.04, 1.5, 1.0), Color(0.26, 0.36, 0.56))
	geo.box(yaw_xf(bp + Vector3(0.0, 4.25, 0.55), 0.0), Vector3(0.05, 0.4, 0.4), Palette.GOLD.darkened(0.2))
	_cyl(body, bp, 0.1, 5.0)
	# weapon rack + cooking pot
	var wr := gp(c.x - 8.0, c.z - 1.0)
	geo.box(yaw_xf(wr + Vector3(0, 1.0, 0), 0.3), Vector3(1.8, 0.08, 0.1), WOOD)
	for k in 3:
		var sp := wr + Vector3(-0.6 + k * 0.6, 0, 0).rotated(Vector3.UP, 0.3)
		geo.limb(sp, sp + Vector3(0.05, 1.6, 0.25), 0.03, 0.02, 4, WOOD_DARK)
		geo.limb(sp + Vector3(0.05, 1.6, 0.25), sp + Vector3(0.06, 1.9, 0.3), 0.04, 0.0, 4, Palette.STEEL)
	_box(body, yaw_xf(wr + Vector3(0, 0.8, 0), 0.3), Vector3(2.0, 1.6, 0.5))
	var pot := fire + Vector3(0, 0.0, 0)
	for k in 3:
		var a := TAU * k / 3.0
		geo.limb(pot + Vector3(cos(a), 0, sin(a)) * 0.9, pot + Vector3(0, 1.4, 0), 0.04, 0.03, 4, WOOD_DARK)
	geo.cylinder(yaw_xf(pot + Vector3(0, 0.55, 0), 0.0), 0.22, 0.3, 0.35, 10, Color(0.18, 0.18, 0.2))
	_commit(geo, "AdventurerCamp")
	stats["areas"] += 1


func _outpost() -> void:
	var geo := WorldGeo.new()
	var body := _body("OutpostBody")
	var c := WorldLayout.RAIDER_OUTPOST
	var gate_a := atan2(120.0 - c.z, 120.0 - c.x)   # toward the camp path
	var gate_b := atan2(-90.0 - c.z, 130.0 - c.x)   # toward the clearing path
	var r := 19.0
	var n := 70
	var seg_start := -1
	for k in n + 1:
		var ang := TAU * k / n
		var in_gate := absf(wrapf(ang - gate_a, -PI, PI)) < 0.17 or absf(wrapf(ang - gate_b, -PI, PI)) < 0.17
		if k < n and not in_gate:
			var p := gp(c.x + cos(ang) * r, c.z + sin(ang) * r)
			stake(geo, p, rng.randf_range(2.6, 3.2), 0.2)
			if seg_start < 0:
				seg_start = k
		if (in_gate or k == n) and seg_start >= 0:
			# collision box for the run of stakes seg_start..k-1
			var a0 := TAU * seg_start / n
			var a1 := TAU * (k - 1) / n
			var steps := maxi(1, int((a1 - a0) / 0.3))
			for m in steps:
				var t0 := lerpf(a0, a1, float(m) / steps)
				var t1 := lerpf(a0, a1, float(m + 1) / steps)
				var p0 := Vector3(c.x + cos(t0) * r, 0, c.z + sin(t0) * r)
				var p1 := Vector3(c.x + cos(t1) * r, 0, c.z + sin(t1) * r)
				var mid := (p0 + p1) * 0.5
				mid.y = gy(mid.x, mid.z) + 1.4
				_box(body, yaw_xf(mid, atan2(p1.x - p0.x, p1.z - p0.z)), Vector3(0.45, 3.2, p0.distance_to(p1) + 0.35))
			seg_start = -1
	# gate posts with skull trophies
	for g: float in [gate_a, gate_b]:
		for s: float in [-1.0, 1.0]:
			var ang := g + s * 0.2
			var p := gp(c.x + cos(ang) * r, c.z + sin(ang) * r)
			geo.limb(p + Vector3(0, -0.3, 0), p + Vector3(0, 4.0, 0), 0.26, 0.22, 7, WOOD_DARK)
			geo.blob(yaw_xf(p + Vector3(0, 4.15, 0), 0.0), Vector3(0.2, 0.18, 0.24), BONE, 1, 0.05, s, 0.8)
			_cyl(body, p, 0.3, 4.0)
	# watchtower
	var tw := gp(c.x + 9.0, c.z - 6.0)
	var hgt := 6.5
	for s in 4:
		var o := Vector3(1.4 if s % 2 == 0 else -1.4, 0, 1.4 if s < 2 else -1.4)
		geo.limb(tw + o * 1.1, tw + o * 0.9 + Vector3(0, hgt + 2.2, 0), 0.16, 0.13, 6, WOOD_DARK)
		_cyl(body, tw + o, 0.2, hgt)
	geo.box(yaw_xf(tw + Vector3(0, hgt, 0), 0.0), Vector3(3.6, 0.25, 3.6), WOOD)
	for s in 4:
		var yaw := PI * 0.5 * s
		geo.box(yaw_xf(tw + Vector3(0, hgt + 0.6, 0) + Vector3(0, 0, 1.75).rotated(Vector3.UP, yaw), yaw), Vector3(3.6, 0.9, 0.1), WOOD.darkened(0.1))
	geo.cylinder(yaw_xf(tw + Vector3(0, hgt + 2.2, 0), PI * 0.25), 2.9, 0.0, 1.6, 4, Color(0.25, 0.2, 0.18))
	# ladder
	for k in 9:
		geo.box(yaw_xf(tw + Vector3(0, 0.4 + k * 0.7, 1.95), 0.0), Vector3(0.8, 0.06, 0.06), WOOD)
	for s: float in [-0.4, 0.4]:
		geo.limb(tw + Vector3(s, 0, 2.0), tw + Vector3(s, hgt, 1.9), 0.04, 0.04, 4, WOOD)
	world.add_blocker(tw.x, tw.z, 3.0)
	# dark tents
	var tcols := [Color(0.26, 0.18, 0.17), Color(0.20, 0.19, 0.18), Color(0.36, 0.20, 0.16)]
	var tspots := [Vector3(-9, 0, -9), Vector3(-11, 0, 4), Vector3(4, 0, 11)]
	for k in 3:
		var tp: Vector3 = tspots[k]
		var p := gp(c.x + tp.x, c.z + tp.z)
		tent(geo, body, p, atan2(tp.x, tp.z), 4.0, 3.2, 2.2, tcols[k])
	# braziers
	for k in 2:
		var bp := gp(c.x + (-3.0 if k == 0 else 4.0), c.z + (2.0 if k == 0 else -3.0))
		for m in 3:
			var a := TAU * m / 3.0
			geo.limb(bp + Vector3(cos(a), 0, sin(a)) * 0.4, bp + Vector3(0, 0.9, 0), 0.04, 0.04, 4, Color(0.2, 0.2, 0.22))
		geo.cylinder(yaw_xf(bp + Vector3(0, 0.85, 0), 0.0), 0.25, 0.45, 0.3, 10, Color(0.22, 0.21, 0.22))
		world.atmosphere.add_fire(self, bp + Vector3(0, 1.1, 0), 0.75, k == 0)
		_cyl(body, bp, 0.45, 1.2)
		world.add_blocker(bp.x, bp.z, 1.0)
	Audio.create_loop(&"fire_loop", _sound_node(gp(c.x - 3.0, c.z + 2.0)))
	# loot crates, weapon rack, a cage of stolen goods
	for k in 4:
		crate(geo, body, gp(c.x - 2.0 + k * 0.95, c.z + 9.0), 0.85, rng.randf() * 0.3)
	barrel(geo, body, gp(c.x + 2.2, c.z + 10.4))
	world.add_blocker(c.x, c.z + 9.5, 2.8)
	_commit(geo, "RaiderOutpost")
	stats["areas"] += 1


func _ogre() -> void:
	var geo := WorldGeo.new()
	var body := _body("OgreBody")
	var c := WorldLayout.OGRE_CLEARING
	var R := WorldLayout.OGRE_ARENA_RADIUS
	var entries := [atan2(-110.0 - c.z, 80.0 - c.x), atan2(-170.0 - c.z, 140.0 - c.x)]
	var hut_ang := -PI * 0.5 + 0.35
	for k in 22:
		var ang := TAU * k / 22.0 + rng.randf_range(-0.05, 0.05)
		var skip := absf(wrapf(ang - hut_ang, -PI, PI)) < 0.28
		for e: float in entries:
			if absf(wrapf(ang - e, -PI, PI)) < 0.3:
				skip = true
		if skip:
			continue
		var r := R + rng.randf_range(2.0, 4.5)
		var s := rng.randf_range(1.6, 3.2)
		boulder(geo, body, c.x + cos(ang) * r, c.z + sin(ang) * r, Vector3(s * 1.2, s, s * 1.1), 0.25, Palette.ROCK_DARK.lerp(Palette.ROCK, 0.3))
	# crude ogre hut outside the rim (north)
	var hp := gp(c.x + cos(hut_ang) * (R + 7.0), c.z + sin(hut_ang) * (R + 7.0))
	var hyaw := -hut_ang + PI * 0.5
	var hxf := yaw_xf(hp, hyaw)
	for k in 9:
		var t := float(k) / 8.0
		var x := lerpf(-3.4, 3.4, t)
		var a := hxf * Vector3(x, 0, 3.0)
		var b := hxf * Vector3(x * 0.4, 5.2, -0.8)
		geo.limb(a, b, 0.22, 0.16, 6, WOOD.darkened(0.25 + rng.randf() * 0.1))
	geo.tent(hxf.translated_local(Vector3(0, 0.1, 0.6)), 6.4, 6.0, 4.4, Color(0.42, 0.34, 0.25), Color(0.32, 0.26, 0.2))
	_box(body, hxf.translated_local(Vector3(0, 1.8, 0.5)), Vector3(6.4, 3.6, 4.8))
	world.add_blocker(hp.x, hp.z, 6.0)
	# bone piles, a giant ribcage, skulls on stakes
	bones(geo, Vector3(c.x, 0, c.z), 26, R * 0.8, 1.4)
	var rc := gp(c.x + 14.0, c.z + 10.0)
	for k in 6:
		var off := Vector3(0, 0, -2.0 + k * 0.8)
		for s: float in [-1.0, 1.0]:
			var base := rc + off + Vector3(s * 0.4, 0, 0)
			geo.limb(base, base + Vector3(s * 1.2, 1.4, 0), 0.09, 0.08, 5, BONE)
			geo.limb(base + Vector3(s * 1.2, 1.4, 0), base + Vector3(s * 0.4, 2.4, 0), 0.08, 0.05, 5, BONE)
	geo.limb(rc + Vector3(0, 0.1, -2.6), rc + Vector3(0, 0.1, 2.6), 0.14, 0.12, 6, BONE)
	_box(body, yaw_xf(rc + Vector3(0, 0.9, 0), 0.0), Vector3(2.6, 1.8, 4.8))
	world.add_blocker(rc.x, rc.z, 3.0)
	for k in 4:
		var ang := TAU * k / 4.0 + 0.6
		var p := gp(c.x + cos(ang) * (R - 1.0), c.z + sin(ang) * (R - 1.0))
		stake(geo, p, 2.4, 0.1)
		geo.blob(yaw_xf(p + Vector3(0, 2.75, 0), 0.0), Vector3(0.26, 0.22, 0.3), BONE, 1, 0.05, k, 0.8)
	# dead trees around the clearing for a grim mood
	for k in 6:
		var ang := TAU * k / 6.0 + 0.3
		var p := gp(c.x + cos(ang) * (R + 10.0), c.z + sin(ang) * (R + 10.0))
		if world.is_blocked(p.x, p.z, 1.0):
			continue
		var h := rng.randf_range(5.0, 8.0)
		var bark := Color(0.30, 0.26, 0.22)
		geo.limb(p + Vector3(0, -0.2, 0), p + Vector3(rng.randf_range(-0.5, 0.5), h, rng.randf_range(-0.5, 0.5)), 0.35, 0.1, 7, bark)
		for m in 3:
			var y := h * rng.randf_range(0.45, 0.8)
			var d := Vector3(cos(rng.randf() * TAU), 0.6, sin(rng.randf() * TAU)) * rng.randf_range(1.4, 2.4)
			geo.limb(p + Vector3(0, y, 0), p + Vector3(0, y, 0) + d, 0.12, 0.03, 5, bark)
		_cyl(tree_body(), p, 0.35, h)
		world.add_blocker(p.x, p.z, 1.2)
	# big tree-stump "throne"
	var st := gp(c.x - 6.0, c.z - 22.0)
	geo.cylinder(yaw_xf(st, 0.0), 1.5, 1.2, 1.2, 10, WOOD.darkened(0.2), Color(0.55, 0.45, 0.32), true, 0.0, 0.0, 0.12, 3)
	_cyl(body, st, 1.4, 1.2)
	world.add_blocker(st.x, st.z, 2.0)
	_commit(geo, "OgreClearing")
	stats["areas"] += 1


func _overlook() -> void:
	var geo := WorldGeo.new()
	var body := _body("OverlookBody")
	var o := WorldLayout.OVERLOOK
	# rocky lip on the north edge (the view side) left open in the middle
	for k in 7:
		var ang := -PI * 0.5 + (k - 3) * 0.32
		if k == 3:
			continue
		var r := 13.0 + rng.randf_range(0.0, 2.0)
		var s := rng.randf_range(0.8, 1.6)
		boulder(geo, body, o.x + cos(ang) * r, o.z + sin(ang) * r, Vector3(s * 1.4, s * 0.8, s), 0.5)
	# weathered cairn + old waystone
	var cp := gp(o.x + 6.0, o.z + 3.0)
	for k in 5:
		var s := 0.55 - k * 0.09
		geo.rock(yaw_xf(cp + Vector3(rng.randf_range(-0.05, 0.05), 0.2 + k * 0.36, 0), rng.randf() * TAU), Vector3(s, s * 0.55, s * 0.9), STONE, k * 2.0, 0.3)
	_cyl(body, cp, 0.5, 1.8)
	world.add_blocker(cp.x, cp.z, 1.0)
	var ws := gp(o.x - 5.0, o.z + 4.0)
	geo.box(yaw_xf(ws + Vector3(0, 0.9, 0), 0.4), Vector3(0.7, 2.0, 0.35), STONE.darkened(0.1), MOSS)
	_box(body, yaw_xf(ws + Vector3(0, 0.9, 0), 0.4), Vector3(0.7, 2.0, 0.35))
	world.add_blocker(ws.x, ws.z, 0.8)
	_commit(geo, "Overlook")
	stats["areas"] += 1


# ------------------------------------------------------------------ secrets
func _secret_spots() -> void:
	var geo := WorldGeo.new()
	var body := _body("SecretsBody")
	var crystal := WorldGeo.new()
	# 1) alcove beside the waterfall: mossy cairn + glowing crystals
	var nk := WorldTerrain.NOOK
	var np := gp(nk.x, nk.z - 2.5)
	for k in 4:
		var s := 0.5 - k * 0.1
		geo.rock(yaw_xf(np + Vector3(0, 0.15 + k * 0.32, 0), rng.randf() * TAU), Vector3(s, s * 0.55, s * 0.9), STONE, k + 10.0, 0.7)
	for k in 6:
		var a := TAU * k / 6.0
		var p := np + Vector3(cos(a) * 1.4, -0.1, sin(a) * 1.2)
		p.y = gy(p.x, p.z) - 0.05
		crystal.limb(p, p + Vector3(cos(a) * 0.2, rng.randf_range(0.4, 0.8), sin(a) * 0.2), 0.12, 0.0, 5, Color(0.55, 0.85, 1.0))
	_secrets.append([&"secret_falls_nook", np, 4.0])
	# 2) hollow log in the Howling Woods (walk-through)
	var hl := gp(-152, 58)
	var hyaw := 0.7
	var hxf := yaw_xf(hl + Vector3(0, 1.0, 0), hyaw)
	var segs := 14
	var length := 8.0
	var ro := 1.55
	var ri := 1.25
	var shell := WorldGeo.new()
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		if sin((a0 + a1) * 0.5) < -0.85:
			continue  # flat bottom gap (floor is the ground)
		var o0 := Vector3(cos(a0) * ro, sin(a0) * ro, 0)
		var o1 := Vector3(cos(a1) * ro, sin(a1) * ro, 0)
		var i0 := Vector3(cos(a0) * ri, sin(a0) * ri, 0)
		var i1 := Vector3(cos(a1) * ri, sin(a1) * ri, 0)
		var zf := Vector3(0, 0, length * 0.5)
		var bc := WOOD.darkened(0.05)
		var ic := Color(0.36, 0.26, 0.18)
		shell.quad(hxf * (o0 - zf), hxf * (o1 - zf), hxf * (o1 + zf), hxf * (o0 + zf), bc, bc.lerp(MOSS, 0.4 if sin(a0) > 0.5 else 0.0))
		shell.quad(hxf * (i0 + zf), hxf * (i1 + zf), hxf * (i1 - zf), hxf * (i0 - zf), ic, ic)
		for e: float in [-1.0, 1.0]:
			var z := Vector3(0, 0, length * 0.5 * e)
			if e > 0:
				shell.quad(hxf * (o0 + z), hxf * (o1 + z), hxf * (i1 + z), hxf * (i0 + z), Color(0.6, 0.48, 0.32))
			else:
				shell.quad(hxf * (i0 + z), hxf * (i1 + z), hxf * (o1 + z), hxf * (o0 + z), Color(0.6, 0.48, 0.32))
	var smi := shell.commit(self, "HollowLog", WorldGeo.vertex_mat(0.9, true), true)
	world.register_vis(smi, 250.0)
	var tm := ConcavePolygonShape3D.new()
	tm.backface_collision = true
	tm.set_faces(smi.mesh.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = tm
	body.add_child(cs)
	world.add_blocker(hl.x, hl.z, 5.0)
	# trinket inside: a little glowing mushroom patch
	for k in 5:
		var p := hxf * Vector3(rng.randf_range(-0.5, 0.5), -0.95, rng.randf_range(-2.0, 2.0))
		crystal.blob(yaw_xf(p, 0.0), Vector3(0.09, 0.05, 0.09), Color(0.5, 0.95, 0.8), 0, 0.0, 0.0, 1.0)
	_secrets.append([&"secret_hollow_log", hl, 3.0])
	# 3) mossy statue on the western hill
	var sp := gp(-150, -128)
	geo.box(yaw_xf(sp + Vector3(0, 0.4, 0), 0.9), Vector3(1.8, 0.8, 1.8), STONE_DARK, MOSS)
	geo.cylinder(yaw_xf(sp + Vector3(0, 0.8, 0), 0.9), 0.75, 0.45, 2.2, 9, STONE, STONE.lerp(MOSS, 0.5))
	geo.blob(yaw_xf(sp + Vector3(0, 3.25, 0), 0.9), Vector3(0.45, 0.55, 0.45), STONE, 1, 0.05, 1.0, 0.75, STONE.lerp(MOSS, 0.7))
	geo.cylinder(yaw_xf(sp + Vector3(0, 3.1, 0), 0.9), 0.55, 0.0, 1.1, 9, STONE.darkened(0.08), STONE.lerp(MOSS, 0.6))
	for s: float in [-1.0, 1.0]:
		var sh := sp + Vector3(0, 2.6, 0) + Vector3(s * 0.55, 0, 0).rotated(Vector3.UP, 0.9)
		geo.limb(sh, sh + Vector3(0, -0.4, 0) + Vector3(0, 0, 0.45).rotated(Vector3.UP, 0.9), 0.15, 0.12, 6, STONE)
	_box(body, yaw_xf(sp + Vector3(0, 1.6, 0), 0.9), Vector3(1.8, 3.2, 1.8))
	world.add_blocker(sp.x, sp.z, 2.5)
	_secrets.append([&"secret_statue", sp, 5.0])
	# 4) small standing-stone circle on the eastern hill
	var sc := gp(160, -112)
	for k in 7:
		var a := TAU * k / 7.0
		var p := gp(sc.x + cos(a) * 5.0, sc.z + sin(a) * 5.0)
		var h := rng.randf_range(1.6, 2.6) if k != 4 else 0.7
		geo.box(Transform3D(Basis(Vector3.UP, a).rotated(Vector3(0, 0, 1), rng.randf_range(-0.06, 0.06)), p + Vector3(0, h * 0.5 - 0.2, 0)), Vector3(0.7, h, 0.5), STONE.darkened(0.12), MOSS)
		_box(body, yaw_xf(p + Vector3(0, h * 0.5 - 0.2, 0), a), Vector3(0.7, h, 0.5))
		world.add_blocker(p.x, p.z, 0.9)
	geo.box(yaw_xf(sc + Vector3(0, 0.25, 0), 0.2), Vector3(1.6, 0.5, 1.0), STONE, MOSS)
	_box(body, yaw_xf(sc + Vector3(0, 0.25, 0), 0.2), Vector3(1.6, 0.5, 1.0))
	_secrets.append([&"secret_stone_circle", sc, 6.0])
	_commit(geo, "Secrets")
	crystal.commit(self, "SecretGlow", Palette.glow(Color(0.55, 0.9, 1.0), 2.5), false)
	stats["secrets"] = _secrets.size()


# ------------------------------------------------------------------ still waters
func _still_waters() -> void:
	for w: Dictionary in terrain.still:
		match w["kind"]:
			&"pond":
				_pond(w)
			&"lake":
				_lake(w)
			&"spring":
				_spring(w)
			&"marsh":
				_marsh(w)


func _reed(fgeo: WorldGeo, p: Vector3, h: float, cattail: bool) -> void:
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var top := p + Vector3(0, h, 0) + lean
	fgeo.limb(p, top, 0.03, 0.012, 4, Color(0.36, 0.42, 0.20), Color(0.52, 0.54, 0.28), 0.0, 0.8)
	if cattail:
		var a := p + Vector3(0, h * 0.72, 0) + lean * 0.72
		fgeo.limb(a, a + (top - a) * 0.45, 0.045, 0.04, 5, Color(0.36, 0.24, 0.14), Color(0.40, 0.27, 0.16), 0.6, 0.7)


func _reed_clump(fgeo: WorldGeo, x: float, z: float, n: int, spread: float, cattails: float) -> void:
	for k in n:
		var p := gp(x + rng.randf_range(-spread, spread), z + rng.randf_range(-spread, spread), -0.05)
		_reed(fgeo, p, rng.randf_range(0.7, 1.5), rng.randf() < cattails)


func _rim_stones(geo: WorldGeo, body: StaticBody3D, c: Vector3, r: float, n: int, smin: float, smax: float, moss: float) -> void:
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.15, 0.15)
		var rr := r + rng.randf_range(0.0, 1.0)
		var s := rng.randf_range(smin, smax)
		boulder(geo, body if s > 0.9 else null, c.x + cos(a) * rr, c.z + sin(a) * rr, Vector3(s * 1.3, s * 0.6, s), moss)


func _pond(w: Dictionary) -> void:
	var geo := WorldGeo.new()
	var fgeo := WorldGeo.new()
	var c: Vector3 = w["pos"]
	var r: float = w["radius"]
	_rim_stones(geo, null, c, r + 0.2, 14, 0.25, 0.6, 0.6)
	for k in 5:
		var a := rng.randf() * TAU
		_reed_clump(fgeo, c.x + cos(a) * (r + 0.3), c.z + sin(a) * (r + 0.3), 7, 0.8, 0.3)
	_lily_pads(fgeo, c, float(w["level"]), r * 0.8, 6)
	world.add_blocker(c.x, c.z, r + 1.5)
	_commit(geo, "Pond_%s" % w["id"])
	_foliage_commit(fgeo, "PondReeds_%s" % w["id"])


func _lily_pads(geo: WorldGeo, c: Vector3, level: float, r: float, n: int) -> void:
	for k in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var p := Vector3(c.x + cos(a) * d, level + 0.025, c.z + sin(a) * d)
		if terrain.height_at(p.x, p.z) > level - 0.08:
			continue
		var pr := rng.randf_range(0.25, 0.5)
		var notch := rng.randf() * TAU
		var col := Color(0.26, 0.40, 0.18).lerp(Color(0.38, 0.46, 0.20), rng.randf())
		col.a = 0.15
		for s in 9:
			var a0 := notch + 0.35 + (TAU - 0.7) * s / 9.0
			var a1 := notch + 0.35 + (TAU - 0.7) * (s + 1) / 9.0
			geo.tri(p, p + Vector3(cos(a1), 0, sin(a1)) * pr, p + Vector3(cos(a0), 0, sin(a0)) * pr, col)
		if rng.randf() < 0.25:
			var fc := Color(0.95, 0.88, 0.92, 0.2)
			geo.blob(Transform3D(Basis(), p + Vector3(0, 0.06, 0)), Vector3(0.09, 0.06, 0.09), fc, 0, 0.0, 0.0, 0.85, Color(0, 0, 0, 0), 0.2)


func _lake(w: Dictionary) -> void:
	var geo := WorldGeo.new()
	var fgeo := WorldGeo.new()
	var body := _body("LakeBody")
	var c: Vector3 = w["pos"]
	var r: float = w["radius"]
	# shore boulders in a few groups, some half in the water
	for g in 5:
		var a := TAU * g / 5.0 + rng.randf_range(-0.3, 0.3)
		for k in 3:
			var aa := a + rng.randf_range(-0.15, 0.15)
			var rr := r + rng.randf_range(-1.5, 1.8)
			var s := rng.randf_range(0.5, 1.4)
			boulder(geo, body if s > 0.9 else null, c.x + cos(aa) * rr, c.z + sin(aa) * rr, Vector3(s * 1.4, s * 0.8, s * 1.1), 0.5)
	# one big rock island
	var ia := 2.1
	var ip := gp(c.x + cos(ia) * r * 0.45, c.z + sin(ia) * r * 0.45, 0.2)
	geo.rock(yaw_xf(ip, 0.7), Vector3(2.2, 1.2, 1.8), Palette.ROCK, 3.3, 0.7)
	# reed beds on the sheltered west/south shores
	for k in 9:
		var a := lerpf(1.6, 3.9, float(k) / 8.0) + rng.randf_range(-0.1, 0.1)
		_reed_clump(fgeo, c.x + cos(a) * (r + 0.2), c.z + sin(a) * (r + 0.2), 9, 1.2, 0.35)
	_lily_pads(fgeo, c, float(w["level"]), r * 0.85, 14)
	# small wooden jetty facing the trail
	var tr: Array = terrain.trails[terrain.trails.size() - 1] if not terrain.trails.is_empty() else []
	var toward := Vector3(-1, 0, 0)
	for t: Array in terrain.trails:
		var e: Vector3 = t[1]
		if Vector2(e.x - c.x, e.z - c.z).length() < r + 3.0:
			toward = Vector3(e.x - c.x, 0, e.z - c.z).normalized()
	var j0 := c + toward * (r + 1.0)
	var j1 := c + toward * (r - 4.0)
	var lvl: float = w["level"]
	var yaw := atan2(toward.x, toward.z)
	var deck_y := maxf(lvl + 0.35, gy(j0.x, j0.z) + 0.05)
	var mid := (j0 + j1) * 0.5
	geo.box(yaw_xf(Vector3(mid.x, deck_y - 0.05, mid.z), yaw), Vector3(1.6, 0.1, 5.2), WOOD.lightened(0.05))
	_box(body, yaw_xf(Vector3(mid.x, deck_y - 0.05, mid.z), yaw), Vector3(1.6, 0.1, 5.2))
	for k in 3:
		var p := j0.lerp(j1, float(k) / 2.0)
		for s: float in [-0.7, 0.7]:
			var q := p + Vector3(cos(yaw), 0, -sin(yaw)) * s
			geo.limb(Vector3(q.x, lvl - 0.8, q.z), Vector3(q.x, deck_y + 0.15, q.z), 0.08, 0.07, 5, WOOD_DARK)
	world.add_blocker(c.x, c.z, r + 2.0)
	_commit(geo, "Lake_%s" % w["id"])
	_foliage_commit(fgeo, "LakeReeds_%s" % w["id"])
	tr = tr


func _spring(w: Dictionary) -> void:
	var geo := WorldGeo.new()
	var fgeo := WorldGeo.new()
	var body := _body("SpringBody")
	var c: Vector3 = w["pos"]
	var r: float = w["radius"]
	var lvl: float = w["level"]
	# ring of flat mossy stones, leaving an opening toward the trail
	var open_dir := 0.0
	for t: Array in terrain.trails:
		var e: Vector3 = t[1]
		if Vector2(e.x - c.x, e.z - c.z).length() < r + 3.0:
			open_dir = atan2(e.z - c.z, e.x - c.x)
	for k in 16:
		var a := TAU * k / 16.0
		if absf(wrapf(a - open_dir, -PI, PI)) < 0.3:
			continue
		var s := rng.randf_range(0.45, 0.75)
		var p := gp(c.x + cos(a) * (r + 0.4), c.z + sin(a) * (r + 0.4), s * 0.12)
		geo.rock(yaw_xf(p, a), Vector3(s * 1.4, s * 0.55, s), Palette.ROCK.lerp(STONE, 0.5), k * 1.9, 0.7)
	# the source: a big mossy stone the water wells up beside
	var src := gp(c.x - cos(open_dir) * (r - 1.2), c.z - sin(open_dir) * (r - 1.2), 0.5)
	geo.rock(yaw_xf(src, open_dir), Vector3(1.4, 1.2, 1.1), STONE.darkened(0.05), 7.7, 0.9)
	_sphere(body, src, 1.0)
	_reed_clump(fgeo, src.x + 1.2, src.z + 1.0, 6, 0.6, 0.0)
	for k in 4:
		bush_cluster(fgeo, c.x + cos(open_dir + 2.0 + k * 0.6) * (r + 2.5), c.z + sin(open_dir + 2.0 + k * 0.6) * (r + 2.5), 0.7)
	world.add_blocker(c.x, c.z, r + 2.5)
	_commit(geo, "Spring")
	_foliage_commit(fgeo, "SpringPlants")
	# bubbles welling up next to the stone
	var bp := Vector3(src.x + cos(open_dir) * 1.4, lvl, src.z + sin(open_dir) * 1.4)
	_bubbles(bp)
	# interactable: drink to heal
	var it := Interactable.new()
	it.name = "SpringDrink"
	it.interact_id = &"spring_drink"
	it.prompt = SPRING_PROMPT
	it.radius = r + 1.5
	it.position = Vector3(c.x, lvl + 0.5, c.z)
	it.interacted.connect(_on_spring_drink)
	add_child(it)
	spring_interactable = it


func _bubbles(p: Vector3) -> void:
	var gp_ := GPUParticles3D.new()
	gp_.name = "SpringBubbles"
	gp_.amount = 18
	gp_.lifetime = 1.4
	gp_.position = p
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.3, Color(1, 1, 1, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp_.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = WorldAtmosphere.soft_particle_mat(Color(0.8, 0.88, 0.88), false)
	gp_.draw_pass_1 = q
	gp_.visibility_range_end = 60.0
	gp_.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gp_)
	# a soft ring of ripples (reuses the foam shader, faint)
	var ring := MeshInstance3D.new()
	ring.name = "SpringRipples"
	var pl := PlaneMesh.new()
	pl.size = Vector2(1.6, 1.6)
	ring.mesh = pl
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/world/foam_ring.gdshader")
	fm.set_shader_parameter("foam_color", Color(0.85, 0.95, 0.95))
	fm.render_priority = 3
	ring.material_override = fm
	ring.position = p + Vector3(0, 0.03, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _on_spring_drink(actor: Node) -> void:
	if not _spring_ready:
		Events.notify.emit("The water is still settling.", &"info")
		return
	var p: Node = GameState.player if is_instance_valid(GameState.player) else actor
	if p and "health" in p and p.health:
		var hc: HealthComponent = p.health
		hc.heal(hc.max_health)
	Events.notify.emit("The cold spring water restores you.", &"info")
	Audio.play_sfx(&"splash", spring_interactable.global_position)
	_spring_ready = false
	spring_interactable.prompt = SPRING_WAIT_PROMPT
	get_tree().create_timer(SPRING_COOLDOWN, false).timeout.connect(_on_spring_ready)


func _on_spring_ready() -> void:
	_spring_ready = true
	if is_instance_valid(spring_interactable):
		spring_interactable.prompt = SPRING_PROMPT


func _marsh(w: Dictionary) -> void:
	var geo := WorldGeo.new()
	var fgeo := WorldGeo.new()
	var body := _body("MarshBody")
	var c: Vector3 = w["pos"]
	var r: float = w["radius"]
	var lvl: float = w["level"]
	# dense reeds and cattails along the water's edge (sample the actual shoreline)
	var placed := 0
	var tries := 0
	while placed < 150 and tries < 2500:
		tries += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * (r + 4.0)
		var x := c.x + cos(a) * d
		var z := c.z + sin(a) * d
		var hgt := terrain.height_at(x, z)
		if absf(hgt - lvl) > 0.22 or terrain.path_distance(x, z) < 2.0:
			continue
		_reed_clump(fgeo, x, z, rng.randi_range(5, 10), 0.7, 0.45)
		placed += 1
	_lily_pads(fgeo, c, lvl, r * 0.9, 120)
	# dead and leaning trees standing in the bog
	var bark := Color(0.30, 0.27, 0.22)
	for k in 14:
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, r + 6.0)
		var x := c.x + cos(a) * d
		var z := c.z + sin(a) * d
		if terrain.path_distance(x, z) < 3.0 or world.is_blocked(x, z, 1.5):
			continue
		var p := gp(x, z, -0.3)
		var h := rng.randf_range(4.0, 9.0)
		var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.3, 2.2)
		var top := p + Vector3(0, h, 0) + lean
		geo.limb(p, top, rng.randf_range(0.25, 0.4), 0.06, 7, bark.darkened(rng.randf() * 0.2), bark)
		for m in rng.randi_range(2, 4):
			var t := rng.randf_range(0.4, 0.85)
			var o := p.lerp(top, t)
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.8), rng.randf_range(-1, 1)).normalized()
			var e := o + dir * rng.randf_range(1.0, 2.4)
			geo.limb(o, e, 0.09, 0.02, 5, bark)
			if rng.randf() < 0.5:
				geo.limb(e, e + Vector3(rng.randf_range(-0.6, 0.6), 0.5, rng.randf_range(-0.6, 0.6)), 0.03, 0.01, 4, bark)
		# hanging moss tufts
		if rng.randf() < 0.6:
			geo.limb(top - lean * 0.3, top - lean * 0.3 + Vector3(0, -1.2, 0), 0.12, 0.02, 4, Color(0.38, 0.42, 0.26))
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = h
		cs.shape = cap
		cs.transform = Transform3D(Basis(Quaternion(Vector3.UP, (top - p).normalized())), (p + top) * 0.5)
		tree_body().add_child(cs)
		world.add_blocker(x, z, 1.4)
	# fallen rotting logs across the mud, mossy stumps, a sunken cart wheel
	for k in 4:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, r - 4.0)
		var p := gp(c.x + cos(a) * d, c.z + sin(a) * d, 0.15)
		var dir := Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * rng.randf_range(2.0, 3.5)
		geo.limb(p - dir, p + dir + Vector3(0, 0.3, 0), 0.38, 0.3, 8, bark.darkened(0.15), Color(0.32, 0.38, 0.2))
		var lb := Basis.looking_at(dir.normalized(), Vector3.UP)
		_box(tree_body(), Transform3D(lb, p + Vector3(0, 0.1, 0)), Vector3(0.6, 0.6, dir.length() * 2.0))
	for k in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(3.0, r)
		var p := gp(c.x + cos(a) * d, c.z + sin(a) * d, -0.1)
		geo.cylinder(yaw_xf(p, 0.0), 0.5, 0.38, rng.randf_range(0.4, 0.9), 7, bark, Color(0.32, 0.38, 0.2), true, 0.0, 0.0, 0.15, k)
	world.add_blocker(c.x, c.z, r * 0.6)
	_commit(geo, "MarshProps")
	_foliage_commit(fgeo, "MarshReeds")
	# low ground mist
	var mist := GPUParticles3D.new()
	mist.name = "MarshMist"
	mist.amount = 26
	mist.lifetime = 14.0
	mist.preprocess = 14.0
	mist.position = Vector3(c.x, lvl + 0.6, c.z)
	mist.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 10, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r, 0.3, r)
	pm.gravity = Vector3(0.08, 0.0, 0.03)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.15
	pm.spread = 180.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.5, Color(1, 1, 1, 0.22))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	mist.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(6, 2.4)
	# own material: fades out within a few metres of the camera so standing in
	# the marsh never fills the screen with overlapping transparent cards
	var mm := WorldAtmosphere.soft_particle_mat(Color(0.78, 0.82, 0.74), false).duplicate() as StandardMaterial3D
	mm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mm.distance_fade_min_distance = 2.0
	mm.distance_fade_max_distance = 9.0
	q.material = mm
	mist.draw_pass_1 = q
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.set_meta("base_amount", 26)
	add_child(mist)
	world.atmosphere.particles.append(mist)
	# ambience (safe no-op if the audio agent has no such loop)
	var sn := _sound_node(Vector3(c.x, lvl, c.z))
	Audio.create_loop(&"marsh_loop", sn, 18.0)


## Called by WorldRoot after zones exist.
func build_secrets(w: Node3D) -> void:
	for s: Array in _secrets:
		w.zones.add_secret(w, s[0], s[1], s[2])
