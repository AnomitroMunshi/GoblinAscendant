class_name PlayerGoblinModel
extends Node3D
## Starting survivor: bare skin, opaque torn waist wrap, bare feet and chipped knife.
## Built entirely in Godot; animation joint names remain compatible with Player.
## Face follows the user's dark-haired, narrow-eyed goblin reference.
## Hobgoblin redesign and acquired equipment are separate future work.

const STAGE_SCALE := {&"goblin": 1.0, &"hobgoblin": 1.3}
const HIP_HEIGHT := 0.42
const BLADE_STEEL := Color(0.66, 0.68, 0.71)
const NEUTRAL_BROW_Z := 0.23   # concept: brows are furrowed even at rest

# ---- fed by the Player every frame -------------------------------------------
var anim_state: StringName = &"idle"   # idle, move, air, attack, dodge, backstep, block, hurt, cast, dead, dash
var anim_speed := 0.0                  # horizontal speed m/s
var anim_vertical := 0.0               # vertical speed m/s
var anim_grounded := true
var anim_sprinting := false
var anim_action: StringName = &""      # move "anim" id: light1.., punch1.., sword_cut1..
var anim_phase := 0.0                  # 0..1 windup, 1..2 active, 2..3 recovery
var anim_t := 0.0                      # normalized progress for dodge / cast / dash / hurt
var anim_move: Dictionary = {}         # ChoreoLibrary move resolved at attack start
var cast_skill: StringName = &""       # ability id for skill-specific cast poses
var hurt_kind: StringName = &"stagger" # stagger, knockdown, guard_break
var hurt_dir := Vector2(0, 1)          # hit direction in body space: x = from right, y = from front
var footsteps_enabled := true

var unarmed := false
var weapon_type: StringName = &"knife" # equipped weapon moveset (ChoreoLibrary type)
var _stowed_weapon: Node3D
var _stowed_main: Node3D
var _knife_node: Node3D
var _weapon_nodes: Dictionary = {}     # type -> Node3D under the grip socket
var _sling_arm: Node3D
var _sling_dir := Vector3.DOWN
var _flinch_dir := Vector2(0, 1)
var _block_hit := 0.0
var _ik: Dictionary = {}               # smoothed IK channels (hips space)
var foot_l: Node3D
var foot_r: Node3D

var stage: StringName = &"goblin"
var skin_mat: StandardMaterial3D

# ---- skeleton ------------------------------------------------------------------
var scale_root: Node3D
var roll: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var sword: Node3D
var blade_root: Node3D
var armour: Array[Node3D] = []

var _joints: Dictionary = {}       # name -> Node3D
var _time := 0.0
var _cycle := 0.0                  # locomotion phase (radians)
var _prev_step_sign := 1.0
var _flinch := 0.0
var _squash := 0.0
var _scale_tween: Tween
var _blade_mat: StandardMaterial3D
var _brow_l: Node3D
var _brow_r: Node3D
var _mouth_closed: Node3D
var _mouth_open: Node3D
var _blink := 0.0
var _next_blink := 2.5
var expression_override: StringName = &""   # optional, e.g. &"happy"
var _pose: Dictionary = {}
var _rest: Dictionary = {}


func _ready() -> void:
	_build()
	_stowed_weapon = _knife_node.duplicate() as Node3D
	_stowed_weapon.name = "StowedKnife"
	hips.add_child(_stowed_weapon)
	_stowed_weapon.position = Vector3(0.145, -0.005, 0.055)
	_stowed_weapon.rotation = Vector3(-PI * 0.5, 0, -0.15)
	_stowed_weapon.visible = false
	set_weapon(weapon_type)


## Shows the equipped weapon in the hand socket (or stowed when holstered).
## The knife is always carried: it sits at the waist whenever it is not in hand.
func set_weapon(type: StringName) -> void:
	weapon_type = type if ChoreoLibrary.has(type) else &"knife"
	for t: StringName in [&"sword", &"sling"]:
		if t == weapon_type and not _weapon_nodes.has(t):
			var n := ChoreoWeapons.build(t)
			sword.add_child(n)
			_weapon_nodes[t] = n
	_knife_node.visible = weapon_type == &"knife"
	for t: StringName in _weapon_nodes:
		(_weapon_nodes[t] as Node3D).visible = t == weapon_type
	_sling_arm = (_weapon_nodes[&"sling"] as Node3D).get_node_or_null("SlingArm") if _weapon_nodes.has(&"sling") else null
	if is_instance_valid(_stowed_main):
		_stowed_main.queue_free()
		_stowed_main = null
	var ms := ChoreoLibrary.moveset(weapon_type)
	if ms.has("stow") and weapon_type != &"knife":
		var st: Dictionary = ms["stow"]
		_stowed_main = ChoreoWeapons.build(weapon_type)
		_stowed_main.name = "StowedMain"
		(hips if st.get("parent", &"hips") == &"hips" else torso).add_child(_stowed_main)
		_stowed_main.position = st["pos"]
		_stowed_main.basis = Basis.looking_at(st.get("dir", Vector3.FORWARD), st.get("up", Vector3.UP))
		if st.get("coiled", false):
			var arm := _stowed_main.get_node_or_null("SlingArm") as Node3D
			if arm:
				arm.scale = Vector3(1.0, 0.3, 1.0)
	_ik.clear()
	set_weapon_drawn(not unarmed)


func set_weapon_drawn(drawn: bool) -> void:
	unarmed = not drawn
	sword.visible = drawn and weapon_type != &"unarmed"
	if is_instance_valid(_stowed_weapon):
		_stowed_weapon.visible = not (drawn and weapon_type == &"knife")
	if is_instance_valid(_stowed_main):
		_stowed_main.visible = not drawn


## The moveset currently animating (unarmed while holstered).
func active_moveset() -> Dictionary:
	return ChoreoLibrary.moveset(&"unarmed" if unarmed else weapon_type)


func get_hand_position(right: bool) -> Vector3:
	return (fore_r if right else fore_l).to_global(Vector3(0, -0.178, 0))


## World point where a sling stone leaves (pouch) or the weapon hand.
func get_release_point() -> Vector3:
	if _sling_arm and _sling_arm.is_visible_in_tree():
		return _sling_arm.to_global(Vector3(0, -ChoreoWeapons.SLING_CORD, 0))
	return get_hand_position(true)


# =============================================================== building
func _m(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	_joints[n] = p
	return p


static func _sphere(r: float, seg: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(6, seg / 2)
	return s


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return c


static func _cyl(top: float, bottom: float, h: float, seg: int = 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	return p


## Converts a primitive into a flat-shaded mesh so low segment counts read as
## crisp facets (the concept's low-poly sculpt look) instead of smooth blobs.
static func _flat(mesh: PrimitiveMesh) -> ArrayMesh:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	if idx.is_empty():
		for v in verts:
			st.add_vertex(v)
	else:
		for i in idx:
			st.add_vertex(verts[i])
	st.generate_normals()
	return st.commit()


static func _fsphere(r: float, seg: int = 10, rings: int = 7) -> SphereMesh:
	# Rounded organic forms retain the primitive silhouette without triangle seams.
	var s := _sphere(r, maxi(seg * 2, 24))
	s.rings = maxi(rings * 2, 16)
	return s


static func _fcyl(top: float, bottom: float, h: float, seg: int = 8) -> CylinderMesh:
	return _cyl(top, bottom, h, maxi(seg * 2, 20))


static func _fbox(size: Vector3) -> ArrayMesh:
	return _flat(_box(size))


## Elliptical rings create continuous anatomy and an opaque wrap with a ragged hem.
static func _profile(rings: Array[Vector3], ragged: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 24
	for row in range(rings.size() - 1):
		for col in count:
			var points: Array[Vector3] = []
			for corner in [Vector2i(row, col), Vector2i(row, col + 1), Vector2i(row + 1, col), Vector2i(row + 1, col + 1)]:
				var ring := rings[corner.x]
				var angle := TAU * float(corner.y) / count
				var y := ring.y
				if ragged and corner.x == rings.size() - 1:
					y += 0.012 * sin(angle * 7.0) + 0.009 * cos(angle * 11.0)
				points.append(Vector3(sin(angle) * ring.x, y, cos(angle) * ring.z))
			var indices := [0, 2, 1, 1, 2, 3] if rings[row + 1].y > rings[row].y else [0, 1, 2, 1, 3, 2]
			for index in indices:
				st.add_vertex(points[index])
	st.index()
	st.generate_normals()
	return st.commit()


## One continuous sculpted surface: skull, cheek planes, jaw, brow and nose.
static func _face_depth(x: float, y: float) -> float:
	var front := 0.156 * sqrt(maxf(0.0, 1.0 - pow(x / 0.19, 2.0)))
	front += 0.047 * exp(-pow(x / 0.043, 2.0) - pow((y - 0.151) / 0.034, 2.0))
	front += 0.018 * exp(-pow(x / 0.024, 2.0) - pow((y - 0.201) / 0.07, 2.0))
	for side in [-1.0, 1.0]:
		front -= 0.028 * exp(-pow((x - side * 0.083) / 0.045, 2.0) - pow((y - 0.213) / 0.027, 2.0))
		front += 0.022 * exp(-pow((x - side * 0.09) / 0.053, 2.0) - pow((y - 0.255) / 0.022, 2.0))
		front += 0.014 * exp(-pow((x - side * 0.112) / 0.043, 2.0) - pow((y - 0.142) / 0.03, 2.0))
	if y > 0.285:
		front *= sqrt(maxf(0.0, 1.0 - pow((y - 0.285) / 0.095, 2.0)))
	return front


static func _head_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 56
	var cols := 80
	var widths := [0.105, 0.14, 0.164, 0.181, 0.19, 0.189, 0.185, 0.171, 0.141, 0.08, 0.001]
	for row in rows:
		for col in cols:
			var points: Array[Vector3] = []
			for ij in [Vector2i(row, col), Vector2i(row, col + 1), Vector2i(row + 1, col), Vector2i(row + 1, col + 1)]:
				var t := float(ij.x) / rows
				var f := t * (widths.size() - 1)
				var index := mini(int(f), widths.size() - 2)
				var width := lerpf(widths[index], widths[index + 1], f - index)
				if t > 0.6:
					width = 0.185 * sqrt(maxf(0.00001, 1.0 - pow((t - 0.6) / 0.4, 2.0)))
				var angle := TAU * float(ij.y) / cols
				var x := width * sin(angle)
				var y := t * 0.38
				var z := cos(angle) * width * 0.88 + 0.022
				if cos(angle) < 0.0:
					var blend := pow(-cos(angle), 2.0)
					z = lerpf(z, -_face_depth(x, y), blend)
				points.append(Vector3(x, y, z))
			for index in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(points[index])
	for col in cols:
		var a := TAU * col / cols
		var b := TAU * (col + 1) / cols
		st.add_vertex(Vector3(0, 0, 0))
		for angle in [a, b]:
			var x := float(widths[0]) * sin(angle)
			var z := cos(angle) * float(widths[0]) * 0.88 + 0.022
			if cos(angle) < 0.0:
				z = lerpf(z, -_face_depth(x, 0), pow(-cos(angle), 2.0))
			st.add_vertex(Vector3(x, 0, z))
	st.index()
	st.generate_normals()
	return st.commit()


## Tapered eyelids bridge into the head instead of a sphere-shaped eye socket.
static func _eyelid_mesh(side: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var points: Array[Vector3] = []
		for corner: Vector2i in [Vector2i(0, i), Vector2i(0, i + 1), Vector2i(1, i), Vector2i(1, i + 1)]:
			var angle := TAU * corner.y / 40.0
			var inner := corner.x == 1
			var x := cos(angle) * (0.038 if inner else 0.047)
			var y := sin(angle) * (0.018 if inner else 0.025) + x * side * 0.17
			var z := -0.163 if inner else -_face_depth(0.083 * side + x, 0.213 + y) - 0.003
			points.append(Vector3(x, y, z + 0.15))
		for index in [0, 1, 2, 1, 3, 2]:
			st.add_vertex(points[index])
	st.generate_normals()
	return st.commit()


static func _ear_mesh(inset: bool = false) -> ArrayMesh:
	var outline: Array[Vector2] = [Vector2(-0.055, 0.0), Vector2(-0.082, 0.075), Vector2(-0.065, 0.14), Vector2(0, 0.28), Vector2(0.06, 0.14), Vector2(0.079, 0.075), Vector2(0.05, 0.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 0.105, -0.019 if inset else 0.009)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if inset:
			a = a * 0.74 + Vector2(0, 0.023)
			b = b * 0.74 + Vector2(0, 0.023)
		var z := -0.028 if inset else -0.033
		st.add_vertex(center)
		st.add_vertex(Vector3(a.x, a.y, z))
		st.add_vertex(Vector3(b.x, b.y, z))
	st.generate_normals()
	return st.commit()


## Curved tapered polygon locks, authored in head space; no imported hair assets.
static func _hair_lock(start: Vector3, bend: Vector3, tip: Vector3, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for row in 7:
		var t := float(row) / 6.0
		var center := start * pow(1.0 - t, 2.0) + bend * (2.0 * t * (1.0 - t)) + tip * t * t
		var tangent := ((bend - start) * (1.0 - t) + (tip - bend) * t).normalized()
		var right := tangent.cross(Vector3.FORWARD).normalized()
		if right.length_squared() < 0.1:
			right = Vector3.RIGHT
		var normal := right.cross(tangent).normalized()
		var radius := width * pow(1.0 - t, 0.75) * (0.75 + sin(t * PI) * 0.4)
		for col in 6:
			var angle := TAU * col / 6.0
			points.append(center + right * cos(angle) * radius + normal * sin(angle) * radius * 0.45)
	for row in 6:
		for col in 6:
			var a := row * 6 + col
			var b := row * 6 + (col + 1) % 6
			for index in [a, b, a + 6, b, b + 6, a + 6]:
				st.add_vertex(points[index])
	st.generate_normals()
	return st.commit()


func _build_hair() -> void:
	var hair := Palette.mat(Color(0.075, 0.061, 0.048), 0.94).duplicate()
	hair.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lighter := Palette.mat(Color(0.11, 0.089, 0.061), 0.94).duplicate()
	lighter.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cap := _m(head, _fsphere(0.18, 18, 12), hair, Vector3(0, 0.31, 0.025), Vector3.ZERO, Vector3(1.05, 0.64, 0.98))
	cap.name = "HairCap"
	# Irregular swept crown silhouette, with alternating lengths and directions.
	var locks: Array[Array] = [
		[Vector3(-0.13, 0.34, 0.01), Vector3(-0.23, 0.42, -0.02), Vector3(-0.16, 0.51, -0.005), 0.065],
		[Vector3(-0.07, 0.37, -0.01), Vector3(-0.10, 0.50, -0.02), Vector3(-0.055, 0.57, 0.015), 0.066],
		[Vector3(0, 0.38, -0.015), Vector3(0.035, 0.48, -0.02), Vector3(0.105, 0.53, 0), 0.065],
		[Vector3(0.08, 0.36, 0), Vector3(0.19, 0.45, 0), Vector3(0.24, 0.49, 0.03), 0.06],
		[Vector3(0.13, 0.32, 0.04), Vector3(0.23, 0.37, 0.06), Vector3(0.265, 0.41, 0.07), 0.055],
		[Vector3(-0.12, 0.31, 0.10), Vector3(-0.23, 0.37, 0.13), Vector3(-0.26, 0.40, 0.12), 0.055],
		[Vector3(0.025, 0.35, 0.13), Vector3(0.09, 0.43, 0.21), Vector3(0.15, 0.48, 0.22), 0.075],
		[Vector3(-0.06, 0.34, 0.13), Vector3(-0.10, 0.43, 0.22), Vector3(-0.035, 0.49, 0.23), 0.065],
		# Front fringe: tapered locks overlap naturally, tips stop above the eyes.
		[Vector3(-0.125, 0.33, -0.10), Vector3(-0.16, 0.29, -0.17), Vector3(-0.13, 0.225, -0.174), 0.052],
		[Vector3(-0.075, 0.35, -0.12), Vector3(-0.08, 0.28, -0.18), Vector3(-0.018, 0.25, -0.19), 0.058],
		[Vector3(0.005, 0.36, -0.12), Vector3(0.04, 0.30, -0.20), Vector3(0.105, 0.27, -0.18), 0.062],
		[Vector3(0.085, 0.34, -0.10), Vector3(0.15, 0.31, -0.16), Vector3(0.17, 0.235, -0.12), 0.052],
		[Vector3(-0.165, 0.285, 0), Vector3(-0.185, 0.23, -0.025), Vector3(-0.16, 0.155, -0.03), 0.033],
		[Vector3(0.165, 0.28, 0), Vector3(0.18, 0.22, -0.02), Vector3(0.16, 0.16, -0.02), 0.033],
		[Vector3(-0.12, 0.25, 0.13), Vector3(-0.15, 0.19, 0.15), Vector3(-0.14, 0.13, 0.13), 0.045],
		[Vector3(0.12, 0.25, 0.13), Vector3(0.15, 0.19, 0.15), Vector3(0.14, 0.13, 0.13), 0.045],
	]
	for i in locks.size():
		var lock: Array = locks[i]
		var tuft := _m(head, _hair_lock(lock[0], lock[1], lock[2], lock[3]), lighter if i % 4 == 0 else hair, Vector3(0, 0.098, 0))
		tuft.scale.y = 0.67


## Sculpted limb profiles overlap at articulation points to avoid toy-like balls.
static func _limb(length: float, radius: float, forearm: bool = false) -> ArrayMesh:
	var rings: Array[Vector3] = []
	var radii := [0.20, 0.73, 1.0, 0.96, 0.82, 0.70, 0.65, 0.42]
	if forearm:
		radii = [0.55, 0.84, 1.0, 0.96, 0.80, 0.65, 0.52, 0.38]
	for i in radii.size():
		var t := float(i) / (radii.size() - 1)
		var r: float = radius * radii[i]
		rings.append(Vector3(r, -length * t + 0.025, r * 0.9))
	return _profile(rings)


static func _eye_leaf() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a := TAU * i / 40.0
		var b := TAU * (i + 1) / 40.0
		st.add_vertex(Vector3(0, 0, -0.018))
		st.add_vertex(Vector3(cos(b) * 0.041, sin(b) * 0.020, -0.009))
		st.add_vertex(Vector3(cos(a) * 0.041, sin(a) * 0.020, -0.009))
	st.generate_normals()
	return st.commit()


static func _nose_mesh() -> ArrayMesh:
	var points: Array[Vector3] = [Vector3(0, 0.202, -0.174), Vector3(-0.027, 0.145, -0.180), Vector3(-0.023, 0.137, -0.215), Vector3(0, 0.145, -0.235), Vector3(0.023, 0.137, -0.215), Vector3(0.027, 0.145, -0.180), Vector3(0, 0.124, -0.187)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 2, 1, 0, 3, 2, 0, 4, 3, 0, 5, 4, 2, 6, 1, 2, 3, 6, 3, 4, 6, 4, 5, 6]:
		st.add_vertex(points[i])
	st.index()
	st.generate_normals()
	return st.commit()


func _build() -> void:
	skin_mat = Palette.mat(Color(0.39, 0.43, 0.235), 0.8).duplicate()
	skin_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	skin_mat.roughness = 0.88
	var ear_inner := Palette.mat(Color(0.30, 0.34, 0.16), 0.85)
	var nose_mat := Palette.mat(Color(0.36, 0.37, 0.19), 0.9).duplicate()
	nose_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var brow_mat := Palette.mat(Color(0.11, 0.085, 0.055), 0.9)
	var eye_white := Palette.mat(Color(0.78, 0.76, 0.63), 0.7).duplicate()
	eye_white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var iris := Palette.mat(Color(0.78, 0.36, 0.07), 0.7)
	var iris_ring := Palette.mat(Color(0.42, 0.22, 0.06), 0.4)
	var pupil := Palette.mat(Color(0.05, 0.03, 0.02), 0.8)
	var mouth := Palette.mat(Color(0.22, 0.09, 0.06), 0.9)
	var tooth := Palette.mat(Color(0.96, 0.93, 0.80), 0.5)
	var grip := Palette.mat(Color(0.42, 0.26, 0.15), 0.85)
	var grip_dark := Palette.mat(Color(0.26, 0.16, 0.09), 0.85)
	_blade_mat = Palette.mat(BLADE_STEEL, 0.35).duplicate()
	_blade_mat.metallic = 0.35

	scale_root = Node3D.new()
	scale_root.name = "ScaleRoot"
	add_child(scale_root)
	roll = _pivot(scale_root, "roll", Vector3(0, HIP_HEIGHT, 0))
	hips = _pivot(roll, "hips", Vector3.ZERO)

	# One opaque wrap, tied from its own cloth; no leather belt or buckle.
	var cloth := Palette.mat(Color(0.30, 0.255, 0.18), 0.98)
	_m(hips, _profile([Vector3(0.126, 0.025, 0.093), Vector3(0.15, -0.045, 0.11), Vector3(0.165, -0.155, 0.12)], true), cloth, Vector3.ZERO)
	_m(hips, _fcyl(0.129, 0.13, 0.026), cloth, Vector3(0, 0.018, 0), Vector3.ZERO, Vector3(1, 1, 0.74))
	_m(hips, _fsphere(0.024), cloth, Vector3(-0.105, 0.012, -0.065), Vector3.ZERO, Vector3(1, 0.65, 0.6))
	_m(hips, _flat(_prism(Vector3(0.034, 0.078, 0.012))), cloth, Vector3(-0.113, -0.035, -0.08), Vector3(0, 0, -12))
	for side in [-1, 1]:
		var sign_side := float(side)
		var leg := _pivot(hips, "leg_l" if side < 0 else "leg_r", Vector3(0.079 * sign_side, -0.04, 0))
		_m(leg, _limb(0.22, 0.060), skin_mat, Vector3.ZERO)
		var shin := _pivot(leg, "shin_l" if side < 0 else "shin_r", Vector3(0, -0.17, 0))
		_m(shin, _limb(0.215, 0.044, true), skin_mat, Vector3.ZERO)
		# Ankle pivot keeps the sole flat on the ground while the leg angles.
		var ankle := _pivot(shin, "foot_l" if side < 0 else "foot_r", Vector3(0, -0.165, 0))
		var foot := _m(ankle, _fsphere(0.065), skin_mat, Vector3(0, -0.015, -0.034), Vector3.ZERO, Vector3(0.82, 0.48, 1.45))
		foot.name = "Foot"
		for toe in 3:
			_m(ankle, _fsphere(0.016), skin_mat, Vector3((float(toe) - 1.0) * 0.028, -0.017, -0.113), Vector3.ZERO, Vector3(0.85, 0.65, 1.25))
		if side < 0:
			leg_l = leg
			shin_l = shin
			foot_l = ankle
		else:
			leg_r = leg
			shin_r = shin
			foot_r = ankle

	torso = _pivot(hips, "torso", Vector3(0, 0.02, 0))
	_m(torso, _profile([Vector3(0.12, 0.0, 0.085), Vector3(0.113, 0.09, 0.077), Vector3(0.15, 0.21, 0.096), Vector3(0.173, 0.265, 0.09), Vector3(0.10, 0.307, 0.062)]), skin_mat, Vector3.ZERO)
	_m(torso, _profile([Vector3(0.085, 0.28, 0.063), Vector3(0.064, 0.32, 0.055), Vector3(0.061, 0.38, 0.052)]), skin_mat, Vector3.ZERO)

	# --- reference-inspired angular head and swept dark hair ---
	head = _pivot(torso, "head", Vector3(0, 0.365, 0))
	head.scale = Vector3(0.83, 0.77, 0.80)
	_m(head, _head_mesh(), skin_mat, Vector3.ZERO)
	_build_hair()
	_m(head, _nose_mesh(), nose_mat, Vector3.ZERO)
	var highlight := Palette.mat(Color(1, 0.99, 0.94), 0.18)
	for side in [-1, 1]:
		var s := float(side)
		# big amber anime eyes: whites, dark iris ring, iris, pupil, highlights.
		# The eye pivot scales on Y for blinks / squints.
		var eye := _pivot(head, "eye_l" if side < 0 else "eye_r", Vector3(0.083 * s, 0.213, -0.15))
		eye.scale = Vector3(1.0, 0.90, 1.0)
		_m(eye, _eye_leaf(), eye_white, Vector3.ZERO)
		_m(eye, _sphere(0.020, 28), iris, Vector3(-0.002 * s, 0, -0.020), Vector3.ZERO, Vector3(0.95, 0.82, 0.16))
		_m(eye, _sphere(0.011, 24), pupil, Vector3(-0.002 * s, 0, -0.023), Vector3.ZERO, Vector3(0.9, 1.0, 0.18))
		_m(eye, _sphere(0.003, 12), highlight, Vector3(-0.007, 0.006, -0.026))
		_m(eye, _eyelid_mesh(s), skin_mat, Vector3.ZERO)
		var brow := _pivot(head, "brow_l" if side < 0 else "brow_r", Vector3(0.083 * s, 0.255, -0.165))
		_m(brow, _capsule(0.009, 0.089), brow_mat, Vector3.ZERO, Vector3(0, 0, 90), Vector3(1, 1, 0.55))
		if side < 0:
			_brow_l = brow
		else:
			_brow_r = brow
		# huge ears swept out sideways and slightly up/back; brownish-pink inside
		var ear := _pivot(head, "ear_l" if side < 0 else "ear_r", Vector3(0.168 * s, 0.20, 0.005))
		ear.rotation_degrees = Vector3(0, -18.0 * s, -76.0 * s)
		var outer_ear := skin_mat.duplicate() as StandardMaterial3D
		outer_ear.cull_mode = BaseMaterial3D.CULL_DISABLED
		ear_inner.cull_mode = BaseMaterial3D.CULL_DISABLED
		_m(ear, _ear_mesh(), outer_ear, Vector3.ZERO)
		_m(ear, _ear_mesh(true), ear_inner, Vector3.ZERO)
	# Mouth follows the muzzle curvature; the nose is part of the head surface.
	_mouth_closed = Node3D.new()
	_mouth_closed.position = Vector3(0, 0.082, -0.157)
	head.add_child(_mouth_closed)
	for i in 12:
		var x := -0.056 + float(i) * 0.0093
		var y := -0.003 * pow(x / 0.056, 2.0) + 0.015 * x
		var depth := -_face_depth(x, 0.082 + y) + 0.155
		_m(_mouth_closed, _capsule(0.002, 0.012), mouth, Vector3(x, y, depth), Vector3(0, 0, 90))
	for side in [-1, 1]:
		_m(_mouth_closed, _cyl(0.001, 0.006, 0.017, 10), tooth, Vector3(0.041 * side, 0.003, -0.002), Vector3(0, 0, -12 * side))
	_mouth_open = Node3D.new()
	_mouth_open.position = Vector3(0, 0.082, -0.16)
	head.add_child(_mouth_open)
	_m(_mouth_open, _sphere(0.045, 12), mouth, Vector3.ZERO, Vector3.ZERO, Vector3(1.3, 0.75, 0.5))
	for side in [-1, 1]:
		_m(_mouth_open, _flat(_prism(Vector3(0.024, 0.042, 0.016))), tooth, Vector3(0.036 * float(side), -0.006, -0.02))
	_mouth_open.visible = false

	# --- arms: bare olive skin, leather bracers, big hands ---
	for side in [-1, 1]:
		var s := float(side)
		var arm := _pivot(torso, "arm_l" if side < 0 else "arm_r", Vector3(0.158 * s, 0.26, 0))
		_m(arm, _limb(0.20, 0.055), skin_mat, Vector3.ZERO)
		var fore := _pivot(arm, "fore_l" if side < 0 else "fore_r", Vector3(0, -0.165, 0))
		_m(fore, _limb(0.19, 0.044, true), skin_mat, Vector3.ZERO)
		_m(fore, _fsphere(0.038, 14, 10), skin_mat, Vector3(0, -0.178, 0), Vector3.ZERO, Vector3(0.92, 1.05, 0.78))
		for finger in 3:
			_m(fore, _fsphere(0.013, 12, 8), skin_mat, Vector3((float(finger) - 1) * 0.021, -0.194, -0.017), Vector3.ZERO, Vector3(0.95, 1.0, 0.95))
		_m(fore, _capsule(0.015, 0.038), skin_mat, Vector3(-0.026 * s, -0.177, -0.019), Vector3(-15, 0, 22 * s))
		if side < 0:
			arm_l = arm
			fore_l = fore
		else:
			arm_r = arm
			fore_r = fore

	# Keep the sword joint API for existing animations; the starting mesh is a knife.
	sword = _pivot(fore_r, "sword", Vector3(0, -0.18, 0))
	_knife_node = Node3D.new()
	_knife_node.name = "Knife"
	sword.add_child(_knife_node)
	_m(_knife_node, _fcyl(0.016, 0.019, 0.09, 8), grip_dark, Vector3(0, 0, 0.014), Vector3(90, 0, 0))
	for i in 5:
		_m(_knife_node, _fcyl(0.02, 0.02, 0.009, 8), grip, Vector3(0, 0, -0.02 + 0.016 * float(i)), Vector3(90, 0, 12))
	blade_root = Node3D.new()
	blade_root.name = "BladeRoot"
	blade_root.position = Vector3(0, 0, -0.035)
	_knife_node.add_child(blade_root)
	# Irregular double-bevel outline, including a chipped cutting edge.
	var outline: Array[Vector2] = [Vector2(-0.024, 0), Vector2(0.025, 0), Vector2(0.031, -0.07), Vector2(0.017, -0.084), Vector2(0.026, -0.094), Vector2(0.018, -0.16), Vector2(-0.009, -0.21), Vector2(-0.025, -0.125)]
	var blade := SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var ridge := Vector3(0, 0.009 * side, -0.085)
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			blade.add_vertex(ridge)
			blade.add_vertex(Vector3(a.x, 0, a.y) if side > 0 else Vector3(b.x, 0, b.y))
			blade.add_vertex(Vector3(b.x, 0, b.y) if side > 0 else Vector3(a.x, 0, a.y))
	blade.generate_normals()
	_blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blade_mat.albedo_color = Color(0.36, 0.38, 0.34)
	_blade_mat.roughness = 0.87
	_m(blade_root, blade.commit(), _blade_mat, Vector3.ZERO)


## Square steel buckle: a frame with the strap showing through the middle.
func _buckle(parent: Node3D, pos: Vector3, size: float, frame_mat: Material, inner_mat: Material, roll_deg: float = 0.0) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation_degrees = Vector3(0, 0, roll_deg)
	parent.add_child(b)
	_m(b, _fbox(Vector3(size, size, 0.014)), frame_mat, Vector3.ZERO)
	_m(b, _box(Vector3(size * 0.55, size * 0.55, 0.016)), inner_mat, Vector3(0, 0, -0.002))
	_m(b, _box(Vector3(size * 0.12, size * 0.6, 0.018)), frame_mat, Vector3(0, 0, -0.003))  # prong


# =============================================================== evolution
func set_stage(p_stage: StringName, animate: bool = true) -> void:
	stage = p_stage
	var evolved := p_stage != &"goblin"
	var target_scale: float = STAGE_SCALE.get(p_stage, 1.3 if evolved else 1.0)
	var skin_col := Palette.HOBGOBLIN_SKIN if evolved else Color(0.39, 0.43, 0.235)
	var blade_col := Palette.STEEL.darkened(0.08) if evolved else BLADE_STEEL
	var blade_scale := Vector3(1.3, 1.2, 1.45) if evolved else Vector3.ONE
	var body_scale := Vector3(target_scale * 1.06, target_scale, target_scale * 1.06) if evolved else Vector3.ONE * target_scale
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	if not animate or not is_inside_tree():
		scale_root.scale = body_scale
		skin_mat.albedo_color = skin_col
		_blade_mat.albedo_color = blade_col
		blade_root.scale = blade_scale
		for a in armour:
			a.visible = false
		return
	_flash()
	_scale_tween = create_tween()
	_scale_tween.set_parallel(true)
	_scale_tween.tween_property(scale_root, "scale", body_scale, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(skin_mat, "albedo_color", skin_col, 0.6)
	_scale_tween.tween_property(_blade_mat, "albedo_color", blade_col, 0.6)
	_scale_tween.tween_property(blade_root, "scale", blade_scale, 0.5).set_delay(0.25)
	_scale_tween.tween_callback(func() -> void:
		for a in armour:
			a.visible = false).set_delay(0.25)
	# skin glow pulse
	skin_mat.emission_enabled = true
	skin_mat.emission = Palette.ESSENCE
	skin_mat.emission_energy_multiplier = 2.5
	_scale_tween.tween_property(skin_mat, "emission_energy_multiplier", 0.0, 1.0)
	_scale_tween.chain().tween_callback(func() -> void: skin_mat.emission_enabled = false)


func _flash() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Palette.ESSENCE, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(0.6, 24)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.6, 0)
	mi.scale = Vector3.ONE * 0.3
	add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(mi.queue_free)


# =============================================================== reactions
## Direction-aware light flinch (no state change). dir: x = hit from the right,
## y = hit from the front (body space).
func flinch(strength: float = 1.0, dir: Vector2 = Vector2(0, 1)) -> void:
	_flinch = maxf(_flinch, clampf(strength, 0.0, 1.0))
	_flinch_dir = dir


## A blocked hit pushes the guard back into the body.
func guard_impact(strength: float = 1.0) -> void:
	_block_hit = maxf(_block_hit, clampf(strength, 0.0, 1.0))


func land(impact: float) -> void:
	_squash = maxf(_squash, clampf(impact, 0.0, 1.0))


func reset_pose() -> void:
	_flinch = 0.0
	_squash = 0.0
	_block_hit = 0.0
	_ik.clear()
	_ik_w.clear()
	for j: Node3D in _joints.values():
		if j.name.begins_with("ear"):
			continue
		j.rotation = Vector3.ZERO
	roll.position = Vector3(0, HIP_HEIGHT, 0)


# =============================================================== animation
## States in which the support foot (or knee) is pinned to the ground and the
## sole is kept flat; hip height is solved from the leg pose, not authored.
const PLANTED_STATES: Array[StringName] = [&"idle", &"attack", &"block", &"cast", &"hurt"]
## States animated purely with FK (rolls, falls): weapon IK fades out.
const FK_ONLY_STATES: Array[StringName] = [&"dodge", &"backstep", &"dash", &"dead"]
const ARM_UPPER := 0.165
const ARM_LOWER := 0.178
const SOLE_DROP := 0.046        # ankle pivot -> sole
const KNEE_DROP := 0.042        # knee pivot -> kneecap surface
const POLE_R := Vector3(0.7, -1.0, 0.45)
const POLE_L := Vector3(-0.7, -1.0, 0.45)

var _ik_w: Dictionary = {}      # channel -> blend weight


func _process(delta: float) -> void:
	if roll == null:
		return
	_time += delta
	var pose := _target_pose(delta)
	var rate := 16.0
	if anim_state == &"attack" or anim_state == &"dodge":
		rate = 38.0
	elif anim_state == &"dead":
		rate = 7.0
	elif anim_state == &"hurt" or anim_state == &"cast":
		rate = 24.0
	var k := 1.0 - exp(-rate * delta)
	for n: String in pose:
		if n == "hip_y" or n == "roll_x" or n in ChoreoPose.IK_CHANNELS:
			continue
		var j: Node3D = _joints.get(n)
		if j:
			var target: Vector3 = pose[n]
			# Poses are authored with +X = "lean forward" for every joint. For
			# upward-pointing joints (torso, head) that is a negative X rotation.
			if n == "torso" or n == "head":
				target.x = -target.x
			j.rotation = j.rotation.lerp(target, k)
	# roll pivot: direct while rolling (avoid smoothing across 2*PI), smoothed otherwise
	var roll_x: float = pose.get("roll_x", 0.0)
	if anim_state == &"dodge":
		roll.rotation.x = roll_x
	else:
		roll.rotation.x = lerpf(wrapf(roll.rotation.x, -PI, PI), roll_x, k)
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_flinch = move_toward(_flinch, 0.0, delta * 5.0)
	_block_hit = move_toward(_block_hit, 0.0, delta * 4.0)
	var sq := _squash * _squash
	hips.scale = Vector3(1.0 + sq * 0.12, 1.0 - sq * 0.18, 1.0 + sq * 0.12)
	_plant_feet(pose, k, delta)
	_apply_ik(pose, k, delta)
	_update_sling(delta)
	_update_face(delta)


func _is_planted() -> bool:
	return anim_grounded and anim_state in PLANTED_STATES


## Solves hip height so the lowest sole/knee touches the ground and flattens the
## supporting feet. Authored "hip_y" is only used in unplanted states.
func _plant_feet(pose: Dictionary, k: float, delta: float) -> void:
	var inv := roll.global_transform.affine_inverse()
	var ankles := [(inv * foot_l.global_transform.origin).y, (inv * foot_r.global_transform.origin).y]
	var lowest_sole := minf(ankles[0], ankles[1]) - SOLE_DROP
	var lowest := lowest_sole
	for sh: Node3D in [shin_l, shin_r]:
		lowest = minf(lowest, (inv * sh.global_transform.origin).y - KNEE_DROP)
	var planted := _is_planted()
	if planted:
		roll.position.y = lerpf(roll.position.y, -lowest, 1.0 - exp(-30.0 * delta))
	else:
		var hip_y: float = HIP_HEIGHT + float(pose.get("hip_y", 0.0))
		roll.position.y = lerpf(roll.position.y, hip_y, k)
	var walking := anim_state == &"move" and anim_grounded
	for i in 2:
		var f: Node3D = foot_l if i == 0 else foot_r
		var leg: Node3D = leg_l if i == 0 else leg_r
		var shin: Node3D = shin_l if i == 0 else shin_r
		var tilt := hips.rotation.x + leg.rotation.x + shin.rotation.x
		var w := 0.0
		if planted:
			w = 1.0 if float(ankles[i]) - SOLE_DROP - lowest_sole < 0.04 else 0.3
		elif walking:
			w = 0.45
		var want := Vector3(-tilt * w, 0, 0)
		var key := "foot_l" if i == 0 else "foot_r"
		if pose.has(key):
			want += pose[key] as Vector3
		f.rotation = f.rotation.lerp(want, k)


func _apply_ik(pose: Dictionary, k: float, delta: float) -> void:
	var fk_only := anim_state in FK_ONLY_STATES
	for ch: String in ChoreoPose.IK_CHANNELS:
		var present := pose.has(ch) and not fk_only
		if present:
			var v: Vector3 = pose[ch]
			_ik[ch] = ChoreoPose.lerp_joint(ch, _ik[ch], v, k) if _ik.has(ch) else v
		_ik_w[ch] = move_toward(float(_ik_w.get(ch, 0.0)), 1.0 if present else 0.0, delta * 9.0)
		if float(_ik_w[ch]) <= 0.0:
			_ik.erase(ch)
	if _ik.has("hand_r"):
		_solve_arm(arm_r, fore_r, _ik["hand_r"], POLE_R, float(_ik_w["hand_r"]))
	if _ik.has("hand_l"):
		_solve_arm(arm_l, fore_l, _ik["hand_l"], POLE_L, float(_ik_w["hand_l"]))
	if _ik.has("aim"):
		_solve_wrist(_ik["aim"], _ik.get("edge", Vector3.DOWN), float(_ik_w["aim"]))


## Two-bone IK toward a hips-space target; blends over the FK result by w.
func _solve_arm(arm: Node3D, fore: Node3D, target_hips: Vector3, pole: Vector3, w: float) -> float:
	var inv := torso.global_transform.affine_inverse()
	var t := inv * (hips.global_transform * target_hips)
	var res := ChoreoIK.two_bone(arm.position, t, ARM_UPPER, ARM_LOWER, pole)
	if w >= 0.999:
		arm.rotation = res[0]
		fore.rotation = Vector3(res[1], 0, 0)
	else:
		arm.basis = arm.basis.orthonormalized().slerp(Basis.from_euler(res[0]), w)
		fore.rotation = fore.rotation.lerp(Vector3(res[1], 0, 0), w)
	return res[2]


## Orients the grip socket so the weapon axis follows "aim" and the edge faces
## "edge" (both hips space).
func _solve_wrist(aim_hips: Vector3, edge_hips: Vector3, w: float) -> void:
	var hb := hips.global_transform.basis.orthonormalized()
	var a := (hb * aim_hips).normalized()
	var e := hb * edge_hips
	e -= a * e.dot(a)
	if e.length_squared() < 1e-5:
		e = hb * Vector3.DOWN
		e -= a * e.dot(a)
	e = e.normalized()
	var z := -a
	var y := -e
	var desired := Basis(y.cross(z), y, z)
	var local := fore_r.global_transform.basis.orthonormalized().inverse() * desired
	sword.basis = local if w >= 0.999 else sword.basis.orthonormalized().slerp(local, w)


## Sling cords: hang under gravity, whirl during the wind-up, whip at release.
func _update_sling(delta: float) -> void:
	if _sling_arm == null or not _sling_arm.is_visible_in_tree():
		return
	var dir := Vector3(0.0, -1.0, 0.04)
	var spun := false
	var stone_visible := true
	if anim_state == &"attack" and anim_move.has("spin"):
		var spin: Dictionary = anim_move["spin"]
		var ph := anim_phase
		if ph < 1.0:
			var a := TAU * float(spin.get("turns", 1.0)) * pow(ph, 1.3)
			if spin.get("plane", &"side") == &"overhead":
				dir = Vector3(sin(a), -0.3, -cos(a))
			else:
				dir = Vector3(0.15, -cos(a), -sin(a))
			spun = true
		elif ph < 2.0:
			dir = Vector3(0.05, 0.25, -1.0).lerp(Vector3(-0.1, -0.5, -1.0), ph - 1.0)
			spun = true
			stone_visible = false
		else:
			stone_visible = ph >= 2.9
	if spun:
		_sling_dir = dir.normalized()
	elif _sling_dir.dot(dir.normalized()) > -0.99:
		_sling_dir = _sling_dir.slerp(dir.normalized(), 1.0 - exp(-10.0 * delta))
	else:
		_sling_dir = dir.normalized()
	var world := (global_transform.basis.orthonormalized() * _sling_dir).normalized()
	var y := -world
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var sc := _sling_arm.global_basis.get_scale()
	_sling_arm.global_basis = Basis(x, y, x.cross(y)).scaled(sc)
	var stone := _sling_arm.get_node_or_null("Stone") as Node3D
	if stone:
		stone.visible = stone_visible


## Expression from state: neutral (blinking), determined (attacks/block/dash),
## wince (hurt / flinch), surprised (airborne), knocked out (dead).
func current_expression() -> StringName:
	if expression_override != &"":
		return expression_override
	match anim_state:
		&"dead":
			return &"ko"
		&"hurt":
			return &"wince"
		&"attack", &"block", &"dash", &"dodge", &"cast":
			return &"determined"
		&"air":
			return &"surprised"
	if _flinch > 0.35:
		return &"wince"
	if anim_sprinting:
		return &"determined"
	return &"neutral"


func _update_face(delta: float) -> void:
	if _brow_l == null:
		return
	var expr := current_expression()
	var eye_y := 0.90
	var brow_z := NEUTRAL_BROW_Z  # positive = angry (inner ends down)
	var brow_y := 0.255
	var open := false
	match expr:
		&"determined":
			eye_y = 0.62
			brow_z = 0.42
			brow_y = 0.245
			# Mouth stays closed in attacks (exaggerated attack teeth were rejected).
			open = false
		&"wince":
			eye_y = 0.22
			brow_z = -0.32
			brow_y = 0.243
			open = true
		&"surprised":
			eye_y = 0.85
			brow_z = -0.15
			brow_y = 0.268
			open = true
		&"ko":
			eye_y = 0.08
			brow_z = -0.2
			open = true
		&"happy":
			eye_y = 0.6
			brow_z = -0.2
			brow_y = 0.262
	# blinking (neutral / happy only)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.2, 4.5)
		_blink = 1.0
	_blink = move_toward(_blink, 0.0, delta * 8.0)
	if expr == &"neutral" or expr == &"happy":
		eye_y *= 1.0 - 0.9 * sin(_blink * PI)
	var k := 1.0 - exp(-20.0 * delta)
	for side in [-1, 1]:
		var eye: Node3D = _joints["eye_l" if side < 0 else "eye_r"]
		eye.scale.y = lerpf(eye.scale.y, eye_y, k)
		var brow := _brow_l if side < 0 else _brow_r
		brow.rotation.z = lerp_angle(brow.rotation.z, brow_z * float(side), k)
		brow.position.y = lerpf(brow.position.y, brow_y, k)
	_mouth_open.visible = open
	_mouth_closed.visible = not open


## Rest = relaxed base + the equipped moveset's carry overlay + breathing.
func _rest_combat(out: Dictionary) -> void:
	var breathe := sin(_time * 2.2)
	out.clear()
	out["hips"] = Vector3.ZERO
	out["torso"] = Vector3(0.04, 0, 0)
	out["head"] = Vector3(-0.03, 0, 0)
	out["arm_l"] = Vector3(0.03, 0, -0.16)
	out["fore_l"] = Vector3(0.16, 0, 0)
	out["arm_r"] = Vector3(0.03, 0, 0.16)
	out["fore_r"] = Vector3(0.18, 0, 0)
	out["sword"] = Vector3(-0.35, 0, 0)
	out["leg_l"] = Vector3(0.05, 0, -0.04)
	out["shin_l"] = Vector3(-0.08, 0, 0)
	out["leg_r"] = Vector3(-0.05, 0, 0.04)
	out["shin_r"] = Vector3(-0.08, 0, 0)
	out["hip_y"] = -0.005 + breathe * 0.004
	out["roll_x"] = 0.0
	var carry: Dictionary = active_moveset().get("carry", {})
	for j: String in carry:
		out[j] = carry[j]
	out["torso"] = (out["torso"] as Vector3) + Vector3(breathe * 0.025, 0, 0)
	out["head"] = (out["head"] as Vector3) + Vector3(-breathe * 0.02, 0, 0)
	out["arm_l"] = (out["arm_l"] as Vector3) + Vector3(0, 0, -breathe * 0.02)
	out["arm_r"] = (out["arm_r"] as Vector3) + Vector3(0, 0, breathe * 0.02)
	if out.has("hand_r"):
		out["hand_r"] = (out["hand_r"] as Vector3) + Vector3(0, breathe * 0.004, 0)


func _target_pose(delta: float) -> Dictionary:
	var p := _pose
	_rest_combat(p)
	match anim_state:
		&"move":
			_locomotion(p, delta)
		&"idle":
			_cycle = 0.0
		&"air":
			_air(p)
		&"attack":
			_attack(p)
		&"dodge":
			_dodge(p)
		&"backstep":
			p["torso"] = Vector3(-0.25, 0, 0)
			p["head"] = Vector3(0.15, 0, 0)
			p["leg_l"] = Vector3(0.5, 0, -0.05)
			p["shin_l"] = Vector3(-0.5, 0, 0)
			p["leg_r"] = Vector3(-0.3, 0, 0.05)
			p["shin_r"] = Vector3(-0.3, 0, 0)
			p["arm_l"] = Vector3(0.6, 0, -0.5)
			p["arm_r"] = Vector3(0.6, 0, 0.5)
			p["hip_y"] = -0.06
		&"block":
			_locomotion(p, delta, 0.4)
			var guard: Dictionary = active_moveset().get("guard", {}).get("pose", {})
			for j: String in guard:
				p[j] = guard[j]
			if _block_hit > 0.0:
				var b := _block_hit
				p["torso"] = (p["torso"] as Vector3) + Vector3(-0.22 * b, 0, 0)
				p["head"] = (p["head"] as Vector3) + Vector3(-0.15 * b, 0, 0)
				p["arm_l"] = (p["arm_l"] as Vector3) + Vector3(-0.25 * b, 0, 0)
				p["arm_r"] = (p["arm_r"] as Vector3) + Vector3(-0.25 * b, 0, 0)
				if p.has("hand_r"):
					p["hand_r"] = (p["hand_r"] as Vector3) + Vector3(0, -0.02, 0.07) * b
				p["leg_r"] = (p["leg_r"] as Vector3) + Vector3(-0.15 * b, 0, 0)
		&"hurt":
			_hurt(p)
		&"cast":
			_cast(p)
		&"dash":
			p["torso"] = Vector3(0.55, 0, 0)
			p["head"] = Vector3(-0.35, 0, 0)
			p["arm_l"] = Vector3(-0.9, 0, -0.3)
			p["arm_r"] = Vector3(-0.9, 0, 0.3)
			p["fore_r"] = Vector3(0.3, 0, 0)
			p["leg_l"] = Vector3(0.7, 0, 0)
			p["shin_l"] = Vector3(-1.2, 0, 0)
			p["leg_r"] = Vector3(-0.5, 0, 0)
			p["shin_r"] = Vector3(-0.6, 0, 0)
			p["hip_y"] = -0.08
		&"dead":
			p["roll_x"] = 1.45
			p["hip_y"] = -0.3
			p["torso"] = Vector3(-0.1, 0, 0)
			p["head"] = Vector3(-0.25, 0.4, 0)
			p["arm_l"] = Vector3(0.4, 0, -1.3)
			p["arm_r"] = Vector3(0.2, 0, 1.2)
			p["fore_l"] = Vector3(0.4, 0, 0)
			p["fore_r"] = Vector3(0.2, 0, 0)
			p["leg_l"] = Vector3(0.35, 0, -0.15)
			p["leg_r"] = Vector3(0.1, 0, 0.2)
			p["shin_l"] = Vector3(-0.5, 0, 0)
	if _flinch > 0.0:
		var f := _flinch
		var d := _flinch_dir
		p["torso"] = (p["torso"] as Vector3) + Vector3(-0.3 * f * d.y, -0.18 * f * d.x, 0.16 * f * d.x)
		p["head"] = (p["head"] as Vector3) + Vector3(-0.25 * f * d.y, 0, 0.1 * f)
	return p


func _locomotion(p: Dictionary, delta: float, amp_scale: float = 1.0) -> void:
	var mv: Dictionary = active_moveset().get("move", {})
	var spd := anim_speed
	var sprint_k := 1.0 if anim_sprinting else 0.0
	var run_k := clampf((spd - 2.4) / 2.8, 0.0, 1.0)
	var cycle_len := lerpf(0.95, 1.55, clampf(spd / 7.6, 0.0, 1.0))
	_cycle += TAU * spd / cycle_len * delta
	var s := sin(_cycle)
	var c := cos(_cycle)
	var amp := lerpf(0.42, 0.75, run_k) * amp_scale + sprint_k * 0.15
	var knee := lerpf(0.5, 1.1, run_k) * amp_scale + sprint_k * 0.2
	p["leg_l"] = Vector3(amp * s, 0, -0.03)
	p["leg_r"] = Vector3(-amp * s, 0, 0.03)
	p["shin_l"] = Vector3(-knee * maxf(0.0, c) - 0.1, 0, 0)
	p["shin_r"] = Vector3(-knee * maxf(0.0, -c) - 0.1, 0, 0)
	var arm_amp := lerpf(0.35, 0.8, run_k) * amp_scale + sprint_k * 0.25
	p["arm_l"] = Vector3(-arm_amp * s + 0.1, 0, -0.2)
	p["fore_l"] = Vector3(0.4 + run_k * 0.6, 0, 0)
	p["arm_r"] = Vector3(arm_amp * s * float(mv.get("arm_r_swing", 0.7)) + float(mv.get("arm_r_bias", 0.3)), 0, 0.22)
	p["fore_r"] = Vector3((mv.get("fore_r", Vector3(0.7, 0, 0)) as Vector3).x + run_k * 0.3, 0, 0)
	if p.has("hand_r"):
		var hs := float(mv.get("hand_swing", 0.05)) * amp_scale
		p["hand_r"] = (p["hand_r"] as Vector3) + Vector3(0, 0.02 * run_k, -hs * s * (0.5 + run_k))
	var lean := lerpf(0.06, 0.2, run_k) + sprint_k * 0.18
	p["torso"] = Vector3(lean, -0.12 * s * run_k, 0)
	p["head"] = Vector3(-lean * 0.7, 0.08 * s * run_k, 0)
	p["hips"] = Vector3(0, 0.1 * s * run_k, 0)
	p["hip_y"] = -0.02 * run_k + 0.03 * absf(c) * (0.5 + run_k)
	# footsteps on each plant
	var sign_now := 1.0 if s >= 0.0 else -1.0
	if sign_now != _prev_step_sign:
		_prev_step_sign = sign_now
		if footsteps_enabled and anim_grounded and spd > 0.8 and is_inside_tree():
			Audio.play_sfx(&"footstep", global_position, -6.0 + run_k * 3.0)


func _air(p: Dictionary) -> void:
	var rising := anim_vertical > 0.5
	if rising:
		p["leg_l"] = Vector3(0.7, 0, -0.05)
		p["shin_l"] = Vector3(-1.1, 0, 0)
		p["leg_r"] = Vector3(-0.25, 0, 0.05)
		p["shin_r"] = Vector3(-0.35, 0, 0)
		p["arm_l"] = Vector3(-0.4, 0, -0.55)
		p["arm_r"] = Vector3(0.9, 0, 0.5)
		p["torso"] = Vector3(0.1, 0, 0)
	else:
		p["leg_l"] = Vector3(0.35, 0, -0.1)
		p["shin_l"] = Vector3(-0.5, 0, 0)
		p["leg_r"] = Vector3(0.1, 0, 0.1)
		p["shin_r"] = Vector3(-0.3, 0, 0)
		p["arm_l"] = Vector3(0.6, 0, -0.95)
		p["arm_r"] = Vector3(0.7, 0, 0.95)
		p["torso"] = Vector3(-0.05, 0, 0)
		p["head"] = Vector3(0.12, 0, 0)


## Attack poses come from the move resolved at attack start (ChoreoLibrary data).
func _attack(p: Dictionary) -> void:
	var move := anim_move
	if move.is_empty():
		move = ChoreoLibrary.find_move(&"unarmed" if unarmed else weapon_type, anim_action)
	if not move.is_empty():
		ChoreoPose.evaluate(move, p, anim_phase)


static func _mix(p: Dictionary, target: Dictionary, w: float) -> void:
	for j: String in target:
		p[j] = ChoreoPose.lerp_joint(j, p.get(j, target[j]), target[j], w)


## Hit reactions. stagger: recoil away from the hit with a catch step;
## knockdown: driven to one knee, then rise; guard_break: guard flung open.
## Durations come from the controller (unchanged hurt/i-frame rules).
func _hurt(p: Dictionary) -> void:
	var t := clampf(anim_t, 0.0, 1.0)
	var d := hurt_dir
	var front := maxf(d.y, 0.0)
	var back := maxf(-d.y, 0.0)
	var jolt := {
		"torso": Vector3(-0.42 * d.y, -0.35 * d.x, 0.28 * d.x), "head": Vector3(-0.3 * d.y, -0.15 * d.x, 0.12 * d.x),
		"arm_l": Vector3(0.75, 0, -0.6), "fore_l": Vector3(0.7, 0, 0), "arm_r": Vector3(0.7, 0, 0.6), "fore_r": Vector3(0.6, 0, 0),
		"leg_l": Vector3(0.25 * front + 0.55 * back, 0, -0.05 - 0.25 * maxf(d.x, 0.0)), "shin_l": Vector3(-0.15 - 0.5 * back, 0, 0),
		"leg_r": Vector3(-0.45 * front + 0.1 * back, 0, 0.05 + 0.25 * maxf(-d.x, 0.0)), "shin_r": Vector3(-0.35 * front - 0.1, 0, 0),
	}
	if p.has("hand_r"):
		jolt["hand_r"] = (p["hand_r"] as Vector3) + Vector3(0.06, 0.02, 0.08)
	match hurt_kind:
		&"knockdown":
			var hit_w := sin(PI * clampf(t / 0.3, 0.0, 1.0))
			var down_w := smoothstep(0.12, 0.35, t) * (1.0 - smoothstep(0.7, 1.0, t))
			_mix(p, jolt, hit_w)
			var kneel := {
				"torso": Vector3(0.38, 0.12 * d.x, 0.1 * d.x), "head": Vector3(-0.2, 0, 0),
				"leg_l": Vector3(1.45, 0, -0.08), "shin_l": Vector3(-1.5, 0, 0),
				"leg_r": Vector3(-0.1, 0, 0.08), "shin_r": Vector3(-1.85, 0, 0),
				"arm_l": Vector3(0.75, 0, -0.3), "fore_l": Vector3(0.35, 0, 0),
				"arm_r": Vector3(0.45, 0, 0.45), "fore_r": Vector3(0.7, 0, 0),
			}
			if p.has("hand_r"):
				kneel["hand_r"] = Vector3(0.2, -0.05, -0.16)
			_mix(p, kneel, down_w)
		&"guard_break":
			var w := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.55, 1.0, t))
			var opened := {
				"torso": Vector3(-0.45, 0, 0), "head": Vector3(-0.3, 0, 0),
				"arm_l": Vector3(1.7, 0, -0.9), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(1.6, 0, 0.9), "fore_r": Vector3(0.3, 0, 0),
				"leg_r": Vector3(-0.45, 0, 0.05), "shin_r": Vector3(-0.3, 0, 0), "leg_l": Vector3(0.2, 0, -0.05),
			}
			if p.has("hand_r"):
				opened["hand_r"] = Vector3(0.3, 0.38, 0.05)
			_mix(p, opened, w)
		_:
			var w2 := smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.45, 1.0, t))
			_mix(p, jolt, w2)


## Grip-aware cast. Origins: flame_burst = mouth/chest (inhale, the free palm
## comes to the mouth, then pushes the breath out), stone_guard = body (crouch,
## palm to the ground), anything else = free palm forward. The weapon stays in
## the right hand, lowered out of the way; the left hand is the casting hand.
func _cast(p: Dictionary) -> void:
	var t := clampf(anim_t, 0.0, 1.0)
	var gather := smoothstep(0.0, 0.3, t)
	var release := smoothstep(0.3, 0.55, t)
	var weapon_low := {}
	if p.has("hand_r"):
		weapon_low["hand_r"] = (p["hand_r"] as Vector3) + Vector3(0.02, -0.02, 0.07)
	elif not unarmed:
		weapon_low = {"arm_r": Vector3(0.12, 0, 0.3), "fore_r": Vector3(0.85, 0, 0)}
	match cast_skill:
		&"stone_guard":
			_mix(p, {"torso": Vector3(0.1, 0, 0), "head": Vector3(0.05, 0, 0),
				"arm_l": Vector3(1.1, 0, 0.45), "fore_l": Vector3(1.8, 0, 0),
				"leg_l": Vector3(0.4, 0, -0.18), "shin_l": Vector3(-0.65, 0, 0), "leg_r": Vector3(-0.25, 0, 0.18), "shin_r": Vector3(-0.6, 0, 0)}, gather)
			_mix(p, {"torso": Vector3(0.38, 0, 0), "head": Vector3(-0.15, 0, 0),
				"arm_l": Vector3(0.45, 0, -0.45), "fore_l": Vector3(0.25, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.2), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.3, 0, 0.2), "shin_r": Vector3(-0.7, 0, 0)}, release)
			if unarmed:
				_mix(p, {"arm_r": Vector3(1.0, 0, -0.4), "fore_r": Vector3(1.7, 0, 0)}, gather * (1.0 - release))
				_mix(p, {"arm_r": Vector3(0.45, 0, 0.45), "fore_r": Vector3(0.25, 0, 0)}, release)
			else:
				_mix(p, weapon_low, gather)
		_:
			var to_mouth := cast_skill == &"flame_burst"
			_mix(p, {"torso": Vector3(-0.12, -0.25, 0), "head": Vector3(-0.15, 0.2, 0),
				"arm_l": Vector3(1.15 if to_mouth else 0.9, 0, 0.35 if to_mouth else 0.1), "fore_l": Vector3(1.95 if to_mouth else 1.2, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.05), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.25, 0, 0.05), "shin_r": Vector3(-0.3, 0, 0)}, gather)
			_mix(p, {"torso": Vector3(0.28, 0.2, 0), "head": Vector3(0.15, -0.15, 0),
				"arm_l": Vector3(1.5, -0.15, -0.05), "fore_l": Vector3(0.12, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.05), "shin_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(-0.35, 0, 0.05), "shin_r": Vector3(-0.1, 0, 0)}, release)
			_mix(p, weapon_low, gather)


func _dodge(p: Dictionary) -> void:
	var t := clampf(anim_t, 0.0, 1.0)
	var spin := clampf(t / 0.85, 0.0, 1.0)
	spin = spin * spin * (3.0 - 2.0 * spin)
	p["roll_x"] = -TAU * spin
	var tuck := sin(PI * clampf(t / 0.9, 0.0, 1.0))
	p["torso"] = Vector3(0.7 * tuck, 0, 0)
	p["head"] = Vector3(0.5 * tuck, 0, 0)
	p["leg_l"] = Vector3(1.4 * tuck, 0, 0)
	p["leg_r"] = Vector3(1.2 * tuck, 0, 0)
	p["shin_l"] = Vector3(-2.0 * tuck, 0, 0)
	p["shin_r"] = Vector3(-1.9 * tuck, 0, 0)
	p["arm_l"] = Vector3(1.0 * tuck, 0, -0.2)
	p["arm_r"] = Vector3(1.0 * tuck, 0, 0.2)
	p["fore_l"] = Vector3(1.4 * tuck, 0, 0)
	p["fore_r"] = Vector3(1.4 * tuck, 0, 0)
	p["hip_y"] = -0.14 * tuck
