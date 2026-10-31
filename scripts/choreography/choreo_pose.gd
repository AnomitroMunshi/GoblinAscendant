class_name ChoreoPose
## Keyframe evaluation for data-driven attack/cast poses.
##
## A move's "curve" is a list of [phase, pose_name, ease?] entries. Phase uses the
## model's anim_phase units: 0..1 windup, 1..2 active (hitbox live), 2..3 recovery.
## An implicit [0.0, "rest"] key starts every curve. "rest" means the live
## weapon carry pose (with breathing). Every other key overlays its joints on the
## PREVIOUS key (carry-forward), so a key lists only the joints that change.
##
## Joint values: Vector3 Euler (authored +X = forward for every joint; the model
## inverts X for upward torso/head joints) or float for "hip_y".
## The model never translates the root horizontally: all travel is controller
## footwork (see ChoreoLibrary "footwork"), so nothing is double-counted.

## Shoulder pivots in hips space (Goblin units) used for arcing hand paths.
const SHOULDER_R := Vector3(0.158, 0.28, 0.0)
const SHOULDER_L := Vector3(-0.158, 0.28, 0.0)
## IK/aim channels: Vector3 positions/directions in hips space, not Euler angles.
const IK_CHANNELS := ["hand_r", "hand_l", "aim", "edge"]

const VECTOR_JOINTS := ["hips", "torso", "head", "arm_l", "fore_l", "arm_r", "fore_r", "sword",
	"leg_l", "shin_l", "leg_r", "shin_r", "foot_l", "foot_r"]


## Writes the pose for `phase` into `out` (which holds the rest pose on entry).
static func evaluate(move: Dictionary, out: Dictionary, phase: float) -> void:
	var poses: Dictionary = move.get("poses", {})
	var curve: Array = move.get("curve", [])
	if curve.is_empty():
		return
	var rest := out.duplicate()
	var a := rest
	var a_pos := 0.0
	for key: Array in curve:
		var pos := float(key[0])
		var pose_name: String = key[1]
		var b: Dictionary
		if pose_name == "rest":
			b = rest
		else:
			b = a.duplicate()
			var pose: Dictionary = poses.get(pose_name, {})
			for j: String in pose:
				b[j] = pose[j]
		if phase <= pos:
			var span := pos - a_pos
			var t := 1.0 if span <= 0.0001 else clampf((phase - a_pos) / span, 0.0, 1.0)
			t = ease_t(t, String(key[2]) if key.size() > 2 else default_ease(pos))
			for j: String in b:
				out[j] = lerp_joint(j, a.get(j, b[j]), b[j], t)
			return
		a = b
		a_pos = pos
	for j: String in a:
		out[j] = a[j]


static func default_ease(pos: float) -> String:
	if pos <= 1.0:
		return "out2"
	if pos <= 2.0:
		return "out3"
	return "smooth"


static func ease_t(t: float, kind: String) -> float:
	match kind:
		"out2":
			return 1.0 - pow(1.0 - t, 2.0)
		"out3":
			return 1.0 - pow(1.0 - t, 3.0)
		"in2":
			return t * t
		"linear":
			return t
		"hold":
			return 0.0 if t < 1.0 else 1.0
		_:
			return t * t * (3.0 - 2.0 * t)


## Hand IK targets travel on arcs around the shoulder; weapon directions slerp.
static func lerp_joint(j: String, a: Variant, b: Variant, t: float) -> Variant:
	match j:
		"hand_r", "hand_l":
			var s := SHOULDER_R if j == "hand_r" else SHOULDER_L
			var va := (a as Vector3) - s
			var vb := (b as Vector3) - s
			if va.length_squared() < 1e-6 or vb.length_squared() < 1e-6:
				return (a as Vector3).lerp(b as Vector3, t)
			return s + va.slerp(vb, t)
		"aim", "edge":
			var na := (a as Vector3).normalized()
			var nb := (b as Vector3).normalized()
			if na.dot(nb) < -0.999:
				return na.lerp(nb, t)
			return na.slerp(nb, t)
	return lerp_v(a, b, t)


static func lerp_v(a: Variant, b: Variant, t: float) -> Variant:
	if a is Vector3:
		return (a as Vector3).lerp(b as Vector3, t)
	return lerpf(float(a), float(b), t)


## Data convenience: floats for limb joints mean a pure X (hinge) rotation.
static func normalize(pose: Dictionary) -> Dictionary:
	var out := {}
	for j: String in pose:
		var v: Variant = pose[j]
		if j in VECTOR_JOINTS and not (v is Vector3):
			v = Vector3(float(v), 0.0, 0.0)
		out[j] = v
	return out
