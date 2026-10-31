class_name ChoreoIK
## Analytic two-bone arm solver for authored grips (two hands on one haft,
## regrip after a cast). Works in the arm's parent (torso) space.
## Limb convention matches PlayerGoblinModel: limbs hang along local -Y and the
## elbow hinge is local +X (positive bend moves the hand toward local -Z).


## Returns [arm_euler: Vector3 (YXZ), elbow_bend: float, reach_error: float].
static func two_bone(shoulder: Vector3, target: Vector3, upper: float, lower: float, pole: Vector3) -> Array:
	var to := target - shoulder
	var dist := to.length()
	var d := clampf(dist, absf(upper - lower) + 0.002, upper + lower - 0.001)
	var cos_b := clampf((d * d - upper * upper - lower * lower) / (2.0 * upper * lower), -1.0, 1.0)
	var bend := acos(cos_b)
	var hand_l := Vector3(0.0, -upper - lower * cos(bend), -lower * sin(bend))
	var elbow_l := Vector3(0.0, -upper, 0.0)
	var x1 := hand_l.normalized()
	var y1 := elbow_l - x1 * elbow_l.dot(x1)
	y1 = y1.normalized() if y1.length_squared() > 1e-8 else Vector3.BACK
	var z1 := x1.cross(y1)
	var x2 := to.normalized() if dist > 1e-5 else Vector3.DOWN
	var y2 := pole - x2 * pole.dot(x2)
	y2 = y2.normalized() if y2.length_squared() > 1e-8 else Vector3.BACK
	var z2 := x2.cross(y2)
	var r := Basis(x2, y2, z2) * Basis(x1, y1, z1).transposed()
	return [r.get_euler(), bend, absf(dist - d)]
