class_name WorldAtmosphere
extends Node3D
## Ambient particles (fireflies, pollen, falling leaves, sunbeam motes),
## glade sunbeam cards, and flickering fire lights. One _process for all.

static var _mats: Dictionary = {}

var terrain: WorldTerrain
var pollen: GPUParticles3D
var particles: Array[GPUParticles3D] = []
var flicker_lights: Array[OmniLight3D] = []
var _t := 0.0


func build(world: Node3D) -> void:
	name = "Atmosphere"
	terrain = world.terrain
	var g := WorldLayout.START_GLADE
	var w := WorldLayout.WOLF_WOODS
	# fireflies / magic motes
	_fireflies(Vector3(g.x, 0, g.z - 6), Vector3(26, 2.5, 22), 70)
	_fireflies(Vector3(w.x, 0, w.z), Vector3(45, 3, 45), 90)
	_fireflies(Vector3(WorldLayout.RUINS.x, 0, WorldLayout.RUINS.z), Vector3(30, 2.5, 30), 50)
	_fireflies(Vector3(WorldTerrain.POND.x, 0, WorldTerrain.POND.z), Vector3(8, 1.5, 8), 24)
	# falling leaves in the woods and around the giant trees
	_leaves(Vector3(w.x, 0, w.z), Vector3(55, 6, 55), 110)
	_leaves(Vector3(-42, 0, 200), Vector3(14, 4, 14), 26)
	# glade sunbeam motes
	_motes(Vector3(g.x + 4, 0, g.z - 4), Vector3(14, 5, 14), 60)
	# pollen around the camera
	pollen = _pollen()
	_sunbeams(world)


static func soft_particle_mat(col: Color, additive: bool, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%.2f" % [col.to_html(), additive, energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	m.albedo_texture = gt
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	_mats[key] = m
	return m


func _base(pos: Vector3, amount: int, life: float, box: Vector3) -> Array:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = pos
	p.visibility_aabb = AABB(-box - Vector3(4, 4, 4), box * 2.0 + Vector3(8, 12, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_meta("base_amount", amount)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	p.process_material = pm
	add_child(p)
	particles.append(p)
	return [p, pm]


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)


func _fireflies(centre: Vector3, box: Vector3, amount: int) -> void:
	var r := _base(_ground(centre) + Vector3(0, box.y + 0.4, 0), amount, 7.0, box)
	var p: GPUParticles3D = r[0]
	var pm: ParticleProcessMaterial = r[1]
	p.name = "Fireflies"
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 1))
	g.add_point(0.7, Color(1, 1, 1, 0.9))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.material = soft_particle_mat(Color(1.0, 0.92, 0.5), true, 6.0)
	p.draw_pass_1 = q
	p.visibility_range_end = 90.0


func _leaves(centre: Vector3, box: Vector3, amount: int) -> void:
	var r := _base(_ground(centre) + Vector3(0, 9, 0), amount, 9.0, box)
	var p: GPUParticles3D = r[0]
	var pm: ParticleProcessMaterial = r[1]
	p.name = "Leaves"
	pm.gravity = Vector3(0.25, -0.55, 0.1)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.25
	pm.color = Color(1, 1, 1)
	pm.hue_variation_min = -0.04
	pm.hue_variation_max = 0.06
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.62, 0.66, 0.24)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.12)
	q.material = m
	p.draw_pass_1 = q
	p.visibility_range_end = 110.0


func _motes(centre: Vector3, box: Vector3, amount: int) -> void:
	var r := _base(_ground(centre) + Vector3(0, box.y, 0), amount, 10.0, box)
	var p: GPUParticles3D = r[0]
	var pm: ParticleProcessMaterial = r[1]
	p.name = "SunMotes"
	pm.gravity = Vector3(0, 0.02, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.15
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.08
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	q.material = soft_particle_mat(Color(1.0, 0.95, 0.8), true, 3.0)
	p.draw_pass_1 = q
	p.visibility_range_end = 70.0


func _pollen() -> GPUParticles3D:
	var r := _base(WorldLayout.PLAYER_START, 140, 8.0, Vector3(18, 5, 18))
	var p: GPUParticles3D = r[0]
	var pm: ParticleProcessMaterial = r[1]
	p.name = "Pollen"
	p.local_coords = false
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 25, 60))
	pm.gravity = Vector3(0.15, -0.03, 0.08)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.7))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = soft_particle_mat(Color(1.0, 0.97, 0.85), false, 1.5)
	p.draw_pass_1 = q
	return p


## Soft god-ray cards slanting along the sun direction in the glade/woods.
func _sunbeams(world: Node3D) -> void:
	var sun_dir: Vector3 = -(Basis.from_euler(WorldSky.SUN_ROT * (PI / 180.0)).z)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/sunbeam.gdshader")
	var geo_v := PackedVector3Array()
	var geo_uv := PackedVector2Array()
	var geo_n := PackedVector3Array()
	var spots := [
		[Vector3(-4, 0, 166), 3.2], [Vector3(-18, 0, 160), 2.4], [Vector3(2, 0, 178), 2.0],
		[Vector3(-120, 0, 78), 2.6], [Vector3(-140, 0, 100), 2.0], [Vector3(-105, 0, 95), 1.8],
		[Vector3(-86, 0, -96), 2.6],
	]
	var length := 26.0
	for s: Array in spots:
		var base: Vector3 = s[0]
		base.y = terrain.height_at(base.x, base.z)
		var w: float = s[1]
		var top := base - sun_dir * length
		# two crossed quads per beam
		for k in 2:
			var side := sun_dir.cross(Vector3.UP).normalized() if k == 0 else sun_dir.cross(Vector3.RIGHT).normalized()
			side = side.rotated(sun_dir.normalized(), 0.6 * k)
			var a := base - side * w * 0.6
			var b := base + side * w * 0.6
			var c := top + side * w
			var d := top - side * w
			geo_v.append_array([a, b, c, a, c, d])
			var nrm := (b - a).cross(c - a).normalized()
			geo_n.append_array([nrm, nrm, nrm, nrm, nrm, nrm])
			geo_uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = geo_v
	arr[Mesh.ARRAY_TEX_UV] = geo_uv
	arr[Mesh.ARRAY_NORMAL] = geo_n
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Sunbeams"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	world.register_vis(mi, 70.0)


## Fire: particles + optional flickering light (no shadows).
func add_fire(parent: Node3D, pos: Vector3, scale_f: float = 1.0, with_light: bool = true) -> void:
	var r := _base(pos, int(28 * scale_f) + 6, 0.9, Vector3(0.25, 0.05, 0.25) * scale_f)
	var p: GPUParticles3D = r[0]
	var pm: ParticleProcessMaterial = r[1]
	p.name = "Fire"
	p.preprocess = 0.5
	if p.get_parent() != parent:
		p.reparent(parent, false)
	p.position = pos
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8 * scale_f
	pm.initial_velocity_max = 1.7 * scale_f
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.15))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1))
	g.set_color(1, Color(0.6, 0.12, 0.04, 0))
	g.add_point(0.4, Color(1.0, 0.5, 0.12, 0.9))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.7) * scale_f
	q.material = soft_particle_mat(Color(1, 1, 1), true, 2.5)
	p.draw_pass_1 = q
	p.visibility_range_end = 120.0
	# smoke
	var r2 := _base(pos + Vector3(0, 1.0 * scale_f, 0), int(10 * scale_f) + 3, 3.5, Vector3(0.2, 0.1, 0.2))
	var sm: GPUParticles3D = r2[0]
	var spm: ParticleProcessMaterial = r2[1]
	sm.name = "Smoke"
	sm.reparent(parent, false)
	sm.position = pos + Vector3(0, 1.0 * scale_f, 0)
	spm.direction = Vector3.UP
	spm.spread = 15.0
	spm.initial_velocity_min = 0.6
	spm.initial_velocity_max = 1.0
	spm.gravity = Vector3(0.2, 0.3, 0)
	var sc2 := Curve.new()
	sc2.add_point(Vector2(0, 0.5))
	sc2.add_point(Vector2(1, 2.0))
	var sct2 := CurveTexture.new()
	sct2.curve = sc2
	spm.scale_curve = sct2
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.5, 0.48, 0.46, 0.0))
	g2.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	g2.add_point(0.2, Color(0.45, 0.43, 0.42, 0.35))
	var gt2 := GradientTexture1D.new()
	gt2.gradient = g2
	spm.color_ramp = gt2
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.0, 1.0) * scale_f
	q2.material = soft_particle_mat(Color(1, 1, 1), false)
	sm.draw_pass_1 = q2
	sm.visibility_range_end = 120.0
	if with_light:
		var l := OmniLight3D.new()
		l.name = "FireLight"
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 1.6 * scale_f
		l.omni_range = 9.0 * scale_f
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.position = pos + Vector3(0, 0.8 * scale_f, 0)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 60.0
		l.distance_fade_length = 20.0
		l.set_meta("base_energy", l.light_energy)
		parent.add_child(l)
		flicker_lights.append(l)


func _process(delta: float) -> void:
	_t += delta
	for i in flicker_lights.size():
		var l := flicker_lights[i]
		var e: float = l.get_meta("base_energy")
		l.light_energy = e * (0.85 + 0.1 * sin(_t * 11.0 + i * 1.7) + 0.08 * sin(_t * 23.0 + i * 3.1))
	var cam := get_viewport().get_camera_3d()
	if cam and is_instance_valid(pollen):
		pollen.global_position = cam.global_position + Vector3(0, 1.0, 0)


func apply_quality() -> void:
	var q := Settings.quality()
	var f := 0.33 if q == 0 else (0.7 if q == 1 else 1.0)
	for p in particles:
		if not is_instance_valid(p):
			continue
		var base: int = p.get_meta("base_amount", p.amount)
		var n := maxi(3, int(base * f))
		if n != p.amount:
			p.amount = n
