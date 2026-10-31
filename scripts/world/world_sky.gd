class_name WorldSky
extends Node3D
## Environment, sun, distant mountain silhouettes and the ruined castle.
## Applies graphics quality / view distance from Settings.

const SUN_ROT := Vector3(-36.0, -62.0, 0.0)

var env: Environment
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: Material


func build(world: Node3D) -> void:
	name = "Sky"
	_build_environment()
	_build_sun()
	_build_outer_ring(world)
	_build_far_ranges()
	_build_castle(world)
	apply_quality()


func _build_environment() -> void:
	var ps := PhysicalSkyMaterial.new()
	ps.rayleigh_coefficient = 1.6
	ps.rayleigh_color = Color(0.30, 0.42, 0.62)
	ps.mie_coefficient = 0.009
	ps.mie_eccentricity = 0.8
	ps.mie_color = Color(0.86, 0.80, 0.68)
	ps.turbidity = 8.0
	ps.sun_disk_scale = 1.2
	ps.ground_color = Color(0.22, 0.24, 0.22)
	ps.energy_multiplier = 3.2
	sky_mat = ps
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
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.95
	# depth fog with aerial perspective (blends distant terrain into the sky)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.66, 0.74, 0.84)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.18
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.0
	env.fog_height = -2.0
	env.fog_height_density = 0.003
	# glow
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# ssao
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	# volumetric fog (high only)
	env.volumetric_fog_density = 0.0028
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
	sun.light_color = Color(1.0, 0.90, 0.76)
	sun.light_energy = 1.6
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 2.0
	sun.shadow_blur = 1.4
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)


## Coarse terrain ring from the edge of the playable grid out to ~1.1 km.
func _build_outer_ring(world: Node3D) -> void:
	var terrain: WorldTerrain = world.terrain
	terrain.build_outer_grid()
	var step := WorldTerrain.OUTER_STEP
	var ext := WorldTerrain.OUTER_EXT
	var n := terrain.outer_n
	var hs := terrain.outer_h
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
	mi.material_override = WorldTextures.terrain_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Layered, haze-tinted mountain silhouettes far beyond the ring: each layer
## farther, taller and paler (aerial perspective), with irregular ridged peaks.
func _build_far_ranges() -> void:
	var geo := WorldGeo.new()
	var nz := FastNoiseLite.new()
	nz.seed = 4711
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	nz.fractal_octaves = 4
	nz.frequency = 1.0
	var layers := [
		[1350.0, 230.0, Color(0.36, 0.42, 0.46), Color(0.50, 0.55, 0.58)],
		[1900.0, 360.0, Color(0.50, 0.57, 0.63), Color(0.66, 0.70, 0.74)],
		[2700.0, 520.0, Color(0.64, 0.70, 0.77), Color(0.80, 0.83, 0.87)],
	]
	for li in layers.size():
		var L: Array = layers[li]
		var r: float = L[0]
		var amp: float = L[1]
		var col: Color = L[2]
		var snow: Color = L[3]
		var segs := 240
		var prev_top := Vector3.ZERO
		var prev_bot := Vector3.ZERO
		var prev_h := 0.0
		var first_top := Vector3.ZERO
		var first_bot := Vector3.ZERO
		for i in segs + 1:
			var a := TAU * float(i % segs) / segs
			var px := cos(a) * 3.0 + li * 10.0
			var py := sin(a) * 3.0
			var ridge := nz.get_noise_2d(px, py) * 0.5 + 0.5
			var hgt := amp * (0.25 + 0.75 * pow(ridge, 1.6))
			var dir := Vector3(sin(a), 0, cos(a))
			var top := dir * r + Vector3(0, hgt, 0)
			var bot := dir * r + Vector3(0, -80.0, 0)
			if i == 0:
				first_top = top
				first_bot = bot
			elif i == segs:
				top = first_top
				bot = first_bot
			if i > 0:
				# snow caps only on the highest peaks of each layer
				var hi := maxf(prev_h, hgt) / amp
				var ctop := col.lerp(snow, smoothstep(0.72, 0.9, hi))
				geo.quad(prev_bot, bot, top, prev_top, col.darkened(0.08), ctop)
				geo.quad(bot, prev_bot, prev_top, top, col.darkened(0.08), ctop)
			prev_top = top
			prev_bot = bot
			prev_h = hgt
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	var mi := geo.commit(self, "FarRanges", mat, false)
	mi.extra_cull_margin = 100.0
	_build_clouds()


## Soft cumulus banks far away (billboards with a noise shader, no fog).
func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/cloud.gdshader")
	var root := Node3D.new()
	root.name = "Clouds"
	add_child(root)
	for k in 46:
		var a := rng.randf() * TAU
		var d := rng.randf_range(1700.0, 3500.0)
		var w := rng.randf_range(450.0, 1100.0)
		var q := QuadMesh.new()
		q.size = Vector2(w, w * rng.randf_range(0.32, 0.5))
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(sin(a) * d, rng.randf_range(520.0, 1050.0) * (d / 2600.0), cos(a) * d)
		mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
		mi.extra_cull_margin = 200.0
		root.add_child(mi)


## Ruined castle on a rocky crag atop the northern mountain (no collision).
## Dark, weathered, partly collapsed; aerial haze desaturates it.
func _build_castle(_world: Node3D) -> void:
	var c := WorldLayout.CASTLE_LANDMARK
	var base := Vector3(c.x, c.y - 3.0, c.z)
	var geo := WorldGeo.new()
	var stone := Color(0.27, 0.26, 0.25)
	var stone2 := Color(0.22, 0.21, 0.21)
	var roof := Color(0.17, 0.16, 0.17)
	var rock := Color(0.30, 0.29, 0.28)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	var T := func(p: Vector3) -> Transform3D: return Transform3D(Basis(), base + p)
	# crag: a jagged rock mass the castle sits on, flaring down into the peak
	for k in 12:
		var a := TAU * k / 12.0 + rng.randf_range(-0.2, 0.2)
		var rr := rng.randf_range(18.0, 46.0)
		var sz := Vector3(rng.randf_range(16, 30), rng.randf_range(22, 46), rng.randf_range(16, 28))
		geo.rock(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(cos(a) * rr, -sz.y * 0.35 + rng.randf_range(-6.0, 4.0), sin(a) * rr)), sz, rock, k * 2.7, 0.0)
	geo.rock(Transform3D(Basis(), base + Vector3(0, -18, 0)), Vector3(48, 30, 40), rock, 9.1, 0.0)
	# keep with a collapsed roof
	geo.box(T.call(Vector3(0, 16, 0)), Vector3(26, 38, 22), stone)
	geo.tent(Transform3D(Basis(), base + Vector3(-6, 35, 0)), 13.0, 22.0, 9.0, roof)
	for m in 6:
		geo.box(T.call(Vector3(6 + m * 1.6, 35 + rng.randf() * 3.0, rng.randf_range(-9, 9))), Vector3(1.5, 3 + rng.randf() * 4.0, 1.5), stone2)
	# towers: one tall intact, one broken, two stumps
	var towers := [Vector3(-26, 0, -14), Vector3(26, 0, -15), Vector3(-24, 0, 16), Vector3(27, 0, 14), Vector3(8, 0, -4)]
	var heights := [40.0, 30.0, 18.0, 24.0, 56.0]
	for k in towers.size():
		var p: Vector3 = towers[k]
		var h: float = heights[k]
		var r := 5.0 if k < 4 else 3.6
		geo.cylinder(T.call(p + Vector3(0, -6, 0)), r * 1.15, r, h + 6.0, 10, stone2, stone)
		if k == 1 or k == 2 or k == 3:
			for m in 6:
				var a2 := TAU * m / 6.0
				geo.box(T.call(p + Vector3(cos(a2) * r * 0.75, h - 1.0 + rng.randf() * 5.0, sin(a2) * r * 0.75)), Vector3(2.2, 3 + rng.randf() * 6.0, 2.2), stone)
		else:
			geo.cylinder(T.call(p + Vector3(0, h, 0)), r * 1.2, 0.0, r * 2.4 + (8.0 if k == 4 else 0.0), 10, roof)
	# curtain walls, one breached and one collapsed into rubble
	var ring := [0, 1, 3, 2, 0]
	for k in 4:
		var a: Vector3 = towers[ring[k]]
		var b: Vector3 = towers[ring[k + 1]]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var yaw := atan2(b.x - a.x, b.z - a.z)
		var xf := Transform3D(Basis(Vector3.UP, yaw), base + mid + Vector3(0, 7, 0))
		if k == 2:
			geo.box(xf.translated_local(Vector3(0, 0, -len * 0.32)), Vector3(4, 22, len * 0.36), stone2)
			geo.box(xf.translated_local(Vector3(0, -6, len * 0.3)), Vector3(4, 10, len * 0.3), stone2)
		elif k == 1:
			for m in 7:
				geo.rock(xf.translated_local(Vector3(rng.randf_range(-3, 3), -6.0, rng.randf_range(-len * 0.45, len * 0.45))), Vector3(3, 2, 3), stone2, m * 1.3, 0.0)
		else:
			geo.box(xf, Vector3(4, 22, len), stone2)
	var mi := geo.commit(self, "Castle", WorldGeo.vertex_mat(0.95), false)
	mi.extra_cull_margin = 80.0


func apply_quality() -> void:
	var q := Settings.quality()
	var vd := float(Settings.get_value(&"view_distance", 1.0))
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.glow_enabled = q >= 1
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.ssil_enabled = q >= 2
	env.ssil_intensity = 0.8
	env.ssil_radius = 4.0
	sun.shadow_enabled = true
	match q:
		0:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 50.0
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 90.0 * clampf(vd, 0.7, 1.3)
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 140.0 * clampf(vd, 0.7, 1.3)
			sun.directional_shadow_split_1 = 0.08
			sun.directional_shadow_split_2 = 0.22
			sun.directional_shadow_split_3 = 0.5
	# volumetric fog adds haze: thin the depth fog a bit to compensate
	env.fog_density = 0.0009 if q < 2 else 0.0007
