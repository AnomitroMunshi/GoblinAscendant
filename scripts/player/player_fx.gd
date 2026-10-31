class_name PlayerFx
## Cheap, controlled combat effects for the player: coloured swing-arc trails,
## small impact bursts and the Hobgoblin shockwave ring. Each effect is a few
## meshes animated by a tween and freed afterwards (no GPU particles).

const LIGHT_ARC := Color(0.72, 0.95, 1.0)
const HEAVY_ARC := Color(1.0, 0.72, 0.28)
const SPARK := Color(1.0, 0.9, 0.55)

static var _arc_cache: Dictionary = {}
static var _arc_pool: Array[MeshInstance3D] = []   # reused trail instances
const ARC_POOL_SIZE := 4


## Returns a free pooled trail MeshInstance3D (each with its own material).
static func _get_arc(host: Node) -> MeshInstance3D:
	var now := Time.get_ticks_msec()
	for i in range(_arc_pool.size() - 1, -1, -1):
		if not is_instance_valid(_arc_pool[i]):
			_arc_pool.remove_at(i)
	var pick: MeshInstance3D = null
	for mi in _arc_pool:
		if int(mi.get_meta(&"free_at", 0)) <= now:
			pick = mi
			break
	if pick == null and _arc_pool.size() >= ARC_POOL_SIZE:
		pick = _arc_pool[0]  # steal the oldest
		_arc_pool.remove_at(0)
		_arc_pool.append(pick)
	if pick == null:
		pick = MeshInstance3D.new()
		pick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pick.material_override = _fade_mat(Color.WHITE, true)
		_arc_pool.append(pick)
	if pick.get_parent() != host:
		if pick.get_parent():
			pick.get_parent().remove_child(pick)
		host.add_child(pick)
	var old: Variant = pick.get_meta(&"tween") if pick.has_meta(&"tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	pick.visible = true
	return pick


static func _host(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	var scene := from.get_tree().current_scene
	return scene if scene else from.get_tree().root


static func _fade_mat(color: Color, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Ribbon arc in the XZ plane: angle 0 = forward (-Z), positive = right (+X).
## Vertex alpha fades toward the tail (start) and toward the inner edge.
static func _arc_mesh(r_in: float, r_out: float, from_deg: float, to_deg: float) -> ArrayMesh:
	var key := "%.2f_%.2f_%.0f_%.0f" % [r_in, r_out, from_deg, to_deg]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 18
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	for i in seg + 1:
		var t := float(i) / float(seg)
		var a := deg_to_rad(lerpf(from_deg, to_deg, t))
		var d := Vector3(sin(a), 0.0, -cos(a))
		var alpha := pow(t, 1.6)
		verts.append(d * r_in)
		cols.append(Color(1, 1, 1, alpha * 0.15))
		verts.append(d * r_out)
		cols.append(Color(1, 1, 1, alpha))
	for i in seg:
		var a0 := i * 2
		for idx in [a0, a0 + 1, a0 + 2, a0 + 1, a0 + 3, a0 + 2]:
			st.set_color(cols[idx])
			st.add_vertex(verts[idx])
	var mesh := st.commit()
	_arc_cache[key] = mesh
	return mesh


## Spawn a swing trail. `xform` is the attacker's facing transform (origin at
## the feet, -Z forward). kind: light1/light2/light3/heavy.
static func swing_arc(from: Node, xform: Transform3D, kind: StringName, size: float = 1.0) -> void:
	var host := _host(from)
	if host == null:
		return
	var heavy := kind == &"heavy"
	var color := HEAVY_ARC if heavy else LIGHT_ARC
	var r_out := (0.78 if heavy else 0.63) * size
	var r_in := r_out * (0.6 if heavy else 0.62)
	var mesh: ArrayMesh
	var tilt := Vector3.ZERO  # rotation applied to the arc plane
	var height := 0.55 * size
	match kind:
		&"light1":
			mesh = _arc_mesh(r_in, r_out, 85.0, -80.0)
			tilt = Vector3(0, 0, deg_to_rad(-28.0))
		&"light2":
			mesh = _arc_mesh(r_in, r_out, -85.0, 80.0)
			tilt = Vector3(0, 0, deg_to_rad(24.0))
		_:
			# vertical chop: arc plane rotated to YZ, sweeping from overhead down to the front
			mesh = _arc_mesh(r_in, r_out, 165.0, -30.0)
			tilt = Vector3(0, 0, deg_to_rad(90.0))
			height = (0.5 if heavy else 0.45) * size
	var mi := _get_arc(host)
	mi.mesh = mesh
	var mat := mi.material_override as StandardMaterial3D
	mat.albedo_color = Color(color, 0.7 if heavy else 0.6)
	var life := 0.24 if heavy else 0.18
	mi.set_meta(&"free_at", Time.get_ticks_msec() + int(life * 1000.0) + 120)
	var b := xform.basis.orthonormalized() * Basis.from_euler(tilt)
	mi.global_transform = Transform3D(b, xform.origin + Vector3.UP * height)
	mi.scale = Vector3.ONE * 0.85
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.08, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.hide)
	mi.set_meta(&"tween", tw)


## Data-driven weapon trail (ChoreoLibrary move "trail"):
##   style &"arc"    {from, to, tilt (deg), height, radius, inner (r_in/r_out), heavy}
##                   the ribbon SWEEPS from `from` to `to` over the active window;
##   style &"thrust" {height, from, to (m forward), width, rise, heavy}: a short
##                   directional streak along the stab line, never a broad arc;
##   style &"none"   punches, kicks, sling releases.
static func trail(from: Node, xform: Transform3D, data: Dictionary, size: float = 1.0, active: float = 0.1) -> void:
	match data.get("style", &"none"):
		&"arc":
			_sweep_arc(from, xform, data, size, active)
		&"thrust":
			_thrust_streak(from, xform, data, size, active)


static func _sweep_arc(from: Node, xform: Transform3D, data: Dictionary, size: float, active: float) -> void:
	var host := _host(from)
	if host == null:
		return
	var heavy := bool(data.get("heavy", false))
	var r_out := float(data.get("radius", 0.63)) * size
	var r_in := r_out * float(data.get("inner", 0.62))
	var a0 := float(data.get("from", 85.0))
	var a1 := float(data.get("to", -80.0))
	var mi := _get_arc(host)
	mi.mesh = _arc_mesh(r_in, r_out, a0, lerpf(a0, a1, 0.25))
	var mat := mi.material_override as StandardMaterial3D
	mat.albedo_color = Color(HEAVY_ARC if heavy else LIGHT_ARC, 0.7 if heavy else 0.6)
	var sweep := maxf(active, 0.06)
	var life := sweep + (0.2 if heavy else 0.15)
	mi.set_meta(&"free_at", Time.get_ticks_msec() + int(life * 1000.0) + 120)
	var b := xform.basis.orthonormalized() * Basis.from_euler(Vector3(0, 0, deg_to_rad(float(data.get("tilt", 0.0)))))
	mi.global_transform = Transform3D(b, xform.origin + Vector3.UP * float(data.get("height", 0.55)) * size)
	var tw := mi.create_tween()
	tw.tween_method(func(f: float) -> void:
		if is_instance_valid(mi):
			var q := snappedf(f, 0.125)
			mi.mesh = _arc_mesh(r_in, r_out, a0, lerpf(a0, a1, q)), 0.25, 1.0, sweep)
	tw.tween_property(mat, "albedo_color:a", 0.0, life - sweep).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.hide)
	mi.set_meta(&"tween", tw)


static func _thrust_streak(from: Node, xform: Transform3D, data: Dictionary, size: float, active: float) -> void:
	var host := _host(from)
	if host == null:
		return
	var heavy := bool(data.get("heavy", false))
	var z0 := float(data.get("from", 0.25)) * size
	var z1 := float(data.get("to", 0.95)) * size
	var w := float(data.get("width", 0.07)) * size
	var rise := float(data.get("rise", 0.0)) * size
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two crossed tapered ribbons so the streak reads from the side and from above.
	for plane in 2:
		var off := Vector3(w * 0.5, 0, 0) if plane == 0 else Vector3(0, w * 0.5, 0)
		var tail := Vector3(0, 0, -z0)
		var tip := Vector3(0, rise, -z1)
		var verts := [tail - off * 0.2, tail + off * 0.2, tip - off, tip + off]
		var cols := [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0)]
		for idx in [0, 2, 1, 1, 2, 3]:
			st.set_color(cols[idx])
			st.add_vertex(verts[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _fade_mat(Color(HEAVY_ARC if heavy else LIGHT_ARC, 0.75), true)
	mi.material_override = mat
	host.add_child(mi)
	mi.global_transform = Transform3D(xform.basis.orthonormalized(), xform.origin + Vector3.UP * float(data.get("height", 0.6)) * size)
	mi.scale = Vector3(1, 1, 0.35)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, maxf(active, 0.06)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14 if not heavy else 0.2)
	tw.tween_callback(mi.queue_free)


## Small impact burst: a bright flash, a star ring and a handful of shards.
static func impact(from: Node, pos: Vector3, heavy: bool = false, color: Color = SPARK) -> void:
	var host := _host(from)
	if host == null:
		return
	var root := Node3D.new()
	host.add_child(root)
	root.global_position = pos
	var s := 1.5 if heavy else 1.0
	var flash_mat := _fade_mat(color, true)
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 10
	sm.rings = 5
	flash.mesh = sm
	flash.material_override = flash_mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flash)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 2.6 * s, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.16)
	var shard_mat := Palette.glow(color, 3.0)
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.025, 0.025, 0.22)
	var n := 8 if heavy else 6
	for i in n:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
		var sh := MeshInstance3D.new()
		sh.mesh = shard_mesh
		sh.material_override = shard_mat
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sh)
		if absf(dir.dot(Vector3.UP)) < 0.98:
			sh.look_at_from_position(Vector3.ZERO, dir, Vector3.UP)
		var dist := randf_range(0.35, 0.7) * s
		tw.tween_property(sh, "position", dir * dist, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sh, "scale", Vector3(0.2, 0.2, 0.05), 0.18).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)


## Expanding ground ring (Hobgoblin shockwave slam).
static func shockwave(from: Node, pos: Vector3, radius: float, color: Color = HEAVY_ARC) -> void:
	var host := _host(from)
	if host == null:
		return
	var mat := _fade_mat(Color(color, 0.9), true)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.08
	mi.scale = Vector3(0.3, 0.25, 0.3)
	var disc_mat := _fade_mat(Color(color.lightened(0.3), 0.45), true)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	cm.radial_segments = 32
	disc.mesh = cm
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(disc)
	disc.global_position = pos + Vector3.UP * 0.05
	disc.scale = Vector3(0.2, 1, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.6, radius), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(disc, "scale", Vector3(radius * 0.9, 1, radius * 0.9), 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc_mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
	tw.tween_callback(disc.queue_free)
