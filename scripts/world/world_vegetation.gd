class_name WorldVegetation
extends Node3D
## Trees (near/far LOD MultiMeshes per 128 m chunk, trunk-only collision),
## giant landmark trees, undergrowth (card bushes, ferns), fallen logs and
## stumps, grass tufts, wildflowers and boulders. Plant meshes come from
## WorldFlora (bark + alpha-cut leaf cards). Deterministic (fixed seeds).
## Density of grass/flowers/ferns/bushes scales with graphics quality by
## re-uploading a prefix of each chunk's shuffled instance buffer.

const CHUNK := 64.0
const SEED := 20261030

var world: Node3D
var terrain: WorldTerrain
var rng := RandomNumberGenerator.new()
var _clear: Array = []          # [pos, r] areas kept free of trees
var _bins: Dictionary = {}      # "kind|cx|cz" -> {xf, col, cu}
var _trunk_body: StaticBody3D   # Layers.TREES: trunks, logs, stumps (camera ignores)
var _rock_body: StaticBody3D    # Layers.WORLD: boulders
var _trunk_shapes: Dictionary = {}
var _rock_shapes: Dictionary = {}
var _density_nodes: Array = []  # [MultiMeshInstance3D, total]
var stats := {"trees": 0, "saplings": 0, "giant_trees": 0, "bushes": 0, "ferns": 0, "logs": 0, "grass": 0, "flowers": 0,
	"boulders": 0, "outer_trees": 0, "multimeshes": 0, "trunk_shapes": 0}

var far_bins: Array = []
var tree_specs: Array = []      # per species: [near Spec, far Spec]
var bush_meshes: Array = []
var fern_meshes: Array = []
var log_meshes: Array = []
var stump_meshes: Array = []
var rock_meshes: Array = []
var grass_mesh: ArrayMesh
var flower_mesh: ArrayMesh
var mat_grass: ShaderMaterial
var mat_flower: ShaderMaterial
var mat_rock: ShaderMaterial


func build(w: Node3D) -> void:
	name = "Vegetation"
	world = w
	terrain = w.terrain
	rng.seed = SEED
	mat_grass = WorldTextures.grass_mat()
	mat_flower = ShaderMaterial.new()
	mat_flower.shader = load("res://shaders/world/flower.gdshader")
	mat_rock = WorldTextures.rock_mat("rock_mossy", 0.7, 0.32, 0.35)
	_trunk_body = StaticBody3D.new()
	_trunk_body.name = "TrunkBodies"
	_trunk_body.collision_layer = Layers.TREES
	_trunk_body.collision_mask = 0
	add_child(_trunk_body)
	_rock_body = StaticBody3D.new()
	_rock_body.name = "RockBodies"
	_rock_body.collision_layer = Layers.WORLD
	_rock_body.collision_mask = 0
	add_child(_rock_body)
	_setup_clearings()
	_make_meshes()
	_place_giants()
	for e: Array in world.extra_trees:
		var ep: Vector3 = e[0]
		_add_tree(int(e[1]), ep.x, terrain.height_at(ep.x, ep.z), ep.z, float(e[2]), _tint(0.0))
	_place_trees()
	_place_outer_trees()
	_place_boulders()
	_place_logs()
	_place_undergrowth()
	_place_grass()
	_place_flowers()
	_flush_bins()
	apply_quality()


# =================================================================== rules
func _setup_clearings() -> void:
	_clear.clear()
	for c: Vector3 in terrain.clearings:
		_clear.append([Vector3(c.x, 0, c.y), c.z])


func _in_clearing(x: float, z: float, scale_r: float = 1.0) -> bool:
	for c: Array in _clear:
		var p: Vector3 = c[0]
		var r: float = c[1] * scale_r
		if (x - p.x) * (x - p.x) + (z - p.z) * (z - p.z) < r * r:
			return true
	return false


func _idx(x: float, z: float) -> int:
	var i := clampi(int(round((x + WorldTerrain.HALF) / WorldTerrain.CELL)), 0, WorldTerrain.RES - 1)
	var j := clampi(int(round((z + WorldTerrain.HALF) / WorldTerrain.CELL)), 0, WorldTerrain.RES - 1)
	return j * WorldTerrain.RES + i


## Basic ground suitability: dry, not on paths/rock, not in the cave, not in water.
func _ground_ok(x: float, z: float, path_clear: float, river_clear: float, max_slope_y: float) -> bool:
	var k := _idx(x, z)
	if terrain.path_d[k] < path_clear:
		return false
	if terrain.river_d[k] < terrain.river_half_width(terrain.river_k[k]) + river_clear:
		return false
	if terrain.normals[k].y < max_slope_y:
		return false
	if terrain.pocket_distance(x, z) < 8.0:
		return false
	if terrain.still_d[k] < river_clear + 1.0:
		return false
	return true


func _chunk_key(kind: String, x: float, z: float) -> String:
	var c := CHUNK
	if kind.begins_with("outer"):
		c = 256.0
	elif kind.begins_with("rock") or kind.begins_with("log") or kind.begins_with("stump"):
		c = 128.0
	return "%s|%d|%d" % [kind, floori(x / c), floori(z / c)]


func _bin(kind: String, x: float, z: float, xf: Transform3D, col: Color, custom: Color = Color(0, 0, 0, 0)) -> void:
	var key := _chunk_key(kind, x, z)
	if not _bins.has(key):
		_bins[key] = {"xf": [], "col": PackedColorArray(), "cu": PackedColorArray()}
	var b: Dictionary = _bins[key]
	b["xf"].append(xf)
	b["col"].append(col)
	b["cu"].append(custom)


# =================================================================== meshes
func _make_meshes() -> void:
	for s in WorldFlora.SPECIES_COUNT:
		tree_specs.append(WorldFlora.tree(s, 1000 + s * 37))
	for k in 3:
		bush_meshes.append(WorldFlora.bush(300 + k, k == 2))
	for k in 2:
		fern_meshes.append(WorldFlora.fern(400 + k))
	for k in 2:
		log_meshes.append(WorldFlora.log_mesh(500 + k, 5.0 + k * 1.5))
		stump_meshes.append(WorldFlora.stump_mesh(600 + k))
	for k in 4:
		var g := WorldGeo.new()
		g.rock(Transform3D(), Vector3(1.0, 0.65 + 0.15 * k, 0.9), Color(0.5, 0.5, 0.48), k * 2.3 + 1.0, 0.0, 2, 0.26)
		var m := ArrayMesh.new()
		g.add_to(m, mat_rock)
		rock_meshes.append(m)
	grass_mesh = _grass_tuft()
	flower_mesh = _flower()


func _grass_tuft() -> ArrayMesh:
	var g := WorldGeo.new()
	var mr := RandomNumberGenerator.new()
	mr.seed = 31
	for i in 26:
		var a := mr.randf() * TAU
		var r := sqrt(mr.randf()) * 0.45
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := mr.randf_range(0.18, 0.42)
		var lean := Vector3(cos(a), 0, sin(a)) * mr.randf_range(0.04, 0.16)
		var side := Vector3(-sin(a + 1.2), 0, cos(a + 1.2)) * mr.randf_range(0.012, 0.022)
		var mid := base + lean * 0.35 + Vector3(0, h * 0.55, 0)
		var tip := base + lean + Vector3(0, h, 0)
		var shade := mr.randf_range(0.8, 1.15)
		var c0 := Color(shade, shade, shade, 0.0)
		var c1 := Color(shade, shade, shade, 0.55)
		var c2 := Color(shade, shade, shade, 1.0)
		g.tri(base - side, base + side, mid + side * 0.7, c0, c0, c1)
		g.tri(base - side, mid + side * 0.7, mid - side * 0.7, c0, c1, c1)
		g.tri(mid - side * 0.7, mid + side * 0.7, tip, c1, c1, c2)
	return g.to_mesh()


func _flower() -> ArrayMesh:
	# Built manually so UV.y can carry the sway weight and COLOR.a the petal mask.
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var stem := Color(0.30, 0.42, 0.20, 0.0)
	var h := 0.34
	var add := func(p: Vector3, nn: Vector3, col: Color, sway: float) -> void:
		v.append(p); n.append(nn); c.append(col); uv.append(Vector2(0, sway))
	for k in 2:
		var s := Vector3(0.008, 0, 0) if k == 0 else Vector3(0, 0, 0.008)
		var nn := Vector3(0, 0, 1) if k == 0 else Vector3(1, 0, 0)
		add.call(-s, nn, stem, 0.0); add.call(Vector3(0, h, 0) + s, nn, stem, 1.0); add.call(s, nn, stem, 0.0)
		add.call(-s, nn, stem, 0.0); add.call(Vector3(0, h, 0) - s, nn, stem, 1.0); add.call(Vector3(0, h, 0) + s, nn, stem, 1.0)
	add.call(Vector3(0, 0.06, 0), Vector3.UP, stem, 0.2); add.call(Vector3(0.12, 0.13, 0.03), Vector3.UP, stem, 0.4); add.call(Vector3(0.04, 0.12, -0.04), Vector3.UP, stem, 0.4)
	var centre := Vector3(0, h + 0.01, 0)
	var petal := Color(1, 1, 1, 1)
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), 0.2, sin(a))
		var sd := Vector3(-sin(a), 0, cos(a)) * 0.022
		var tip := centre + d * 0.06
		add.call(centre, Vector3.UP, petal, 1.0); add.call(tip + sd, Vector3.UP, petal, 1.0); add.call(tip - sd, Vector3.UP, petal, 1.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# =================================================================== trees
func _trunk(x: float, y: float, z: float, r: float, h: float) -> void:
	if absf(x) > WorldLayout.PLAYABLE_HALF + 2.0 or absf(z) > WorldLayout.PLAYABLE_HALF + 2.0:
		return
	var key := "%.2f_%.1f" % [r, h]
	if not _trunk_shapes.has(key):
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = h
		_trunk_shapes[key] = cyl
	var cs := CollisionShape3D.new()
	cs.shape = _trunk_shapes[key]
	cs.position = Vector3(x, y + h * 0.5 - 0.3, z)
	_trunk_body.add_child(cs)
	stats["trunk_shapes"] += 1


## Per-instance tint (multiplies bark + leaf colour); dark = gloomier woods.
func _tint(dark: float) -> Color:
	var v := rng.randf_range(0.88, 1.08) * (1.0 - dark)
	var warm := rng.randf() * 0.1
	return Color(v * (1.0 + warm), v * (1.0 + warm * 0.4), v * (1.0 - warm * 0.6))


func _pick_species(x: float, z: float, y: float) -> int:
	var ww := WorldLayout.WOLF_WOODS
	var in_woods := Vector2(x - ww.x, z - ww.z).length() < 85.0
	var high := smoothstep(10.0, 40.0, y)
	var k := _idx(x, z)
	var near_water := terrain.river_d[k] < 22.0 or terrain.still_d[k] < 14.0
	var r := rng.randf()
	if near_water and r < 0.5:
		return WorldFlora.BIRCH
	if in_woods:
		if r < 0.06:
			return WorldFlora.SNAG
		if r < 0.6:
			return WorldFlora.FIR if rng.randf() < 0.6 else WorldFlora.PINE
		return WorldFlora.OAK_A if rng.randf() < 0.5 else WorldFlora.BEECH
	var conifer_p := 0.22 + high * 0.6
	if rng.randf() < conifer_p:
		return WorldFlora.PINE if rng.randf() < 0.55 else WorldFlora.FIR
	if r < 0.02:
		return WorldFlora.SNAG
	var b := rng.randf()
	return WorldFlora.OAK_A if b < 0.35 else (WorldFlora.OAK_B if b < 0.6 else (WorldFlora.BEECH if b < 0.85 else WorldFlora.BIRCH))


## Overstory on a jittered grid: cell 5.0 m, jitter +-1.1 m, so trunk centres
## are always >= 2.8 m apart (>= ~1.6 m clear gap for walking actors).
## Trails stay clear (trunk centre >= 2.9 m from the trail centre line).
func _place_trees() -> void:
	var spacing := 5.0
	var jit := 1.1
	var n := int(470.0 / spacing)
	var ww := WorldLayout.WOLF_WOODS
	for gj in n:
		for gi in n:
			var x := -235.0 + gi * spacing + rng.randf_range(-jit, jit)
			var z := -235.0 + gj * spacing + rng.randf_range(-jit, jit)
			var roll := rng.randf()
			var dens := terrain.forest_density(x, z)
			if roll > dens * 0.9:
				continue
			if absf(x) > 232.0 or absf(z) > 232.0:
				continue
			if _in_clearing(x, z) or world.is_blocked(x, z, 1.4):
				continue
			if not _ground_ok(x, z, 2.9, 3.5, 0.78):
				continue
			var y := terrain.height_at(x, z)
			var in_woods := Vector2(x - ww.x, z - ww.z).length() < 90.0
			var sp := _pick_species(x, z, y)
			var s := rng.randf_range(1.05, 1.75) * (1.1 if in_woods else 1.0)
			if sp == WorldFlora.BIRCH:
				s *= 0.85
			_add_tree(sp, x, y, z, s, _tint(0.22 if in_woods else 0.05))
	_place_saplings()


## Mid layer: young trees between the trunks (no collision, thin stems).
func _place_saplings() -> void:
	var spacing := 6.5
	var n := int(470.0 / spacing)
	for gj in n:
		for gi in n:
			var x := -235.0 + (gi + 0.5) * spacing + rng.randf_range(-1.5, 1.5)
			var z := -235.0 + (gj + 0.5) * spacing + rng.randf_range(-1.5, 1.5)
			var dens := terrain.forest_density(x, z)
			if rng.randf() > dens * 0.55:
				continue
			if _in_clearing(x, z, 0.9) or world.is_blocked(x, z, 0.4):
				continue
			if not _ground_ok(x, z, 2.2, 2.0, 0.8):
				continue
			var y := terrain.height_at(x, z)
			var sp := _pick_species(x, z, y)
			if sp == WorldFlora.SNAG:
				sp = WorldFlora.FIR
			var s := rng.randf_range(0.35, 0.65)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
			_bin("sap%d" % sp, x, z, Transform3D(b, Vector3(x, y - 0.05, z)), _tint(0.08))
			stats["saplings"] += 1


func _add_tree(sp: int, x: float, y: float, z: float, s: float, tint: Color) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.92, 1.1), s))
	var xf := Transform3D(b, Vector3(x, y - 0.12, z))
	_bin("tree%d" % sp, x, z, xf, tint)
	var near: WorldFlora.Spec = tree_specs[sp][0]
	_trunk(x, y, z, near.trunk_r * s * 1.1, near.trunk_h * s)
	world.add_blocker(x, z, 1.0)
	stats["trees"] += 1


## Forest on the mountain slopes beyond the boundary: far meshes only.
func _place_outer_trees() -> void:
	var spacing := 8.0
	var ext := 420.0
	var n := int(ext * 2.0 / spacing)
	for gj in n:
		for gi in n:
			var x := -ext + gi * spacing + rng.randf_range(-3.0, 3.0)
			var z := -ext + gj * spacing + rng.randf_range(-3.0, 3.0)
			var dd := maxf(absf(x), absf(z))
			if dd < 236.0:
				continue
			var y := terrain.ring_height(x, z) if dd > 250.0 else terrain.height_at(x, z)
			if y > 72.0 + rng.randf() * 30.0:
				continue
			if terrain.castle_notch(x, z) > 0.3 and y > 20.0:
				continue
			var e := 4.0
			var slope_y := Vector3(terrain.ring_height(x - e, z) - terrain.ring_height(x + e, z), 2.0 * e, terrain.ring_height(x, z - e) - terrain.ring_height(x, z + e)).normalized().y
			if slope_y < 0.68:
				continue
			if rng.randf() > 0.65 + terrain.forest_density(x, z) * 0.3 - smoothstep(40.0, 95.0, y) * 0.45:
				continue
			var sp := (WorldFlora.PINE if rng.randf() < 0.5 else WorldFlora.FIR) if rng.randf() < 0.75 else (WorldFlora.OAK_A if rng.randf() < 0.5 else WorldFlora.BEECH)
			var s := rng.randf_range(1.0, 1.4)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, y - 0.8, z))
			_bin("outer%d" % sp, x, z, xf, _tint(0.1))
			stats["outer_trees"] += 1


## A few huge old trees as landmarks.
func _place_giants() -> void:
	var spots := [Vector3(-44, 0, 206), Vector3(-112, 0, 64), Vector3(-50, 0, -122), Vector3(152, 0, 92), Vector3(-196, 0, -12)]
	var mr := RandomNumberGenerator.new()
	mr.seed = 4242
	for i in spots.size():
		var p: Vector3 = spots[i]
		var y := terrain.height_at(p.x, p.z)
		var spec: WorldFlora.Spec = WorldFlora.giant(7000 + i * 13)
		var mi := MeshInstance3D.new()
		mi.name = "GiantTree%d" % i
		mi.mesh = spec.mesh
		mi.position = Vector3(p.x, y - 0.3, p.z)
		mi.rotation.y = mr.randf() * TAU
		add_child(mi)
		world.register_vis(mi, 950.0)
		_trunk(p.x, y, p.z, spec.trunk_r * 1.05, spec.trunk_h)
		world.add_blocker(p.x, p.z, 9.0)
		stats["giant_trees"] += 1


# =================================================================== small stuff
func _place_boulders() -> void:
	var count := 0
	var tries := 0
	while count < 300 and tries < 8000:
		tries += 1
		var x := rng.randf_range(-232.0, 232.0)
		var z := rng.randf_range(-232.0, 232.0)
		var dd := maxf(absf(x), absf(z))
		var f := terrain.forest_density(x, z)
		var p_keep := 0.22 + f * 0.5 + smoothstep(180.0, 225.0, dd) * 0.6
		if rng.randf() > p_keep:
			continue
		if _in_clearing(x, z, 0.8) or world.is_blocked(x, z, 1.5):
			continue
		if not _ground_ok(x, z, 3.5, 2.0, 0.6):
			continue
		var y := terrain.height_at(x, z)
		var s := rng.randf_range(0.45, 1.5)
		if rng.randf() < 0.2 or dd > 200.0:
			s *= rng.randf_range(1.6, 2.6)
		var kind := rng.randi() % rock_meshes.size()
		var b := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3(1, 0, 0), rng.randf_range(-0.2, 0.2)).scaled(Vector3(s, s, s))
		var xf := Transform3D(b, Vector3(x, y - 0.18 * s, z))
		_bin("rock%d" % kind, x, z, xf, Color(1, 1, 1).darkened(rng.randf() * 0.15))
		if s > 0.9:
			_rock_collider(kind, xf)
		world.add_blocker(x, z, 1.1 * s)
		count += 1
	stats["boulders"] = count


func _rock_collider(kind: int, xf: Transform3D) -> void:
	if not _rock_shapes.has(kind):
		var mesh: ArrayMesh = rock_meshes[kind]
		_rock_shapes[kind] = mesh.create_convex_shape(true, true)
	var cs := CollisionShape3D.new()
	cs.shape = _rock_shapes[kind]
	cs.transform = xf
	_rock_body.add_child(cs)


## Fallen logs (with collision) and stumps in forested areas.
func _place_logs() -> void:
	var count := 0
	var tries := 0
	while count < 220 and tries < 9000:
		tries += 1
		var x := rng.randf_range(-230.0, 230.0)
		var z := rng.randf_range(-230.0, 230.0)
		var f := terrain.forest_density(x, z)
		if rng.randf() > f * 0.9:
			continue
		if _in_clearing(x, z, 0.9) or world.is_blocked(x, z, 1.2):
			continue
		if not _ground_ok(x, z, 4.5, 3.0, 0.88):
			continue
		var y := terrain.height_at(x, z)
		var yaw := rng.randf() * TAU
		# logs lie roughly along the nearest trail so they never block it
		if terrain.path_distance(x, z) < 9.0:
			yaw = rng.randf_range(-0.3, 0.3) + atan2(x, z)
		if rng.randf() < 0.55:
			var k := rng.randi() % log_meshes.size()
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y - 0.15, z))
			_bin("log%d" % k, x, z, xf, Color(1, 1, 1))
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.42
			cap.height = 5.0 + k * 1.5
			cs.shape = cap
			cs.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, y + 0.25, z))
			_trunk_body.add_child(cs)
			world.add_blocker(x, z, 3.2)
		else:
			var k2 := rng.randi() % stump_meshes.size()
			_bin("stump%d" % k2, x, z, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y - 0.05, z)), Color(1, 1, 1))
			_trunk(x, y, z, 0.5, 0.9)
			world.add_blocker(x, z, 1.0)
		count += 1
	stats["logs"] = count


func _place_undergrowth() -> void:
	var spacing := 2.8
	var n := int(470.0 / spacing)
	for gj in n:
		for gi in n:
			var x := -235.0 + gi * spacing + rng.randf_range(-1.3, 1.3)
			var z := -235.0 + gj * spacing + rng.randf_range(-1.3, 1.3)
			var f := terrain.forest_density(x, z)
			if rng.randf() > 0.03 + f * 0.5:
				continue
			if absf(x) > 234.0 or absf(z) > 234.0:
				continue
			if _in_clearing(x, z, 0.75) or world.is_blocked(x, z, 0.5):
				continue
			if not _ground_ok(x, z, 1.9, 1.5, 0.75):
				continue
			var y := terrain.height_at(x, z)
			var fern := f > 0.4 and rng.randf() < 0.65
			var s := rng.randf_range(0.7, 1.4)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s))
			if fern:
				_bin("fern%d" % (rng.randi() % fern_meshes.size()), x, z, Transform3D(b, Vector3(x, y - 0.05, z)), _tint(0.1))
				stats["ferns"] += 1
			else:
				_bin("bush%d" % (rng.randi() % bush_meshes.size()), x, z, Transform3D(b, Vector3(x, y - 0.1, z)), _tint(f * 0.15))
				stats["bushes"] += 1


func _place_grass() -> void:
	var g := WorldLayout.START_GLADE
	for cj in 8:
		for ci in 8:
			var x0 := -256.0 + ci * CHUNK
			var z0 := -256.0 + cj * CHUNK
			var cc := Vector2(x0 + 32.0, z0 + 32.0)
			var glade := 1.0 - smoothstep(30.0, 90.0, cc.distance_to(Vector2(g.x, g.z)))
			var tries := int(1500 + glade * 2600)
			for t in tries:
				var x := x0 + rng.randf() * CHUNK
				var z := z0 + rng.randf() * CHUNK
				if absf(x) > 236.0 or absf(z) > 236.0:
					continue
				var k := _idx(x, z)
				var at := terrain.attrs[k]
				if at.r > 0.3 or at.g > 0.25 or terrain.normals[k].y < 0.8 or terrain.mud[k] > 0.5:
					continue
				if rng.randf() < at.a * 0.93:
					continue
				if terrain.river_d[k] < terrain.river_half_width(terrain.river_k[k]) + 0.8:
					continue
				if terrain.pocket_distance(x, z) < 3.0 or terrain.still_d[k] < 0.4:
					continue
				var y := terrain.height_at(x, z)
				var s := rng.randf_range(0.75, 1.25) * (1.0 + at.b * 0.25)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.25), s))
				var v := rng.randf_range(0.85, 1.12)
				var tint := Color(v, v, v * 0.95).lerp(Color(1.08, 1.02, 0.78), at.b * 0.5 + rng.randf() * 0.15).lerp(Color(0.75, 0.82, 0.72), at.a * 0.6)
				_bin("grass", x, z, Transform3D(b, Vector3(x, y - 0.03, z)), tint)
				stats["grass"] += 1


func _place_flowers() -> void:
	var g := WorldLayout.START_GLADE
	# muted, natural wildflower colours
	var cols: Array = [Color(0.88, 0.80, 0.42), Color(0.74, 0.46, 0.56), Color(0.56, 0.52, 0.76), Color(0.92, 0.90, 0.84), Color(0.84, 0.58, 0.34)]
	var fn := FastNoiseLite.new()
	fn.seed = 55
	fn.frequency = 0.02
	for t in 8000:
		var x: float
		var z: float
		if t < 2500:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 40.0
			x = g.x + cos(a) * r
			z = g.z + sin(a) * r
		else:
			x = rng.randf_range(-232.0, 232.0)
			z = rng.randf_range(-232.0, 232.0)
			if fn.get_noise_2d(x, z) < 0.3:
				continue
		var k := _idx(x, z)
		var at := terrain.attrs[k]
		if at.r > 0.25 or at.g > 0.2 or at.a > 0.45 or terrain.normals[k].y < 0.85 or terrain.mud[k] > 0.3:
			continue
		if Vector2(x - WorldLayout.PLAYER_START.x, z - WorldLayout.PLAYER_START.z).length() < 2.5:
			continue
		if terrain.pocket_distance(x, z) < 3.0 or terrain.still_d[k] < 1.0:
			continue
		var y := terrain.height_at(x, z)
		var s := rng.randf_range(0.7, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		var ci := int(absf(fn.get_noise_2d(x * 3.0 + 100.0, z * 3.0)) * 10.0 + rng.randf() * 1.6) % cols.size()
		_bin("flower", x, z, Transform3D(b, Vector3(x, y - 0.02, z)), Color(1, 1, 1), cols[ci])
		stats["flowers"] += 1


# =================================================================== output
func _flush_bins() -> void:
	var keys := _bins.keys()
	keys.sort()
	for key: String in keys:
		var parts := key.split("|")
		var kind := parts[0]
		var b: Dictionary = _bins[key]
		var xfs: Array = b["xf"]
		var cols: PackedColorArray = b["col"]
		var cus: PackedColorArray = b["cu"]
		# deterministic shuffle so any prefix is an even sample (density scaling)
		var order := range(xfs.size())
		var sr := RandomNumberGenerator.new()
		sr.seed = hash(key)
		for i in range(order.size() - 1, 0, -1):
			var j := sr.randi_range(0, i)
			var tmp: int = order[i]
			order[i] = order[j]
			order[j] = tmp
		if kind.begins_with("tree"):
			var sp: Array = tree_specs[int(kind.substr(4))]
			# near detail: 64 m chunks, node culled beyond split + chunk radius
			_mm(key + "_near", (sp[0] as WorldFlora.Spec).mesh, xfs, cols, null, order, null, true, 0.0, 100.0)
			far_bins.append([kind, xfs, cols])
		elif kind.begins_with("sap"):
			# mid layer: near-detail mesh only (it fades out at the LOD split), thinned on low
			var ssp: Array = tree_specs[int(kind.substr(3))]
			_density_nodes.append([_mm(key, (ssp[0] as WorldFlora.Spec).mesh, xfs, cols, null, order, null, true, 0.0, 100.0), xfs.size()])
		elif kind.begins_with("outer"):
			var sp2: Array = tree_specs[int(kind.substr(5))]
			_mm(key, (sp2[1] as WorldFlora.Spec).mesh, xfs, cols, null, order, null, false, 0.0, 1100.0)
		elif kind.begins_with("bush"):
			_density_nodes.append([_mm(key, bush_meshes[int(kind.substr(4))], xfs, cols, null, order, null, false, 0.0, 90.0), xfs.size()])
		elif kind.begins_with("fern"):
			_density_nodes.append([_mm(key, fern_meshes[int(kind.substr(4))], xfs, cols, null, order, null, false, 0.0, 80.0), xfs.size()])
		elif kind.begins_with("log"):
			_mm(key, log_meshes[int(kind.substr(3))], xfs, cols, null, order, null, true, 0.0, 220.0)
		elif kind.begins_with("stump"):
			_mm(key, stump_meshes[int(kind.substr(5))], xfs, cols, null, order, null, true, 0.0, 160.0)
		elif kind.begins_with("rock"):
			_mm(key, rock_meshes[int(kind.substr(4))], xfs, cols, null, order, null, true, 0.0, 400.0)
		elif kind == "grass":
			_density_nodes.append([_mm(key, grass_mesh, xfs, cols, null, order, mat_grass, false, 0.0, 110.0), xfs.size()])
		elif kind == "flower":
			_density_nodes.append([_mm(key, flower_mesh, xfs, cols, cus, order, mat_flower, false, 0.0, 110.0), xfs.size()])
	_bins.clear()
	# far LOD merged into 128 m chunks (fewer draw calls); shadows on (cascades limit them)
	var far: Dictionary = {}
	for e: Array in far_bins:
		var xa: Array = e[1]
		var ca: PackedColorArray = e[2]
		for i in xa.size():
			var t: Transform3D = xa[i]
			var k2 := "%s|%d|%d" % [e[0], floori(t.origin.x / 128.0), floori(t.origin.z / 128.0)]
			if not far.has(k2):
				far[k2] = [[], PackedColorArray()]
			far[k2][0].append(t)
			far[k2][1].append(ca[i])
	var fkeys := far.keys()
	fkeys.sort()
	for k2: String in fkeys:
		var sp2: Array = tree_specs[int(k2.split("|")[0].substr(4))]
		var fx: Array = far[k2][0]
		_mm(k2 + "_far", (sp2[1] as WorldFlora.Spec).mesh, fx, far[k2][1], null, range(fx.size()), null, false, 0.0, 950.0)
	far_bins.clear()


func _mm(n: String, mesh: Mesh, xfs: Array, cols: PackedColorArray, cus: Variant, order: Array, mat: Material, shadows: bool, vis_begin: float, vis_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var has_cu := cus != null
	mm.use_custom_data = has_cu
	mm.mesh = mesh
	# Bulk buffer: per instance 12 floats (3x4 row-major transform) + 4 colour (+ 4 custom).
	var stride := 16 + (4 if has_cu else 0)
	var buf := PackedFloat32Array()
	buf.resize(order.size() * stride)
	var w := 0
	for i in order.size():
		var src: int = order[i]
		var t: Transform3D = xfs[src]
		var bx := t.basis.x
		var by := t.basis.y
		var bz := t.basis.z
		buf[w] = bx.x; buf[w + 1] = by.x; buf[w + 2] = bz.x; buf[w + 3] = t.origin.x
		buf[w + 4] = bx.y; buf[w + 5] = by.y; buf[w + 6] = bz.y; buf[w + 7] = t.origin.y
		buf[w + 8] = bx.z; buf[w + 9] = by.z; buf[w + 10] = bz.z; buf[w + 11] = t.origin.z
		var c: Color = cols[src]
		buf[w + 12] = c.r; buf[w + 13] = c.g; buf[w + 14] = c.b; buf[w + 15] = c.a
		if has_cu:
			var cu: Color = cus[src]
			buf[w + 16] = cu.r; buf[w + 17] = cu.g; buf[w + 18] = cu.b; buf[w + 19] = cu.a
		w += stride
	mm.instance_count = order.size()
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n.replace("|", "_")
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta("full_buffer", buf)
	mmi.set_meta("stride", stride)
	add_child(mmi)
	world.register_vis(mmi, vis_end, vis_begin)
	stats["multimeshes"] += 1
	return mmi


func apply_quality() -> void:
	var q := Settings.quality()
	var vd := clampf(float(Settings.get_value(&"view_distance", 1.0)), 0.3, 2.0)
	var f := 0.3 if q == 0 else (0.65 if q == 1 else 1.0)
	for e: Array in _density_nodes:
		var mmi: MultiMeshInstance3D = e[0]
		if not is_instance_valid(mmi):
			continue
		# Instances are shuffled, so a prefix is an even sample of the chunk.
		var n := int(e[1] * f)
		var mm := mmi.multimesh
		if mm.instance_count == n:
			continue
		var full: PackedFloat32Array = mmi.get_meta("full_buffer")
		var stride: int = mmi.get_meta("stride")
		mm.instance_count = n
		if n > 0:
			mm.buffer = full.slice(0, n * stride)
	var fade := (38.0 if q == 0 else (55.0 if q == 1 else 70.0)) * vd
	mat_grass.set_shader_parameter("fade_start", fade * 0.65)
	mat_grass.set_shader_parameter("fade_end", fade)
	mat_flower.set_shader_parameter("fade_start", fade * 0.75)
	mat_flower.set_shader_parameter("fade_end", fade * 1.1)
