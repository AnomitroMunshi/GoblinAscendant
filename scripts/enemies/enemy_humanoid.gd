class_name EnemyHumanoid
extends EnemyBase
## Articulated biped: goblin raiders, human raiders, raider captain, adventurers
## (and the ogre via EnemyOgre). Anime-leaning primitive look: big readable
## heads/eyes, angry brows for raiders, calm faces for adventurers.
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
var _hip_height := 0.9


func _default_type() -> StringName:
	return &"goblin_raider"


# ------------------------------------------------------------------ styles
func _make_style() -> Dictionary:
	var s := {
		"leg_len": 0.85, "leg_r": 0.09, "hip_w": 0.12, "torso_len": 0.62, "torso_w": 0.42, "torso_d": 0.26,
		"head_r": 0.15, "arm_len": 0.62, "arm_r": 0.07, "shoulder_w": 0.26,
		"skin": Palette.HUMAN_SKIN, "top": Palette.CLOTH_BLUE, "pants": Color(0.25, 0.22, 0.2),
		"boots": Palette.LEATHER, "iris": Color(0.3, 0.45, 0.7), "mood": 0.0, "brow": Color(0.3, 0.2, 0.12),
		"weapon": &"sword", "offhand": &"",
	}
	match stats.enemy_type:
		&"goblin_raider":
			s.merge({"leg_len": 0.38, "leg_r": 0.07, "hip_w": 0.09, "torso_len": 0.36, "torso_w": 0.34, "torso_d": 0.26,
				"head_r": 0.17, "arm_len": 0.4, "arm_r": 0.055, "shoulder_w": 0.2,
				"skin": Color(0.38, 0.47, 0.25), "top": Palette.CLOTH_RED.darkened(0.15), "pants": Color(0.22, 0.17, 0.12),
				"boots": Palette.LEATHER.darkened(0.3), "iris": Color(0.95, 0.2, 0.1), "mood": 1.0, "brow": Color(0.2, 0.25, 0.12),
				"weapon": &"club" if variant % 2 == 0 else &"spear", "eye_scale": 0.27}, true)
		&"human_raider":
			s.merge({"top": Color(0.13, 0.11, 0.11), "pants": Color(0.2, 0.15, 0.12), "iris": Color(0.35, 0.25, 0.15),
				"mood": 1.0, "weapon": &"sword" if variant % 2 == 0 else &"axe", "skin": Palette.HUMAN_SKIN.darkened(0.08 * (variant % 3))}, true)
		&"raider_captain":
			s.merge({"top": Color(0.1, 0.08, 0.09), "torso_w": 0.48, "shoulder_w": 0.3, "iris": Color(0.6, 0.15, 0.1),
				"mood": 1.0, "weapon": &"sword", "offhand": &"torch"}, true)
		&"adventurer":
			match variant % 3:
				0:
					s.merge({"top": Palette.CLOTH_BLUE, "iris": Color(0.3, 0.5, 0.25), "mood": -0.3, "weapon": &"sword"}, true)
				1:
					s.merge({"top": Palette.CLOTH_BLUE.lightened(0.15), "iris": Color(0.25, 0.45, 0.75), "mood": -0.3,
						"weapon": &"sword", "offhand": &"shield", "torso_w": 0.38, "brow": Color(0.6, 0.35, 0.15)}, true)
				_:
					s.merge({"top": Color(0.2, 0.42, 0.55), "skin": Color(0.93, 0.85, 0.76), "iris": Color(0.35, 0.75, 0.6),
						"mood": -0.4, "weapon": &"bow", "torso_w": 0.36, "leg_len": 0.9, "brow": Color(0.85, 0.85, 0.8)}, true)
	return s


# ------------------------------------------------------------------ model
func _build_model(root: Node3D) -> void:
	_style = _make_style()
	_build_rig(root, _style)
	_decorate(_style)


func _build_rig(root: Node3D, s: Dictionary) -> void:
	var leg: float = s["leg_len"]
	var leg_r: float = s["leg_r"]
	var tl: float = s["torso_len"]
	var tw: float = s["torso_w"]
	var td: float = s["torso_d"]
	var hr: float = s["head_r"]
	var al: float = s["arm_len"]
	var ar: float = s["arm_r"]
	var skin: Color = s["skin"]
	_hip_height = leg
	_hips = EnemyModelKit.joint(root, Vector3(0, leg, 0))
	for side: float in [-1.0, 1.0]:
		var hip := EnemyModelKit.joint(_hips, Vector3(side * float(s["hip_w"]), 0, 0))
		EnemyModelKit.part(hip, EnemyModelKit.capsule(leg_r, leg + leg_r), s["pants"], Vector3(0, -leg * 0.5, 0))
		EnemyModelKit.part(hip, EnemyModelKit.box(Vector3(leg_r * 2.3, leg_r * 1.4, leg_r * 3.4)), s["boots"], Vector3(0, -leg + leg_r * 0.6, -leg_r * 0.6))
		if side < 0.0:
			_leg_l = hip
		else:
			_leg_r = hip
	_torso = EnemyModelKit.joint(_hips, Vector3.ZERO)
	EnemyModelKit.part(_torso, EnemyModelKit.capsule(tw * 0.5, tl + tw * 0.35), s["top"], Vector3(0, tl * 0.5, 0), Vector3.ZERO, Vector3(1, 1, td / tw))
	EnemyModelKit.part(_torso, EnemyModelKit.cyl(tw * 0.5, tw * 0.5, 0.07), Palette.LEATHER.darkened(0.2), Vector3(0, tl * 0.1, 0), Vector3.ZERO, Vector3(1.04, 1, td / tw * 1.08))
	_head = EnemyModelKit.joint(_torso, Vector3(0, tl + hr * 0.95, 0))
	EnemyModelKit.part(_head, EnemyModelKit.sphere(hr, 16), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.05, 1))
	var mood: float = s["mood"]
	for side: float in [-1.0, 1.0]:
		var er: float = hr * float(s.get("eye_scale", 0.2))
		EnemyModelKit.eye(_head, Vector3(side * hr * 0.42, hr * 0.05, -hr * 0.84), er, s["iris"], side, mood, s["brow"])
	EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(hr * 0.5, hr * 0.07 + maxf(0.0, mood) * hr * 0.05, hr * 0.1)), Color(0.25, 0.08, 0.07), Vector3(0, -hr * 0.45, -hr * 0.9))
	for side: float in [-1.0, 1.0]:
		var sh := EnemyModelKit.joint(_torso, Vector3(side * float(s["shoulder_w"]), tl * 0.9, 0))
		EnemyModelKit.part(sh, EnemyModelKit.capsule(ar, al + ar), s["top"] if stats.enemy_type != &"goblin_raider" else skin, Vector3(0, -al * 0.45, 0))
		EnemyModelKit.part(sh, EnemyModelKit.sphere(ar * 1.35, 10), skin, Vector3(0, -al, 0))
		if side < 0.0:
			_arm_l = sh
		else:
			_arm_r = sh
	_weapon = EnemyModelKit.joint(_arm_r, Vector3(0, -al, 0), Vector3(0.5, 0, 0))
	_offhand = EnemyModelKit.joint(_arm_l, Vector3(0, -al, 0))
	_build_weapon(_weapon, s["weapon"])
	_build_offhand(_offhand, s["offhand"])


func _build_weapon(w: Node3D, kind: StringName) -> void:
	var sc := 1.0 if stats.enemy_type != &"goblin_raider" else 0.75
	match kind:
		&"club":
			EnemyModelKit.part(w, EnemyModelKit.cyl(0.075, 0.035, 0.65), Palette.BARK, Vector3(0, -0.3, 0), Vector3(180, 0, 0))
			for i in 3:
				EnemyModelKit.part(w, EnemyModelKit.prism(Vector3(0.05, 0.1, 0.05)), Palette.STEEL.darkened(0.3), Vector3(0.07 * cos(i * 2.1), -0.55, 0.07 * sin(i * 2.1)), Vector3(0, 0, -90 if i == 0 else 90))
		&"spear":
			EnemyModelKit.part(w, EnemyModelKit.cyl(0.022, 0.022, 1.5), Palette.BARK, Vector3(0, -0.45, 0))
			EnemyModelKit.part(w, EnemyModelKit.prism(Vector3(0.1, 0.24, 0.03)), Palette.RUST, Vector3(0, -1.3, 0), Vector3(180, 0, 0))
			EnemyModelKit.part(w, EnemyModelKit.box(Vector3(0.12, 0.05, 0.04)), Palette.CLOTH_RED, Vector3(0, -1.14, 0))
		&"sword":
			EnemyModelKit.part(w, EnemyModelKit.box(Vector3(0.07, 0.8, 0.02) * sc), Palette.STEEL, Vector3(0, -0.52 * sc, 0))
			EnemyModelKit.part(w, EnemyModelKit.box(Vector3(0.22, 0.04, 0.05) * sc), Palette.GOLD if stats.is_elite else Palette.LEATHER, Vector3(0, -0.1 * sc, 0))
			EnemyModelKit.part(w, EnemyModelKit.cyl(0.02, 0.02, 0.14), Palette.LEATHER, Vector3(0, -0.02, 0))
		&"axe":
			EnemyModelKit.part(w, EnemyModelKit.cyl(0.025, 0.025, 0.85), Palette.BARK, Vector3(0, -0.4, 0))
			EnemyModelKit.part(w, EnemyModelKit.box(Vector3(0.03, 0.26, 0.24)), Palette.STEEL.darkened(0.1), Vector3(0, -0.72, -0.11))
		&"bow":
			for i: int in [-1, 1]:
				EnemyModelKit.part(w, EnemyModelKit.cyl(0.018, 0.026, 0.62), Color(0.55, 0.4, 0.22), Vector3(0, -0.35 + i * 0.27, -0.05), Vector3(i * 14.0, 0, 0))
			EnemyModelKit.part(w, EnemyModelKit.box(Vector3(0.008, 1.12, 0.008)), Color(0.9, 0.9, 0.85), Vector3(0, -0.35, 0.06))


func _build_offhand(o: Node3D, kind: StringName) -> void:
	match kind:
		&"shield":
			var sh := EnemyModelKit.joint(o, Vector3(0, 0, -0.06), Vector3(deg_to_rad(90), 0, 0))
			EnemyModelKit.part(sh, EnemyModelKit.cyl(0.3, 0.3, 0.05, 18), Palette.CLOTH_BLUE.darkened(0.2), Vector3.ZERO)
			EnemyModelKit.part(sh, EnemyModelKit.cyl(0.08, 0.08, 0.07, 10), Palette.STEEL, Vector3(0, -0.02, 0))
			EnemyModelKit.part(sh, EnemyModelKit.torus(0.28, 0.32), Palette.STEEL.darkened(0.2), Vector3.ZERO)
		&"torch":
			var t := EnemyModelKit.joint(o, Vector3.ZERO, Vector3(deg_to_rad(-75), 0, 0))
			EnemyModelKit.part(t, EnemyModelKit.cyl(0.035, 0.025, 0.55), Palette.BARK, Vector3(0, 0.15, 0))
			EnemyModelKit.part(t, EnemyModelKit.cyl(0.05, 0.045, 0.08), Palette.LEATHER.darkened(0.3), Vector3(0, 0.42, 0))
			_torch_flame = EnemyModelKit.part(t, EnemyModelKit.sphere(0.09, 10), Palette.glow(Palette.FIRE, 3.0), Vector3(0, 0.52, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
			EnemyModelKit.part(t, EnemyModelKit.sphere(0.05, 8), Palette.glow(Color(1, 0.9, 0.5), 3.0), Vector3(0, 0.5, 0))
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


func _decorate(s: Dictionary) -> void:
	var hr: float = s["head_r"]
	var tl: float = s["torso_len"]
	var tw: float = s["torso_w"]
	match stats.enemy_type:
		&"goblin_raider":
			var skin: Color = s["skin"]
			for side: float in [-1.0, 1.0]:
				# long notched ears pointing sideways
				EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.12, 0.3, 0.04)), skin.darkened(0.1), Vector3(side * hr * 1.15, hr * 0.15, 0.02), Vector3(0, 0, -side * 75.0))
				# red war paint: two cheek stripes
				for i in 2:
					EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.07, 0.018, 0.02)), Palette.DANGER, Vector3(side * hr * 0.45, -hr * 0.18 - i * 0.04, -hr * 0.86), Vector3(0, side * 20.0, side * 15.0))
				# tusks
				EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.03, 0.06, 0.03)), Color(0.95, 0.92, 0.8), Vector3(side * hr * 0.22, -hr * 0.42, -hr * 0.88))
			EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.025, 0.12, 0.02)), Palette.DANGER, Vector3(0, hr * 0.55, -hr * 0.85))
			# leather skull cap with horns
			EnemyModelKit.part(_head, EnemyModelKit.sphere(hr * 1.04, 14), Palette.LEATHER.darkened(0.25), Vector3(0, hr * 0.5, 0.06), Vector3.ZERO, Vector3(1, 0.5, 1))
			for side: float in [-1.0, 1.0]:
				EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.06, 0.16, 0.06)), Color(0.85, 0.8, 0.65), Vector3(side * hr * 0.6, hr * 0.95, 0.05), Vector3(0, 0, -side * 25.0))
			# crude rusty shoulder plate with spikes (left)
			var pad := EnemyModelKit.joint(_torso, Vector3(-s["shoulder_w"] as float, tl * 0.95, 0))
			EnemyModelKit.part(pad, EnemyModelKit.sphere(0.1, 10), Palette.RUST, Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.7, 1.1))
			for i in 2:
				EnemyModelKit.part(pad, EnemyModelKit.prism(Vector3(0.04, 0.12, 0.04)), Palette.STEEL.darkened(0.3), Vector3(-0.03, 0.07, -0.04 + i * 0.08), Vector3(0, 0, 20))
		&"human_raider", &"raider_captain":
			var elite := stats.enemy_type == &"raider_captain"
			# red-black tabard
			EnemyModelKit.part(_torso, EnemyModelKit.box(Vector3(tw * 0.62, tl * 0.95, 0.02)), Palette.CLOTH_RED, Vector3(0, tl * 0.38, -s["torso_d"] as float * 0.55))
			EnemyModelKit.part(_torso, EnemyModelKit.box(Vector3(tw * 0.64, 0.06, 0.025)), Color(0.05, 0.04, 0.04), Vector3(0, tl * 0.55, -s["torso_d"] as float * 0.56))
			# steel helmet + nasal
			EnemyModelKit.part(_head, EnemyModelKit.sphere(hr * 1.08, 14), Palette.STEEL.darkened(0.15), Vector3(0, hr * 0.3, 0.01), Vector3.ZERO, Vector3(1, 0.65, 1))
			EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.025, hr * 0.7, 0.03)), Palette.STEEL.darkened(0.15), Vector3(0, hr * 0.25, -hr * 1.02))
			# stubble beard
			EnemyModelKit.part(_head, EnemyModelKit.sphere(hr * 0.7, 10), Color(0.25, 0.17, 0.1), Vector3(0, -hr * 0.55, -hr * 0.45), Vector3.ZERO, Vector3(1.1, 0.6, 0.8))
			for side: float in [-1.0, 1.0]:
				EnemyModelKit.part(_torso, EnemyModelKit.sphere(0.12 if elite else 0.1, 10), Palette.STEEL.darkened(0.25) if not elite else Color(0.15, 0.12, 0.12),
					Vector3(side * (s["shoulder_w"] as float), tl * 0.95, 0), Vector3.ZERO, Vector3(1.2, 0.75, 1.1))
			if elite:
				for side: float in [-1.0, 1.0]:
					EnemyModelKit.part(_torso, EnemyModelKit.torus(0.1, 0.13), Palette.GOLD, Vector3(side * (s["shoulder_w"] as float), tl * 0.92, 0), Vector3(0, 0, 90))
				# crest plume and cape
				EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(0.05, 0.16, hr * 1.7)), Palette.DANGER, Vector3(0, hr * 1.05, 0.03))
				_cape = EnemyModelKit.joint(_torso, Vector3(0, tl * 0.95, s["torso_d"] as float * 0.5))
				EnemyModelKit.part(_cape, EnemyModelKit.box(Vector3(tw * 1.05, tl + _hip_height * 0.7, 0.03)), Palette.CLOTH_RED.darkened(0.2), Vector3(0, -(tl + _hip_height * 0.7) * 0.5, 0.02))
				EnemyModelKit.part(_torso, EnemyModelKit.cyl(tw * 0.52, tw * 0.52, 0.05), Palette.GOLD, Vector3(0, tl * 0.1, 0), Vector3.ZERO, Vector3(1.05, 1, (s["torso_d"] as float) / tw * 1.12))
		&"adventurer":
			match variant % 3:
				0:
					EnemyModelKit.part(_head, EnemyModelKit.sphere(hr * 1.07, 14), Color(0.35, 0.22, 0.12), Vector3(0, hr * 0.25, 0.04), Vector3.ZERO, Vector3(1, 0.75, 1))
					EnemyModelKit.part(_torso, EnemyModelKit.box(Vector3(0.06, tl * 1.1, 0.03)), Palette.LEATHER, Vector3(0.05, tl * 0.5, -(s["torso_d"] as float) * 0.55), Vector3(0, 0, 35))
				1:
					EnemyModelKit.part(_head, EnemyModelKit.sphere(hr * 1.08, 14), Color(0.75, 0.4, 0.18), Vector3(0, hr * 0.22, 0.05), Vector3.ZERO, Vector3(1, 0.8, 1))
					EnemyModelKit.part(_head, EnemyModelKit.capsule(0.05, 0.3), Color(0.75, 0.4, 0.18), Vector3(0, -hr * 0.1, hr * 1.05), Vector3(25, 0, 0))
				_:
					var hair := Color(0.88, 0.88, 0.82)
					EnemyModelKit.part(_head, EnemyModelKit.sphere(hr * 1.08, 14), hair, Vector3(0, hr * 0.2, 0.05), Vector3.ZERO, Vector3(1, 0.8, 1))
					EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(hr * 1.6, hr * 1.3, 0.04)), hair, Vector3(0, -hr * 0.3, hr * 0.85))
					for side: float in [-1.0, 1.0]:
						# long pointed elf ears, swept up and back
						EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.06, 0.24, 0.035)), s["skin"], Vector3(side * hr * 1.0, hr * 0.25, 0.05), Vector3(-30, 0, -side * 55.0))
			# travel satchel
			EnemyModelKit.part(_torso, EnemyModelKit.box(Vector3(0.16, 0.18, 0.09)), Palette.LEATHER, Vector3(-tw * 0.45, tl * 0.15, 0.08))


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
		arm_r = 1.3
		arm_r_z = -0.7
		arm_l = 1.35
		arm_l_z = 0.3
		torso_x = -0.12
		crouch = 0.06
	match state:
		State.ATTACK:
			var atk := current_attack
			if attack_phase == Phase.WINDUP:
				var k := clampf(_phase_time / maxf(atk.windup * 0.55, 0.01), 0.0, 1.0)  # reach pose early, then HOLD
				var shake := sin(_time * 40.0) * 0.03 * clampf(_phase_time / atk.windup, 0.0, 1.0) if atk.heavy else 0.0
				var p := _windup_pose(atk.anim)
				arm_r = lerpf(arm_r, p.x, k) + shake
				arm_l = lerpf(arm_l, p.y, k)
				torso_x = lerpf(torso_x, p.z, k)
				torso_y = lerpf(0.0, p.w, k)
				crouch = 0.06 * k
				leg_l = -0.25 * k
				leg_r = 0.3 * k
				rate = 10.0
			else:
				var p2 := _strike_pose(atk.anim)
				arm_r = p2.x
				arm_l = p2.y
				torso_x = p2.z
				torso_y = p2.w
				leg_l = 0.45
				leg_r = -0.3
				crouch = 0.08
				rate = 32.0
		State.RECOVER:
			if current_attack and _state_time < _state_len * 0.45:
				var p3 := _strike_pose(current_attack.anim)  # follow-through hold
				arm_r = p3.x
				arm_l = p3.y
				torso_x = p3.z * 0.8
				torso_y = p3.w
				leg_l = 0.35
				leg_r = -0.25
				crouch = 0.06
			rate = 6.0
		State.HURT:
			torso_x = 0.35
			head_x = 0.35
			arm_l = -0.4
			arm_r = -0.3
			arm_l_z = -0.5
			arm_r_z = 0.5
			rate = 22.0
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


## x = right arm, y = left arm, z = torso pitch (+ = lean back), w = torso yaw
func _windup_pose(anim: StringName) -> Vector4:
	match anim:
		&"chop": return Vector4(2.8, 0.6, 0.18, 0.35)
		&"thrust": return Vector4(-0.6, 0.9, 0.1, 0.55)
		&"sweep": return Vector4(1.5, 0.3, 0.05, 1.1)
		&"flame": return Vector4(0.3, 2.9, 0.25, 0.5)
	return Vector4(2.5, 0.4, 0.15, 0.3)


func _strike_pose(anim: StringName) -> Vector4:
	match anim:
		&"chop": return Vector4(1.0, -0.2, -0.35, -0.15)
		&"thrust": return Vector4(1.55, -0.3, -0.25, -0.35)
		&"sweep": return Vector4(1.5, -0.2, -0.15, -1.1)
		&"flame": return Vector4(0.2, 1.5, -0.3, -0.6)
	return Vector4(1.0, 0.0, -0.3, 0.0)


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
