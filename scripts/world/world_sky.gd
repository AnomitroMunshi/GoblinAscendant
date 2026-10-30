class_name WorldSky
extends Node3D
## Environment, sun, distant mountain silhouettes and the ruined castle.
## Applies graphics quality / view distance from Settings.

const SUN_ROT := Vector3(-36.0, -62.0, 0.0)

var env: Environment
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ShaderMaterial


func build(world: Node3D) -> void:
	name = "Sky"
	_build_environment()
	_build_sun()
	_build_outer_ring(world)
	_build_far_ranges()
	_build_castle(world)
	apply_quality()


func _build_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/world/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	# depth fog with aerial perspective (blends distant terrain into the sky)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.70, 0.80, 0.92)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.18
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.0
	env.fog_height = -2.0
	env.fog_height_density = 0.003
	# glow
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# ssao
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	# volumetric fog (high only)
	env.volumetric_fog_density = 0.0012
	env.volumetric_fog_albedo = Color(0.92, 0.94, 1.0)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_ambient_inject = 0.4
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROT
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.35
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.4
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)


## Coarse terrain ring from the edge of the playable grid out to ~1.1 km.
func _build_outer_ring(world: Node3D) -> void:
	var terrain: WorldTerrain = world.terrain
	var step := 16.0
	var ext := 1104.0
	var n := int(ext * 2.0 / step) + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		var z := -ext + j * step
		for i in n:
			var x := -ext + i * step
			var h := terrain.outer_height(x, z)
			if absf(x) < 257.0 and absf(z) < 257.0:
				h = terrain.height_at(clampf(x, -255.9, 255.9), clampf(z, -255.9, 255.9)) - 2.5
			hs[j * n + i] = h
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	var idx := PackedInt32Array()
	var map := PackedInt32Array()
	map.resize(n * n)
	map.fill(-1)
	for j in range(n - 1):
		for i in range(n - 1):
			var x0 := -ext + i * step
			var z0 := -ext + j * step
			if x0 >= -240.0 and x0 + step <= 240.0 and z0 >= -240.0 and z0 + step <= 240.0:
				continue
			var corners := [j * n + i, j * n + i + 1, (j + 1) * n + i, (j + 1) * n + i + 1]
			for k: int in corners:
				if map[k] < 0:
					var ci := k % n
					var cj := k / n
					var x := -ext + ci * step
					var z := -ext + cj * step
					map[k] = v.size()
					v.append(Vector3(x, hs[k], z))
					var hl := hs[cj * n + maxi(ci - 1, 0)]
					var hr := hs[cj * n + mini(ci + 1, n - 1)]
					var hu := hs[maxi(cj - 1, 0) * n + ci]
					var hd := hs[mini(cj + 1, n - 1) * n + ci]
					nn.append(Vector3(hl - hr, 2.0 * step, hu - hd).normalized())
					var dd := maxf(absf(x), absf(z))
					var forest := clampf(1.0 - (hs[k] - 30.0) / 70.0, 0.0, 1.0) * smoothstep(200.0, 300.0, dd)
					cc.append(Color(0, 0, 0, forest))
			var a: int = map[corners[0]]
			var b: int = map[corners[1]]
			var c: int = map[corners[2]]
			var d: int = map[corners[3]]
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cc
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "OuterRing"
	mi.mesh = mesh
	mi.material_override = WorldGeo.shader_mat("res://shaders/world/terrain.gdshader")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Layered, fog-tinted mountain silhouettes far beyond the ring.
func _build_far_ranges() -> void:
	var geo := WorldGeo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var layers := [[1500.0, 260.0, Color(0.48, 0.58, 0.68)], [2100.0, 420.0, Color(0.58, 0.68, 0.80)]]
	for L: Array in layers:
		var r: float = L[0]
		var amp: float = L[1]
		var col: Color = L[2]
		var segs := 120
		var prev_top := Vector3.ZERO
		var prev_bot := Vector3.ZERO
		var first_top := Vector3.ZERO
		var first_bot := Vector3.ZERO
		for i in segs + 1:
			var a := TAU * float(i % segs) / segs
			var hgt: float
			if i == segs:
				hgt = 0.0
			var n1 := sin(a * 7.0 + r) * 0.5 + 0.5
			var n2 := sin(a * 17.0 + r * 0.3) * 0.5 + 0.5
			var n3 := absf(sin(a * 41.0 + r * 0.7))
			hgt = amp * (0.35 + 0.45 * n1 * n1 + 0.15 * n2 + 0.08 * n3)
			var dir := Vector3(sin(a), 0, cos(a))
			var top := dir * r + Vector3(0, hgt, 0)
			var bot := dir * r + Vector3(0, -60.0, 0)
			if i == 0:
				first_top = top
				first_bot = bot
			elif i == segs:
				top = first_top
				bot = first_bot
			if i > 0:
				var ctop := col.lightened(0.08)
				geo.quad(prev_bot, bot, top, prev_top, col, ctop)
				geo.quad(bot, prev_bot, prev_top, top, col, ctop)
			prev_top = top
			prev_bot = bot
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.disable_fog = false
	var mi := geo.commit(self, "FarRanges", mat, false)
	mi.extra_cull_margin = 100.0


## Ruined castle silhouette on the northern mountain (no collision).
func _build_castle(_world: Node3D) -> void:
	var c := WorldLayout.CASTLE_LANDMARK
	var base := Vector3(c.x, c.y - 4.0, c.z)
	var geo := WorldGeo.new()
	var stone := Color(0.30, 0.29, 0.34)
	var stone2 := Color(0.24, 0.23, 0.29)
	var roof := Color(0.20, 0.16, 0.24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	var T := func(p: Vector3) -> Transform3D: return Transform3D(Basis(), base + p)
	# rocky plinth
	for k in 7:
		var a := TAU * k / 7.0
		geo.rock(T.call(Vector3(cos(a) * 40.0, -6.0, sin(a) * 34.0)), Vector3(26, 16, 22), Color(0.32, 0.31, 0.33), k * 1.7, 0.0)
	# keep
	geo.box(T.call(Vector3(0, 22, 0)), Vector3(30, 52, 26), stone)
	geo.tent(T.call(Vector3(0, 48, 0)), 30.0, 26.0, 16.0, roof)
	# towers
	var towers := [Vector3(-44, 0, -22), Vector3(44, 0, -24), Vector3(-40, 0, 26), Vector3(46, 0, 22), Vector3(14, 0, -6)]
	var heights := [62.0, 54.0, 38.0, 46.0, 88.0]
	for k in towers.size():
		var p: Vector3 = towers[k]
		var h: float = heights[k]
		var r := 7.0 if k < 4 else 5.0
		geo.cylinder(T.call(p + Vector3(0, -4, 0)), r * 1.1, r, h, 10, stone2, stone)
		if k == 2:
			# broken tower: jagged crown
			for m in 5:
				var a := TAU * m / 5.0
				geo.box(T.call(p + Vector3(cos(a) * r * 0.7, h - 2.0 + rng.randf() * 6.0, sin(a) * r * 0.7)), Vector3(3, 6 + rng.randf() * 6.0, 3), stone)
		else:
			geo.cylinder(T.call(p + Vector3(0, h - 4.0, 0)), r * 1.25, 0.0, r * 2.6 + (14.0 if k == 4 else 0.0), 10, roof)
	# curtain walls between towers
	var ring := [0, 1, 3, 2, 0]
	for k in 4:
		var a: Vector3 = towers[ring[k]]
		var b: Vector3 = towers[ring[k + 1]]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var yaw := atan2(b.x - a.x, b.z - a.z)
		var xf := Transform3D(Basis(Vector3.UP, yaw), base + mid + Vector3(0, 10, 0))
		if k == 2:
			# breached wall
			geo.box(xf.translated_local(Vector3(0, 0, -len * 0.3)), Vector3(4, 26, len * 0.4), stone2)
			geo.box(xf.translated_local(Vector3(0, -6, len * 0.32)), Vector3(4, 14, len * 0.36), stone2)
		else:
			geo.box(xf, Vector3(4, 26, len), stone2)
	var mi := geo.commit(self, "Castle", WorldGeo.vertex_mat(0.95), false)
	mi.extra_cull_margin = 50.0
	# A few faint ember-lit windows.
	var win := WorldGeo.new()
	for p: Vector3 in [Vector3(0, 30, 13.2), Vector3(-8, 38, 13.2), Vector3(14, 70, 5.2), Vector3(9, 22, 13.2)]:
		win.box(T.call(p), Vector3(2.0, 3.6, 0.4), Color(1.0, 0.45, 0.18))
	win.commit(self, "CastleWindows", Palette.glow(Color(1.0, 0.42, 0.16), 3.0), false)


func apply_quality() -> void:
	var q := Settings.quality()
	var vd := float(Settings.get_value(&"view_distance", 1.0))
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.glow_enabled = q >= 1
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.ssil_enabled = false
	sun.shadow_enabled = true
	match q:
		0:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 40.0
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 90.0 * clampf(vd, 0.7, 1.3)
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 140.0 * clampf(vd, 0.7, 1.3)
			sun.directional_shadow_split_1 = 0.08
			sun.directional_shadow_split_2 = 0.22
			sun.directional_shadow_split_3 = 0.5
	sky_mat.set_shader_parameter("clouds_enabled", true)
	# volumetric fog adds haze: thin the depth fog a bit to compensate
	env.fog_density = 0.0009 if q < 2 else 0.0007
