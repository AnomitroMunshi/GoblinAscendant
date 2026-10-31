extends RefCounted
## Unarmed (knife holstered): alternating punch combo with torso rotation and a
## stable opposite guard, plus a front kick (chamber -> extend -> knee-first
## retract -> plant). Q raises a boxing guard. See ChoreoLibrary for the format.


static func data() -> Dictionary:
	return {
		"id": &"unarmed",
		"label": "Unarmed",
		"slot": &"none",
		"category": &"none",
		"hands": 0,
		"stages": [],
		"grip": {"main_hand": &"none", "off_role": &"guard"},
		"carry": {"arm_l": Vector3(0.03, 0, -0.16), "fore_l": 0.16, "arm_r": Vector3(0.03, 0, 0.16), "fore_r": 0.18},
		"move": {"fore_r": 0.25, "arm_r_bias": 0.3, "arm_r_swing": 0.7},
		"guard": {"reduction": 0.35, "boxing": true, "pose": {
			# Boxing guard: elbows in, fists beside the jaw, chin tucked.
			"torso": Vector3(0.12, -0.08, 0), "head": Vector3(0.10, 0.08, 0),
			"arm_l": Vector3(1.30, 0, 0.20), "fore_l": 1.40, "arm_r": Vector3(1.25, 0, -0.20), "fore_r": 1.45}},
		"cast": {"free_hand": &"l"},
		"light": [_punch1(), _punch2(), _punch3()],
		"heavy": _kick(),
	}


static func _stance(front: float) -> Dictionary:
	# Small boxing stance: left foot leads, weight shifts with each punch.
	return {"leg_l": Vector3(0.18 + front, 0, -0.05), "shin_l": -0.18 - front * 0.5, "leg_r": Vector3(-0.16 - front * 0.5, 0, 0.05), "shin_r": -0.12}


static func _punch1() -> Dictionary:
	var antic := {"torso": Vector3(0.08, -0.25, 0), "head": Vector3(0.0, 0.18, 0), "arm_l": Vector3(0.8, 0, -0.2), "fore_l": 1.3, "arm_r": Vector3(0.85, 0, 0.2), "fore_r": 1.4}
	antic.merge(_stance(0.0))
	var contact := {"torso": Vector3(0.18, 0.25, 0), "head": Vector3(-0.05, -0.18, 0), "arm_r": Vector3(1.55, 0, 0.12), "fore_r": 0.08, "arm_l": Vector3(0.8, 0, -0.25), "fore_l": 1.3}
	contact.merge(_stance(0.12))
	return {
		"id": &"punch1", "anim": &"punch1", "attack_id": &"punch1", "heavy": false,
		"windup": 0.10, "active": 0.09, "recovery": 0.23, "chain_open": 0.25,
		"mult": 0.45, "stagger": 0.2, "knock": 1.0, "stamina": 5.0,
		"footwork": {"lunge": 0.13, "time": 0.12},
		"hitbox": {"size": Vector3(0.55, 0.72, 0.42), "offset": Vector3(0, 0.70, -0.38)},
		"trail": {"style": &"none"},
		"sfx": &"swing_light",
		"poses": {"antic": antic, "contact": contact},
		"curve": [[1.0, "antic", "out2"], [1.7, "contact", "out3"], [2.04, "contact", "linear"], [3.0, "rest", "smooth"]],
	}


static func _punch2() -> Dictionary:
	var antic := {"torso": Vector3(0.1, 0.3, 0), "head": Vector3(0.0, -0.2, 0), "arm_r": Vector3(0.8, 0, 0.25), "fore_r": 1.35, "arm_l": Vector3(0.8, 0, -0.25), "fore_l": 1.4}
	antic.merge(_stance(0.05))
	var contact := {"torso": Vector3(0.2, -0.35, 0), "head": Vector3(-0.05, 0.25, 0), "arm_l": Vector3(1.55, 0, -0.12), "fore_l": 0.06, "arm_r": Vector3(0.8, 0, 0.25), "fore_r": 1.3}
	contact.merge(_stance(0.18))
	return {
		"id": &"punch2", "anim": &"punch2", "attack_id": &"punch2", "heavy": false,
		"windup": 0.12, "active": 0.09, "recovery": 0.25, "chain_open": 0.25,
		"mult": 0.50, "stagger": 0.25, "knock": 1.4, "stamina": 5.0,
		"footwork": {"lunge": 0.13, "time": 0.12},
		"hitbox": {"size": Vector3(0.55, 0.72, 0.42), "offset": Vector3(0, 0.70, -0.38)},
		"trail": {"style": &"none"},
		"sfx": &"swing_light",
		"poses": {"antic": antic, "contact": contact},
		"curve": [[1.0, "antic", "out2"], [1.7, "contact", "out3"], [2.04, "contact", "linear"], [3.0, "rest", "smooth"]],
	}


static func _punch3() -> Dictionary:
	var antic := {"torso": Vector3(-0.1, -0.4, 0), "head": Vector3(0.05, 0.3, 0), "arm_r": Vector3(0.5, 0, 0.65), "fore_r": 1.25, "arm_l": Vector3(0.8, 0, -0.25), "fore_l": 1.35}
	antic.merge(_stance(0.0))
	var contact := {"torso": Vector3(0.25, 0.4, 0), "head": Vector3(-0.08, -0.3, 0), "arm_r": Vector3(1.45, 0, -0.45), "fore_r": 0.75, "arm_l": Vector3(0.8, 0, -0.25), "fore_l": 1.35}
	contact.merge(_stance(0.25))
	return {
		"id": &"punch3", "anim": &"punch3", "attack_id": &"punch3", "heavy": false,
		"windup": 0.18, "active": 0.10, "recovery": 0.35, "chain_open": 0.25,
		"mult": 0.70, "stagger": 0.45, "knock": 2.5, "stamina": 5.0,
		"footwork": {"lunge": 0.18, "time": 0.14},
		"hitbox": {"size": Vector3(0.55, 0.72, 0.42), "offset": Vector3(0, 0.70, -0.38)},
		"trail": {"style": &"none"},
		"sfx": &"swing_light",
		"poses": {"antic": antic, "contact": contact},
		"curve": [[1.0, "antic", "out2"], [1.7, "contact", "out3"], [2.04, "contact", "linear"], [3.0, "rest", "smooth"]],
	}


static func _kick() -> Dictionary:
	return {
		"id": &"kick", "anim": &"kick", "attack_id": &"kick", "heavy": true,
		"windup": 0.32, "active": 0.20, "recovery": 0.48, "chain_open": 0.25,
		"mult": 0.9, "stagger": 0.65, "knock": 4.5, "stamina": 14.0,
		"footwork": {"lunge": 0.24, "time": 0.2},
		"hitbox": {"size": Vector3(0.55, 0.72, 0.56), "offset": Vector3(0, 0.45, -0.48)},
		"trail": {"style": &"none"},
		"sfx": &"swing_heavy",
		"poses": {
			"chamber": {"torso": Vector3(-0.15, 0.1, 0), "leg_r": Vector3(1.1, 0, 0.05), "shin_r": -1.2, "leg_l": Vector3(0.05, 0, -0.05), "shin_l": -0.18,
				"arm_l": Vector3(0.75, 0, -0.3), "fore_l": 1.25, "arm_r": Vector3(0.65, 0, 0.3), "fore_r": 1.2},
			"contact": {"torso": Vector3(-0.25, -0.1, 0), "leg_r": Vector3(1.45, 0, 0.05), "shin_r": -0.08, "leg_l": Vector3(0.1, 0, -0.05), "shin_l": -0.12,
				"arm_l": Vector3(0.7, 0, -0.4), "fore_l": 1.2, "arm_r": Vector3(0.35, 0, 0.6), "fore_r": 0.8},
			# Knee-first retraction back to the chamber, then the foot plants.
			"retract": {"torso": Vector3(-0.1, -0.03, 0), "leg_r": Vector3(1.1, 0, 0.05), "shin_r": -1.2,
				"arm_l": Vector3(0.6, 0, -0.3), "fore_l": 1.0, "arm_r": Vector3(0.3, 0, 0.4), "fore_r": 0.7},
			"plant": {"leg_r": Vector3(0.2, 0, 0.04), "shin_r": -0.4, "torso": Vector3(0.0, 0, 0)},
		},
		"curve": [[1.0, "chamber", "out2"], [1.55, "contact", "out3"], [2.0, "contact", "linear"], [2.45, "retract", "smooth"], [2.75, "plant", "smooth"], [3.0, "rest", "smooth"]],
	}
