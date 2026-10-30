class_name WorldTerrain
extends Node3D
## Heightfield terrain for the 512 x 512 m valley.
## Heights are generated once on a 2 m grid (257 x 257 samples) from an
## analytic shape (noise + hills + border mountains + northern cliff + cave
## massif), then areas are flattened, the river/pond are carved and paths are
## smoothed. The same grid feeds the chunked render mesh and the
## HeightMapShape3D, and height_at() interpolates it with the exact triangle
## split the physics engine uses, so queries match the collision.
## Outside the grid an analytic "outer" function shapes the distant ring.

const CELL := 2.0
const RES := 257
const HALF := 256.0
const CHUNKS := 8
const CHUNK_CELLS := 32
const RIVER_HW := WorldLayout.RIVER_WIDTH * 0.5
const POOL_RADIUS := 13.0
const NOOK := Vector3(18, 0, -210)  # small alcove beside the falls (secret)
const POND := Vector3(14, 0, 160)
const POND_RADIUS := 6.0

## Diagonal used to split each grid cell into two triangles.
## false: diagonal (i+1,j)-(i,j+1) -- verified to match both Godot Physics
## and Jolt HeightMapShape3D (tests/world_check.gd). true: (i,j)-(i+1,j+1).
var diag_main := false

# Hills: x, z, height, sigma
const HILLS := [
	[-25.0, -5.0, 17.0, 30.0],    # overlook
	[-185.0, -70.0, 15.0, 38.0],
	[-60.0, 55.0, 6.0, 26.0],
	[145.0, 55.0, 9.0, 32.0],
	[195.0, 150.0, 13.0, 30.0],
	[-150.0, -165.0, 16.0, 36.0],
	[105.0, -55.0, 7.0, 28.0],
	[-205.0, 175.0, 10.0, 28.0],
	[160.0, -110.0, 8.0, 24.0],
	[-110.0, 160.0, 6.0, 30.0],
	[-200.0, 40.0, 9.0, 30.0],
]

var heights := PackedFloat32Array()
var normals := PackedVector3Array()
var attrs := PackedColorArray()        # r dirt, g sand, b meadow, a forest
var river_d := PackedFloat32Array()     # distance to river centre (<= 40 m band, else big)
var river_k := PackedFloat32Array()     # arc-length of the closest centre-line point
var path_d := PackedFloat32Array()
var valley_d := PackedFloat32Array()    # distance to the raw river polyline (wide band)

var river_pts := PackedVector3Array()   # smoothed centre line, y = water level
var river_s := PackedFloat32Array()
var river_len := 0.0
var pool_level := 0.0
var pond_level := 0.0
var cave_floor := 0.0
var falls_top := 0.0

var _nb: FastNoiseLite
var _nd: FastNoiseLite
var _nr: FastNoiseLite
var _nf: FastNoiseLite
var _flats: Array = []   # [x, z, r_in, r_out, level]
var _cave_dir := Vector2.ZERO
var _castle_line_a := Vector2(WorldLayout.OVERLOOK.x, WorldLayout.OVERLOOK.z)
var _castle_line_b := Vector2(WorldLayout.CASTLE_LANDMARK.x, WorldLayout.CASTLE_LANDMARK.z)


func _init() -> void:
	name = "Terrain"
	_nb = _noise(1337, 0.0042, 4)
	_nd = _noise(4242, 0.035, 2)
	_nr = _noise(777, 0.006, 5)
	_nr.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_nf = _noise(9001, 0.011, 3)
	var e := Vector2(WorldLayout.CAVE_ENTRANCE.x, WorldLayout.CAVE_ENTRANCE.z)
	var i := Vector2(WorldLayout.CAVE_INTERIOR.x, WorldLayout.CAVE_INTERIOR.z)
	_cave_dir = (i - e).normalized()


static func _noise(seed_v: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


# =================================================================== build
func build() -> void:
	_build_river_line()
	_rasterize_distances()
	_setup_flats()
	_generate_heights()
	_compute_normals()
	_compute_attrs()
	_build_meshes()
	_build_collision()


func _build_river_line() -> void:
	var pts: Array = WorldLayout.RIVER_POINTS
	var out := PackedVector3Array()
	for i in pts.size() - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		var seg := int(ceil(p1.distance_to(p2) / 3.0))
		for k in seg:
			var t := float(k) / seg
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(pts[pts.size() - 1])
	river_s.resize(out.size())
	var acc := 0.0
	for i in out.size():
		if i > 0:
			acc += Vector2(out[i].x, out[i].z).distance_to(Vector2(out[i - 1].x, out[i - 1].z))
		river_s[i] = acc
	river_len = acc
	# Water level: low-passed natural ground (lowered), monotonic downstream.
	var nat := PackedFloat32Array()
	nat.resize(out.size())
	for i in out.size():
		nat[i] = _natural(out[i].x, out[i].z)
	var lv := PackedFloat32Array()
	lv.resize(out.size())
	for i in out.size():
		var acc := 0.0
		var wsum := 0.0
		for k in range(maxi(i - 12, 0), mini(i + 13, out.size())):
			var wgt := 1.0 - absf(k - i) / 13.0
			acc += nat[k] * wgt
			wsum += wgt
		lv[i] = acc / wsum - 1.3
	for i in range(1, out.size()):
		lv[i] = minf(lv[i], lv[i - 1] - 0.004 * (river_s[i] - river_s[i - 1]))
	for i in out.size():
		out[i].y = lv[i]
	river_pts = out
	pool_level = lv[0]


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func river_level_at_s(s: float) -> float:
	if river_pts.is_empty():
		return 0.0
	var i := river_s.bsearch(s)
	if i <= 0:
		return river_pts[0].y
	if i >= river_s.size():
		return river_pts[river_pts.size() - 1].y
	var t := (s - river_s[i - 1]) / maxf(river_s[i] - river_s[i - 1], 0.001)
	return lerpf(river_pts[i - 1].y, river_pts[i].y, t)


func river_half_width(s: float) -> float:
	return lerpf(POOL_RADIUS, RIVER_HW, smoothstep(6.0, 30.0, s))


func _rasterize_distances() -> void:
	var n := RES * RES
	river_d.resize(n); river_d.fill(1e6)
	river_k.resize(n); river_k.fill(0.0)
	path_d.resize(n); path_d.fill(1e6)
	valley_d.resize(n); valley_d.fill(1e6)
	for i in river_pts.size() - 1:
		_raster_seg(river_pts[i], river_pts[i + 1], 42.0, 1, river_s[i], river_s[i + 1])
	for path: Array in WorldLayout.PATHS:
		for i in path.size() - 1:
			_raster_seg(path[i], path[i + 1], 10.0, 0, 0.0, 0.0)
	var rp: Array = WorldLayout.RIVER_POINTS
	for i in rp.size() - 1:
		_raster_seg(rp[i], rp[i + 1], 130.0, 2, 0.0, 0.0)


## mode 0 = paths, 1 = river (with arc length), 2 = coarse valley distance
func _raster_seg(a3: Vector3, b3: Vector3, band: float, mode: int, sa: float, sb: float) -> void:
	var ax := a3.x; var az := a3.z
	var bx := b3.x; var bz := b3.z
	var dx := bx - ax; var dz := bz - az
	var l2 := maxf(dx * dx + dz * dz, 1e-6)
	var i0 := maxi(int(floor((minf(ax, bx) - band + HALF) / CELL)), 0)
	var i1 := mini(int(ceil((maxf(ax, bx) + band + HALF) / CELL)), RES - 1)
	var j0 := maxi(int(floor((minf(az, bz) - band + HALF) / CELL)), 0)
	var j1 := mini(int(ceil((maxf(az, bz) + band + HALF) / CELL)), RES - 1)
	for j in range(j0, j1 + 1):
		var z := -HALF + j * CELL
		var row := j * RES
		for i in range(i0, i1 + 1):
			var x := -HALF + i * CELL
			var t := clampf(((x - ax) * dx + (z - az) * dz) / l2, 0.0, 1.0)
			var qx := ax + dx * t - x
			var qz := az + dz * t - z
			var d := sqrt(qx * qx + qz * qz)
			var idx := row + i
			if mode == 0:
				if d < path_d[idx]:
					path_d[idx] = d
			elif mode == 1:
				if d < river_d[idx]:
					river_d[idx] = d
					river_k[idx] = lerpf(sa, sb, t)
			elif d < valley_d[idx]:
				valley_d[idx] = d


func _setup_flats() -> void:
	var L := WorldLayout
	var defs := [
		[L.START_GLADE, 24.0, 44.0], [L.PLAYER_START, 6.0, 14.0],
		[L.ALPHA_WOLF_DEN, 10.0, 22.0], [L.RESCUE_SITE, 16.0, 28.0],
		[L.RUINS, 34.0, 52.0], [L.RUINS_SHRINE, 6.0, 12.0],
		[L.OVERLOOK, 12.0, 24.0],
		[L.ADVENTURER_CAMP, 20.0, 34.0], [L.RAIDER_OUTPOST, 22.0, 36.0],
		[L.OGRE_CLEARING, L.OGRE_ARENA_RADIUS + 2.0, L.OGRE_ARENA_RADIUS + 16.0],
		[L.CAVE_ENTRANCE, 9.0, 20.0],
	]
	for cp: StringName in L.CHECKPOINTS:
		defs.append([L.CHECKPOINTS[cp], 4.0, 10.0])
	for d: Array in defs:
		var c: Vector3 = d[0]
		_flats.append([c.x, c.z, d[1], d[2], 0.0])
	# Levels are sampled on the progressively flattened surface so overlapping
	# flats agree with each other.
	for k in _flats.size():
		var f: Array = _flats[k]
		var lvl := _natural(f[0], f[1])
		for m in k:
			lvl = _apply_flat(_flats[m], f[0], f[1], lvl)
		f[4] = lvl
	cave_floor = _flatten(WorldLayout.CAVE_ENTRANCE.x, WorldLayout.CAVE_ENTRANCE.z, _natural(WorldLayout.CAVE_ENTRANCE.x, WorldLayout.CAVE_ENTRANCE.z))


static func _apply_flat(f: Array, x: float, z: float, h: float) -> float:
	var dx: float = x - f[0]
	var dz: float = z - f[1]
	var d := sqrt(dx * dx + dz * dz)
	var r_out: float = f[3]
	if d >= r_out:
		return h
	var w := 1.0 - smoothstep(f[2], r_out, d)
	return lerpf(h, f[4], w)


func _flatten(x: float, z: float, h: float) -> float:
	for f: Array in _flats:
		h = _apply_flat(f, x, z, h)
	return h


# =================================================================== shape
## Natural ground before flattening/carving (also used for the outer ring).
func _natural(x: float, z: float, dr: float = -1.0) -> float:
	var h := 4.0 + _nb.get_noise_2d(x, z) * 9.0 + _nd.get_noise_2d(x, z) * 0.6
	for hl: Array in HILLS:
		var dx: float = x - hl[0]
		var dz: float = z - hl[1]
		var s: float = hl[3]
		var d2 := dx * dx + dz * dz
		if d2 < 9.0 * s * s:
			h += hl[2] * exp(-d2 / (2.0 * s * s))
	# soft river valley (raw polyline, large scale)
	if dr < 0.0:
		dr = WorldLayout.distance_to_river(Vector3(x, 0, z)) if absf(x) < 400 and absf(z) < 400 else 999.0
	h -= 3.5 * exp(-(dr * dr) / (55.0 * 55.0))
	h += _border(x, z)
	return h


func _border(x: float, z: float) -> float:
	var ax := absf(x)
	var az := absf(z)
	var dd := pow(pow(ax, 6.0) + pow(az, 6.0), 1.0 / 6.0)
	var edge := 216.0 + _nb.get_noise_2d(x * 0.7 + 300.0, z * 0.7) * 14.0
	var b := dd - edge
	if b <= 0.0:
		return 0.0
	var ridge := (_nr.get_noise_2d(x, z) * 0.5 + 0.5)
	var hh := 70.0 * smoothstep(0.0, 60.0, b) + ridge * 55.0 * smoothstep(10.0, 90.0, b) + maxf(0.0, b - 60.0) * 0.3
	# Lower the ridge where the overlook looks at the distant castle.
	var notch := _castle_notch(x, z)
	if notch > 0.0:
		var p := Vector2(x, z)
		var t := clampf((p - _castle_line_a).dot(_castle_line_b - _castle_line_a) / _castle_line_a.distance_squared_to(_castle_line_b), 0.0, 1.0)
		var los := lerpf(26.0, WorldLayout.CASTLE_LANDMARK.y, t) - 14.0
		hh = lerpf(hh, minf(hh, los - 4.0 - _border_base(x, z)), notch)
	return hh


func _border_base(_x: float, _z: float) -> float:
	return 4.0


func _castle_notch(x: float, z: float) -> float:
	if z > -150.0:
		return 0.0
	var p := Vector2(x, z)
	var ab := _castle_line_b - _castle_line_a
	var t := clampf((p - _castle_line_a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var d := p.distance_to(_castle_line_a + ab * t)
	return (1.0 - smoothstep(40.0, 110.0, d)) * (1.0 - smoothstep(0.92, 0.99, t))


func _cliff(x: float, z: float) -> float:
	var xm := smoothstep(-90.0, -50.0, x) * (1.0 - smoothstep(110.0, 150.0, x))
	if xm <= 0.0:
		return 0.0
	var nook := 1.0 - smoothstep(2.5, 4.5, absf(x - NOOK.x))
	var z0 := -208.5 - 6.5 * nook + _nd.get_noise_2d(x * 2.0, 50.0) * 1.5 * (1.0 - nook)
	var c := smoothstep(z0, z0 - 5.0, z)
	return 24.0 * c * xm + 4.0 * smoothstep(z0 - 5.0, z0 - 30.0, z) * xm


func _cave(x: float, z: float, h: float) -> float:
	var e := Vector2(WorldLayout.CAVE_ENTRANCE.x, WorldLayout.CAVE_ENTRANCE.z)
	var p := Vector2(x, z)
	var rel := p - e
	if rel.length_squared() > 95.0 * 95.0:
		return h
	var along := rel.dot(_cave_dir)
	var lat := absf(rel.dot(Vector2(-_cave_dir.y, _cave_dir.x)))
	var behind := smoothstep(-9.0, 3.0, along) * (1.0 - smoothstep(55.0, 85.0, lat))
	var dp := pocket_distance(x, z)
	var mass := lerpf(12.0, 30.0, smoothstep(4.0, 26.0, dp)) + _nr.get_noise_2d(x * 2.0, z * 2.0) * 4.0
	h = maxf(h, cave_floor + mass * behind)
	var pm := 1.0 - smoothstep(0.0, 4.5, dp)
	return lerpf(h, cave_floor, pm)


## Signed-ish distance to the open cave pocket (corridor + chamber). <= 0 inside.
func pocket_distance(x: float, z: float) -> float:
	var e := Vector2(WorldLayout.CAVE_ENTRANCE.x, WorldLayout.CAVE_ENTRANCE.z)
	var i := Vector2(WorldLayout.CAVE_INTERIOR.x, WorldLayout.CAVE_INTERIOR.z)
	var p := Vector2(x, z)
	var chamber := p.distance_to(i) - (WorldLayout.CAVE_RADIUS + 1.5)
	var a := e - _cave_dir * 6.0
	var ab := i - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var corridor := p.distance_to(a + ab * t) - 5.0
	return minf(chamber, corridor)


func _carve_river(idx: int, x: float, z: float, h: float) -> float:
	var d := river_d[idx]
	if d > 40.0:
		return h
	var s := river_k[idx]
	var hw := river_half_width(s)
	var wl := river_level_at_s(s)
	var depth := 1.7 if s > 20.0 else 2.4
	for f: Vector3 in WorldLayout.FORDS:
		var fd := Vector2(x - f.x, z - f.z).length()
		depth = lerpf(0.32, depth, smoothstep(5.0, 12.0, fd))
	var prof: float
	if d < hw:
		var t := d / hw
		prof = wl - depth * (1.0 - t * t) + 0.15 * t * t * t * t
	else:
		prof = wl + 0.15 + (d - hw) * 0.28
	var blend := smoothstep(hw + 1.5, hw + 24.0, d)
	var out := lerpf(prof, h, blend)
	if d >= hw + 0.5:
		out = maxf(out, wl + 0.25)
	return out


func _carve_pond(x: float, z: float, h: float) -> float:
	var d := Vector2(x - POND.x, z - POND.z).length()
	if d > POND_RADIUS + 6.0:
		return h
	var t := d / POND_RADIUS
	var prof := pond_level - 1.0 * (1.0 - t * t) + 0.1 if d < POND_RADIUS else pond_level + 0.12 + (d - POND_RADIUS) * 0.1
	return lerpf(prof, h, smoothstep(POND_RADIUS, POND_RADIUS + 6.0, d))


func _generate_heights() -> void:
	heights.resize(RES * RES)
	pond_level = _flatten(POND.x, POND.z, _natural(POND.x, POND.z)) - 0.35
	for j in RES:
		var z := -HALF + j * CELL
		var row := j * RES
		for i in RES:
			var x := -HALF + i * CELL
			var idx := row + i
			var h := _natural(x, z, valley_d[idx])
			h = _flatten(x, z, h)
			h = _carve_river(idx, x, z, h)
			h = _carve_pond(x, z, h)
			h += _cliff(x, z)
			h = _cave(x, z, h)
			heights[idx] = h
	# Smooth & slightly sink paths (but not near the river crossings).
	var src := heights.duplicate()
	for j in range(2, RES - 2):
		var row := j * RES
		for i in range(2, RES - 2):
			var idx := row + i
			var pd := path_d[idx]
			if pd > 6.0 or river_d[idx] < RIVER_HW + 7.0:
				continue
			var acc := 0.0
			for dj in range(-2, 3):
				var r2 := (j + dj) * RES
				for di in range(-2, 3):
					acc += src[r2 + i + di]
			var w := 1.0 - smoothstep(2.0, 6.0, pd)
			heights[idx] = lerpf(src[idx], acc / 25.0, w * 0.85) - 0.12 * (1.0 - smoothstep(0.8, 2.4, pd))
	falls_top = height_at(WorldLayout.WATERFALL.x, -215.0)


func _compute_normals() -> void:
	normals.resize(RES * RES)
	for j in RES:
		var jm := maxi(j - 1, 0)
		var jp := mini(j + 1, RES - 1)
		for i in RES:
			var im := maxi(i - 1, 0)
			var ip := mini(i + 1, RES - 1)
			var hx := heights[j * RES + im] - heights[j * RES + ip]
			var hz := heights[jm * RES + i] - heights[jp * RES + i]
			normals[j * RES + i] = Vector3(hx, 2.0 * CELL, hz).normalized()


## Forest density 0..1 used for terrain tint and tree placement.
func forest_density(x: float, z: float) -> float:
	var ww := WorldLayout.WOLF_WOODS
	var dw := Vector2(x - ww.x, z - ww.z).length()
	var f := 1.0 - smoothstep(45.0, 105.0, dw)
	var clump := smoothstep(0.02, 0.32, _nf.get_noise_2d(x, z)) * 0.85
	f = maxf(f, clump)
	var dd := pow(pow(absf(x), 6.0) + pow(absf(z), 6.0), 1.0 / 6.0)
	f = maxf(f, smoothstep(165.0, 210.0, dd) * 0.9)
	var g := WorldLayout.START_GLADE
	f *= smoothstep(38.0, 62.0, Vector2(x - g.x, z - g.z).length())
	return f


func _compute_attrs() -> void:
	attrs.resize(RES * RES)
	var L := WorldLayout
	var dirt_discs := [
		[L.ADVENTURER_CAMP, 15.0, 0.7], [L.RAIDER_OUTPOST, 18.0, 0.8], [L.RESCUE_SITE, 13.0, 0.75],
		[L.OGRE_CLEARING, L.OGRE_ARENA_RADIUS - 3.0, 1.0], [L.ALPHA_WOLF_DEN, 10.0, 0.55],
		[L.CAVE_ENTRANCE, 7.0, 0.6], [L.CAVE_INTERIOR, 14.0, 0.85], [L.RUINS_SHRINE, 4.0, 0.4],
	]
	for j in RES:
		var z := -HALF + j * CELL
		for i in RES:
			var x := -HALF + i * CELL
			var idx := j * RES + i
			var dirt := clampf(1.0 - path_d[idx] / 4.6, 0.0, 1.0)
			for dd: Array in dirt_discs:
				var c: Vector3 = dd[0]
				var r: float = dd[1]
				var dist := Vector2(x - c.x, z - c.z).length()
				if dist < r + 8.0:
					dirt = maxf(dirt, (1.0 - smoothstep(r * 0.55, r + 6.0, dist)) * dd[2])
			var sand := 0.0
			var rd := river_d[idx]
			if rd < 30.0:
				var hw := river_half_width(river_k[idx])
				sand = 1.0 - smoothstep(hw + 0.5, hw + 4.0 + (3.0 if river_k[idx] < 25.0 else 0.0), rd)
			var pdist := Vector2(x - POND.x, z - POND.z).length()
			sand = maxf(sand, 1.0 - smoothstep(POND_RADIUS - 0.5, POND_RADIUS + 2.0, pdist))
			var g := L.START_GLADE
			var gd := Vector2(x - g.x, z - g.z).length()
			var meadow := 1.0 - smoothstep(18.0, 46.0, gd)
			var forest := forest_density(x, z)
			attrs[idx] = Color(dirt, sand, meadow, forest)


func _build_meshes() -> void:
	var mat := WorldGeo.shader_mat("res://shaders/world/terrain.gdshader")
	var vpc := CHUNK_CELLS + 1
	for cj in CHUNKS:
		for ci in CHUNKS:
			var v := PackedVector3Array()
			var nn := PackedVector3Array()
			var cc := PackedColorArray()
			v.resize(vpc * vpc); nn.resize(vpc * vpc); cc.resize(vpc * vpc)
			for lj in vpc:
				var j := cj * CHUNK_CELLS + lj
				for li in vpc:
					var i := ci * CHUNK_CELLS + li
					var g := j * RES + i
					var k := lj * vpc + li
					v[k] = Vector3(-HALF + i * CELL, heights[g], -HALF + j * CELL)
					nn[k] = normals[g]
					cc[k] = attrs[g]
			var idx := PackedInt32Array()
			idx.resize(CHUNK_CELLS * CHUNK_CELLS * 6)
			var w := 0
			for lj in CHUNK_CELLS:
				for li in CHUNK_CELLS:
					var a := lj * vpc + li
					var b := a + 1
					var c := a + vpc
					var d := c + 1
					# clockwise seen from above = front face (Godot)
					if diag_main:
						idx[w] = a; idx[w + 1] = b; idx[w + 2] = d
						idx[w + 3] = a; idx[w + 4] = d; idx[w + 5] = c
					else:
						idx[w] = a; idx[w + 1] = b; idx[w + 2] = c
						idx[w + 3] = b; idx[w + 4] = d; idx[w + 5] = c
					w += 6
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_NORMAL] = nn
			arr[Mesh.ARRAY_COLOR] = cc
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [ci, cj]
			mi.mesh = mesh
			mi.material_override = mat
			add_child(mi)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = RES
	shape.map_depth = RES
	var data := PackedFloat32Array()
	data.resize(RES * RES)
	for k in RES * RES:
		data[k] = heights[k] * 0.5
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(CELL, CELL, CELL)
	body.add_child(cs)
	add_child(body)


# =================================================================== queries
func height_at(x: float, z: float) -> float:
	var fx := (x + HALF) / CELL
	var fz := (z + HALF) / CELL
	if fx < 0.0 or fz < 0.0 or fx > RES - 1 or fz > RES - 1:
		return outer_height(x, z)
	var i := mini(int(fx), RES - 2)
	var j := mini(int(fz), RES - 2)
	var tx := fx - i
	var tz := fz - j
	var g := j * RES + i
	var h00 := heights[g]
	var h10 := heights[g + 1]
	var h01 := heights[g + RES]
	var h11 := heights[g + RES + 1]
	if diag_main:
		if tx >= tz:
			return h00 + (h10 - h00) * tx + (h11 - h10) * tz
		return h00 + (h01 - h00) * tz + (h11 - h01) * tx
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.0
	var hx := height_at(x - e, z) - height_at(x + e, z)
	var hz := height_at(x, z - e) - height_at(x, z + e)
	return Vector3(hx, 2.0 * e, hz).normalized()


## Slope in degrees.
func slope_at(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).y, -1.0, 1.0)))


func _sample(arr: PackedFloat32Array, x: float, z: float, fallback: float) -> float:
	var i := int(round((x + HALF) / CELL))
	var j := int(round((z + HALF) / CELL))
	if i < 0 or j < 0 or i >= RES or j >= RES:
		return fallback
	return arr[j * RES + i]


func river_distance(x: float, z: float) -> float:
	return _sample(river_d, x, z, 1e6)


func path_distance(x: float, z: float) -> float:
	return _sample(path_d, x, z, 1e6)


func attr_at(x: float, z: float) -> Color:
	var i := clampi(int(round((x + HALF) / CELL)), 0, RES - 1)
	var j := clampi(int(round((z + HALF) / CELL)), 0, RES - 1)
	return attrs[j * RES + i]


## Water surface height at (x,z) if over river/pool/pond, else -INF.
func water_level_at(x: float, z: float) -> float:
	var i := int(round((x + HALF) / CELL))
	var j := int(round((z + HALF) / CELL))
	if i >= 0 and j >= 0 and i < RES and j < RES:
		var idx := j * RES + i
		if river_d[idx] < river_half_width(river_k[idx]) + 0.5:
			return river_level_at_s(river_k[idx])
	if Vector2(x - POND.x, z - POND.z).length() < POND_RADIUS:
		return pond_level
	return -INF


## Analytic shape of the distant ring (no collision) incl. castle mountain.
func outer_height(x: float, z: float) -> float:
	var h := _natural(x, z)
	var c := WorldLayout.CASTLE_LANDMARK
	var dc := Vector2(x - c.x, z - c.z).length()
	if dc < 400.0:
		var peak := (c.y - 3.0) * (1.0 - smoothstep(25.0, 190.0, dc)) + _nd.get_noise_2d(x, z) * 3.0
		peak = (c.y - 3.0) if dc < 30.0 else peak
		h = maxf(h, peak)
	var dd := maxf(absf(x), absf(z))
	h += maxf(0.0, dd - 700.0) * -0.15
	return h
