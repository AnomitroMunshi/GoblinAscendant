class_name CharDefs
## Character Art kit: character definitions (data only). A definition is a
## Dictionary consumed by CharHumanoid.build (see CharHumanoid.DEFAULTS for all
## keys). `id` keys the per-definition mesh cache, so identical NPCs share meshes.
## To add an NPC: copy a definition, change colours / face / outfit, give it a new id.

const SKIN_FAIR := Color(0.74, 0.58, 0.47)
const SKIN_TAN := Color(0.64, 0.47, 0.36)
const SKIN_DARK := Color(0.42, 0.29, 0.21)
const GOBLIN_SKIN := Color(0.39, 0.43, 0.24)   # matches the player model


static func human_raider(variant: int) -> Dictionary:
	var skins := [SKIN_TAN, SKIN_FAIR.darkened(0.04), Color(0.55, 0.40, 0.30), SKIN_TAN.darkened(0.06)]
	var hairs := [Color(0.13, 0.09, 0.06), Color(0.25, 0.16, 0.09), Color(0.1, 0.08, 0.07), Color(0.32, 0.22, 0.13)]
	var v := variant % 4
	return {
		"id": "human_raider_%d" % v, "species": &"human", "height": 1.79 + 0.02 * float(v % 2), "build": 1.02,
		"skin": skins[v], "hair": [&"short", &"crop", &"swept", &"short"][v], "hair_col": hairs[v],
		"beard": [&"", &"short", &"", &"full"][v], "beard_col": hairs[v], "stubble": 0.55,
		"face": {"stern": 0.85, "iris": Color(0.25, 0.19, 0.13), "brow_col": hairs[v].darkened(0.1), "brow": 0.04,
			"chin": 0.035, "jaw_w": 0.8, "scar": v == 1, "nose_hook": 0.3 if v == 2 else 0.0, "mouth_curve": 0.5},
		"top_col": Color(0.36, 0.25, 0.16), "sleeves": 0, "hem": 0.3, "hem_ragged": 0.012,
		"pants_col": Color(0.29, 0.27, 0.25), "boots_col": Color(0.30, 0.20, 0.13), "boot_h": 0.13,
		"belt_col": Color(0.17, 0.11, 0.07), "strap_col": Color(0.2, 0.13, 0.08), "bracers_col": Color(0.24, 0.16, 0.1),
		"pauldrons": [-1.0], "pauldron_col": Color(0.42, 0.42, 0.42), "pauldron_kind": &"plate",
		"weapon": &"sword" if variant % 2 == 0 else &"axe",
	}


static func raider_captain() -> Dictionary:
	var hair := Color(0.22, 0.13, 0.07)
	return {
		"id": "raider_captain", "species": &"human", "height": 1.8, "build": 1.12, "mass": 1.12,
		"skin": SKIN_TAN.darkened(0.03), "hair": &"short", "hair_col": hair, "beard": &"full", "beard_col": hair,
		"face": {"stern": 1.0, "iris": Color(0.22, 0.16, 0.1), "brow_col": hair.darkened(0.15), "brow": 0.05, "jaw_w": 0.84,
			"chin": 0.04, "scar": true, "mouth_curve": 0.6},
		"top_col": Color(0.42, 0.16, 0.13), "sleeves": 1, "hem": 0.38,
		"pants_col": Color(0.25, 0.2, 0.17), "boots_col": Color(0.27, 0.17, 0.1), "boot_h": 0.15,
		"belt_col": Color(0.15, 0.1, 0.06), "bracers_col": Color(0.22, 0.14, 0.09),
		"pauldrons": [-1.0, 1.0], "pauldron_col": Color(0.4, 0.4, 0.41), "pauldron_kind": &"plate",
		"back": &"plank_shield", "weapon": &"broadsword", "offhand": &"torch",
	}


static func goblin_raider(variant: int) -> Dictionary:
	var v := variant % 3
	var skin: Color = [GOBLIN_SKIN.darkened(0.08), Color(0.35, 0.38, 0.22), Color(0.41, 0.42, 0.26)][v]
	return {
		"id": "goblin_raider_%d" % v, "species": &"goblin", "height": 1.06 + 0.03 * float(v), "build": 0.98, "mass": 0.92,
		"skin": skin, "hair": &"bald", "hunch": 0.35,
		"face": {"w": 0.4, "df": 0.42, "db": 0.56, "jaw_w": 0.62, "brow": 0.06, "socket": 0.04, "cheek": 0.03,
			"eye_y": 0.47, "eye_x": 0.165, "eye_w": 0.07, "eye_h": 0.022, "eye_tilt": 0.02, "iris": Color(0.72, 0.42, 0.1),
			"sclera": Color(0.7, 0.64, 0.45), "brow_col": skin.darkened(0.45), "brow_w": 0.02, "stern": 1.0,
			"nose_len": 0.13, "nose_w": 0.085, "nose_y": 0.29, "nose_hook": 0.4, "mouth_y": 0.18, "mouth_w": 0.12,
			"mouth_curve": 0.8, "tusks": 0.06, "ear": &"goblin", "ear_len": 1.05, "muzzle": 0.02,
			"paint": Color(0.32, 0.1, 0.08, 0.75) if v != 1 else Color(0.08, 0.07, 0.06, 0.6), "scar": v == 2,
			"ear_inner": Color(0.42, 0.3, 0.24)},
		"top_col": Color(0.33, 0.24, 0.15), "sleeves": 0, "hem": 0.42, "hem_ragged": 0.03, "neck": &"crew",
		"bare_legs": true, "pants_col": skin, "boots_col": Color(0.24, 0.16, 0.1), "boot_h": 0.12,
		"bare_feet": v == 1,
		"belt_col": Color(0.16, 0.11, 0.07), "buckle": false, "strap_col": Color(0.18, 0.12, 0.08) if v != 2 else Color(0, 0, 0, 0),
		"bracers_col": Color(0.22, 0.15, 0.1), "pauldrons": [-1.0], "pauldron_col": Color(0.3, 0.22, 0.15), "pauldron_kind": &"leather",
		"weapon": &"club" if variant % 2 == 0 else &"spear", "weapon_scale": 0.82,
	}


## Camp adventurers. variant 0 Bram = mage (elder, staff), 1 Mira = knight
## (sword + shield, matches her lines), 2 Thalen = elf ranger (bow).
static func adventurer(variant: int) -> Dictionary:
	match variant % 3:
		0:
			var white := Color(0.74, 0.72, 0.68)
			return {
				"id": "adv_mage", "species": &"human", "height": 1.76, "build": 0.95,
				"skin": SKIN_FAIR.darkened(0.02), "hair": &"white_short", "hair_col": white, "beard": &"full", "beard_col": white,
				"face": {"stern": 0.35, "iris": Color(0.3, 0.38, 0.42), "brow_col": white.darkened(0.08), "brow_w": 0.017,
					"age": 0.8, "jaw_w": 0.76, "nose_len": 0.115, "nose_hook": 0.2},
				"top_col": Color(0.3, 0.24, 0.36), "top_trim": Color(0.4, 0.34, 0.46), "sleeves": 2, "hem": 0.75, "robe": true,
				"hem_split": 0.18, "collar_col": Color(0.26, 0.2, 0.31),
				"pants_col": Color(0.22, 0.2, 0.2), "boots_col": Color(0.3, 0.21, 0.14), "boot_h": 0.08,
				"belt_col": Color(0.3, 0.2, 0.12), "satchel": true, "weapon": &"staff",
			}
		1:
			var hair := Color(0.36, 0.2, 0.11)
			return {
				"id": "adv_knight", "species": &"human", "female": true, "height": 1.72, "build": 0.94,
				"skin": SKIN_FAIR, "hair": &"bun", "hair_col": hair,
				"face": {"stern": 0.3, "iris": Color(0.28, 0.36, 0.3), "brow_col": hair.darkened(0.2), "brow_w": 0.012,
					"jaw_w": 0.7, "chin": 0.02, "brow": 0.02, "nose_len": 0.09, "nose_w": 0.042, "lip": 0.6, "mouth_w": 0.075},
				"top_col": Color(0.2, 0.27, 0.42), "sleeves": 2, "top_trim": Color(0.17, 0.22, 0.34), "hem": 0.4, "hem_split": 0.12,
				"pants_col": Color(0.2, 0.2, 0.21), "boots_col": Color(0.33, 0.22, 0.14), "boot_h": 0.15,
				"belt_col": Color(0.26, 0.17, 0.1), "pauldrons": [-1.0, 1.0], "pauldron_col": Color(0.5, 0.51, 0.52),
				"vambraces": true, "neck": &"high", "weapon": &"sword", "offhand": &"shield",
			}
		_:
			var hair := Color(0.66, 0.62, 0.52)
			return {
				"id": "adv_ranger_elf", "species": &"elf", "height": 1.85, "build": 0.92,
				"skin": Color(0.78, 0.66, 0.56), "hair": &"cap", "hair_col": hair, "cap_col": Color(0.25, 0.32, 0.2),
				"face": {"stern": 0.2, "iris": Color(0.3, 0.42, 0.32), "brow_col": hair.darkened(0.25), "brow_w": 0.011,
					"jaw_w": 0.68, "w": 0.31, "cheek": 0.03, "eye_tilt": 0.012, "nose_len": 0.1, "nose_w": 0.04, "ear": &"elf"},
				"top_col": Color(0.27, 0.35, 0.21), "sleeves": 1, "neck": &"v", "hem": 0.45, "hem_split": 0.2,
				"pants_col": Color(0.2, 0.19, 0.16), "boots_col": Color(0.33, 0.22, 0.14), "boot_h": 0.17,
				"belt_col": Color(0.3, 0.2, 0.12), "gloves_col": Color(0.3, 0.2, 0.13), "bracers_col": Color(0.3, 0.2, 0.13),
				"back": &"quiver", "weapon": &"bow",
			}


static func ogre() -> Dictionary:
	var skin := Color(0.47, 0.45, 0.32)
	return {
		"id": "ogre", "species": &"ogre", "height": 3.35, "build": 1.0, "mass": 1.0, "belly": 0.55, "hunch": 0.9,
		"skin": skin, "hair": &"bald",
		"face": {"w": 0.38, "df": 0.38, "db": 0.42, "jaw_w": 1.08, "jaw_drop": 0.25, "brow": 0.09, "socket": 0.05,
			"cheek": 0.03, "eye_y": 0.55, "eye_x": 0.14, "eye_w": 0.05, "eye_h": 0.018, "iris": Color(0.42, 0.28, 0.1),
			"sclera": Color(0.62, 0.56, 0.42), "brow_col": skin.darkened(0.5), "brow_w": 0.024, "stern": 1.0,
			"nose_len": 0.12, "nose_w": 0.1, "nose_y": 0.36, "mouth_y": 0.2, "mouth_w": 0.17, "mouth_curve": 0.9,
			"tusks": 0.11, "underbite": 0.07, "chin": 0.05, "ear": &"ogre", "scar": true, "top_flat": 0.15,
			"tusk_col": Color(0.74, 0.68, 0.52)},
		"top_col": Color(0, 0, 0, 0), "hem": 0.0, "loincloth": Color(0.33, 0.24, 0.16),
		"bare_legs": true, "bare_feet": true, "belt_col": Color(0.2, 0.14, 0.09), "bracers_col": Color(0.24, 0.17, 0.11),
		"pauldrons": [-1.0], "pauldron_col": Color(0.3, 0.25, 0.2), "pauldron_kind": &"fur",
		"weapon": &"ogre_club",
	}


## Nib, the friendly goblin scout (goblins-turnaround SCOUT): tan tunic, simple
## hood, bandaged forearm and head while injured.
static func nib(injured: bool) -> Dictionary:
	var skin := Color(0.42, 0.46, 0.27)
	return {
		"id": "nib_injured" if injured else "nib", "species": &"goblin", "height": 1.02, "build": 0.92, "mass": 0.88,
		"skin": skin, "hair": &"hood", "hood_col": Color(0.27, 0.32, 0.2),
		"face": {"w": 0.4, "df": 0.42, "db": 0.55, "jaw_w": 0.64, "brow": 0.035, "socket": 0.03, "cheek": 0.025,
			"eye_y": 0.47, "eye_x": 0.165, "eye_w": 0.068, "eye_h": 0.025, "eye_tilt": 0.012, "iris": Color(0.74, 0.5, 0.16),
			"sclera": Color(0.74, 0.7, 0.56), "brow_col": Color(0.17, 0.14, 0.09), "brow_w": 0.017, "stern": 0.0,
			"nose_len": 0.11, "nose_w": 0.075, "nose_y": 0.3, "mouth_y": 0.19, "mouth_w": 0.1, "mouth_curve": 0.1,
			"tusks": 0.035, "ear": &"goblin", "ear_len": 0.95, "ear_inner": Color(0.5, 0.36, 0.3)},
		"top_col": Color(0.55, 0.45, 0.31), "sleeves": 0, "hem": 0.45, "hem_ragged": 0.012,
		"pants_col": Color(0.25, 0.24, 0.17), "boots_col": Color(0.3, 0.2, 0.13), "boot_h": 0.12,
		"belt_col": Color(0.25, 0.16, 0.1), "buckle": true, "bracers_col": Color(0.3, 0.2, 0.13),
		"bandage_arm": injured, "bandage_head": false,
	}
