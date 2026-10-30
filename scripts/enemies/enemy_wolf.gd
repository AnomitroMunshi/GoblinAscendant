class_name EnemyWolf
extends EnemyBase
## Wolf / Alpha wolf. Circles the target, then a telegraphed crouch -> lunging bite,
## then backs off. The alpha is bigger, darker, has glowing eyes, a heavy pounce
## and HOWLS on engage, alerting wolves within its assist radius.


var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []   # FL, FR, BL, BR
var _howl_time := 0.0
var _is_alpha := false


func _default_type() -> StringName:
	return &"wolf"


func _build_model(root: Node3D) -> void:
	_is_alpha = stats.enemy_type == &"alpha_wolf"
	var fur := Palette.WOLF_FUR if not _is_alpha else Color(0.17, 0.16, 0.19)
	var fur_light := fur.lightened(0.35)
	var fur_dark := fur.darkened(0.35)
	var eye_col := Color(0.95, 0.75, 0.2) if not _is_alpha else Color(1.0, 0.35, 0.15)
	_body = EnemyModelKit.joint(root, Vector3(0, 0.62, 0))
	EnemyModelKit.part(_body, EnemyModelKit.capsule(0.27, 1.2), fur, Vector3(0, 0, 0.05), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.95))
	EnemyModelKit.part(_body, EnemyModelKit.sphere(0.31), fur_light, Vector3(0, 0.02, -0.36), Vector3.ZERO, Vector3(0.95, 1.0, 1.0))
	# scruff ridge (spiky mane for the alpha)
	if _is_alpha:
		for i in 4:
			EnemyModelKit.part(_body, EnemyModelKit.prism(Vector3(0.14, 0.24, 0.12)), fur_dark, Vector3(0, 0.27, -0.35 + i * 0.2), Vector3(-25, 0, 0))
	else:
		EnemyModelKit.part(_body, EnemyModelKit.prism(Vector3(0.22, 0.14, 0.3)), fur_dark, Vector3(0, 0.27, -0.3), Vector3(-20, 0, 0))
	_head = EnemyModelKit.joint(_body, Vector3(0, 0.2, -0.6))
	EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.32, 0.28, 0.32)), fur, Vector3(0, 0, -0.05))
	EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.18, 0.14, 0.28)), fur_light, Vector3(0, -0.06, -0.3))
	EnemyModelKit.part(_head, EnemyModelKit.sphere(0.045, 8), Color(0.08, 0.07, 0.07), Vector3(0, -0.01, -0.45))
	EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.11, 0.18, 0.06)), fur_dark, Vector3(-0.1, 0.2, 0.0), Vector3(0, 0, 12))
	EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.11, 0.18, 0.06)), fur_dark, Vector3(0.1, 0.2, 0.0), Vector3(0, 0, -12))
	var eye_mat: Material = Palette.glow(eye_col, 3.0 if _is_alpha else 1.4)
	for s: float in [-1.0, 1.0]:
		EnemyModelKit.part(_head, EnemyModelKit.sphere(0.04, 8), eye_mat, Vector3(0.09 * s, 0.05, -0.2), Vector3.ZERO, Vector3(1.2, 0.7, 0.6))
		# angry brow ridge
		EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.1, 0.03, 0.05)), fur_dark, Vector3(0.09 * s, 0.1, -0.21), Vector3(0, 0, s * 18.0))
	_tail = EnemyModelKit.joint(_body, Vector3(0, 0.1, 0.62))
	EnemyModelKit.part(_tail, EnemyModelKit.capsule(0.08, 0.6), fur_dark, Vector3(0, 0, 0.26), Vector3(-70, 0, 0))
	for p: Vector3 in [Vector3(-0.15, -0.04, -0.38), Vector3(0.15, -0.04, -0.38), Vector3(-0.15, -0.04, 0.42), Vector3(0.15, -0.04, 0.42)]:
		var hip := EnemyModelKit.joint(_body, p)
		EnemyModelKit.part(hip, EnemyModelKit.capsule(0.075, 0.6), fur, Vector3(0, -0.28, 0))
		EnemyModelKit.part(hip, EnemyModelKit.sphere(0.08, 8), fur_dark, Vector3(0, -0.55, -0.03), Vector3.ZERO, Vector3(1, 0.6, 1.3))
		_legs.append(hip)


func _build_attacks() -> void:
	var sc := stats.model_scale
	var d := stats.damage
	var lunge := EnemyAttack.make(&"lunge", &"lunge", d, stats.telegraph_time, 0.3, stats.recovery_time,
		3.6 * sc, EnemyAttack.sphere(0.45 * sc), Vector3(0, 0.55 * sc, -0.85 * sc))
	lunge.min_range = 1.2
	lunge.lunge_speed = 9.5
	lunge.knockback = 3.0
	lunge.stagger = 0.4
	lunge.step_back = 1.2
	lunge.track = 0.8
	lunge.cooldown = 0.6
	attacks.append(lunge)
	var bite := EnemyAttack.make(&"bite", &"bite", d * 0.8, stats.telegraph_time * 0.75, 0.14, stats.recovery_time * 0.8,
		1.7 * sc, EnemyAttack.sphere(0.42 * sc), Vector3(0, 0.55 * sc, -0.85 * sc))
	bite.knockback = 2.0
	bite.weight = 0.8
	attacks.append(bite)
	if _is_alpha:
		var pounce := EnemyAttack.make(&"pounce", &"lunge", d * 1.5, 0.95, 0.4, 1.2,
			6.5, EnemyAttack.sphere(0.6 * sc), Vector3(0, 0.55 * sc, -0.9 * sc))
		pounce.min_range = 3.0
		pounce.lunge_speed = 13.0
		pounce.heavy = true
		pounce.knockback = 7.0
		pounce.stagger = 0.8
		pounce.step_back = 1.5
		pounce.cooldown = 5.0
		pounce.weight = 1.5
		attacks.append(pounce)


func _on_target_acquired(t: Node3D) -> void:
	if _is_alpha:
		_howl_time = 1.3
		Audio.play_sfx(&"wolf_howl", global_position + Vector3.UP)
		EnemyFx.shockwave(self, global_position, stats.ally_assist_radius * 0.35, Color(1.0, 0.5, 0.2, 0.6), 0.9)
		# Howl: wolves within the radius come to investigate / chase.
		var r2 := stats.ally_assist_radius * stats.ally_assist_radius
		for a in get_tree().get_nodes_in_group(&"enemies"):
			if a != self and a is EnemyBase and (a as EnemyBase).get_faction() == get_faction() \
					and (a as Node3D).global_position.distance_squared_to(global_position) <= r2:
				(a as EnemyBase).alert(t)
	else:
		Audio.play_sfx(&"wolf_growl", global_position + Vector3.UP)


func _custom_process(delta: float) -> void:
	if _howl_time > 0.0:
		_howl_time -= delta
		_circle_until = maxf(_circle_until, _time + 0.1)


func _state_chase(delta: float) -> void:
	super(delta)
	if _howl_time > 0.0 and state == State.CHASE:
		_desired_velocity = Vector3.ZERO


func _recover_velocity() -> Vector3:
	# Back off after the lunge.
	if target != null and is_instance_valid(target) and _state_time < _state_len * 0.7:
		return _flat(global_position - target.global_position).normalized() * stats.move_speed * 1.5
	return Vector3.ZERO


func _on_active_start(atk: EnemyAttack) -> void:
	if atk.heavy:
		EnemyFx.burst(self, global_position + Vector3.UP * 0.6, 1.2, Color(1.0, 0.45, 0.2, 0.6), 0.3)


func _animate(delta: float) -> void:
	var r := 1.0 - exp(-14.0 * delta)
	var run := _move_blend
	var ph := _walk_phase
	var swing := sin(ph) * (0.25 + 0.55 * run) * clampf(Vector2(velocity.x, velocity.z).length(), 0.0, 1.0)
	var body_y := 0.62 + absf(sin(ph)) * 0.05 * run + sin(_time * 2.0) * 0.008
	var body_x := 0.0
	var head_x := 0.0
	var tail_x := 0.3 + sin(_time * (8.0 if state == State.CHASE else 2.0)) * 0.1
	var tail_y := sin(_time * 3.0) * 0.25
	var legs := [swing, -swing, -swing, swing]
	match state:
		State.ATTACK:
			var k := clampf(_phase_time / maxf(current_attack.windup, 0.01), 0.0, 1.0) if attack_phase == Phase.WINDUP else 1.0
			if attack_phase == Phase.WINDUP:
				# crouch, haunches down, head low, tail rigid
				body_y = 0.62 - 0.2 * k
				body_x = 0.18 * k
				head_x = -0.25 * k
				tail_x = 0.8
				legs = [-0.5 * k, -0.5 * k, 0.6 * k, 0.6 * k]
			else:
				body_y = 0.75
				body_x = -0.2
				head_x = 0.35
				legs = [1.1, 1.1, -1.0, -1.0]
				r = 1.0 - exp(-30.0 * delta)
		State.RECOVER:
			head_x = 0.1
		State.HURT:
			body_x = 0.2
			head_x = 0.5
		State.IDLE, State.INVESTIGATE:
			head_x = sin(_time * 0.7) * 0.15
	if _howl_time > 0.0:
		body_x = 0.25
		head_x = 0.9
		body_y = 0.6
	_body.position.y = lerpf(_body.position.y, body_y, r)
	_body.rotation.x = lerpf(_body.rotation.x, body_x, r)
	_head.rotation.x = lerpf(_head.rotation.x, head_x, r)
	_tail.rotation.x = lerpf(_tail.rotation.x, tail_x, r)
	_tail.rotation.y = lerpf(_tail.rotation.y, tail_y, r)
	for i in 4:
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, legs[i], r)
