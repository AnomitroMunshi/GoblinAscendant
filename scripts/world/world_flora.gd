class_name WorldFlora
extends RefCounted
## Procedural plant meshes for a grounded, realistic-leaning forest.
## Every plant mesh has up to two surfaces: bark (triplanar textured, bark.gdshader)
## and foliage cards (alpha-cut atlas, leaves.gdshader). Vertex COLOR.a is the
## wind-sway weight; bark COLOR.rgb ~0.5 grey = neutral texture tint, leaf
## COLOR.rgb ~1 = atlas colour.
##
## Species: OAK_A, OAK_B (broad, spreading), BEECH (tall, dense), BIRCH (white,
## slender, small leaves), PINE (tall, sparse whorls), FIR (dense drooping
## tiers), SNAG (dead tree). Each has a near and a far (cheaper) version.

enum { OAK_A, OAK_B, BEECH, BIRCH, PINE, FIR, SNAG }
const SPECIES_COUNT := 7
const NEUTRAL := 0.5


class Spec:
	var mesh: ArrayMesh
	var trunk_r := 0.3
	var trunk_h := 6.0


## Returns [near: Spec, far: Spec] for a species.
static func tree(species: int, seed_v: int) -> Array:
	var out: Array = []
	for near: bool in [true, false]:
		var mr := RandomNumberGenerator.new()
		mr.seed = seed_v  # same skeleton for both LODs
		match species:
			PINE, FIR:
				out.append(_conifer(mr, species == FIR, near))
			SNAG:
				out.append(_snag(mr, near))
			_:
				out.append(_broadleaf(mr, species, near))
	return out


static func _bark_col(sway: float, tint: float = NEUTRAL) -> Color:
	return Color(tint, tint, tint, sway)


## Tapered, gently bent trunk as a chain of limbs. Returns the centre-line points.
static func _trunk(geo: WorldGeo, mr: RandomNumberGenerator, h: float, r0: float, r1: float, segs: int, sides: int, bend: float, tint: float, sway_top: float) -> Array:
	var pts: Array = [Vector3.ZERO]
	var dir := Vector3.UP
	var off := Vector3(mr.randf_range(-1, 1), 0, mr.randf_range(-1, 1)).normalized()
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var lateral := off * sin(t * PI * 0.9) * bend + Vector3(mr.randf_range(-1, 1), 0, mr.randf_range(-1, 1)) * bend * 0.15
		pts.append(Vector3(lateral.x, h * t, lateral.z))
	for i in segs:
		var ta := float(i) / segs
		var tb := float(i + 1) / segs
		var ra := lerpf(r0, r1, pow(ta, 0.8))
		var rb := lerpf(r0, r1, pow(tb, 0.8))
		geo.limb(pts[i], pts[i + 1], ra, rb, sides, _bark_col(ta * sway_top, tint), _bark_col(tb * sway_top, tint), ta * sway_top, tb * sway_top)
	dir = dir
	return pts


static func _roots(geo: WorldGeo, mr: RandomNumberGenerator, r0: float, n: int, sides: int, tint: float) -> void:
	for k in n:
		var a := TAU * k / n + mr.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var a0 := d * r0 * 0.5 + Vector3(0, r0 * 1.6, 0)
		var a1 := d * r0 * mr.randf_range(2.2, 3.0) + Vector3(0, -0.15, 0)
		geo.limb(a0, a1, r0 * 0.55, r0 * 0.12, sides, _bark_col(0.0, tint * 0.9))


## A clump of 3-5 crossed leaf cards around c, shaded outward from `centre`.
static func _cluster(leaf: WorldGeo, mr: RandomNumberGenerator, c: Vector3, centre: Vector3, size: float, n: int, cell: Rect2, tint: Color, droop: float = 0.0) -> void:
	var out := (c - centre)
	out = out.normalized() if out.length() > 0.01 else Vector3.UP
	var nrm := (out + Vector3.UP * 0.35).normalized()
	for k in n:
		var r := Vector3(mr.randf_range(-1, 1), mr.randf_range(-0.4, 0.4), mr.randf_range(-1, 1)).normalized()
		var u := r.cross(Vector3(mr.randf_range(-1, 1), 1.0, mr.randf_range(-1, 1)).normalized()).normalized()
		if u.y < 0.0:
			u = -u
		u = (u + Vector3.DOWN * droop).normalized()
		var s := size * mr.randf_range(0.8, 1.15)
		var shade := mr.randf_range(0.85, 1.08)
		var col := Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0)
		leaf.card(c + Vector3(mr.randf_range(-0.2, 0.2), mr.randf_range(-0.15, 0.15), mr.randf_range(-0.2, 0.2)) * size, r * s * 0.5, u * s * 0.5, nrm, col, cell)


static func _broadleaf(mr: RandomNumberGenerator, species: int, near: bool) -> Spec:
	var bark := WorldGeo.new()
	var leaf := WorldGeo.new()
	var birch := species == BIRCH
	var beech := species == BEECH
	var h: float
	var crown_r: float
	var r0: float
	var cell := WorldTextures.CELL_BROAD
	var tint := Color(1.0, 1.0, 1.0)
	var bark_tint := NEUTRAL
	match species:
		OAK_A:
			h = mr.randf_range(5.0, 6.0); crown_r = 4.2; r0 = 0.42
		OAK_B:
			h = mr.randf_range(4.2, 5.2); crown_r = 4.8; r0 = 0.46; tint = Color(0.95, 1.0, 0.9)
		BEECH:
			h = mr.randf_range(8.0, 9.5); crown_r = 3.6; r0 = 0.36; tint = Color(1.05, 1.05, 0.95)
		_:
			h = mr.randf_range(8.5, 10.0); crown_r = 2.4; r0 = 0.2; cell = WorldTextures.CELL_SMALL
			tint = Color(1.05, 1.08, 0.92); bark_tint = 0.74
	var sides := 9 if near else 5
	var segs := 5 if near else 3
	var trunk_h := h + crown_r * (0.9 if not birch else 1.2)
	var pts := _trunk(bark, mr, trunk_h, r0, r0 * 0.25, segs, sides, 0.35 if not beech else 0.2, bark_tint, 0.35)
	if near and not birch:
		_roots(bark, mr, r0, 5, 5, bark_tint)
	var centre := Vector3(0, h + crown_r * 0.55, 0)
	var ends: Array = []
	# primary branches
	var nb := (6 if not birch else 5) if near else 4
	for b in nb:
		var t := lerpf(0.42, 0.9, float(b) / maxf(nb - 1, 1)) + mr.randf_range(-0.04, 0.04)
		var base: Vector3 = _along(pts, t)
		var ang := TAU * b / nb * 1.618 + mr.randf_range(-0.4, 0.4)
		var up := mr.randf_range(0.35, 0.8) if not birch else mr.randf_range(0.1, 0.4)
		var dir := Vector3(cos(ang), up, sin(ang)).normalized()
		var L := crown_r * mr.randf_range(0.7, 1.0) * (1.0 - t * 0.35)
		var tip := base + dir * L
		if birch:
			tip.y -= L * 0.25
		var rb := r0 * lerpf(0.5, 0.25, t)
		bark.limb(base, tip, rb, rb * 0.3, 5 if near else 3, _bark_col(0.3, bark_tint), _bark_col(0.8, bark_tint), 0.3, 0.8)
		ends.append(tip)
		ends.append(base.lerp(tip, 0.55) + Vector3(0, 0.3, 0))
		if near:
			for s in 2:
				var sb := base.lerp(tip, mr.randf_range(0.45, 0.75))
				var sdir := (dir + Vector3(mr.randf_range(-0.8, 0.8), mr.randf_range(0.0, 0.6), mr.randf_range(-0.8, 0.8))).normalized()
				var stip := sb + sdir * L * 0.45
				bark.limb(sb, stip, rb * 0.35, rb * 0.08, 4, _bark_col(0.6, bark_tint), _bark_col(0.9, bark_tint), 0.6, 0.9)
				ends.append(stip)
	ends.append(pts[pts.size() - 1])
	# foliage: clusters at branch ends + fill inside the crown ellipsoid
	var csize := (1.8 if near else 2.9) * (0.8 if birch else 1.0)
	var ncard := 5 if near else 3
	for e: Vector3 in ends:
		_cluster(leaf, mr, e, centre, csize, ncard, cell, tint, 0.35 if birch else 0.0)
	var fill := (30 if not birch else 18) if near else 12
	for k in fill:
		var d := Vector3(mr.randf_range(-1, 1), mr.randf_range(-0.7, 1.0), mr.randf_range(-1, 1))
		if d.length() > 1.0:
			d = d.normalized() * mr.randf_range(0.6, 1.0)
		var c := centre + Vector3(d.x * crown_r, d.y * crown_r * (0.75 if not beech else 1.1), d.z * crown_r)
		_cluster(leaf, mr, c, centre, csize, ncard, cell, tint, 0.35 if birch else 0.0)
	var spec := Spec.new()
	spec.mesh = ArrayMesh.new()
	bark.add_to(spec.mesh, WorldTextures.bark_mat("bark_oak", 0.7 if not birch else 1.1, 0.25 if not birch else 0.0))
	leaf.add_to(spec.mesh, WorldTextures.leaf_mat())
	spec.trunk_r = r0
	spec.trunk_h = trunk_h * 0.7
	return spec


static func _along(pts: Array, t: float) -> Vector3:
	var f := t * (pts.size() - 1)
	var i := clampi(int(f), 0, pts.size() - 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


static func _conifer(mr: RandomNumberGenerator, fir: bool, near: bool) -> Spec:
	var bark := WorldGeo.new()
	var leaf := WorldGeo.new()
	var h := mr.randf_range(13.0, 16.0) if not fir else mr.randf_range(10.0, 12.5)
	var r0 := 0.34 if not fir else 0.4
	var sides := 8 if near else 5
	var pts := _trunk(bark, mr, h, r0, 0.05, 5 if near else 3, sides, 0.12, NEUTRAL, 0.25)
	if near:
		_roots(bark, mr, r0, 4, 4, NEUTRAL)
	var start := 0.35 if not fir else 0.12
	var whorls := (11 if not fir else 14) if near else (5 if not fir else 6)
	var per := (6 if not fir else 7) if near else 5
	var base_len := 3.0 if not fir else 3.4
	var tint := Color(0.95, 1.0, 0.95) if not fir else Color(0.85, 0.92, 0.85)
	for w in whorls:
		var t := lerpf(start, 0.97, float(w) / maxf(whorls - 1, 1))
		var y := h * t
		var L := base_len * (1.0 - t) * (1.0 if not fir else 1.1) + 0.5
		var droop := 0.25 + 0.25 * (1.0 - t) if fir else 0.05 + 0.15 * (1.0 - t)
		var rot := mr.randf() * TAU
		for b in per:
			var ang := rot + TAU * b / per + mr.randf_range(-0.2, 0.2)
			var dir := Vector3(cos(ang), -droop, sin(ang)).normalized()
			var base := _along(pts, t)
			var tip := base + dir * L
			if near:
				bark.limb(base, tip, 0.06 * (1.0 - t) + 0.02, 0.01, 3, _bark_col(0.4), _bark_col(0.9), 0.4, 0.9)
			# needle sprays: card along the branch (texture stem runs along "u"),
			# a second one crossed for volume
			var side := dir.cross(Vector3.UP).normalized()
			var mid := base.lerp(tip, 0.55)
			var wdt := L * (0.95 if fir else 0.85)
			var nrm := (Vector3(dir.x, 0.0, dir.z).normalized() + Vector3.UP * 0.6).normalized()
			var shade := mr.randf_range(0.85, 1.08)
			var col := Color(tint.r * shade, tint.g * shade, tint.b * shade, lerpf(0.5, 1.0, 1.0 - t * 0.3))
			leaf.card(mid, side * wdt * 0.5, dir * L * 0.6, nrm, col, WorldTextures.CELL_NEEDLE)
			var tilt := (side * 0.35 + Vector3.UP).normalized()
			leaf.card(mid + Vector3(0, 0.08, 0), tilt * wdt * 0.35, dir * L * 0.55, nrm, col, WorldTextures.CELL_NEEDLE)
			if near:
				var tilt2 := (-side * 0.35 + Vector3.UP).normalized()
				leaf.card(mid - Vector3(0, 0.06, 0), tilt2 * wdt * 0.35, dir * L * 0.5, nrm, col, WorldTextures.CELL_NEEDLE)
	# leader at the top
	var top: Vector3 = pts[pts.size() - 1]
	for k in 2:
		var r := Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5))
		leaf.card(top + Vector3(0, -0.6, 0), r * 0.5, Vector3.UP * 1.2, Vector3.UP, Color(tint, 1.0), WorldTextures.CELL_NEEDLE)
	var spec := Spec.new()
	spec.mesh = ArrayMesh.new()
	bark.add_to(spec.mesh, WorldTextures.bark_mat("bark_fir", 0.8, 0.1))
	leaf.add_to(spec.mesh, WorldTextures.leaf_mat())
	spec.trunk_r = r0
	spec.trunk_h = h * 0.75
	return spec


static func _snag(mr: RandomNumberGenerator, near: bool) -> Spec:
	var bark := WorldGeo.new()
	var h := mr.randf_range(6.0, 9.0)
	var r0 := 0.38
	var tint := 0.55
	var pts := _trunk(bark, mr, h, r0, 0.12, 4, 8 if near else 5, 0.5, tint, 0.05)
	if near:
		_roots(bark, mr, r0, 4, 4, tint)
	for b in (5 if near else 3):
		var t := mr.randf_range(0.35, 0.9)
		var base := _along(pts, t)
		var ang := mr.randf() * TAU
		var dir := Vector3(cos(ang), mr.randf_range(-0.1, 0.7), sin(ang)).normalized()
		var L := mr.randf_range(1.0, 2.6) * (1.0 - t * 0.4)
		var tip := base + dir * L
		bark.limb(base, tip, r0 * 0.3 * (1.0 - t * 0.5), 0.02, 4, _bark_col(0.05, tint), _bark_col(0.1, tint))
		if near and mr.randf() < 0.6:
			var t2 := tip + (dir + Vector3(mr.randf_range(-0.6, 0.6), 0.5, mr.randf_range(-0.6, 0.6))).normalized() * L * 0.4
			bark.limb(tip, t2, 0.03, 0.01, 3, _bark_col(0.1, tint), _bark_col(0.15, tint))
	var spec := Spec.new()
	spec.mesh = ArrayMesh.new()
	bark.add_to(spec.mesh, WorldTextures.bark_mat("bark_oak", 0.7, 0.35))
	spec.trunk_r = r0
	spec.trunk_h = h
	return spec


## Giant old broadleaf landmark (single mesh, unique).
static func giant(seed_v: int) -> Spec:
	var mr := RandomNumberGenerator.new()
	mr.seed = seed_v
	var bark := WorldGeo.new()
	var leaf := WorldGeo.new()
	var h := mr.randf_range(11.0, 13.0)
	var crown_r := 9.0
	var r0 := 1.5
	var pts := _trunk(bark, mr, h + 4.0, r0, 0.5, 6, 14, 0.8, NEUTRAL, 0.12)
	_roots(bark, mr, r0, 8, 7, NEUTRAL)
	var centre := Vector3(0, h + crown_r * 0.45, 0)
	var ends: Array = []
	for b in 7:
		var t := lerpf(0.55, 0.92, float(b) / 6.0)
		var base := _along(pts, t)
		var ang := TAU * b / 7.0 + mr.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), mr.randf_range(0.25, 0.6), sin(ang)).normalized()
		var L := crown_r * mr.randf_range(0.8, 1.05)
		var mid := base + dir * L * 0.5 + Vector3(0, mr.randf_range(-0.6, 0.4), 0)
		var tip := base + dir * L
		bark.limb(base, mid, r0 * 0.45, r0 * 0.28, 8, _bark_col(0.0), _bark_col(0.2), 0.0, 0.2)
		bark.limb(mid, tip, r0 * 0.28, r0 * 0.08, 6, _bark_col(0.2), _bark_col(0.5), 0.2, 0.5)
		ends.append(tip)
		ends.append(mid + Vector3(0, 1.0, 0))
		for s in 3:
			var sb := base.lerp(tip, mr.randf_range(0.4, 0.85))
			var sdir := (dir + Vector3(mr.randf_range(-0.9, 0.9), mr.randf_range(0.1, 0.7), mr.randf_range(-0.9, 0.9))).normalized()
			var stip := sb + sdir * L * 0.4
			bark.limb(sb, stip, r0 * 0.12, r0 * 0.03, 5, _bark_col(0.4), _bark_col(0.7), 0.4, 0.7)
			ends.append(stip)
	for e: Vector3 in ends:
		_cluster(leaf, mr, e, centre, 2.4, 6, WorldTextures.CELL_BROAD, Color(0.95, 1.0, 0.9))
	for k in 70:
		var d := Vector3(mr.randf_range(-1, 1), mr.randf_range(-0.6, 1.0), mr.randf_range(-1, 1))
		if d.length() > 1.0:
			d = d.normalized() * mr.randf_range(0.55, 1.0)
		_cluster(leaf, mr, centre + Vector3(d.x * crown_r, d.y * crown_r * 0.6, d.z * crown_r), centre, 2.4, 5, WorldTextures.CELL_BROAD, Color(0.95, 1.0, 0.9))
	var spec := Spec.new()
	spec.mesh = ArrayMesh.new()
	bark.add_to(spec.mesh, WorldTextures.bark_mat("bark_oak", 0.45, 0.4))
	leaf.add_to(spec.mesh, WorldTextures.leaf_mat())
	spec.trunk_r = r0
	spec.trunk_h = h
	return spec


## Undergrowth bush made of leaf cards (no bark).
static func bush(seed_v: int, small_leaves: bool) -> ArrayMesh:
	var mr := RandomNumberGenerator.new()
	mr.seed = seed_v
	var leaf := WorldGeo.new()
	var centre := Vector3(0, 0.45, 0)
	var cell := WorldTextures.CELL_SMALL if small_leaves else WorldTextures.CELL_BROAD
	for k in 9:
		var c := centre + Vector3(mr.randf_range(-0.7, 0.7), mr.randf_range(-0.2, 0.45), mr.randf_range(-0.7, 0.7))
		var col := Color(0.8, 0.88, 0.75) if not small_leaves else Color(0.9, 0.95, 0.8)
		_cluster(leaf, mr, c, centre - Vector3(0, 0.6, 0), 0.95, 3, cell, col)
	var m := ArrayMesh.new()
	# low sway near the ground
	for i in leaf.cols.size():
		leaf.cols[i].a = 0.35
	leaf.add_to(m, WorldTextures.leaf_mat())
	return m


## Fern: arching fronds (two card segments each).
static func fern(seed_v: int) -> ArrayMesh:
	var mr := RandomNumberGenerator.new()
	mr.seed = seed_v
	var leaf := WorldGeo.new()
	var n := 9
	for k in n:
		var a := TAU * k / n + mr.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		var L := mr.randf_range(0.7, 1.1)
		var side := d.cross(Vector3.UP).normalized()
		var p0 := Vector3(0, 0.02, 0)
		var p1 := d * L * 0.5 + Vector3(0, L * 0.55, 0)
		var p2 := d * L * 1.05 + Vector3(0, L * 0.35, 0)
		var col := Color(0.9, 0.95, 0.85, 0.6)
		var nrm := (d + Vector3.UP * 1.5).normalized()
		leaf.card((p0 + p1) * 0.5, side * L * 0.22, (p1 - p0) * 0.5, nrm, col, Rect2(0.5, 0.75, 0.5, 0.25))
		leaf.card((p1 + p2) * 0.5, side * L * 0.2, (p2 - p1) * 0.5, nrm, col, Rect2(0.5, 0.5, 0.5, 0.25))
	var m := ArrayMesh.new()
	leaf.add_to(m, WorldTextures.leaf_mat("fern", 0.6))
	return m


## Fallen mossy log (lies along +Z, centred) and a broken stump.
static func log_mesh(seed_v: int, length: float) -> ArrayMesh:
	var mr := RandomNumberGenerator.new()
	mr.seed = seed_v
	var bark := WorldGeo.new()
	var r := mr.randf_range(0.35, 0.5)
	bark.limb(Vector3(0, r * 0.8, -length * 0.5), Vector3(0, r * 0.75, length * 0.5), r, r * 0.85, 9, _bark_col(0.0, 0.45), _bark_col(0.0, 0.45))
	# snapped branch stubs
	for k in 3:
		var p := Vector3(0, r * 0.8, mr.randf_range(-length * 0.4, length * 0.4))
		var d := Vector3(mr.randf_range(-1, 1), mr.randf_range(0.2, 1.0), mr.randf_range(-0.3, 0.3)).normalized()
		bark.limb(p, p + d * mr.randf_range(0.5, 1.0), r * 0.25, r * 0.12, 5, _bark_col(0.0, 0.45))
	var m := ArrayMesh.new()
	bark.add_to(m, WorldTextures.bark_mat("bark_oak", 0.7, 0.75))
	return m


static func stump_mesh(seed_v: int) -> ArrayMesh:
	var mr := RandomNumberGenerator.new()
	mr.seed = seed_v
	var bark := WorldGeo.new()
	var r := mr.randf_range(0.35, 0.55)
	bark.cylinder(Transform3D(), r * 1.15, r, mr.randf_range(0.4, 0.9), 9, _bark_col(0.0, 0.5), _bark_col(0.0, 0.62), true, 0.0, 0.0, 0.1, seed_v)
	_roots(bark, mr, r * 0.8, 4, 4, 0.5)
	var m := ArrayMesh.new()
	bark.add_to(m, WorldTextures.bark_mat("bark_oak", 0.7, 0.5))
	return m
