class_name AbilityEffects
## Procedural, short-lived VFX for essence abilities. Every effect frees itself.
## Style: controlled, colourful, readable; a brief anticipation beat before the
## main burst. Wolf Dash = blue-white streak, Stone Guard = amber/stone shell,
## Flame Burst = orange cone burst.

const DASH_COLOR := Color(0.72, 0.9, 1.0)
const DASH_CORE := Color(0.95, 0.98, 1.0)
const STONE_COLOR := Color(0.95, 0.66, 0.28)
const FIRE_COLOR := Color(1.0, 0.55, 0.15)
const FIRE_CORE := Color(1.0, 0.85, 0.45)


static var _mesh_cache: Dictionary = {}


## Returns a shared mesh with the same parameters (primitive meshes only build
## geometry on first use, so the throw-away duplicate is cheap). Mobile-friendly:
## repeated casts reuse the same mesh + cached Palette materials.
static func _shared(mesh: Mesh) -> Mesh:
	var key := mesh.get_class()
	for p in ["size", "radius", "height", "top_radius", "bottom_radius", "inner_radius", "outer_radius", "radial_segments", "rings"]:
		var v: Variant = mesh.get(p)
		if v != null:
			key += "|%s" % [v]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


static func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _shared(mesh)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _fade_and_free(node: Node, meshes: Array, delay: float, duration: float) -> void:
	if not node.is_inside_tree():
		return
	var tw := node.create_tween().set_parallel(true)
	for m: GeometryInstance3D in meshes:
		tw.tween_property(m, "transparency", 1.0, duration).set_delay(delay)
	tw.chain().tween_callback(node.queue_free)


## Blue-white streak along the dash path plus a small burst ring at the start.
static func dash_streak(parent: Node, from: Vector3, dir: Vector3, length: float) -> Node3D:
	var root := Node3D.new()
	root.name = "WolfDashTrail"
	parent.add_child(root)
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	root.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), from)
	var meshes := []
	for i in 3:
		var box := BoxMesh.new()
		var w := 0.10 if i == 0 else 0.05
		box.size = Vector3(w, w, length)
		var streak := _mesh(box, Palette.glow(DASH_CORE if i == 0 else DASH_COLOR, 3.0, true))
		streak.position = Vector3([0.0, -0.35, 0.35][i], [0.9, 0.6, 1.1][i], -length * 0.5)
		root.add_child(streak)
		meshes.append(streak)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.45
	ring_mesh.outer_radius = 0.6
	var ring := _mesh(ring_mesh, Palette.glow(DASH_COLOR, 2.5, true))
	ring.position = Vector3(0, 0.1, 0)
	root.add_child(ring)
	meshes.append(ring)
	var tw := root.create_tween()
	tw.tween_property(ring, "scale", Vector3(2.2, 1.0, 2.2), 0.25).from(Vector3(0.4, 1.0, 0.4))
	_fade_and_free(root, meshes, 0.12, 0.3)
	return root


## Amber stone shell parented to the player. Caller frees it via dissolve_shell().
static func stone_shell(player: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "StoneGuardShell"
	player.add_child(root)
	root.position = Vector3(0, 0.9, 0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.85
	sphere.height = 1.8
	var shell := _mesh(sphere, Palette.glow(STONE_COLOR, 1.2, true))
	shell.transparency = 0.75
	root.add_child(shell)
	var spin := Node3D.new()
	spin.name = "Chunks"
	root.add_child(spin)
	for i in 6:
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.18, 0.2)
		var chunk := _mesh(box, Palette.mat(Palette.ROCK if i % 2 == 0 else Palette.STONE_RUIN))
		var a := TAU * i / 6.0
		chunk.position = Vector3(cos(a) * 0.95, -0.4 + 0.25 * (i % 3), sin(a) * 0.95)
		chunk.rotation = Vector3(a, a * 0.7, 0.3)
		spin.add_child(chunk)
	# Anticipation: shell snaps in from small with an overshoot.
	root.scale = Vector3.ONE * 0.2
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin_tw := spin.create_tween().set_loops()
	spin_tw.tween_property(spin, "rotation:y", TAU, 2.5).from(0.0)
	return root


static func dissolve_shell(shell: Node3D) -> void:
	if not is_instance_valid(shell):
		return
	if not shell.is_inside_tree():
		shell.queue_free()
		return
	var tw := shell.create_tween()
	tw.tween_property(shell, "scale", Vector3.ONE * 1.25, 0.18)
	tw.tween_callback(shell.queue_free)


## Small glowing ember gathering at the cast origin (anticipation beat).
static func flame_charge(parent: Node, origin: Vector3, duration: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var ember := _mesh(sphere, Palette.glow(FIRE_CORE, 4.0, true))
	parent.add_child(ember)
	ember.global_position = origin
	var tw := ember.create_tween()
	tw.tween_property(ember, "scale", Vector3.ONE * 1.8, duration).from(Vector3.ONE * 0.3)
	tw.tween_callback(ember.queue_free)


## Orange cone of fire pointing along `dir`, with particles and a warm flash light.
static func flame_cone(parent: Node, origin: Vector3, dir: Vector3, length: float, width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FlameBurst"
	parent.add_child(root)
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	root.global_transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), origin)
	var meshes := []
	for i in 2:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = width * (0.5 if i == 0 else 0.3)
		cyl.height = length
		cyl.radial_segments = 16
		cyl.rings = 1
		var cone := _mesh(cyl, Palette.glow(FIRE_COLOR if i == 0 else FIRE_CORE, 2.5 + i, true))
		# Cylinder axis is +Y: rotate so the wide end points to -Z (forward).
		cone.rotation = Vector3(-PI * 0.5, 0, 0)
		cone.position = Vector3(0, 0, -length * 0.5)
		cone.transparency = 0.35 if i == 0 else 0.2
		root.add_child(cone)
		meshes.append(cone)
	var tw := root.create_tween().set_parallel(true)
	for m: Node3D in meshes:
		tw.tween_property(m, "scale", Vector3.ONE, 0.12).from(Vector3(0.3, 0.2, 0.3))
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.5
	p.explosiveness = 0.85
	p.direction = Vector3(0, 0, -1)
	p.spread = 22.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, 2.0, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 4
	pm.rings = 2
	p.mesh = _shared(pm)
	p.material_override = Palette.glow(FIRE_COLOR, 3.0)
	var grad := Gradient.new()
	grad.set_color(0, FIRE_CORE)
	grad.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = grad
	root.add_child(p)
	p.emitting = true
	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = 4.0
	light.omni_range = 6.0
	light.position = Vector3(0, 0, -1.5)
	root.add_child(light)
	tw.tween_property(light, "light_energy", 0.0, 0.5).set_delay(0.1)
	_fade_and_free(root, meshes, 0.18, 0.35)
	return root
