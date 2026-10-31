extends RefCounted
## One-handed short sword: diagonal cut -> returning horizontal cut -> finishing
## thrust; heavy is a committed descending cut. Wider arcs and more reach than
## the knife. Main-hand poses use IK hand targets ("hand_r", hips space, metres)
## plus a weapon direction ("aim") and edge direction ("edge") solved at the
## wrist, so the blade path is authored directly. Hips space: +X right, +Y up,
## -Z forward; right shoulder ~(0.16, 0.28, 0), arm reach ~0.34.


static func data() -> Dictionary:
	return {
		"id": &"sword",
		"label": "Short sword",
		"slot": &"main",
		"category": &"edge",
		"hands": 1,
		"stages": [&"goblin"],
		"grip": {"main_hand": &"r", "off_role": &"guard"},
		"carry": {"hand_r": Vector3(0.19, 0.0, -0.13), "aim": Vector3(-0.05, -0.35, -1.0), "edge": Vector3(0, -1, 0.3),
			"arm_l": Vector3(0.25, 0, -0.18), "fore_l": 0.7},
		"move": {"hand_swing": 0.05},
		"guard": {"reduction": 0.8, "pose": {
			"torso": Vector3(0.15, -0.1, 0), "head": Vector3(-0.1, 0.08, 0),
			"hand_r": Vector3(0.1, 0.2, -0.24), "aim": Vector3(-0.4, 0.9, -0.25), "edge": Vector3(0, 0, -1),
			"arm_l": Vector3(0.95, 0, -0.05), "fore_l": 1.35}},
		"stow": {"parent": &"hips", "pos": Vector3(-0.16, 0.04, 0.03), "dir": Vector3(-0.3, -1.0, 0.35), "up": Vector3(0, 0, -1)},
		"cast": {"free_hand": &"l"},
		"light": [_cut1(), _cut2(), _thrust()],
		"heavy": _descending(),
	}


static func _cut1() -> Dictionary:
	return {
		"id": &"sword_cut1", "anim": &"sword_cut1", "attack_id": &"sword_cut1", "heavy": false,
		"windup": 0.15, "active": 0.11, "recovery": 0.30, "chain_open": 0.3,
		"mult": 1.15, "stagger": 0.35, "knock": 3.0, "stamina": 6.0,
		"footwork": {"lunge": 0.35, "time": 0.2},
		"hitbox": {"size": Vector3(1.3, 1.0, 0.85), "offset": Vector3(0, 0.6, -0.6)},
		"trail": {"style": &"arc", "from": 80.0, "to": -95.0, "tilt": -35.0, "height": 0.6, "radius": 0.95, "inner": 0.55},
		"sfx": &"swing_light",
		"poses": {
			# High right, blade cocked back over the shoulder; free hand forward.
			"antic": {"torso": Vector3(-0.05, -0.6, 0), "head": Vector3(0, 0.45, 0),
				"hand_r": Vector3(0.28, 0.44, 0.04), "aim": Vector3(0.45, 0.65, 0.6), "edge": Vector3(-0.3, 0.4, -0.85),
				"arm_l": Vector3(0.95, 0, -0.2), "fore_l": 0.6,
				"leg_l": Vector3(0.28, 0, -0.04), "shin_l": -0.2, "leg_r": Vector3(-0.28, 0, 0.05), "shin_r": -0.35},
			# Mid-sweep: blade tip out to the upper right, already travelling forward.
			"sweep": {"torso": Vector3(0.08, -0.1, 0), "head": Vector3(0, 0.1, 0),
				"hand_r": Vector3(0.24, 0.3, -0.2), "aim": Vector3(0.55, 0.5, -0.65), "edge": Vector3(-0.5, -0.4, -0.6)},
			# Blade crosses the centre line at chest height.
			"contact": {"torso": Vector3(0.2, 0.35, 0), "head": Vector3(-0.05, -0.3, 0),
				"hand_r": Vector3(0.03, 0.1, -0.34), "aim": Vector3(-0.6, -0.25, -0.75), "edge": Vector3(-0.6, -0.7, 0.3),
				"arm_l": Vector3(0.45, 0, -0.45), "fore_l": 1.35,
				"leg_l": Vector3(0.55, 0, -0.04), "shin_l": -0.5, "leg_r": Vector3(-0.42, 0, 0.05), "shin_r": -0.08},
			# Follow through low left; weight stays on the front foot.
			"follow": {"torso": Vector3(0.28, 0.7, 0), "head": Vector3(-0.08, -0.55, 0),
				"hand_r": Vector3(-0.14, 0.0, -0.24), "aim": Vector3(-0.85, -0.45, -0.1), "edge": Vector3(0.0, -0.6, 0.8)},
		},
		"curve": [[1.0, "antic"], [1.2, "sweep", "in2"], [1.5, "contact", "linear"], [2.3, "follow", "out2"], [3.0, "rest"]],
	}


static func _cut2() -> Dictionary:
	return {
		"id": &"sword_cut2", "anim": &"sword_cut2", "attack_id": &"sword_cut2", "heavy": false,
		"windup": 0.13, "active": 0.11, "recovery": 0.30, "chain_open": 0.3,
		"mult": 1.2, "stagger": 0.35, "knock": 3.0, "stamina": 6.0,
		"footwork": {"lunge": 0.3, "time": 0.2},
		"hitbox": {"size": Vector3(1.4, 0.9, 0.85), "offset": Vector3(0, 0.62, -0.58)},
		"trail": {"style": &"arc", "from": -95.0, "to": 95.0, "tilt": 6.0, "height": 0.62, "radius": 0.95, "inner": 0.55},
		"sfx": &"swing_light",
		"poses": {
			# Cocked across the body, blade pointing back-left, edge leading forward.
			"antic": {"torso": Vector3(0.08, 0.6, 0), "head": Vector3(0, -0.45, 0),
				"hand_r": Vector3(-0.08, 0.2, -0.16), "aim": Vector3(-0.9, 0.08, 0.4), "edge": Vector3(0.2, 0.0, -1.0),
				"arm_l": Vector3(0.35, 0, -0.5), "fore_l": 1.1,
				"leg_l": Vector3(0.4, 0, -0.04), "shin_l": -0.35, "leg_r": Vector3(-0.32, 0, 0.05), "shin_r": -0.12},
			"contact": {"torso": Vector3(0.15, -0.15, 0), "head": Vector3(-0.05, 0.1, 0),
				"hand_r": Vector3(0.1, 0.2, -0.34), "aim": Vector3(0.15, 0.0, -1.0), "edge": Vector3(1, 0, 0),
				"arm_l": Vector3(0.6, 0, -0.35), "fore_l": 1.2},
			"follow": {"torso": Vector3(0.15, -0.65, 0), "head": Vector3(0, 0.5, 0),
				"hand_r": Vector3(0.3, 0.2, -0.12), "aim": Vector3(0.95, 0.05, 0.1), "edge": Vector3(0.1, 0, 1),
				"arm_l": Vector3(0.8, 0, -0.2), "fore_l": 1.0},
		},
		"curve": [[1.0, "antic"], [1.45, "contact", "linear"], [2.3, "follow", "out2"], [3.0, "rest"]],
	}


static func _thrust() -> Dictionary:
	return {
		"id": &"sword_thrust", "anim": &"sword_thrust", "attack_id": &"sword_thrust", "heavy": false,
		"windup": 0.19, "active": 0.11, "recovery": 0.42, "chain_open": 0.3,
		"mult": 1.55, "stagger": 0.6, "knock": 5.0, "stamina": 6.0,
		"footwork": {"lunge": 0.5, "time": 0.22},
		"hitbox": {"size": Vector3(0.5, 0.7, 1.0), "offset": Vector3(0, 0.62, -0.7)},
		"trail": {"style": &"thrust", "height": 0.62, "from": 0.35, "to": 1.25, "width": 0.08},
		"sfx": &"swing_light",
		"poses": {
			"antic": {"torso": Vector3(-0.05, -0.55, 0), "head": Vector3(0.05, 0.45, 0),
				"hand_r": Vector3(0.2, 0.14, 0.06), "aim": Vector3(-0.05, 0.05, -1.0), "edge": Vector3(1, 0, 0),
				"arm_l": Vector3(1.15, 0, -0.08), "fore_l": 0.35,
				"leg_l": Vector3(0.3, 0, -0.04), "shin_l": -0.3, "leg_r": Vector3(-0.28, 0, 0.05), "shin_r": -0.5},
			"contact": {"torso": Vector3(0.3, 0.4, 0), "head": Vector3(-0.15, -0.35, 0),
				"hand_r": Vector3(0.02, 0.2, -0.4), "aim": Vector3(-0.04, 0.0, -1.0), "edge": Vector3(1, 0, 0),
				"arm_l": Vector3(0.2, 0, -0.5), "fore_l": 1.4,
				"leg_l": Vector3(0.75, 0, -0.04), "shin_l": -0.75, "leg_r": Vector3(-0.55, 0, 0.05), "shin_r": -0.05},
			"retract": {"torso": Vector3(0.15, 0.1, 0), "hand_r": Vector3(0.14, 0.1, -0.2), "aim": Vector3(-0.05, -0.1, -1.0), "edge": Vector3(0.6, -0.8, 0)},
		},
		"curve": [[1.0, "antic"], [1.55, "contact", "out3"], [2.2, "contact", "linear"], [2.6, "retract", "smooth"], [3.0, "rest"]],
	}


static func _descending() -> Dictionary:
	return {
		"id": &"sword_heavy", "anim": &"sword_heavy", "attack_id": &"sword_heavy", "heavy": true,
		"windup": 0.46, "active": 0.13, "recovery": 0.56, "chain_open": 0.3,
		"mult": 2.3, "stagger": 0.95, "knock": 8.0, "stamina": 15.0,
		"footwork": {"lunge": 0.55, "time": 0.24},
		"hitbox": {"size": Vector3(0.75, 1.2, 0.95), "offset": Vector3(0, 0.6, -0.65)},
		"trail": {"style": &"arc", "from": 160.0, "to": -25.0, "tilt": 90.0, "height": 0.55, "radius": 1.0, "inner": 0.55, "heavy": true},
		"sfx": &"swing_heavy",
		"poses": {
			# Blade high over the head and back; chest open, back knee loaded.
			"antic": {"torso": Vector3(-0.3, -0.2, 0), "head": Vector3(0.2, 0.15, 0),
				"hand_r": Vector3(0.12, 0.6, 0.06), "aim": Vector3(0.1, 0.45, 1.0), "edge": Vector3(0, 1, -0.4),
				"arm_l": Vector3(1.5, 0, -0.25), "fore_l": 0.5,
				"leg_l": Vector3(0.3, 0, -0.04), "shin_l": -0.3, "leg_r": Vector3(-0.3, 0, 0.05), "shin_r": -0.55},
			"contact": {"torso": Vector3(0.55, 0.05, 0), "head": Vector3(-0.4, 0, 0),
				"hand_r": Vector3(0.03, 0.12, -0.38), "aim": Vector3(0, -0.4, -1.0), "edge": Vector3(0, -1, -0.3),
				"arm_l": Vector3(0.05, 0, -0.5), "fore_l": 1.0,
				"leg_l": Vector3(0.9, 0, -0.04), "shin_l": -1.0, "leg_r": Vector3(-0.7, 0, 0.05), "shin_r": -0.08},
			"follow": {"torso": Vector3(0.6, 0.05, 0), "hand_r": Vector3(0.03, -0.02, -0.32), "aim": Vector3(0.05, -0.85, -0.5), "edge": Vector3(0, -0.5, 0.85)},
		},
		"curve": [[1.0, "antic"], [1.6, "contact", "in2"], [2.3, "follow", "out2"], [3.0, "rest"]],
	}
