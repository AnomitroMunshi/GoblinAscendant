class_name PlayerGoblinModel
extends Node3D
## Procedural, articulated goblin built from primitives. Faces -Z, feet at y=0,
## roughly 1.1 m tall. All animation is code-driven: the Player writes the
## public "anim_*" fields every physics frame and this node blends joint
## rotations toward per-state target poses in _process.
## Evolution: set_stage(&"hobgoblin") grows the model (~1.3x), darkens the
## skin, shows armour and swaps to a bigger blade with a glow flash.

const STAGE_SCALE := {&"goblin": 1.0, &"hobgoblin": 1.3}
const HIP_HEIGHT := 0.42
const BLADE_RUSTY := Color(0.6, 0.57, 0.53)  # dull steel; rust shown by spots

# ---- fed by the Player every frame -------------------------------------------
var anim_state: StringName = &"idle"   # idle, move, air, attack, dodge, backstep, block, hurt, cast, dead, dash
var anim_speed := 0.0                  # horizontal speed m/s
var anim_vertical := 0.0               # vertical speed m/s
var anim_grounded := true
var anim_sprinting := false
var anim_action: StringName = &""      # light1, light2, light3, heavy
var anim_phase := 0.0                  # 0..1 windup, 1..2 active, 2..3 recovery
var anim_t := 0.0                      # normalized progress for dodge / cast / dash
var footsteps_enabled := true

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


func _build() -> void:
	skin_mat = Palette.mat(Palette.GOBLIN_SKIN, 0.75).duplicate()
	var skin_dark := Palette.mat(Palette.GOBLIN_SKIN.darkened(0.25), 0.8)
	var ear_inner := Palette.mat(Color(0.72, 0.52, 0.45), 0.8)
	var cloth := Palette.mat(Palette.CLOTH_BROWN, 0.95)
	var cloth_dark := Palette.mat(Palette.CLOTH_BROWN.darkened(0.3), 0.95)
	var leather := Palette.mat(Palette.LEATHER, 0.8)
	var leather_dark := Palette.mat(Palette.LEATHER.darkened(0.35), 0.8)
	var gold := Palette.mat(Palette.GOLD, 0.45)
	var eye_white := Palette.mat(Color(0.98, 0.96, 0.86), 0.4)
	var iris := Palette.mat(Color(0.95, 0.66, 0.12), 0.35)
	var pupil := Palette.mat(Color(0.05, 0.04, 0.04), 0.3)
	var mouth := Palette.mat(Color(0.18, 0.06, 0.06), 0.9)
	var tooth := Palette.mat(Color(0.97, 0.94, 0.82), 0.5)
	var nail := Palette.mat(Color(0.25, 0.22, 0.15), 0.8)
	_blade_mat = Palette.mat(BLADE_RUSTY, 0.5).duplicate()
	var rust_spot := Palette.mat(Palette.RUST.darkened(0.35), 0.9)
	var steel_dark := Palette.mat(Palette.STEEL.darkened(0.35), 0.4)

	scale_root = Node3D.new()
	scale_root.name = "ScaleRoot"
	add_child(scale_root)
	roll = _pivot(scale_root, "roll", Vector3(0, HIP_HEIGHT, 0))
	hips = _pivot(roll, "hips", Vector3.ZERO)

	# --- pelvis / tunic hem (ragged) ---
	_m(hips, _cyl(0.165, 0.2, 0.13), cloth_dark, Vector3(0, -0.01, 0))
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.2
		var tatter := _m(hips, _prism(Vector3(0.07, 0.07, 0.02)), cloth_dark,
			Vector3(sin(a) * 0.19, -0.1, cos(a) * 0.19), Vector3(180, rad_to_deg(a), 0))
		tatter.scale = Vector3(1.0, 0.7 + 0.5 * float(i % 3) / 2.0, 1.0)

	# --- legs ---
	for side in [-1, 1]:
		var s := float(side)
		var leg := _pivot(hips, "leg_l" if side < 0 else "leg_r", Vector3(0.085 * s, -0.03, 0))
		_m(leg, _capsule(0.06, 0.2), cloth_dark, Vector3(0, -0.07, 0))
		var shin := _pivot(leg, "shin_l" if side < 0 else "shin_r", Vector3(0, -0.17, 0))
		_m(shin, _capsule(0.048, 0.2), skin_mat, Vector3(0, -0.09, 0))
		_m(shin, _cyl(0.055, 0.052, 0.06), leather, Vector3(0, -0.13, 0))  # ankle wrap
		var foot := _m(shin, _sphere(0.065, 12), skin_mat, Vector3(0, -0.19, -0.04), Vector3.ZERO, Vector3(0.85, 0.55, 1.45))
		foot.name = "Foot"
		for t in 3:
			_m(shin, _sphere(0.016, 8), nail, Vector3(0.025 * float(t - 1), -0.2, -0.13))
		if side < 0:
			leg_l = leg
			shin_l = shin
		else:
			leg_r = leg
			shin_r = shin

	# --- torso ---
	torso = _pivot(hips, "torso", Vector3(0, 0.02, 0))
	_m(torso, _sphere(0.175), cloth, Vector3(0, 0.1, -0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.92))  # pot belly
	_m(torso, _cyl(0.13, 0.17, 0.2), cloth, Vector3(0, 0.2, 0.0))
	_m(torso, _cyl(0.09, 0.13, 0.06), cloth_dark, Vector3(0, 0.3, 0.0))  # collar
	var belt := TorusMesh.new()
	belt.inner_radius = 0.165
	belt.outer_radius = 0.2
	belt.rings = 16
	belt.ring_segments = 6
	_m(torso, belt, leather, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 1.1, 0.96))
	_m(torso, _box(Vector3(0.06, 0.05, 0.02)), gold, Vector3(0, 0.03, -0.19))
	# satchel on the left hip + strap over the right shoulder
	_m(torso, _box(Vector3(0.08, 0.12, 0.13)), leather, Vector3(-0.21, -0.02, 0.03), Vector3(0, 0, 6))
	_m(torso, _box(Vector3(0.085, 0.05, 0.135)), leather_dark, Vector3(-0.215, 0.04, 0.03), Vector3(0, 0, 6))
	_m(torso, _box(Vector3(0.022, 0.02, 0.02)), gold, Vector3(-0.255, 0.02, 0.03))
	_m(torso, _box(Vector3(0.035, 0.42, 0.02)), leather_dark, Vector3(0.0, 0.17, -0.155), Vector3(0, 0, -38))
	_m(torso, _box(Vector3(0.035, 0.42, 0.02)), leather_dark, Vector3(0.0, 0.17, 0.155), Vector3(0, 0, 38))
	# patch on the tunic
	_m(torso, _box(Vector3(0.06, 0.06, 0.01)), Palette.mat(Palette.CLOTH_RED.darkened(0.2)), Vector3(0.08, 0.12, -0.17), Vector3(0, 0, 12))

	# --- head ---
	head = _pivot(torso, "head", Vector3(0, 0.32, 0))
	_m(head, _sphere(0.19, 20), skin_mat, Vector3(0, 0.16, 0.01), Vector3.ZERO, Vector3(1.06, 0.95, 1.0))
	_m(head, _sphere(0.14), skin_mat, Vector3(0, 0.07, -0.05), Vector3.ZERO, Vector3(1.12, 0.78, 1.0))  # jaw / cheeks
	var highlight := Palette.glow(Color(1, 1, 1), 1.2)
	for side in [-1, 1]:
		var s := float(side)
		# big anime-style eyes: whites, amber iris, pupil, two highlights. The eye
		# pivot scales on Y for blinks / squints.
		var eye := _pivot(head, "eye_l" if side < 0 else "eye_r", Vector3(0.078 * s, 0.172, -0.15))
		_m(eye, _sphere(0.062, 14), eye_white, Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.0, 1.12, 0.7))
		_m(eye, _sphere(0.04, 12), iris, Vector3(0.002 * s, -0.004, -0.032), Vector3.ZERO, Vector3(1.0, 1.15, 0.5))
		_m(eye, _sphere(0.022, 8), pupil, Vector3(0.002 * s, -0.004, -0.048), Vector3.ZERO, Vector3(1.0, 1.15, 0.5))
		_m(eye, _sphere(0.011, 6), highlight, Vector3(-0.012, 0.016, -0.06))
		_m(eye, _sphere(0.006, 6), highlight, Vector3(0.012, -0.016, -0.058))
		var brow := _pivot(head, "brow_l" if side < 0 else "brow_r", Vector3(0.08 * s, 0.25, -0.168))
		_m(brow, _box(Vector3(0.09, 0.024, 0.035)), skin_dark, Vector3.ZERO)
		if side < 0:
			_brow_l = brow
		else:
			_brow_r = brow
		# big pointed ears
		var ear := _pivot(head, "ear_l" if side < 0 else "ear_r", Vector3(0.165 * s, 0.17, 0.02))
		ear.rotation_degrees = Vector3(14, 0, -72.0 * s)
		_m(ear, _cyl(0.0, 0.075, 0.34, 10), skin_mat, Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1, 1, 0.35))
		_m(ear, _cyl(0.0, 0.045, 0.24, 8), ear_inner, Vector3(0, 0.13, -0.017), Vector3.ZERO, Vector3(1, 1, 0.2))
		_m(head, _sphere(0.04, 8), skin_dark, Vector3(0.12 * s, 0.07, -0.13))  # cheek bump
	_m(head, _cyl(0.0, 0.042, 0.13, 10), skin_mat, Vector3(0, 0.13, -0.24), Vector3(-100, 0, 0))  # long nose
	_m(head, _sphere(0.035, 10), skin_dark, Vector3(0, 0.125, -0.19))  # nose root
	# mouth: a closed smile line (with little fangs) and an open mouth, swapped by expression
	_mouth_closed = Node3D.new()
	_mouth_closed.position = Vector3(0, 0.045, -0.172)
	head.add_child(_mouth_closed)
	_m(_mouth_closed, _box(Vector3(0.1, 0.02, 0.03)), mouth, Vector3(0, 0, 0))
	_m(_mouth_closed, _box(Vector3(0.035, 0.018, 0.03)), mouth, Vector3(0.06, 0.008, 0.004), Vector3(0, 0, 28))
	_m(_mouth_closed, _box(Vector3(0.035, 0.018, 0.03)), mouth, Vector3(-0.06, 0.008, 0.004), Vector3(0, 0, -28))
	for side in [-1, 1]:
		_m(_mouth_closed, _prism(Vector3(0.025, 0.04, 0.015)), tooth, Vector3(0.035 * float(side), 0.02, -0.011))
	_mouth_open = Node3D.new()
	_mouth_open.position = Vector3(0, 0.045, -0.165)
	head.add_child(_mouth_open)
	_m(_mouth_open, _sphere(0.045, 12), mouth, Vector3.ZERO, Vector3.ZERO, Vector3(1.3, 0.75, 0.5))
	for side in [-1, 1]:
		_m(_mouth_open, _prism(Vector3(0.022, 0.035, 0.015)), tooth, Vector3(0.03 * float(side), -0.012, -0.018))
		_m(_mouth_open, _prism(Vector3(0.02, 0.03, 0.015)), tooth, Vector3(0.028 * float(side), 0.018, -0.018), Vector3(0, 0, 180))
	_mouth_open.visible = false
	_m(head, _cyl(0.0, 0.03, 0.08, 8), skin_dark, Vector3(0.0, 0.34, 0.02), Vector3(-25, 0, 0))  # little tuft

	# --- arms ---
	for side in [-1, 1]:
		var s := float(side)
		var arm := _pivot(torso, "arm_l" if side < 0 else "arm_r", Vector3(0.18 * s, 0.25, 0))
		_m(arm, _sphere(0.068, 12), cloth, Vector3(0, -0.02, 0))  # short sleeve
		_m(arm, _capsule(0.043, 0.18), skin_mat, Vector3(0, -0.08, 0))
		var fore := _pivot(arm, "fore_l" if side < 0 else "fore_r", Vector3(0, -0.16, 0))
		_m(fore, _capsule(0.04, 0.17), skin_mat, Vector3(0, -0.075, 0))
		_m(fore, _cyl(0.05, 0.047, 0.08), leather, Vector3(0, -0.1, 0))  # bracer
		_m(fore, _sphere(0.052, 12), skin_mat, Vector3(0, -0.175, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.1))  # fist
		if side < 0:
			arm_l = arm
			fore_l = fore
		else:
			arm_r = arm
			fore_r = fore

	# --- rusty short sword in the right hand (blade along -Z of the sword pivot) ---
	sword = _pivot(fore_r, "sword", Vector3(0, -0.175, 0))
	_m(sword, _cyl(0.018, 0.018, 0.11, 8), leather_dark, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	_m(sword, _sphere(0.026, 8), gold, Vector3(0, 0, 0.065))
	_m(sword, _box(Vector3(0.15, 0.03, 0.03)), steel_dark, Vector3(0, 0, -0.06))
	blade_root = Node3D.new()
	blade_root.name = "BladeRoot"
	blade_root.position = Vector3(0, 0, -0.07)
	sword.add_child(blade_root)
	_m(blade_root, _box(Vector3(0.055, 0.014, 0.4)), _blade_mat, Vector3(0, 0, -0.2))
	_m(blade_root, _prism(Vector3(0.055, 0.08, 0.014)), _blade_mat, Vector3(0, 0, -0.44), Vector3(-90, 0, 0))
	_m(blade_root, _box(Vector3(0.025, 0.018, 0.06)), rust_spot, Vector3(0.012, 0, -0.12))
	_m(blade_root, _box(Vector3(0.02, 0.018, 0.04)), rust_spot, Vector3(-0.014, 0, -0.29))

	# --- hobgoblin armour (hidden until evolution) ---
	var pad_mat := Palette.mat(Palette.STEEL.darkened(0.25), 0.45)
	var pad := Node3D.new()
	arm_r.add_child(pad)
	_m(pad, _sphere(0.1, 14), pad_mat, Vector3(0.02, 0.0, 0), Vector3(0, 0, -20), Vector3(1.0, 0.7, 1.05))
	_m(pad, _sphere(0.02, 6), gold, Vector3(0.09, 0.03, 0))
	armour.append(pad)
	var pad_l := Node3D.new()
	arm_l.add_child(pad_l)
	_m(pad_l, _sphere(0.085, 12), Palette.mat(Palette.LEATHER.darkened(0.1), 0.7), Vector3(-0.015, 0.0, 0), Vector3(0, 0, 20), Vector3(1.0, 0.65, 1.0))
	armour.append(pad_l)
	var chest := Node3D.new()
	torso.add_child(chest)
	_m(chest, _cyl(0.145, 0.18, 0.16), Palette.mat(Palette.LEATHER.darkened(0.15), 0.7), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.02, 1, 1.02))
	for i in 3:
		_m(chest, _sphere(0.016, 6), gold, Vector3(-0.05 + 0.05 * float(i), 0.24, -0.15))
	armour.append(chest)
	for a in armour:
		a.visible = false


# =============================================================== evolution
func set_stage(p_stage: StringName, animate: bool = true) -> void:
	stage = p_stage
	var evolved := p_stage != &"goblin"
	var target_scale: float = STAGE_SCALE.get(p_stage, 1.3 if evolved else 1.0)
	var skin_col := Palette.HOBGOBLIN_SKIN if evolved else Palette.GOBLIN_SKIN
	var blade_col := Palette.STEEL.darkened(0.08) if evolved else BLADE_RUSTY
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
			a.visible = evolved
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
			a.visible = evolved).set_delay(0.25)
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
func flinch(strength: float = 1.0) -> void:
	_flinch = maxf(_flinch, clampf(strength, 0.0, 1.0))


func land(impact: float) -> void:
	_squash = maxf(_squash, clampf(impact, 0.0, 1.0))


func reset_pose() -> void:
	_flinch = 0.0
	_squash = 0.0
	for j: Node3D in _joints.values():
		if j.name.begins_with("ear"):
			continue
		j.rotation = Vector3.ZERO
	roll.position = Vector3(0, HIP_HEIGHT, 0)


# =============================================================== animation
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
	elif anim_state == &"hurt":
		rate = 24.0
	var k := 1.0 - exp(-rate * delta)
	for n: String in pose:
		if n == "hip_y" or n == "roll_x":
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
	var hip_y: float = HIP_HEIGHT + float(pose.get("hip_y", 0.0))
	roll.position.y = lerpf(roll.position.y, hip_y, k)
	# squash on landing
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_flinch = move_toward(_flinch, 0.0, delta * 5.0)
	var sq := _squash * _squash
	hips.scale = Vector3(1.0 + sq * 0.12, 1.0 - sq * 0.18, 1.0 + sq * 0.12)
	_update_face(delta)


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
	var eye_y := 1.0
	var brow_z := 0.0       # positive = angry (inner ends down)
	var brow_y := 0.25
	var open := false
	match expr:
		&"determined":
			eye_y = 0.78
			brow_z = 0.38
			brow_y = 0.238
			open = anim_state == &"attack" and anim_phase >= 0.9 and anim_phase < 2.4
		&"wince":
			eye_y = 0.22
			brow_z = -0.32
			brow_y = 0.235
			open = true
		&"surprised":
			eye_y = 1.12
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


func _rest_combat(out: Dictionary) -> void:
	var breathe := sin(_time * 2.2)
	out["hips"] = Vector3.ZERO
	out["torso"] = Vector3(0.04 + breathe * 0.025, 0, 0)
	out["head"] = Vector3(-0.03 - breathe * 0.02, 0, 0)
	out["arm_l"] = Vector3(0.1, 0, -0.18 - breathe * 0.03)
	out["fore_l"] = Vector3(0.35, 0, 0)
	out["arm_r"] = Vector3(0.25, 0, 0.2 + breathe * 0.03)
	out["fore_r"] = Vector3(0.75, 0, 0)
	out["sword"] = Vector3(-0.35, 0, 0)
	out["leg_l"] = Vector3(0.05, 0, -0.04)
	out["shin_l"] = Vector3(-0.08, 0, 0)
	out["leg_r"] = Vector3(-0.05, 0, 0.04)
	out["shin_r"] = Vector3(-0.08, 0, 0)
	out["hip_y"] = -0.005 + breathe * 0.004
	out["roll_x"] = 0.0


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
			p["torso"] = Vector3(0.18, 0, 0)
			p["head"] = Vector3(-0.12, 0, 0)
			p["arm_r"] = Vector3(1.25, 0, -0.35)
			p["fore_r"] = Vector3(0.95, 0, 0)
			p["sword"] = Vector3(0, 1.45, 0)
			p["arm_l"] = Vector3(1.0, 0, 0.25)
			p["fore_l"] = Vector3(1.35, 0, 0)
			p["hip_y"] = float(p["hip_y"]) - 0.05
		&"hurt":
			p["torso"] = Vector3(-0.38, 0.15, 0)
			p["head"] = Vector3(-0.3, 0, 0.1)
			p["arm_l"] = Vector3(0.7, 0, -0.65)
			p["arm_r"] = Vector3(0.7, 0, 0.65)
			p["fore_l"] = Vector3(0.6, 0, 0)
			p["hip_y"] = -0.04
		&"cast":
			var e := clampf(anim_t * 4.0, 0.0, 1.0)
			p["torso"] = Vector3(0.12, 0.3 * e, 0)
			p["arm_l"] = Vector3(1.55 * e, -0.2, -0.1)
			p["fore_l"] = Vector3(0.0, 0, 0)
			p["arm_r"] = Vector3(0.1, 0, 0.45)
			p["leg_l"] = Vector3(0.35, 0, 0)
			p["leg_r"] = Vector3(-0.3, 0, 0)
			p["hip_y"] = -0.03
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
		p["torso"] = (p["torso"] as Vector3) + Vector3(-0.3 * f, 0, 0)
		p["head"] = (p["head"] as Vector3) + Vector3(-0.25 * f, 0, 0.1 * f)
	return p


func _locomotion(p: Dictionary, delta: float, amp_scale: float = 1.0) -> void:
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
	p["arm_r"] = Vector3(arm_amp * s * 0.7 + 0.3, 0, 0.22)
	p["fore_r"] = Vector3(0.7 + run_k * 0.3, 0, 0)
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


## Key poses for attacks: [windup, strike-end]. Joints omitted keep rest values.
const ATTACK_KEYS := {
	&"light1": [  # diagonal slash right -> left
		{"torso": Vector3(0.0, -0.75, 0), "arm_r": Vector3(1.5, 0, 1.15), "fore_r": Vector3(0.7, 0, 0), "sword": Vector3(0, -0.3, 0),
		"arm_l": Vector3(0.5, 0, -0.45), "leg_l": Vector3(0.3, 0, 0), "leg_r": Vector3(-0.25, 0, 0), "shin_r": Vector3(-0.3, 0, 0)},
		{"torso": Vector3(0.22, 0.75, 0), "arm_r": Vector3(1.25, 0, -0.75), "fore_r": Vector3(0.15, 0, 0), "sword": Vector3(0, 0.6, 0),
		"arm_l": Vector3(-0.3, 0, -0.6), "leg_l": Vector3(0.45, 0, 0), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.35, 0, 0), "hip_y": -0.04},
	],
	&"light2": [  # backhand left -> right
		{"torso": Vector3(0.05, 0.85, 0), "arm_r": Vector3(1.55, 0, -0.95), "fore_r": Vector3(1.1, 0, 0), "sword": Vector3(0, 0.9, 0),
		"arm_l": Vector3(0.2, 0, -0.3), "leg_r": Vector3(0.3, 0, 0), "leg_l": Vector3(-0.2, 0, 0)},
		{"torso": Vector3(0.2, -0.7, 0), "arm_r": Vector3(1.35, 0, 1.25), "fore_r": Vector3(0.2, 0, 0), "sword": Vector3(0, -0.5, 0),
		"arm_l": Vector3(0.5, 0, -0.7), "leg_r": Vector3(0.45, 0, 0), "shin_r": Vector3(-0.2, 0, 0), "leg_l": Vector3(-0.35, 0, 0), "hip_y": -0.04},
	],
	&"light3": [  # overhead chop
		{"torso": Vector3(-0.3, 0, 0), "head": Vector3(0.15, 0, 0), "arm_r": Vector3(3.0, 0, 0.25), "fore_r": Vector3(0.7, 0, 0), "sword": Vector3(0.2, 0, 0),
		"arm_l": Vector3(2.6, 0, -0.2), "fore_l": Vector3(0.6, 0, 0), "hip_y": 0.02},
		{"torso": Vector3(0.5, 0, 0), "head": Vector3(-0.3, 0, 0), "arm_r": Vector3(0.9, 0, 0.05), "fore_r": Vector3(0.05, 0, 0), "sword": Vector3(-0.1, 0, 0),
		"arm_l": Vector3(0.9, 0, -0.1), "fore_l": Vector3(0.2, 0, 0), "leg_l": Vector3(0.65, 0, 0), "shin_l": Vector3(-0.5, 0, 0),
		"leg_r": Vector3(-0.5, 0, 0), "shin_r": Vector3(-0.15, 0, 0), "hip_y": -0.07},
	],
	&"heavy": [  # big two-handed overhead slam
		{"torso": Vector3(-0.5, -0.2, 0), "head": Vector3(0.25, 0, 0), "arm_r": Vector3(3.25, 0, 0.15), "fore_r": Vector3(0.95, 0, 0), "sword": Vector3(0.3, 0, 0),
		"arm_l": Vector3(3.0, 0, -0.15), "fore_l": Vector3(0.9, 0, 0), "leg_l": Vector3(0.25, 0, 0), "leg_r": Vector3(-0.2, 0, 0), "hip_y": -0.03},
		{"torso": Vector3(0.7, 0.05, 0), "head": Vector3(-0.45, 0, 0), "arm_r": Vector3(0.55, 0, 0.0), "fore_r": Vector3(0.0, 0, 0), "sword": Vector3(-0.2, 0, 0),
		"arm_l": Vector3(0.65, 0, 0.1), "fore_l": Vector3(0.1, 0, 0), "leg_l": Vector3(0.85, 0, 0), "shin_l": Vector3(-0.95, 0, 0),
		"leg_r": Vector3(-0.65, 0, 0), "shin_r": Vector3(-0.2, 0, 0), "hip_y": -0.13},
	],
}


func _attack(p: Dictionary) -> void:
	var keys: Array = ATTACK_KEYS.get(anim_action, ATTACK_KEYS[&"heavy"])
	var wind: Dictionary = keys[0]
	var strike: Dictionary = keys[1]
	var rest := _rest
	rest.merge(p, true)
	var ph := anim_phase
	for n: String in rest:
		var a: Variant = rest[n]
		var w: Variant = wind.get(n, a)
		var s: Variant = strike.get(n, a)
		var v: Variant
		if ph < 1.0:
			var t := 1.0 - pow(1.0 - ph, 2.0)
			v = _lerp_v(a, w, t)
		elif ph < 2.0:
			var t2 := 1.0 - pow(1.0 - (ph - 1.0), 3.0)
			v = _lerp_v(w, s, t2)
		else:
			var t3 := smoothstep(0.35, 1.0, ph - 2.0)
			v = _lerp_v(s, a, t3)
		p[n] = v


static func _lerp_v(a: Variant, b: Variant, t: float) -> Variant:
	if a is Vector3:
		return (a as Vector3).lerp(b as Vector3, t)
	return lerpf(float(a), float(b), t)


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
