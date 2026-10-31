extends RefCounted
## Sling (carried ranged slot): LMB = quick side-arm snap release, RMB = full
## overhead wind-up with two-plus turns and a harder release. The model spins the
## cords/pouch during the windup ("spin" data) and the controller launches a
## ChoreoSlingStone at the start of the active window (visible release).
## FK arm poses; the off hand points at the target during the heavy wind-up.


static func data() -> Dictionary:
	return {
		"id": &"sling",
		"label": "Sling",
		"slot": &"ranged",
		"category": &"ranged",
		"hands": 1,
		"stages": [],
		"grip": {"main_hand": &"r", "off_role": &"aim"},
		"carry": {"arm_l": Vector3(0.08, 0, -0.16), "fore_l": 0.3, "arm_r": Vector3(0.08, 0, 0.18), "fore_r": 0.35, "sword": Vector3(0.3, 0, 0)},
		"move": {"fore_r": 0.35, "arm_r_bias": 0.2, "arm_r_swing": 0.7},
		"guard": {"reduction": 0.35, "boxing": true, "pose": {
			"torso": Vector3(0.12, -0.08, 0), "head": Vector3(0.10, 0.08, 0),
			"arm_l": Vector3(1.30, 0, 0.20), "fore_l": 1.40, "arm_r": Vector3(1.25, 0, -0.20), "fore_r": 1.45}},
		"stow": {"parent": &"hips", "pos": Vector3(0.11, 0.01, -0.1), "dir": Vector3(1, 0, 0), "up": Vector3(0, 1, 0), "coiled": true},
		"cast": {"free_hand": &"l"},
		"light": [_snap()],
		"heavy": _overhead(),
	}


static func _snap() -> Dictionary:
	return {
		"id": &"sling_snap", "anim": &"sling_snap", "attack_id": &"sling_snap", "heavy": false,
		"windup": 0.36, "active": 0.08, "recovery": 0.34, "chain_open": 0.45,
		"mult": 0.7, "stagger": 0.25, "knock": 1.5, "stamina": 6.0,
		"footwork": {"lunge": 0.0, "time": 0.1},
		"projectile": {"speed": 19.0, "range": 13.0, "radius": 0.14, "loft": 0.06},
		"spin": {"plane": &"side", "turns": 1.25},
		"trail": {"style": &"none"},
		"sfx": &"swing_light",
		"poses": {
			# Arm low and back beside the hip: cords whirl in a vertical side circle.
			"antic": {"torso": Vector3(-0.05, -0.5, 0), "head": Vector3(0.0, 0.45, 0),
				"arm_r": Vector3(-0.25, 0, 0.45), "fore_r": 0.6, "sword": Vector3(0.0, 0, 0),
				"arm_l": Vector3(1.1, 0, -0.15), "fore_l": 0.3,
				"leg_l": Vector3(0.3, 0, -0.05), "shin_l": -0.25, "leg_r": Vector3(-0.25, 0, 0.05), "shin_r": -0.35},
			# Release: arm whips forward at shoulder height.
			"contact": {"torso": Vector3(0.2, 0.4, 0), "head": Vector3(-0.08, -0.35, 0),
				"arm_r": Vector3(1.45, 0, 0.1), "fore_r": 0.15, "sword": Vector3(0.0, 0, 0),
				"arm_l": Vector3(0.3, 0, -0.45), "fore_l": 1.2,
				"leg_l": Vector3(0.5, 0, -0.05), "shin_l": -0.45, "leg_r": Vector3(-0.4, 0, 0.05), "shin_r": -0.1},
			"follow": {"torso": Vector3(0.25, 0.6, 0), "arm_r": Vector3(0.9, 0, -0.55), "fore_r": 0.35},
		},
		"curve": [[1.0, "antic"], [1.5, "contact", "out3"], [2.35, "follow", "out2"], [3.0, "rest"]],
	}


static func _overhead() -> Dictionary:
	return {
		"id": &"sling_overhead", "anim": &"sling_overhead", "attack_id": &"sling_overhead", "heavy": true,
		"windup": 0.78, "active": 0.08, "recovery": 0.44, "chain_open": 0.45,
		"mult": 1.35, "stagger": 0.55, "knock": 3.5, "stamina": 12.0,
		"footwork": {"lunge": 0.0, "time": 0.1},
		"projectile": {"speed": 25.0, "range": 18.0, "radius": 0.15, "loft": 0.04},
		"spin": {"plane": &"overhead", "turns": 2.6},
		"trail": {"style": &"none"},
		"sfx": &"swing_heavy",
		"poses": {
			# Hand above the head, cords whirling flat; the free hand points at the target.
			"antic": {"torso": Vector3(-0.12, -0.4, 0), "head": Vector3(0.12, 0.35, 0),
				"arm_r": Vector3(2.75, 0, 0.3), "fore_r": 0.35, "sword": Vector3(0.0, 0, 0),
				"arm_l": Vector3(1.5, 0, -0.08), "fore_l": 0.1,
				"leg_l": Vector3(0.32, 0, -0.05), "shin_l": -0.25, "leg_r": Vector3(-0.3, 0, 0.05), "shin_r": -0.4},
			"contact": {"torso": Vector3(0.3, 0.35, 0), "head": Vector3(-0.15, -0.3, 0),
				"arm_r": Vector3(1.75, 0, 0.0), "fore_r": 0.05, "sword": Vector3(0.0, 0, 0),
				"arm_l": Vector3(0.2, 0, -0.5), "fore_l": 1.2,
				"leg_l": Vector3(0.6, 0, -0.05), "shin_l": -0.55, "leg_r": Vector3(-0.45, 0, 0.05), "shin_r": -0.08},
			"follow": {"torso": Vector3(0.35, 0.5, 0), "arm_r": Vector3(0.7, 0, -0.5), "fore_r": 0.4},
		},
		"curve": [[1.0, "antic"], [1.5, "contact", "out3"], [2.35, "follow", "out2"], [3.0, "rest"]],
	}
