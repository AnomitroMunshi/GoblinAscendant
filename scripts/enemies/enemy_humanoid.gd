class_name EnemyHumanoid
extends EnemyBase
## Articulated biped: goblin raiders, human raiders, raider captain, adventurers
## (and the ogre via EnemyOgre). Models come from the Character Art kit
## (scripts/characters/): grounded proportions, definitions in CharDefs.
##
## Fighting styles
##   goblin_raider : quick chops/thrusts, retreats briefly when wounded (< 30 % HP)
##   human_raider  : deliberate slashes + heavy axe chop, raises a guard (blocks frontal hits)
##   raider_captain: sword + torch; long, glowing FLAME SWEEP heavy attack
##   adventurer    : sword / shield / elf bow-stick, defends itself only

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _weapon: Node3D
var _offhand: Node3D
var _cape: Node3D
var _torch_light: OmniLight3D
var _torch_flame: MeshInstance3D
var _style: Dictionary = {}
## ---- Choreography data (edit freely; AI code never reads these) ------------------
## Key poses per attack `anim` (EnemyAttack.anim). Vector4 = (right arm pitch,
## left arm pitch, torso pitch [+ = lean back], torso yaw). Arm pitch: 0 = hanging,
## PI/2 = forward, PI = straight up.
##   reach  : fraction of the wind-up spent moving into the wind-up pose (rest = held anticipation)
##   follow : fraction of the recovery that holds the strike pose (follow-through)
##   windup_rate / strike_rate / recover_rate : blend speeds (1/s)
## Timings (wind-up / active / recovery seconds) live in _build_attacks() of each type.
const POSES := {
	&"chop":   {"windup": Vector4(2.8, 0.6, 0.18, 0.35), "strike": Vector4(1.0, -0.2, -0.35, -0.15), "reach": 0.55, "follow": 0.45, "windup_rate": 10.0, "strike_rate": 32.0, "recover_rate": 6.0},
	&"thrust": {"windup": Vector4(-0.6, 0.9, 0.1, 0.55), "strike": Vector4(1.55, -0.3, -0.25, -0.35), "reach": 0.55, "follow": 0.4, "windup_rate": 10.0, "strike_rate": 34.0, "recover_rate": 6.0},
	&"sweep":  {"windup": Vector4(1.5, 0.3, 0.05, 1.1), "strike": Vector4(1.5, -0.2, -0.15, -1.1), "reach": 0.55, "follow": 0.45, "windup_rate": 10.0, "strike_rate": 28.0, "recover_rate": 6.0},
	&"flame":  {"windup": Vector4(0.3, 2.9, 0.25, 0.5), "strike": Vector4(0.2, 1.5, -0.3, -0.6), "reach": 0.4, "follow": 0.5, "windup_rate": 8.0, "strike_rate": 26.0, "recover_rate": 5.0},
}
## Guard (block) pose and hit reaction.
const GUARD_POSE := {"arm_r": 1.3, "arm_r_z": -0.7, "arm_l": 1.35, "arm_l_z": 0.3, "torso": -0.12, "crouch": 0.06}
const HURT_POSE := {"arm_r": -0.3, "arm_l": -0.4, "arm_z": 0.5, "torso": 0.35, "head": 0.35, "rate": 22.0}

var _hip_height := 0.9


func _default_type() -> StringName:
	return &"goblin_raider"


# ------------------------------------------------------------------ styles
## Character definition (CharDefs) for this enemy; also read by the AI for
## `_style["weapon"]`. Character Art owns the look; see scripts/characters/.
func _make_style() -> Dictionary:
	match stats.enemy_type:
		&"goblin_raider":
			return CharDefs.goblin_raider(variant)
		&"human_raider":
			return CharDefs.human_raider(variant)
		&"raider_captain":
			return CharDefs.raider_captain()
		&"adventurer":
			return CharDefs.adventurer(variant)
	return CharDefs.human_raider(variant)


# ------------------------------------------------------------------ model
func _build_model(root: Node3D) -> void:
	_style = CharHumanoid.resolve(_make_style())
	var rig := CharHumanoid.build(root, _style)
	_hips = rig["hips"]
	_torso = rig["torso"]
	_head = rig["head"]
	_arm_l = rig["shoulder_l"]
	_arm_r = rig["shoulder_r"]
	_leg_l = rig["hip_l"]
	_leg_r = rig["hip_r"]
	_weapon = rig["weapon"]
	_offhand = rig["offhand"]
	_hip_height = rig["hip_height"]
	_build_offhand(_offhand, _style["offhand"])


func _build_offhand(o: Node3D, kind: StringName) -> void:
	match kind:
		&"shield":
			# strapped to the left forearm, face turned out and forward
			var g := CharGeo.new()
			CharProps.round_shield(g, CharGeo.xf(Vector3(-0.06, 0.13, -0.02), Vector3(0, 62, 0)), 0.3, Color(0.27, 0.32, 0.42))
			g.instance(o, "Shield")
		&"torch":
			var t := EnemyModelKit.joint(o, Vector3.ZERO, Vector3(deg_to_rad(-75), 0, 0))
			var g2 := CharGeo.new()
			g2.loft(Transform3D(), [Vector4(-0.13, 0.016, 0.016, 0), Vector4(0.36, 0.02, 0.02, 0), Vector4(0.42, 0.03, 0.03, 0)], [CharProps.WOOD_DARK, CharProps.WOOD, CharProps.WOOD_DARK], 7)
			g2.loft(Transform3D(), [Vector4(0.36, 0.034, 0.034, 0), Vector4(0.47, 0.042, 0.042, 0)], Color(0.16, 0.12, 0.09), 8)
			g2.instance(t, "Torch")
			_torch_flame = EnemyModelKit.part(t, EnemyModelKit.sphere(0.075, 10), Palette.glow(Palette.FIRE, 3.0), Vector3(0, 0.53, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
			EnemyModelKit.part(t, EnemyModelKit.sphere(0.045, 8), Palette.glow(Color(1, 0.9, 0.5), 3.0), Vector3(0, 0.5, 0))
			_torch_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_torch_light = OmniLight3D.new()
			_torch_light.light_color = Palette.FIRE
			_torch_light.light_energy = 1.4
			_torch_light.omni_range = 5.0
			_torch_light.shadow_enabled = false
			_torch_light.position = Vector3(0, 0.6, 0)
			_torch_light.distance_fade_enabled = true
			_torch_light.distance_fade_begin = 40.0
			_torch_light.distance_fade_length = 15.0
			t.add_child(_torch_light)


# ------------------------------------------------------------------ attacks
func _build_attacks() -> void:
	var sc := stats.model_scale
	var d := stats.damage
	var tt := stats.telegraph_time
	var rt := stats.recovery_time
	var chest := stats.body_height * 0.55
	match stats.enemy_type:
		&"goblin_raider":
			if _style["weapon"] == &"spear":
				var thrust := EnemyAttack.make(&"thrust", &"thrust", d, tt, 0.14, rt, 2.3,
					EnemyAttack.box(Vector3(0.4, 0.5, 1.3)), Vector3(0, chest, -1.15))
				thrust.knockback = 2.5
				attacks.append(thrust)
			else:
				var chop := EnemyAttack.make(&"chop", &"chop", d, tt, 0.14, rt, 1.8,
					EnemyAttack.sphere(0.55), Vector3(0, chest, -0.95))
				attacks.append(chop)
				var jab := EnemyAttack.make(&"jab", &"thrust", d * 0.7, tt * 0.7, 0.12, rt * 0.7, 1.6,
					EnemyAttack.sphere(0.45), Vector3(0, chest, -0.85))
				jab.weight = 0.6
				attacks.append(jab)
		&"human_raider", &"raider_captain", &"adventurer":
			if _style["weapon"] == &"axe":
				var axe := EnemyAttack.make(&"axe_chop", &"chop", d * 1.4, tt * 1.5, 0.16, rt * 1.3, 2.2 * sc,
					EnemyAttack.sphere(0.6 * sc), Vector3(0, chest, -1.35 * sc))
				axe.heavy = true
				axe.knockback = 6.0
				axe.stagger = 0.7
				axe.step_back = 0.8
				axe.cooldown = 1.5
				attacks.append(axe)
			var slash := EnemyAttack.make(&"slash", &"sweep", d, tt, 0.18, rt, 2.0 * sc,
				EnemyAttack.box(Vector3(1.8, 0.8, 1.5) * sc), Vector3(0, chest, -1.0 * sc))
			slash.knockback = 3.0
			attacks.append(slash)
			if stats.enemy_type == &"raider_captain":
				var flame := EnemyAttack.make(&"flame_sweep", &"flame", d * 1.6, 1.4, 0.3, 1.5, 3.4,
					EnemyAttack.box(Vector3(2.6, 1.4, 3.0)), Vector3(0, 1.0, -1.9))
				flame.heavy = true
				flame.element = &"fire"
				flame.knockback = 7.0
				flame.stagger = 0.8
				flame.step_back = 1.0
				flame.cooldown = 6.0
				flame.weight = 2.0
				flame.marker_radius = 1.7
				flame.track = 0.5
				attacks.append(flame)
				var chop := EnemyAttack.make(&"overhead", &"chop", d * 1.2, tt * 1.3, 0.16, rt * 1.1, 2.2 * sc,
					EnemyAttack.sphere(0.6), Vector3(0, chest, -1.3 * sc))
				chop.heavy = true
				chop.knockback = 5.0
				chop.cooldown = 2.5
				attacks.append(chop)


func _on_windup_start(atk: EnemyAttack) -> void:
	if atk.id == &"flame_sweep" and _torch_light:
		Audio.play_sfx(&"flame", global_position + Vector3.UP * 1.5)


func _on_active_start(atk: EnemyAttack) -> void:
	var col := Color(1, 1, 1, 0.5)
	if atk.element == &"fire":
		col = Palette.FIRE
		var fwd := _forward()
		for i in 3:
			EnemyFx.burst(self, global_position + Vector3.UP * 1.0 + fwd * (1.0 + i * 0.9), 0.9 + i * 0.25, Palette.FIRE, 0.45)
		Audio.play_sfx(&"flame", global_position + Vector3.UP)
	elif atk.heavy:
		col = Color(1.0, 0.55, 0.4)
	EnemyFx.swing_arc(self, atk.offset.y, atk.max_range, col, rotation.y)


# ------------------------------------------------------------------ animation
func _animate(delta: float) -> void:
	var rate := 12.0
	var spd := Vector2(velocity.x, velocity.z).length()
	var stride := clampf(spd / 1.5, 0.0, 1.0)
	var sw := sin(_walk_phase) * (0.35 + 0.35 * _move_blend) * stride
	var breathe := sin(_time * 2.2 + float(variant)) * 0.015
	var leg_l := sw
	var leg_r := -sw
	var arm_l := -sw * 0.7 + 0.1
	var arm_r := sw * 0.7 + 0.25
	var arm_l_z := -0.12
	var arm_r_z := 0.12
	var torso_x := -0.12 * _move_blend + breathe
	var torso_y := 0.0
	var head_x := 0.0
	var head_y := 0.0
	var crouch := absf(sin(_walk_phase)) * 0.03 * stride
	if _torch_light:
		arm_l += 0.55  # torch held up and forward
	if state == State.IDLE and stats.aggression <= 0.0:
		head_y = sin(_time * 0.4 + variant) * 0.4
	if blocking:
		arm_r = GUARD_POSE["arm_r"]
		arm_r_z = GUARD_POSE["arm_r_z"]
		arm_l = GUARD_POSE["arm_l"]
		arm_l_z = GUARD_POSE["arm_l_z"]
		torso_x = GUARD_POSE["torso"]
		crouch = GUARD_POSE["crouch"]
	match state:
		State.ATTACK:
			var atk := current_attack
			if attack_phase == Phase.WINDUP:
				var pd := _pose_data(atk.anim)
				var k := clampf(_phase_time / maxf(atk.windup * float(pd["reach"]), 0.01), 0.0, 1.0)  # reach pose early, then HOLD
				var shake := sin(_time * 40.0) * 0.03 * clampf(_phase_time / atk.windup, 0.0, 1.0) if atk.heavy else 0.0
				var p: Vector4 = pd["windup"]
				arm_r = lerpf(arm_r, p.x, k) + shake
				arm_l = lerpf(arm_l, p.y, k)
				torso_x = lerpf(torso_x, p.z, k)
				torso_y = lerpf(0.0, p.w, k)
				crouch = 0.06 * k
				leg_l = -0.25 * k
				leg_r = 0.3 * k
				rate = float(pd["windup_rate"])
			else:
				var pd2 := _pose_data(atk.anim)
				var p2: Vector4 = pd2["strike"]
				arm_r = p2.x
				arm_l = p2.y
				torso_x = p2.z
				torso_y = p2.w
				leg_l = 0.45
				leg_r = -0.3
				crouch = 0.08
				rate = float(pd2["strike_rate"])
		State.RECOVER:
			var pd3: Dictionary = _pose_data(current_attack.anim) if current_attack else POSES[&"chop"]
			if current_attack and _state_time < _state_len * float(pd3["follow"]):
				var p3: Vector4 = pd3["strike"]  # follow-through hold
				arm_r = p3.x
				arm_l = p3.y
				torso_x = p3.z * 0.8
				torso_y = p3.w
				leg_l = 0.35
				leg_r = -0.25
				crouch = 0.06
			rate = float(pd3["recover_rate"])
		State.HURT:
			torso_x = HURT_POSE["torso"]
			head_x = HURT_POSE["head"]
			arm_l = HURT_POSE["arm_l"]
			arm_r = HURT_POSE["arm_r"]
			arm_l_z = -float(HURT_POSE["arm_z"])
			arm_r_z = HURT_POSE["arm_z"]
			rate = HURT_POSE["rate"]
		State.RETREAT:
			torso_x = 0.15
	_pose(delta, rate, leg_l, leg_r, arm_l, arm_r, arm_l_z, arm_r_z, torso_x, torso_y, head_x, head_y, crouch)
	if _cape:
		_cape.rotation.x = lerpf(_cape.rotation.x, 0.15 + 0.5 * _move_blend + sin(_time * 3.0) * 0.05, 1.0 - exp(-6.0 * delta))
	if _torch_light:
		var flare := 1.0
		if state == State.ATTACK and current_attack and current_attack.element == &"fire":
			flare = 1.0 + 2.5 * clampf(_phase_time / current_attack.windup, 0.0, 1.0)
		_torch_light.light_energy = (1.3 + sin(_time * 17.0) * 0.15 + sin(_time * 7.3) * 0.1) * flare
		_torch_flame.scale = Vector3(1, 1.6, 1) * (0.9 + 0.1 * sin(_time * 13.0)) * sqrt(flare)


func _pose_data(anim: StringName) -> Dictionary:
	return POSES.get(anim, POSES[&"chop"])


func _pose(delta: float, rate: float, leg_l: float, leg_r: float, arm_l: float, arm_r: float, arm_l_z: float, arm_r_z: float,
		torso_x: float, torso_y: float, head_x: float, head_y: float, crouch: float) -> void:
	var r := 1.0 - exp(-rate * delta)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_l, r)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, leg_r, r)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_l, r)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_r, r)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, arm_l_z, r)
	_arm_r.rotation.z = lerpf(_arm_r.rotation.z, arm_r_z, r)
	_torso.rotation.x = lerpf(_torso.rotation.x, -torso_x, r)
	_torso.rotation.y = lerpf(_torso.rotation.y, torso_y, r)
	_head.rotation.x = lerpf(_head.rotation.x, -head_x, r)
	_head.rotation.y = lerpf(_head.rotation.y, head_y, r)
	_hips.position.y = lerpf(_hips.position.y, _hip_height - crouch * _hip_height, r)
