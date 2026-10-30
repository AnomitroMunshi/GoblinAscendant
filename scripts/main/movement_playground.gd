extends Node3D
## Lead-owned test level for the player-only build: tests movement, camera
## collision, slopes, steps and jumps without the full world.
## main.gd uses it while PLAYER_ONLY is true. Provides height_at() for the
## spawn code, and is_in_water() for a shallow pool.

const SIZE := 160.0
const POOL_CENTER := Vector3(-20, 0, 20)
const POOL_RADIUS := 6.0


func _ready() -> void:
	GameState.world = self
	_environment()
	_ground()
	# Slopes of increasing steepness: the last ones exceed floor_max_angle (46°).
	var angles := [15.0, 25.0, 35.0, 45.0, 55.0]
	for i in angles.size():
		_ramp(Vector3(-24 + i * 9, 0, -20), angles[i])
	_stairs(Vector3(24, 0, -12), 10, 0.25, 0.45)
	_stairs(Vector3(32, 0, -12), 8, 0.4, 0.5)
	# Jump course: platforms at rising heights and gaps.
	var plats := [Vector3(10, 0.6, 12), Vector3(13.5, 1.2, 14), Vector3(17, 1.8, 12), Vector3(20.5, 2.4, 14), Vector3(24.5, 2.4, 14)]
	for p: Vector3 in plats:
		_box(p, Vector3(2.4, 0.4, 2.4), Palette.STONE_RUIN)
	# Camera-collision test: a narrow corridor and a low tunnel.
	_box(Vector3(-30, 2, 10), Vector3(0.6, 4, 18), Palette.ROCK)
	_box(Vector3(-27, 2, 10), Vector3(0.6, 4, 18), Palette.ROCK)
	_box(Vector3(-28.5, 2.2, 22), Vector3(3.6, 0.5, 6), Palette.ROCK_DARK)
	_box(Vector3(-30.5, 1, 22), Vector3(0.4, 2, 6), Palette.ROCK)
	_box(Vector3(-26.5, 1, 22), Vector3(0.4, 2, 6), Palette.ROCK)
	# Pillars and a big rock to circle around.
	for i in 6:
		var a := TAU * i / 6.0
		_cylinder(Vector3(cos(a) * 9, 0, 28 + sin(a) * 9), 0.7, 5.0, Palette.STONE_RUIN)
	_box(Vector3(12, 1.5, 30), Vector3(5, 3, 4), Palette.MOSS)
	_pool()
	_boundary()


func height_at(_x: float, _z: float) -> float:
	return 0.0


func is_in_water(p: Vector3) -> bool:
	return Vector2(p.x - POOL_CENTER.x, p.z - POOL_CENTER.z).length() < POOL_RADIUS and p.y < 0.6


# ---------------------------------------------------------------- builders
func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.78, 0.85, 0.88)
	sky_mat.ground_horizon_color = Color(0.6, 0.66, 0.55)
	sky_mat.ground_bottom_color = Color(0.25, 0.32, 0.2)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.86)
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _static(shape: Shape3D, xf: Transform3D, mesh: Mesh, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.transform = xf
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Palette.mat(color)
	body.add_child(mi)
	add_child(body)
	return body


func _ground() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, 1, SIZE)
	var mesh := BoxMesh.new()
	mesh.size = box.size
	_static(box, Transform3D(Basis(), Vector3(0, -0.5, 0)), mesh, Palette.GRASS)
	# Path strips so motion and speed are easy to read.
	for i in 5:
		var strip := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(3, SIZE * 0.8)
		strip.mesh = pm
		strip.position = Vector3(-40 + i * 20, 0.01, 0)
		strip.material_override = Palette.mat(Palette.DIRT if i % 2 == 0 else Palette.GRASS_LIGHT)
		add_child(strip)


func _box(center: Vector3, size: Vector3, color: Color) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var mesh := BoxMesh.new()
	mesh.size = size
	_static(shape, Transform3D(Basis(), center), mesh, color)


func _cylinder(base: Vector3, radius: float, height: float, color: Color) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	_static(shape, Transform3D(Basis(), base + Vector3.UP * height * 0.5), mesh, color)


## A ramp rising toward -Z, 6 m wide, topped by a landing.
func _ramp(start: Vector3, angle_deg: float) -> void:
	var length := 10.0
	var rise := tan(deg_to_rad(angle_deg)) * length
	var size := Vector3(6, 0.5, length / cos(deg_to_rad(angle_deg)))
	var basis := Basis(Vector3.RIGHT, deg_to_rad(angle_deg))
	var center := start + Vector3(0, rise * 0.5 - 0.2, -length * 0.5)
	var shape := BoxShape3D.new()
	shape.size = size
	var mesh := BoxMesh.new()
	mesh.size = size
	var color := Palette.SAND if angle_deg <= 45.0 else Palette.DANGER
	_static(shape, Transform3D(basis, center), mesh, color)
	if angle_deg <= 45.0:
		_box(start + Vector3(0, rise * 0.5, -length - 2), Vector3(6, rise, 4), Palette.ROCK)
	var label := Label3D.new()
	label.text = "%d°" % int(angle_deg)
	label.font_size = 96
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = start + Vector3(0, 2.0, 1.5)
	add_child(label)


func _stairs(start: Vector3, steps: int, step_h: float, step_d: float) -> void:
	for i in steps:
		var h := step_h * (i + 1)
		_box(start + Vector3(0, h * 0.5, -i * step_d), Vector3(3, h, step_d), Palette.STONE_RUIN)
	var label := Label3D.new()
	label.text = "%.2f m steps" % step_h
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = start + Vector3(0, 2.0, 1.5)
	add_child(label)


func _pool() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = POOL_RADIUS
	cm.bottom_radius = POOL_RADIUS
	cm.height = 0.05
	mi.mesh = cm
	mi.position = POOL_CENTER + Vector3(0, 0.3, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Palette.WATER, 0.65)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	mi.material_override = m
	add_child(mi)


func _boundary() -> void:
	var h := SIZE * 0.5
	for d: Vector3 in [Vector3(h, 0, 0), Vector3(-h, 0, 0), Vector3(0, 0, h), Vector3(0, 0, -h)]:
		var size := Vector3(1, 6, SIZE) if d.x != 0.0 else Vector3(SIZE, 6, 1)
		_box(d + Vector3.UP * 3, size, Palette.ROCK_DARK)
