class_name QuestFriend
extends StaticBody3D
## Nib, the injured goblin friend. Primitive chibi-goblin model (big head, big
## expressive eyes, blue scarf, bandages), smaller than the player and visually
## distinct from raiders. Not damageable (take_damage returns IGNORED).
## Poses: sitting/injured (worried face) and standing idle (happy face).

const SKIN := Color(0.50, 0.74, 0.36)
const SKIN_SHADE := Color(0.40, 0.62, 0.29)
const SCARF := Color(0.22, 0.48, 0.86)
const TUNIC := Color(0.62, 0.46, 0.28)
const BANDAGE := Color(0.95, 0.93, 0.86)
const EYE_DARK := Color(0.10, 0.08, 0.14)
const BLUSH := Color(0.95, 0.52, 0.52)

var display_name := "Nib"
var interactable: Interactable
var injured := true

var _pivot: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _mouth_worried: Node3D
var _mouth_happy: Node3D
var _blush: Array[Node3D] = []
var _meshes: Array[GeometryInstance3D] = []
var _collision: CollisionShape3D
var _walking := false
var _time := 0.0


func _init() -> void:
	collision_layer = Layers.ACTORS
	collision_mask = 0


func _ready() -> void:
	name = "Nib"
	_build()
	interactable = Interactable.new()
	interactable.interact_id = &"nib_rescue"
	interactable.prompt = QuestData.prompt("nib_injured")
	interactable.radius = 2.3
	interactable.position = Vector3(0, 0.6, 0)
	add_child(interactable)
	set_injured(injured)


# ---------------------------------------------------------------- damage contract
func get_faction() -> StringName: return Factions.FRIEND
func is_dead() -> bool: return false
func take_damage(_info: DamageInfo) -> int: return DamageInfo.Result.IGNORED
func get_lock_point() -> Vector3: return global_position + Vector3.UP * 0.8


# ---------------------------------------------------------------- poses
func set_injured(value: bool) -> void:
	injured = value
	if _pivot == null:
		return
	_pivot.position.y = -0.3 if injured else 0.0
	for leg in _legs:
		leg.rotation = Vector3(PI * 0.47, 0, 0) if injured else Vector3.ZERO
	_arms[0].rotation = Vector3(-0.5, 0, -0.35) if injured else Vector3(0, 0, -0.12)   # holding side
	_arms[1].rotation = Vector3(0.2, 0, 0.6) if injured else Vector3(0, 0, 0.12)
	_head.rotation = Vector3(0.15, 0, 0.18) if injured else Vector3.ZERO
	set_expression(not injured)


func set_expression(happy: bool) -> void:
	if _brows.is_empty():
		return
	# Worried: inner brow ends raised. Happy: relaxed arch.
	_brows[0].rotation.z = -0.12 if happy else 0.38
	_brows[1].rotation.z = 0.12 if happy else -0.38
	_brows[0].position.y = 0.15 if happy else 0.135
	_brows[1].position.y = 0.15 if happy else 0.135
	_mouth_worried.visible = not happy
	_mouth_happy.visible = happy
	for b in _blush:
		b.visible = happy


func _process(delta: float) -> void:
	_time += delta
	if _pivot == null:
		return
	if _walking:
		var s := sin(_time * 9.0)
		_legs[0].rotation.x = s * 0.6
		_legs[1].rotation.x = -s * 0.6
		_arms[0].rotation.x = -s * 0.5
		_arms[1].rotation.x = s * 0.5
		_pivot.position.y = absf(s) * 0.04
	elif injured:
		_head.rotation.z = 0.18 + sin(_time * 1.3) * 0.04
	else:
		_pivot.position.y = sin(_time * 2.0) * 0.012
		_head.rotation.y = sin(_time * 0.6) * 0.25
		_arms[0].rotation.z = -0.12 - sin(_time * 2.0) * 0.03
		_arms[1].rotation.z = 0.12 + sin(_time * 2.0) * 0.03


## Stand up, walk `distance` m along `dir`, fade out, then reappear at `home`.
func walk_away_and_go_home(dir: Vector3, distance: float, home: Vector3, face_toward: Vector3) -> void:
	set_injured(false)
	interactable.enabled = false
	_collision.disabled = true
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
	look_at(global_position + dir, Vector3.UP)
	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree():
		return
	_walking = true
	var start := global_position
	var t := 0.0
	var dur := distance / 2.0
	while t < dur and is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			return
		t += get_process_delta_time()
		var p := start + dir * distance * clampf(t / dur, 0.0, 1.0)
		p.y = GameState.ground_height(p.x, p.z)
		global_position = p
		if t > dur - 0.7:
			_set_fade(clampf((t - (dur - 0.7)) / 0.7, 0.0, 1.0))
	_walking = false
	place_at_home(home, face_toward)


func place_at_home(home: Vector3, face_toward: Vector3) -> void:
	_walking = false
	global_position = GameState.ground_point(home)
	var to := face_toward - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		look_at(global_position + to, Vector3.UP)
	set_injured(false)
	_set_fade(0.0)
	if _collision:
		_collision.disabled = false
	if interactable:
		interactable.enabled = true
		interactable.interact_id = &"nib_talk"
		interactable.prompt = QuestData.prompt("nib_talk")


func _set_fade(f: float) -> void:
	for m in _meshes:
		if is_instance_valid(m):
			m.transparency = f


# ---------------------------------------------------------------- model
func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Palette.glow(color, 1.5) if glow else Palette.mat(color, 0.7)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	_meshes.append(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 10
	return m


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


static func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	return m


static func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m


func _build() -> void:
	_collision = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.1
	_collision.shape = cap
	_collision.position = Vector3(0, 0.55, 0)
	add_child(_collision)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	# Model faces -Z.
	# Legs (hip pivots) + feet.
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, 0.42, 0)
		_pivot.add_child(hip)
		_part(hip, _capsule(0.075, 0.42), SKIN_SHADE, Vector3(0, -0.2, 0))
		_part(hip, _box(Vector3(0.13, 0.07, 0.2)), Palette.LEATHER, Vector3(0, -0.4, -0.04))
		_legs.append(hip)
	# Torso: tunic + belt.
	_part(_pivot, _capsule(0.2, 0.56), TUNIC, Vector3(0, 0.66, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	_part(_pivot, _torus(0.17, 0.215), Palette.LEATHER, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 0.6, 0.9))
	# Blue scarf (signature) + tail.
	_part(_pivot, _torus(0.1, 0.19), SCARF, Vector3(0, 0.9, 0), Vector3(0.1, 0, 0), Vector3(1, 1.4, 1))
	_part(_pivot, _box(Vector3(0.1, 0.32, 0.04)), SCARF, Vector3(0.09, 0.76, 0.17), Vector3(0.25, 0, 0.2))
	# Arms (shoulder pivots); left forearm bandaged.
	for side: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.24 * side, 0.84, 0)
		_pivot.add_child(sh)
		_part(sh, _capsule(0.06, 0.4), SKIN, Vector3(0, -0.19, 0))
		_part(sh, _sphere(0.07), SKIN, Vector3(0, -0.4, 0))
		if side < 0.0:
			_part(sh, _torus(0.05, 0.075), BANDAGE, Vector3(0, -0.27, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
		_arms.append(sh)
	# Head: big chibi proportions.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.15, 0)
	_pivot.add_child(_head)
	_part(_head, _sphere(0.27), SKIN, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 1))
	# Long goblin ears pointing out and slightly up.
	for side: float in [-1.0, 1.0]:
		_part(_head, _cone(0.085, 0.36), SKIN, Vector3(0.33 * side, 0.06, 0.02), Vector3(0, 0, -side * (PI * 0.5 - 0.35)))
	# Nose.
	_part(_head, _sphere(0.045), SKIN_SHADE, Vector3(0, -0.03, -0.265), Vector3.ZERO, Vector3(1, 0.9, 1.3))
	# Big eyes: sclera, pupil, sparkle highlight.
	for side: float in [-1.0, 1.0]:
		var ex := 0.105 * side
		_part(_head, _sphere(0.075), Color(0.98, 0.98, 0.96), Vector3(ex, 0.03, -0.215), Vector3.ZERO, Vector3(0.9, 1.25, 0.55))
		_part(_head, _sphere(0.05), EYE_DARK, Vector3(ex, 0.02, -0.25), Vector3.ZERO, Vector3(0.9, 1.25, 0.5))
		_part(_head, _sphere(0.017), Color.WHITE, Vector3(ex + 0.018, 0.055, -0.27), Vector3.ZERO, Vector3.ONE, true)
		var brow := _part(_head, _box(Vector3(0.1, 0.022, 0.03)), Color(0.22, 0.30, 0.15), Vector3(ex, 0.14, -0.235))
		_brows.append(brow)
		var blush := _part(_head, _sphere(0.04), BLUSH, Vector3(0.17 * side, -0.06, -0.2), Vector3.ZERO, Vector3(1.2, 0.6, 0.4))
		_blush.append(blush)
	# Mouths: small worried "o" / wide open smile.
	_mouth_worried = _part(_head, _sphere(0.03), EYE_DARK, Vector3(0, -0.12, -0.245), Vector3.ZERO, Vector3(1.0, 0.8, 0.5))
	_mouth_happy = _part(_head, _sphere(0.05), Color(0.35, 0.10, 0.12), Vector3(0, -0.11, -0.24), Vector3.ZERO, Vector3(1.4, 0.55, 0.45))
	# Bandage around the forehead + cheek patch.
	_part(_head, _torus(0.24, 0.285), BANDAGE, Vector3(0, 0.12, 0), Vector3(0.25, 0, 0.12), Vector3(1.02, 0.6, 1.0))
	_part(_head, _box(Vector3(0.07, 0.05, 0.02)), BANDAGE, Vector3(-0.17, -0.02, -0.23), Vector3(0, 0.5, 0.3))
	# Hair tuft.
	_part(_head, _cone(0.06, 0.16), Color(0.25, 0.35, 0.18), Vector3(0.02, 0.29, 0), Vector3(0, 0, -0.3))
