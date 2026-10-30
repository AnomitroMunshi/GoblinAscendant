class_name EnemyFx
## Short-lived combat effects (shockwave rings, impact bursts, swing arcs).
## Each effect owns a duplicated material so tweens never touch shared caches.


static func _mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _host(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	var h := from.get_parent()
	return h if h != null else from


## Expanding ground ring (ogre slam shockwave, stomp, howl).
static func shockwave(from: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.5) -> void:
	var host := _host(from)
	if host == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = EnemyModelKit.torus(0.82, 1.0)
	var m := _mat(color, 3.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.12
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.4, radius), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Flash sphere (impact dust, fire flare).
static func burst(from: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var host := _host(from)
	if host == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = EnemyModelKit.sphere(1.0, 12)
	var m := _mat(color, 2.5)
	m.albedo_color.a = 0.75
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


## Flat crescent swing arc in front of an attacker (yaw = attacker yaw).
static func swing_arc(from: Node3D, height: float, radius: float, color: Color, yaw: float, duration: float = 0.22) -> void:
	var host := _host(from)
	if host == null:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.04
	cyl.radial_segments = 24
	mi.mesh = cyl
	var m := _mat(color, 2.2)
	m.albedo_color.a = 0.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = from.global_position + Vector3.UP * height + Vector3(-sin(yaw), 0, -cos(yaw)) * radius * 0.45
	mi.rotation.y = yaw
	mi.scale = Vector3(radius * 0.8, 1.0, radius * 0.45)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.55, duration * 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, duration * 0.7)
	tw.tween_callback(mi.queue_free)
