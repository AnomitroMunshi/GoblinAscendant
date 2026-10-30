class_name WorldWater
extends Node3D
## River surface, waterfall pool, glade pond, waterfall curtain + mist,
## the stone bridge, water Area3Ds (layer WATER) and river ambience.

var terrain: WorldTerrain
var water_meshes: Array[MeshInstance3D] = []
var mat_depth: ShaderMaterial
var mat_simple: ShaderMaterial
var still_depth: ShaderMaterial
var still_simple: ShaderMaterial
var particles: Array[GPUParticles3D] = []
var stats := {}


func build(world: Node3D) -> void:
	name = "Water"
	terrain = world.terrain
	mat_depth = _water_mat("res://shaders/world/water.gdshader", 0.0)
	mat_simple = _water_mat("res://shaders/world/water_simple.gdshader", 0.0)
	still_depth = _water_mat("res://shaders/world/water.gdshader", 1.0)
	still_simple = _water_mat("res://shaders/world/water_simple.gdshader", 1.0)
	_build_river()
	_build_pond()
	_build_waterfall()
	_build_bridge(world)
	_build_ford_stones(world)
	_build_areas()
	_build_audio()
	apply_quality()


func _water_mat(path: String, still: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("still", still)
	m.render_priority = 1
	return m


# ------------------------------------------------------------------ river
func _build_river() -> void:
	var pts := terrain.river_pts
	var ss := terrain.river_s
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var extra := 1.6
	var acr := 4  # vertices across each side (soft bank gradient)
	var cols := acr * 2 + 1
	for i in pts.size():
		var p := pts[i]
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var tan := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := Vector3(-tan.z, 0, tan.x)
		var hw := terrain.river_half_width(ss[i])
		for k in cols:
			var u := float(k - acr) / acr  # -1..1
			var off := u * (hw + extra)
			v.append(Vector3(p.x, p.y, p.z) + side * off)
			nn.append(Vector3.UP)
			uv.append(Vector2(ss[i], off))
			uv2.append(Vector2(absf(off) / hw, 0))
		if i > 0:
			var r0 := (i - 1) * cols
			var r1 := i * cols
			for k in cols - 1:
				idx.append_array([r0 + k, r1 + k, r0 + k + 1, r0 + k + 1, r1 + k, r1 + k + 1])
	# upstream half-disc cap for the pool
	var p0 := pts[0]
	var t0 := Vector3(pts[1].x - p0.x, 0, pts[1].z - p0.z).normalized()
	var s0 := Vector3(-t0.z, 0, t0.x)
	var rad := terrain.river_half_width(0.0) + extra
	var centre := v.size()
	v.append(Vector3(p0.x, p0.y, p0.z)); nn.append(Vector3.UP); uv.append(Vector2.ZERO); uv2.append(Vector2.ZERO)
	var ring_start := v.size()
	var seg := 16
	for k in seg + 1:
		var ang := PI * float(k) / seg
		var dir := s0 * cos(ang) - t0 * sin(ang)
		v.append(Vector3(p0.x, p0.y, p0.z) + dir * rad)
		nn.append(Vector3.UP)
		uv.append(Vector2(-sin(ang) * rad, cos(ang) * rad))
		uv2.append(Vector2(rad / terrain.river_half_width(0.0), 0))
	for k in seg:
		idx.append_array([centre, ring_start + k + 1, ring_start + k])
	var mi := _commit_water("River", v, nn, uv, uv2, idx)
	_fix_winding(mi)
	stats["river_vertices"] = v.size()


## Ensures every water triangle faces up (Godot front faces are clockwise).
func _fix_winding(mi: MeshInstance3D) -> void:
	var mesh: ArrayMesh = mi.mesh
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var a := v[idx[t]]
		var b := v[idx[t + 1]]
		var c := v[idx[t + 2]]
		if (b - a).cross(c - a).y > 0.0:  # CCW from above -> back face; flip
			var tmp := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
	arr[Mesh.ARRAY_INDEX] = idx
	var m2 := ArrayMesh.new()
	m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = m2


func _commit_water(n: String, v: PackedVector3Array, nn: PackedVector3Array, uv: PackedVector2Array, uv2: PackedVector2Array, idx: PackedInt32Array, still: bool = false) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("still", still)
	add_child(mi)
	water_meshes.append(mi)
	return mi


func _disc(n: String, centre: Vector3, radius: float, segs: int, still: bool) -> MeshInstance3D:
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	v.append(centre); nn.append(Vector3.UP); uv.append(Vector2.ZERO); uv2.append(Vector2.ZERO)
	for ring in 2:
		var rr := radius * (0.7 if ring == 0 else 1.0)
		for k in segs:
			var a := TAU * k / segs
			v.append(centre + Vector3(cos(a) * rr, 0, sin(a) * rr))
			nn.append(Vector3.UP)
			uv.append(Vector2(cos(a), sin(a)) * rr)
			uv2.append(Vector2(rr / (radius - 1.0), 0))
	for k in segs:
		var k2 := (k + 1) % segs
		idx.append_array([0, 1 + k, 1 + k2])
		idx.append_array([1 + k, 1 + segs + k, 1 + k2, 1 + k2, 1 + segs + k, 1 + segs + k2])
	var mi := _commit_water(n, v, nn, uv, uv2, idx, still)
	_fix_winding(mi)
	return mi


func _build_pond() -> void:
	var p := WorldTerrain.POND
	_disc("Pond", Vector3(p.x, terrain.pond_level, p.z), WorldTerrain.POND_RADIUS + 1.2, 24, true)


# ------------------------------------------------------------------ waterfall
func _build_waterfall() -> void:
	var top := terrain.falls_top + 0.25
	var pool := terrain.pool_level
	var x0 := WorldLayout.WATERFALL.x
	var z_lip := -214.0
	var z_land := -205.0
	var rows := 18
	var colsn := 7
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rows + 1:
		var t := float(r) / rows
		var y := top - (top - pool + 0.3) * t * t
		var z := z_lip + (z_land - z_lip) * t
		var w := lerpf(7.0, 9.5, t)
		for c in colsn + 1:
			var u := float(c) / colsn
			var bulge := sin(u * PI) * 0.6
			v.append(Vector3(x0 + (u - 0.5) * w, y, z + bulge))
			nn.append(Vector3(0, 0.3, 1).normalized())
			uv.append(Vector2(u, t))
		if r > 0:
			var r0 := (r - 1) * (colsn + 1)
			var r1 := r * (colsn + 1)
			for c in colsn:
				idx.append_array([r0 + c, r0 + c + 1, r1 + c, r0 + c + 1, r1 + c + 1, r1 + c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall"
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/world/waterfall.gdshader")
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# foam where it lands
	var foam := MeshInstance3D.new()
	foam.name = "FallsFoam"
	var q := PlaneMesh.new()
	q.size = Vector2(16, 12)
	foam.mesh = q
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/world/foam_ring.gdshader")
	fm.render_priority = 3
	foam.material_override = fm
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.position = Vector3(x0, pool + 0.04, z_land + 1.5)
	add_child(foam)
	# mist + splash particles
	particles.append(_mist(Vector3(x0, pool + 1.0, z_land + 1.0), 48, Vector3(5, 1, 3), 3.5, 2.6, Color(1, 1, 1, 0.22)))
	particles.append(_mist(Vector3(x0, pool + 0.3, z_land), 40, Vector3(4, 0.3, 1.5), 1.2, 0.9, Color(1, 1, 1, 0.55), 4.0))
	particles.append(_mist(Vector3(x0, top - 1.0, z_lip + 0.8), 16, Vector3(3.5, 0.5, 0.5), 2.0, 1.6, Color(1, 1, 1, 0.18)))


func _mist(pos: Vector3, amount: int, box: Vector3, life: float, size: float, col: Color, up_speed: float = 1.2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = amount
	p.lifetime = life
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 16, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(0, 1, 0.4)
	pm.spread = 50.0
	pm.initial_velocity_min = up_speed * 0.5
	pm.initial_velocity_max = up_speed
	pm.gravity = Vector3(0, -1.0 if up_speed > 2.0 else 0.15, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.3))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.2, col)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = WorldAtmosphere.soft_particle_mat(Color(1, 1, 1), false)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_meta("base_amount", amount)
	add_child(p)
	return p


# ------------------------------------------------------------------ bridge
func _river_tangent_near(p: Vector3) -> Array:
	var best := INF
	var bi := 0
	var pts := terrain.river_pts
	for i in pts.size():
		var d := Vector2(pts[i].x - p.x, pts[i].z - p.z).length()
		if d < best:
			best = d
			bi = i
	var a := pts[maxi(bi - 1, 0)]
	var b := pts[mini(bi + 1, pts.size() - 1)]
	return [pts[bi], Vector3(b.x - a.x, 0, b.z - a.z).normalized()]


func _build_bridge(world: Node3D) -> void:
	var info := _river_tangent_near(WorldLayout.BRIDGE)
	var c: Vector3 = info[0]
	var tan: Vector3 = info[1]
	var axis := Vector3(-tan.z, 0, tan.x)  # across the river
	var half := WorldTerrain.RIVER_HW + 5.0
	var e0 := Vector3(c.x, 0, c.z) - axis * half
	var e1 := Vector3(c.x, 0, c.z) + axis * half
	var h0 := terrain.height_at(e0.x, e0.z)
	var h1 := terrain.height_at(e1.x, e1.z)
	var crown := maxf(h0, h1) + 1.2
	crown = maxf(crown, c.y + 2.2)
	var geo := WorldGeo.new()
	var stone := Palette.STONE_RUIN
	var body := StaticBody3D.new()
	body.name = "BridgeBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var segs := 10
	var width := 3.4
	var yaw := atan2(axis.x, axis.z)
	var prev := Vector3(e0.x, h0 - 0.05, e0.z)
	for k in range(1, segs + 1):
		var u := float(k) / segs
		var base_y := lerpf(h0, h1, u) - 0.05
		var arch := sin(u * PI)
		var y := lerpf(base_y, crown, arch)
		var p := Vector3(e0.x, 0, e0.z).lerp(Vector3(e1.x, 0, e1.z), u)
		p.y = y
		var mid := (prev + p) * 0.5
		var seg_len := prev.distance_to(p) + 0.08
		var pitch := atan2(p.y - prev.y, Vector2(p.x - prev.x, p.z - prev.z).length())
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
		var xf := Transform3D(b, mid - b.y * 0.25)
		geo.box(xf, Vector3(width, 0.5, seg_len), stone.darkened(0.05), stone.lightened(0.04))
		# parapets
		for s: float in [-1.0, 1.0]:
			var px := xf.translated_local(Vector3(s * (width * 0.5 - 0.2), 0.55, 0))
			geo.box(px, Vector3(0.4, 0.7, seg_len), stone.darkened(0.12), Palette.MOSS.lerp(stone, 0.5))
		_box_shape(body, xf, Vector3(width, 0.5, seg_len))
		for s: float in [-1.0, 1.0]:
			_box_shape(body, xf.translated_local(Vector3(s * (width * 0.5 - 0.2), 0.55, 0)), Vector3(0.4, 0.7, seg_len))
		prev = p
	# arch underside + piers
	for s: float in [-1.0, 1.0]:
		var foot := Vector3(c.x, 0, c.z) + axis * s * (WorldTerrain.RIVER_HW + 0.8)
		var fy := terrain.height_at(foot.x, foot.z)
		var top_y := lerpf(fy, crown, 0.6)
		geo.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(foot.x, (fy - 1.0 + top_y) * 0.5, foot.z)), Vector3(width + 0.4, top_y - fy + 1.0, 2.0), stone.darkened(0.2), Palette.MOSS)
	for k in 7:
		var u := lerpf(0.22, 0.78, float(k) / 6.0)
		var p := Vector3(e0.x, 0, e0.z).lerp(Vector3(e1.x, 0, e1.z), u)
		var y := lerpf(lerpf(h0, h1, u), crown, sin(u * PI)) - 0.9 - 0.25 * sin(u * PI)
		geo.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.z)), Vector3(width + 0.2, 0.9, 1.7), stone.darkened(0.15))
	geo.commit(self, "Bridge")
	world.add_blocker(c.x, c.z, half + 2.0)


func _box_shape(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	body.add_child(cs)


func _build_ford_stones(world: Node3D) -> void:
	var geo := WorldGeo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for f: Vector3 in WorldLayout.FORDS:
		var info := _river_tangent_near(f)
		var c: Vector3 = info[0]
		var tan: Vector3 = info[1]
		var axis := Vector3(-tan.z, 0, tan.x)
		for k in 9:
			var off := axis * (rng.randf_range(-7.0, 7.0)) + tan * rng.randf_range(-6.0, 6.0)
			if absf(off.dot(tan)) < 2.2:
				off += tan * 3.0 * signf(off.dot(tan) + 0.01)
			var p := Vector3(c.x, 0, c.z) + off
			var y := terrain.height_at(p.x, p.z)
			var s := rng.randf_range(0.35, 0.8)
			geo.rock(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y + s * 0.2, p.z)), Vector3(s * 1.4, s * 0.7, s), Palette.ROCK, rng.randf() * 10.0, 0.6)
	# pebbles along the banks
	for i in range(0, terrain.river_pts.size(), 3):
		var p := terrain.river_pts[i]
		var a := terrain.river_pts[maxi(i - 1, 0)]
		var b := terrain.river_pts[mini(i + 1, terrain.river_pts.size() - 1)]
		var tan := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := Vector3(-tan.z, 0, tan.x)
		var hw := terrain.river_half_width(terrain.river_s[i])
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				continue
			var q := Vector3(p.x, 0, p.z) + side * s * (hw + rng.randf_range(0.2, 2.5)) + tan * rng.randf_range(-1.5, 1.5)
			if absf(q.x) > 236 or absf(q.z) > 236:
				continue
			var sz := rng.randf_range(0.2, 0.7)
			geo.rock(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, terrain.height_at(q.x, q.z) + sz * 0.15, q.z)), Vector3(sz * 1.3, sz * 0.6, sz), Palette.ROCK.lerp(Palette.SAND, 0.3), rng.randf() * 10.0, 0.4, 0)
	geo.commit(self, "RiverStones", null, true, 220.0 * float(Settings.get_value(&"view_distance", 1.0)))


# ------------------------------------------------------------------ areas / audio
func _build_areas() -> void:
	var area := Area3D.new()
	area.name = "WaterVolume"
	area.collision_layer = Layers.WATER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	add_child(area)
	var pts := terrain.river_pts
	var step := 3
	var i := 0
	while i < pts.size() - 1:
		var j := mini(i + step, pts.size() - 1)
		var a := pts[i]
		var b := pts[j]
		var mid := (a + b) * 0.5
		var len := Vector2(b.x - a.x, b.z - a.z).length()
		var hw := terrain.river_half_width(terrain.river_s[i])
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(hw * 2.0, 2.6, len + 1.0)
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z)), Vector3(mid.x, mid.y - 1.25, mid.z))
		area.add_child(cs)
		i = j
	var pool := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = WorldTerrain.POOL_RADIUS
	cyl.height = 3.0
	pool.shape = cyl
	pool.position = Vector3(pts[0].x, pts[0].y - 1.45, pts[0].z)
	area.add_child(pool)
	var pond := CollisionShape3D.new()
	var cyl2 := CylinderShape3D.new()
	cyl2.radius = WorldTerrain.POND_RADIUS
	cyl2.height = 1.6
	pond.shape = cyl2
	pond.position = Vector3(WorldTerrain.POND.x, terrain.pond_level - 0.75, WorldTerrain.POND.z)
	area.add_child(pond)


func _build_audio() -> void:
	var pts := terrain.river_pts
	var n := 0
	for frac: float in [0.12, 0.3, 0.48, 0.66, 0.84]:
		var i := int(frac * (pts.size() - 1))
		var node := Node3D.new()
		node.name = "RiverSound%d" % n
		node.position = pts[i] + Vector3.UP * 0.5
		add_child(node)
		Audio.create_loop(&"river_loop", node)
		n += 1
	var wf := Node3D.new()
	wf.name = "WaterfallSound"
	wf.position = Vector3(WorldLayout.WATERFALL.x, terrain.pool_level + 3.0, -206.0)
	add_child(wf)
	Audio.create_loop(&"waterfall_loop", wf, 22.0)


func apply_quality() -> void:
	var q := Settings.quality()
	for mi in water_meshes:
		var still: bool = mi.get_meta("still", false)
		if q >= 1:
			mi.material_override = still_depth if still else mat_depth
		else:
			mi.material_override = still_simple if still else mat_simple
	for p in particles:
		p.amount = maxi(4, int(p.get_meta("base_amount", p.amount) * (0.35 if q == 0 else 1.0)))


func is_in_water(p: Vector3) -> bool:
	var wl := terrain.water_level_at(p.x, p.z)
	if wl == -INF:
		return false
	return p.y < wl + 0.15 and p.y > terrain.height_at(p.x, p.z) - 0.5
