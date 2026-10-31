extends RefCounted
## Rough knife: diagonal cut -> backhand cut -> quick finishing stab; heavy is a
## committed lunging thrust. One-handed (right); the free hand guards the ribs
## or balances, never mimics a second grip. Short reach, quick recovery.
## Uses FK wrist angles ("sword" joint) because the knife mesh lives in the model.


static func data() -> Dictionary:
	return {
		"id": &"knife",
		"label": "Rough knife",
		"slot": &"knife",
		"category": &"edge",
		"hands": 1,
		"stages": [],
		"grip": {"main_hand": &"r", "off_role": &"guard"},
		"carry": {"arm_l": Vector3(0.1, 0, -0.16), "fore_l": 0.35, "arm_r": Vector3(0.25, 0, 0.16), "fore_r": 0.75, "sword": Vector3(-0.35, 0, 0)},
		"move": {"fore_r": 0.7, "arm_r_bias": 0.3, "arm_r_swing": 0.7},
		"guard": {"reduction": 0.8, "pose": {
			"torso": Vector3(0.18, 0, 0), "head": Vector3(-0.12, 0, 0),
			"arm_r": Vector3(1.25, 0, -0.35), "fore_r": 0.95, "sword": Vector3(0, 1.45, 0),
			"arm_l": Vector3(1.0, 0, 0.25), "fore_l": 1.35}},
		"stow": {"parent": &"hips", "pos": Vector3(0.145, -0.005, 0.055), "dir": Vector3(0, -1, 0), "up": Vector3(0, 0, 1)},
		"cast": {"free_hand": &"l"},
		"light": [_cut1(), _cut2(), _stab()],
		"heavy": _thrust(),
	}


static func _cut1() -> Dictionary:
	return {
		"id": &"knife_cut1", "anim": &"light1", "attack_id": &"light1", "heavy": false,
		"windup": 0.13, "active": 0.10, "recovery": 0.27, "chain_open": 0.25,
		"mult": 1.0, "stagger": 0.3, "knock": 2.5, "stamina": 5.0,
		"footwork": {"lunge": 0.32, "time": 0.18},
		"hitbox": {"size": Vector3(0.9, 1.0, 0.7), "offset": Vector3(0, 0.6, -0.5)},
		"trail": {"style": &"arc", "from": 85.0, "to": -80.0, "tilt": -28.0, "height": 0.55, "radius": 0.63, "inner": 0.62},
		"sfx": &"swing_light",
		"poses": {
			# diagonal cut, right -> left
			"antic": {"torso": Vector3(0.0, -0.75, 0), "head": Vector3(0, 0.35, 0), "arm_r": Vector3(1.5, 0, 1.15), "fore_r": 0.7, "sword": Vector3(0, -0.3, 0),
				"arm_l": Vector3(0.5, 0, -0.45), "fore_l": 0.6, "leg_l": Vector3(0.3, 0, 0), "shin_l": -0.15, "leg_r": Vector3(-0.25, 0, 0), "shin_r": -0.3},
			"contact": {"torso": Vector3(0.22, 0.75, 0), "head": Vector3(-0.05, -0.4, 0), "arm_r": Vector3(1.25, 0, -0.75), "fore_r": 0.15, "sword": Vector3(0, 0.6, 0),
				"arm_l": Vector3(-0.3, 0, -0.6), "fore_l": 0.5, "leg_l": Vector3(0.45, 0, 0), "shin_l": -0.2, "leg_r": Vector3(-0.35, 0, 0), "shin_r": -0.1},
			"follow": {"torso": Vector3(0.26, 0.85, 0), "arm_r": Vector3(1.1, 0, -0.95), "fore_r": 0.3, "sword": Vector3(0, 0.75, 0)},
		},
		"curve": [[1.0, "antic"], [1.8, "contact"], [2.3, "follow", "smooth"], [3.0, "rest"]],
	}


static func _cut2() -> Dictionary:
	return {
		"id": &"knife_cut2", "anim": &"light2", "attack_id": &"light2", "heavy": false,
		"windup": 0.11, "active": 0.10, "recovery": 0.27, "chain_open": 0.25,
		"mult": 1.1, "stagger": 0.3, "knock": 2.5, "stamina": 5.0,
		"footwork": {"lunge": 0.32, "time": 0.18},
		"hitbox": {"size": Vector3(0.9, 1.0, 0.7), "offset": Vector3(0, 0.6, -0.5)},
		"trail": {"style": &"arc", "from": -85.0, "to": 80.0, "tilt": 24.0, "height": 0.55, "radius": 0.63, "inner": 0.62},
		"sfx": &"swing_light",
		"poses": {
			# backhand cut, left -> right
			"antic": {"torso": Vector3(0.05, 0.85, 0), "head": Vector3(0, -0.4, 0), "arm_r": Vector3(1.55, 0, -0.95), "fore_r": 1.1, "sword": Vector3(0, 0.9, 0),
				"arm_l": Vector3(0.2, 0, -0.3), "fore_l": 0.6, "leg_r": Vector3(0.3, 0, 0), "shin_r": -0.15, "leg_l": Vector3(-0.2, 0, 0), "shin_l": -0.15},
			"contact": {"torso": Vector3(0.2, -0.7, 0), "head": Vector3(-0.05, 0.35, 0), "arm_r": Vector3(1.35, 0, 1.25), "fore_r": 0.2, "sword": Vector3(0, -0.5, 0),
				"arm_l": Vector3(0.5, 0, -0.7), "fore_l": 0.7, "leg_r": Vector3(0.45, 0, 0), "shin_r": -0.2, "leg_l": Vector3(-0.35, 0, 0), "shin_l": -0.1},
			"follow": {"torso": Vector3(0.22, -0.82, 0), "arm_r": Vector3(1.2, 0, 1.4), "fore_r": 0.3, "sword": Vector3(0, -0.65, 0)},
		},
		"curve": [[1.0, "antic"], [1.8, "contact"], [2.3, "follow", "smooth"], [3.0, "rest"]],
	}


static func _stab() -> Dictionary:
	return {
		"id": &"knife_stab", "anim": &"light3", "attack_id": &"light3", "heavy": false,
		"windup": 0.2, "active": 0.12, "recovery": 0.42, "chain_open": 0.25,
		"mult": 1.5, "stagger": 0.6, "knock": 5.0, "stamina": 5.0,
		"footwork": {"lunge": 0.5, "time": 0.22},
		"hitbox": {"size": Vector3(0.6, 0.8, 0.8), "offset": Vector3(0, 0.62, -0.58)},
		"trail": {"style": &"thrust", "height": 0.6, "from": 0.25, "to": 0.95, "width": 0.07},
		"sfx": &"swing_light",
		"poses": {
			# Chamber the knife at the hip, point forward, free hand reaches out to measure.
			"antic": {"torso": Vector3(-0.05, -0.45, 0), "head": Vector3(0.05, 0.4, 0),
				"arm_r": Vector3(-0.35, 0, 0.3), "fore_r": 1.95, "sword": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(1.05, 0, -0.1), "fore_l": 0.45,
				"leg_l": Vector3(0.3, 0, -0.04), "shin_l": -0.3, "leg_r": Vector3(-0.25, 0, 0.04), "shin_r": -0.45},
			# Straight-line stab driven by the hips; free hand pulls back to the ribs.
			"contact": {"torso": Vector3(0.3, 0.4, 0), "head": Vector3(-0.15, -0.35, 0),
				"arm_r": Vector3(1.42, 0, -0.08), "fore_r": 0.05, "sword": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(0.25, 0, -0.45), "fore_l": 1.45,
				"leg_l": Vector3(0.7, 0, -0.04), "shin_l": -0.7, "leg_r": Vector3(-0.5, 0, 0.04), "shin_r": -0.1},
			"retract": {"torso": Vector3(0.15, 0.15, 0), "arm_r": Vector3(0.6, 0, 0.15), "fore_r": 1.2, "sword": Vector3(-1.0, 0, 0)},
		},
		"curve": [[1.0, "antic"], [1.6, "contact"], [2.25, "contact", "linear"], [2.6, "retract", "smooth"], [3.0, "rest"]],
	}


static func _thrust() -> Dictionary:
	return {
		"id": &"knife_thrust", "anim": &"heavy", "attack_id": &"heavy", "heavy": true,
		"windup": 0.42, "active": 0.14, "recovery": 0.52, "chain_open": 0.25,
		"mult": 2.2, "stagger": 0.95, "knock": 8.0, "stamina": 14.0,
		"footwork": {"lunge": 0.7, "time": 0.26},
		"hitbox": {"size": Vector3(0.6, 0.8, 0.85), "offset": Vector3(0, 0.6, -0.62)},
		"trail": {"style": &"thrust", "height": 0.58, "from": 0.2, "to": 1.05, "width": 0.1, "heavy": true},
		"sfx": &"swing_heavy",
		"poses": {
			# Deep coil: weight on the back leg, knife drawn behind the hip, free hand aims.
			"antic": {"torso": Vector3(-0.15, -0.6, 0), "head": Vector3(0.1, 0.5, 0),
				"arm_r": Vector3(-0.55, 0, 0.35), "fore_r": 2.1, "sword": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(1.25, 0, -0.08), "fore_l": 0.3,
				"leg_l": Vector3(0.35, 0, -0.05), "shin_l": -0.35, "leg_r": Vector3(-0.3, 0, 0.05), "shin_r": -0.75},
			# Committed lunge: front knee bent, back leg long, full arm extension.
			"contact": {"torso": Vector3(0.5, 0.5, 0), "head": Vector3(-0.35, -0.4, 0),
				"arm_r": Vector3(1.48, 0, -0.1), "fore_r": 0.0, "sword": Vector3(-1.52, 0, 0),
				"arm_l": Vector3(0.1, 0, -0.55), "fore_l": 1.3,
				"leg_l": Vector3(0.95, 0, -0.05), "shin_l": -1.0, "leg_r": Vector3(-0.7, 0, 0.05), "shin_r": -0.05},
			"recover": {"torso": Vector3(0.2, 0.2, 0), "arm_r": Vector3(0.7, 0, 0.1), "fore_r": 1.0, "sword": Vector3(-0.9, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.05), "shin_l": -0.45, "leg_r": Vector3(-0.3, 0, 0.05), "shin_r": -0.2},
		},
		"curve": [[1.0, "antic"], [1.6, "contact"], [2.3, "contact", "linear"], [2.7, "recover", "smooth"], [3.0, "rest"]],
	}
