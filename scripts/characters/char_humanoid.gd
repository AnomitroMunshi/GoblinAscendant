class_name CharHumanoid
## Character Art kit: articulated, data-driven humanoid (humans, elves,
## goblins, ogres). A character is a definition Dictionary (see CharDefs);
## build() creates the joint hierarchy under `root` and one merged mesh per
## bone, and returns the rig:
##   hips, torso, head, shoulder_l/r, elbow_l/r, hip_l/r, knee_l/r  (Node3D joints)
##   weapon (right-hand attachment, item points along -Y), offhand (left hand)
##   hip_height, shoulder_y, arm_len (shoulder -> grip), torso_len, head_h, height
## Model faces -Z. Joint rotation conventions match EnemyHumanoid's pose tables:
## shoulder/hip +X pitch swings the limb forward.

const DEFAULTS := {
	"species": &"human", "height": 1.8, "build": 1.0, "mass": 1.0, "female": false,
	"skin": Color(0.72, 0.55, 0.43), "face": {}, "hair": &"short", "hair_col": Color(0.2, 0.14, 0.09),
	"beard": &"", "beard_col": Color(0.2, 0.14, 0.09), "stubble": 0.0,
	"top_col": Color(0.4, 0.3, 0.2), "top_trim": Color(0, 0, 0, 0), "sleeves": 0, "neck": &"crew",
	"hem": 0.35, "hem_ragged": 0.0, "hem_split": 0.0, "robe": false,
	"pants_col": Color(0.25, 0.22, 0.2), "bare_legs": false, "boots_col": Color(0.33, 0.22, 0.14), "boot_h": 0.1,
	"bare_feet": false, "belt_col": Color(0.2, 0.13, 0.08), "buckle": true, "strap_col": Color(0, 0, 0, 0),
	"bracers_col": Color(0, 0, 0, 0), "gloves_col": Color(0, 0, 0, 0), "pauldrons": [], "pauldron_col": Color(0.42, 0.42, 0.42),
	"pauldron_kind": &"plate", "vambraces": false, "back": &"", "loincloth": Color(0, 0, 0, 0), "belly": 0.0,
	"hunch": 0.0, "weapon": &"", "offhand": &"", "weapon_scale": 1.0, "collar_col": Color(0, 0, 0, 0),
	"satchel": false, "neck_wrap": Color(0, 0, 0, 0), "bandage_head": false, "bandage_arm": false,
}

## Species proportions in fractions of total height.
const SPECIES := {
	&"human":  {"leg": 0.49, "shoulder": 0.82, "neck": 0.865, "head": 0.137, "sw": 0.105, "hip_w": 0.05,
		"upper": 0.17, "fore": 0.145, "hand": 0.1, "limb_r": 1.0, "foot": 0.145},
	&"elf":    {"leg": 0.5, "shoulder": 0.82, "neck": 0.87, "head": 0.132, "sw": 0.098, "hip_w": 0.048,
		"upper": 0.17, "fore": 0.145, "hand": 0.1, "limb_r": 0.9, "foot": 0.14},
	&"goblin": {"leg": 0.4, "shoulder": 0.72, "neck": 0.765, "head": 0.235, "sw": 0.125, "hip_w": 0.06,
		"upper": 0.17, "fore": 0.155, "hand": 0.095, "limb_r": 1.05, "foot": 0.17},
	&"ogre":   {"leg": 0.31, "shoulder": 0.79, "neck": 0.8, "head": 0.165, "sw": 0.27, "hip_w": 0.1,
		"upper": 0.215, "fore": 0.2, "hand": 0.1, "limb_r": 1.75, "foot": 0.16},
}

static var _mesh_cache: Dictionary = {}


static func resolve(def: Dictionary) -> Dictionary:
	var d := DEFAULTS.duplicate()
	d.merge(def, true)
	return d


static func build(root: Node3D, def_in: Dictionary) -> Dictionary:
	var d := resolve(def_in)
	var sp: Dictionary = SPECIES[d["species"]]
	var H: float = d["height"]
	var build_k: float = d["build"]
	var mass: float = float(d["mass"]) * float(sp["limb_r"])
	var leg: float = H * float(sp["leg"])
	var sh_y: float = H * float(sp["shoulder"]) - leg
	var neck_y: float = H * float(sp["neck"]) - leg
	var head_h: float = H * float(sp["head"])
	var S: float = H * float(sp["sw"]) * build_k
	var upper: float = H * float(sp["upper"])
	var fore: float = H * float(sp["fore"])
	var hand_l: float = H * float(sp["hand"])
	var key: String = def_in.get("id", "")
	var cache: Dictionary = _mesh_cache.get(key, {}) if key != "" else {}
	var store := key != "" and cache.is_empty()

	var rig := {"hip_height": leg, "shoulder_y": sh_y, "torso_len": sh_y, "head_h": head_h, "height": H,
		"arm_len": upper + fore + hand_l * 0.45, "def": d}
	var hips := _joint(root, "Hips", Vector3(0, leg, 0))
	var torso := _joint(hips, "Torso", Vector3.ZERO)
	rig["hips"] = hips
	rig["torso"] = torso
	# ---------------- pelvis / skirt (hips bone)
	_emit(hips, "HipsMesh", cache, store, func(g: CharGeo) -> void: _pelvis(g, d, S, sh_y, leg, H))
	# ---------------- torso
	_emit(torso, "TorsoMesh", cache, store, func(g: CharGeo) -> void: _torso(g, d, S, sh_y, neck_y, H))
	# ---------------- head
	var hunch: float = d["hunch"]
	var head := _joint(torso, "Head", Vector3(0, neck_y, -hunch * head_h * 0.5))
	rig["head"] = head
	_emit(head, "HeadMesh", cache, store, func(g: CharGeo) -> void: _head(g, d, head_h, S, hunch))
	# ---------------- arms
	for side: float in [-1.0, 1.0]:
		var sn := "R" if side > 0.0 else "L"
		var sh := _joint(torso, "Shoulder" + sn, Vector3(side * (S * 1.04 + 0.01 * H * mass), sh_y * 0.93, 0))
		var bend := 0.22 if side > 0.0 else 0.18
		var el := _joint(sh, "Elbow" + sn, Vector3(0, -upper, 0), Vector3(bend, 0, 0))
		var item: StringName = d["weapon"] if side > 0.0 else d["offhand"]
		var att := _joint(el, "Weapon" if side > 0.0 else "Offhand", Vector3(0, -fore - hand_l * 0.45, 0), Vector3(0.5 - bend if side > 0.0 else 0.0, 0, 0))
		_emit(sh, "UpperArm" + sn, cache, store, func(g: CharGeo) -> void: _upper_arm(g, d, side, upper, mass, H))
		_emit(el, "Forearm" + sn, cache, store, func(g: CharGeo) -> void: _forearm(g, d, side, fore, hand_l, mass, H, att.transform, item))
		if side > 0.0:
			rig["shoulder_r"] = sh
			rig["elbow_r"] = el
			rig["weapon"] = att
		else:
			rig["shoulder_l"] = sh
			rig["elbow_l"] = el
			rig["offhand"] = att
	# right-hand weapon mesh lives on the weapon joint
	if d["weapon"] != &"":
		_emit(rig["weapon"], "WeaponMesh", cache, store, func(g: CharGeo) -> void:
			CharProps.build(g, Transform3D(), d["weapon"], float(d["weapon_scale"])))
	# ---------------- legs
	var thigh := leg * 0.52
	var shin := leg - thigh
	for side: float in [-1.0, 1.0]:
		var sn := "R" if side > 0.0 else "L"
		var hip := _joint(hips, "Hip" + sn, Vector3(side * H * float(sp["hip_w"]) * build_k, 0, 0))
		var knee := _joint(hip, "Knee" + sn, Vector3(0, -thigh, 0))
		_emit(hip, "Thigh" + sn, cache, store, func(g: CharGeo) -> void: _thigh(g, d, thigh, mass, H))
		_emit(knee, "Shin" + sn, cache, store, func(g: CharGeo) -> void: _shin(g, d, shin, mass, H, float(sp["foot"])))
		if side > 0.0:
			rig["hip_r"] = hip
			rig["knee_r"] = knee
		else:
			rig["hip_l"] = hip
			rig["knee_l"] = knee
	if store:
		_mesh_cache[key] = cache
	return rig


static func _joint(parent: Node3D, n: String, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	j.rotation = rot
	parent.add_child(j)
	return j


## Builds (or reuses from the per-definition cache) one merged mesh on `bone`.
static func _emit(bone: Node3D, n: String, cache: Dictionary, store: bool, fn: Callable) -> void:
	var mesh: ArrayMesh = cache.get(n) if cache.has(n) else null
	if mesh == null and not cache.has(n):
		var g := CharGeo.new()
		fn.call(g)
		mesh = g.commit()
		if store:
			cache[n] = mesh
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.visibility_range_end = 170.0
	bone.add_child(mi)


# ================================================================== torso
## Torso cross-section rings (relative to the hip joint) shared by the
## pelvis, chest, straps and belts so clothing sits on the body.
static func torso_rings(d: Dictionary, S: float, sh_y: float, neck_y: float) -> Array:
	var fem := bool(d["female"])
	var belly: float = d["belly"]
	var sp: StringName = d["species"]
	var waist := 0.74 if not fem else 0.64
	var hipk := 0.86 if not fem else 0.95
	var chest_d := 0.62 if not fem else 0.66
	if sp == &"goblin":
		waist = 0.66
		hipk = 0.78
	var r := [
		Vector4(-sh_y * 0.12, S * hipk * 0.92, S * 0.55, 0.0),
		Vector4(0.0, S * hipk, S * 0.56, 0.0),
		Vector4(sh_y * 0.24, S * (waist + belly * 0.35), S * (0.5 + belly * 0.55), -belly * S * 0.35),
		Vector4(sh_y * 0.5, S * (0.84 + belly * 0.25), S * (0.58 + belly * 0.5), -belly * S * 0.3),
		Vector4(sh_y * 0.74, S * 0.95, S * chest_d, -belly * S * 0.05),
		Vector4(sh_y * 0.9, S * 1.0, S * 0.52, 0.0),
		Vector4(sh_y * 1.0, S * 0.72, S * 0.42, 0.01 * S),
		Vector4(neck_y - sh_y * 0.04, S * 0.36, S * 0.32, 0.02 * S),
	]
	return r


## Point on the torso surface at height `y` and angle `phi` (0 = front).
static func torso_point(rings: Array, y: float, phi: float, off: float = 0.0) -> Vector3:
	var a: Vector4 = rings[0]
	var b: Vector4 = rings[rings.size() - 1]
	for i in rings.size() - 1:
		if y >= (rings[i] as Vector4).x and y <= (rings[i + 1] as Vector4).x:
			a = rings[i]
			b = rings[i + 1]
			break
	var t := clampf((y - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0)
	var r := a.lerp(b, t)
	return Vector3(sin(phi) * (r.y + off), y, -cos(phi) * (r.z + off) + r.w)


static func _pelvis(g: CharGeo, d: Dictionary, S: float, sh_y: float, leg: float, H: float) -> void:
	var rings := torso_rings(d, S, sh_y, 0.0)
	var pants: Color = d["pants_col"] if not d["bare_legs"] else d["skin"]
	var low := [rings[0], rings[1], rings[2]]
	g.loft(Transform3D(), low, [pants.darkened(0.1), pants, pants], 16, true, true, 0.25)
	var belt_y := sh_y * 0.2
	var top: Color = d["top_col"]
	var robe := bool(d["robe"])
	var hem: float = d["hem"]
	var loin: Color = d["loincloth"]
	if loin.a > 0.0:
		_skirt(g, rings, belt_y, -leg * 0.42, 0.04 * S, loin, 0.04 * H, 0.9, 0.0)
	if hem > 0.0:
		var bottom := -leg * hem
		var flare := (0.12 if not robe else 0.45) * S
		_skirt(g, rings, sh_y * 0.3, bottom, flare, top, float(d["hem_ragged"]) * H, 1.0, float(d["hem_split"]))
		var trim: Color = d["top_trim"]
		if trim.a > 0.0:
			_skirt(g, rings, bottom + 0.035 * H * 0.6, bottom, flare * 1.04 + 0.004, trim, 0.0, 1.0, float(d["hem_split"]), bottom, flare)
	# belt + buckle
	var bc: Color = d["belt_col"]
	if bc.a > 0.0:
		g.surf_override = CharGeo.LEATHER
		var bw := 0.012 * H * (1.0 if d["species"] != &"ogre" else 0.8)
		var b0 := rings[1] as Vector4
		var b1 := rings[2] as Vector4
		var t := clampf((belt_y - b0.x) / (b1.x - b0.x), 0, 1)
		var br := b0.lerp(b1, t)
		var grow := 0.012 * H + (0.03 * S if hem > 0.0 else 0.0)
		g.loft(Transform3D(), [Vector4(belt_y - bw, br.y + grow, br.z + grow, br.w), Vector4(belt_y + bw, br.y + grow, br.z + grow, br.w)], bc, 18, true, true, 0.2)
		g.surf_override = -1
		if d["buckle"]:
			# open square buckle frame (four bars)
			var fz := -(br.z + grow) + br.w - 0.003
			var bs := bw * 1.35
			var t2 := bw * 0.28
			for k: Vector3 in [Vector3(0, bs, 0), Vector3(0, -bs, 0)]:
				g.box(Transform3D(Basis(), Vector3(0, belt_y, fz) + k), Vector3(bs * 2.0 + t2, t2, t2), CharProps.STEEL_DARK, CharGeo.METAL)
			for k: Vector3 in [Vector3(bs, 0, 0), Vector3(-bs, 0, 0)]:
				g.box(Transform3D(Basis(), Vector3(0, belt_y, fz) + k), Vector3(t2, bs * 2.0 + t2, t2), CharProps.STEEL_DARK, CharGeo.METAL)
			g.box(Transform3D(Basis(), Vector3(-bs * 0.1, belt_y, fz)), Vector3(t2 * 0.6, bs * 1.8, t2 * 0.8), CharProps.STEEL_DARK, CharGeo.METAL)
		if d["satchel"]:
			g.surf_override = CharGeo.LEATHER
			var sp := torso_point(rings, belt_y - 0.05 * H, PI * 0.62, 0.05 * H)
			g.frustum(Transform3D(Basis.from_euler(Vector3(0, PI * 0.62, 0)), sp), 0.09 * H, Vector2(0.065 * H, 0.03 * H), Vector2(0.06 * H, 0.025 * H), bc.lightened(0.12))
			g.surf_override = -1


## Skirt / tunic hem / robe: a flared tube from `y0` down to `y1`. `ragged` jags
## the hem; `split` (radians) opens the front.
static func _skirt(g: CharGeo, rings: Array, y0: float, y1: float, flare: float, col: Color, ragged: float,
		coverage: float, split: float, _band_from: float = 0.0, _band_flare: float = 0.0) -> void:
	var cols := 22
	var rows := 5
	var grid: Array = []
	var wrap := split <= 0.0
	for r in rows:
		var t := float(r) / float(rows - 1)
		var ring := PackedVector3Array()
		var nc := cols if wrap else cols + 1
		for c in nc:
			var u := float(c) / float(cols)
			var phi := TAU * u if wrap else lerpf(split, TAU - split, u)
			var base := torso_point(rings, maxf(y0 - (y0 - y1) * t, (rings[0] as Vector4).x), phi, 0.012 + flare * t * t)
			var y := lerpf(y0, y1, t)
			if r == rows - 1 and ragged > 0.0:
				y += ragged * (0.5 + 0.5 * sin(phi * 7.0 + 1.3) * sin(phi * 3.0)) * coverage
			if r >= 1:
				# below the pelvis the skirt hangs straight off the widest ring
				var wide := torso_point(rings, 0.0, phi, 0.012 + flare * t * t)
				base.x = wide.x
				base.z = wide.z
			ring.append(Vector3(base.x, y, base.z))
		grid.append(ring)
	var cl := [col, col, col, col.darkened(0.06), col.darkened(0.14)]
	g.grid(grid, cl, wrap, true, CharGeo.MATTE, Vector3.ZERO, true)


static func _torso(g: CharGeo, d: Dictionary, S: float, sh_y: float, neck_y: float, H: float) -> void:
	var rings := torso_rings(d, S, sh_y, neck_y)
	var top: Color = d["top_col"]
	var skin: Color = d["skin"]
	var upper := rings.slice(2)
	var vneck: StringName = d["neck"]
	var bare := top.a <= 0.0
	var colfn := func(p: Vector3, _r: int, _c: int) -> Color:
		if bare:
			return skin
		if p.y > sh_y * 1.0:
			return skin if vneck != &"high" else top
		if vneck == &"v" and p.z < 0.0 and p.y > sh_y * 0.72 and absf(p.x) < (p.y - sh_y * 0.72) * 0.9:
			return skin
		var k := top
		if p.y < sh_y * 0.4:
			k = k.darkened(0.06 * (1.0 - p.y / (sh_y * 0.4)))
		return k
	if bare:
		g.surf_override = CharGeo.SKIN
	g.loft(Transform3D(), upper, colfn, 18, true, true, 0.2)
	g.surf_override = -1
	# cloth layer seam at the waist (tunic tucked under the belt)
	var strap: Color = d["strap_col"]
	if strap.a > 0.0:
		# diagonal baldric: left hip -> over the right shoulder -> down the back
		var pts: Array = []
		for i in 15:
			var t := float(i) / 14.0
			var y: float
			var phi: float
			if t <= 0.5:
				y = lerpf(sh_y * 0.22, sh_y * 0.99, t * 2.0)
				phi = lerpf(-0.8, 0.75, t * 2.0)
			else:
				y = lerpf(sh_y * 0.99, sh_y * 0.22, (t - 0.5) * 2.0)
				phi = lerpf(0.75, PI + 0.8, (t - 0.5) * 2.0)
			pts.append(torso_point(rings, y, phi, 0.008 * H))
		g.surf_override = CharGeo.LEATHER
		g.tube(pts, 0.016 * H, strap, 6, true, CharGeo.MATTE, Vector3.FORWARD, 0.35)
		g.surf_override = -1
	var collar: Color = d["collar_col"]
	if collar.a > 0.0:
		# folded collar / mantle around the neck (healer, mage)
		var mant := [Vector4(sh_y * 0.84, S * 1.06, S * 0.6, 0.0), Vector4(sh_y * 0.98, S * 0.86, S * 0.5, 0.01 * S), Vector4(sh_y * 1.06, S * 0.5, S * 0.42, 0.02 * S)]
		g.loft(Transform3D(), mant, [collar.darkened(0.1), collar, collar], 18, true, false, 0.15)
	var wrap: Color = d["neck_wrap"]
	if wrap.a > 0.0:
		g.loft(Transform3D(), [Vector4(sh_y * 0.98, S * 0.5, S * 0.44, 0.02 * S), Vector4(neck_y + 0.01 * H, S * 0.4, S * 0.38, 0.02 * S)], wrap, 14)
	# shoulder armour
	var pk: StringName = d["pauldron_kind"]
	for side: float in d["pauldrons"]:
		_pauldron(g, d, side, S, sh_y, H, pk)
	match d["back"]:
		&"plank_shield":
			var bx := Transform3D(Basis.from_euler(Vector3(0.08, PI, 0.25)), Vector3(0.0, sh_y * 0.6, S * 0.62 + 0.03))
			CharProps.plank_shield(g, bx, 0.34 * H / 1.8, 0.46 * H / 1.8)
		&"quiver":
			var qx := Transform3D(Basis.from_euler(Vector3(0.15, 0, -0.45)), Vector3(S * 0.25, sh_y * 0.72, S * 0.62 + 0.04))
			g.surf_override = CharGeo.LEATHER
			g.loft(qx, [Vector4(-0.26 * H / 1.8, 0.04, 0.035, 0), Vector4(0.2 * H / 1.8, 0.05, 0.04, 0)], Color(0.32, 0.21, 0.13), 10)
			g.surf_override = -1
			for i in 4:
				var ax := qx * Transform3D(Basis(), Vector3((float(i) - 1.5) * 0.015, 0.25 * H / 1.8, 0.0))
				g.tube([ax.origin, ax * Vector3(0, 0.07, 0)], 0.006, Color(0.55, 0.5, 0.42), 4)


static func _pauldron(g: CharGeo, d: Dictionary, side: float, S: float, sh_y: float, H: float, kind: StringName) -> void:
	var col: Color = d["pauldron_col"]
	var surf := CharGeo.METAL if kind == &"plate" else CharGeo.LEATHER
	var r := S * (0.42 if d["species"] != &"ogre" else 0.3)
	var center := Vector3(side * S * 1.0, sh_y * 0.98, 0.0)
	var b := Basis.from_euler(Vector3(0, 0, -side * 0.55))
	# layered lames: a dome and one lower plate
	for i in 2:
		var k := 1.0 - float(i) * 0.12
		var off := b * Vector3(side * float(i) * r * 0.35, -float(i) * r * 0.45, 0)
		var x := Transform3D(b, center + off)
		g.loft(x, [Vector4(-r * 0.35, r * 1.05 * k, r * 1.2 * k, 0), Vector4(0.0, r * 0.98 * k, r * 1.12 * k, 0), Vector4(r * 0.35, r * 0.7 * k, r * 0.85 * k, 0),
			Vector4(r * 0.55, r * 0.2 * k, r * 0.3 * k, 0)], [col.darkened(0.15), col, col, col.lightened(0.05)], 14, true, false, 0.0,
			surf if surf != CharGeo.LEATHER else CharGeo.MATTE)
	if kind == &"fur":
		g.ellipsoid(Transform3D(b, center + Vector3(0, -r * 0.1, 0)), Vector3(r * 1.1, r * 0.6, r * 1.15), col, 12, 6)


# ================================================================== head
static func _head(g: CharGeo, d: Dictionary, hh: float, S: float, hunch: float) -> void:
	var face: Dictionary = (d["face"] as Dictionary).duplicate()
	face["female"] = d["female"]
	var stubble: float = d["stubble"]
	if stubble > 0.0:
		var bcol: Color = d["beard_col"]
		face["stubble"] = Color(bcol.r, bcol.g, bcol.b, stubble)
	var xf := Transform3D(Basis().scaled(Vector3.ONE * hh), Vector3(0, 0.0, -0.02 * hh - hunch * hh * 0.3))
	CharParts.head(g, xf, face, d["skin"], 0.32 + hunch * 0.4, (S * 0.34) / hh)
	var hs: StringName = d["hair"]
	if hs != &"bald":
		CharParts.hair(g, xf, face, hs, d["hair_col"], d)
	CharParts.beard(g, xf, face, d["beard"], d["beard_col"])
	if d["bandage_head"]:
		var band := Color(0.72, 0.68, 0.58)
		CharParts.skull_shell(g, xf, face, [band.darkened(0.1), band, band], 0.03, 0.95, 0.55, 0.45, CharGeo.MATTE, 22)


# ================================================================== limbs
static func _upper_arm(g: CharGeo, d: Dictionary, side: float, upper: float, mass: float, H: float) -> void:
	var r := 0.027 * H * mass
	var skin: Color = d["skin"]
	var sleeves: int = d["sleeves"]
	var top: Color = d["top_col"]
	var cloth := sleeves > 0 and top.a > 0.0
	var sleeve_end := -upper * (0.45 if sleeves == 1 else 1.1)
	var rings := [Vector4(0.035 * H, r * 0.8, r * 0.85, 0), Vector4(0.0, r * 1.12, r * 1.08, 0), Vector4(-upper * 0.3, r * 1.0, r * 0.98, 0),
		Vector4(-upper * 0.7, r * 0.86, r * 0.85, 0), Vector4(-upper * 1.02, r * 0.74, r * 0.74, 0.004)]
	var colfn := func(p: Vector3, _r: int, _c: int) -> Color:
		return top if cloth and p.y > sleeve_end else skin
	g.surf_override = CharGeo.SKIN if not cloth else -1
	g.loft(Transform3D(Basis(), Vector3(side * -0.002, 0, 0)), rings, colfn, 14, true, true)
	# deltoid: rounded cap that overlaps the torso so the shoulder reads as one mass
	var dc: Color = top if cloth else skin
	g.ellipsoid(Transform3D(Basis.from_euler(Vector3(0, 0, -side * 0.35)), Vector3(-side * r * 0.25, -r * 0.35, 0)), Vector3(r * 1.32, r * 1.75, r * 1.2), dc, 14, 9)
	g.surf_override = -1
	if cloth and sleeves == 1:
		# short sleeve cuff stands off the arm a little
		g.loft(Transform3D(), [Vector4(sleeve_end + 0.02 * H, r * 1.12, r * 1.1, 0), Vector4(sleeve_end, r * 1.12, r * 1.1, 0)], top.darkened(0.05), 12)


static func _forearm(g: CharGeo, d: Dictionary, side: float, fore: float, hand_l: float, mass: float, H: float,
		att: Transform3D, item: StringName) -> void:
	var r := 0.024 * H * mass
	var skin: Color = d["skin"]
	var sleeves: int = d["sleeves"]
	var top: Color = d["top_col"]
	var long_sleeve := sleeves >= 2 and top.a > 0.0
	var rings := [Vector4(0.03 * H, r * 0.9, r * 0.85, 0), Vector4(-fore * 0.2, r * 1.05, r * 0.95, 0), Vector4(-fore * 0.6, r * 0.85, r * 0.75, 0),
		Vector4(-fore * 1.0, r * 0.66, r * 0.55, 0)]
	g.surf_override = CharGeo.SKIN if not long_sleeve else -1
	g.loft(Transform3D(), rings, top if long_sleeve else skin, 12, true, true)
	g.surf_override = -1
	if long_sleeve:
		var trim: Color = d["top_trim"] if (d["top_trim"] as Color).a > 0.0 else top.darkened(0.08)
		# wide robe cuff
		g.loft(Transform3D(), [Vector4(-fore * 0.62, r * 1.2, r * 1.15, 0), Vector4(-fore * 0.98, r * 1.65, r * 1.55, 0)], trim, 12, true, false)
	var br: Color = d["bracers_col"]
	if d["vambraces"]:
		g.loft(Transform3D(), [Vector4(-fore * 0.25, r * 1.18, r * 1.1, 0), Vector4(-fore * 0.92, r * 0.95, r * 0.85, 0)],
			d["pauldron_col"], 12, true, true, 0.0, CharGeo.METAL)
	elif br.a > 0.0:
		g.surf_override = CharGeo.LEATHER
		g.loft(Transform3D(), [Vector4(-fore * 0.35, r * 1.12, r * 1.05, 0), Vector4(-fore * 0.94, r * 0.88, r * 0.8, 0)], br, 12, true, true)
		g.surf_override = -1
	if d["bandage_arm"] and side < 0.0:
		g.loft(Transform3D(), [Vector4(-fore * 0.3, r * 1.08, r * 1.0, 0), Vector4(-fore * 0.75, r * 0.95, r * 0.86, 0)], Color(0.7, 0.66, 0.56), 12)
	# hand
	var glove: Color = d["gloves_col"]
	g.surf_override = CharGeo.SKIN if glove.a <= 0.0 else CharGeo.LEATHER
	var wrist := Transform3D(Basis(), Vector3(0, -fore + 0.004, 0))
	var holds := item != &"" and item != &"shield"
	if holds:
		var gr := 0.016 * H / 1.8 * mass
		if item == &"ogre_club":
			gr = 0.09
		elif item in [&"club", &"axe", &"staff", &"bow", &"torch"]:
			gr = 0.018 * H / 1.8 * (mass if item != &"club" else 1.0)
		var hxf := att
		if item == &"torch":
			hxf = att * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-75), 0, 0)), Vector3.ZERO)
		CharParts.grip_hand(g, hxf, side, hand_l, gr, skin, glove)
	elif item == &"shield":
		CharParts.hand(g, wrist, side, hand_l, skin, 0.9, glove)
	else:
		CharParts.hand(g, wrist, side, hand_l, skin, 0.4, glove)
	g.surf_override = -1


static func _thigh(g: CharGeo, d: Dictionary, thigh: float, mass: float, H: float) -> void:
	var r := 0.04 * H * mass
	var bare := bool(d["bare_legs"])
	var col: Color = d["skin"] if bare else d["pants_col"]
	g.surf_override = CharGeo.SKIN if bare else -1
	g.loft(Transform3D(), [Vector4(0.05 * H, r * 0.9, r * 0.95, 0), Vector4(0.0, r * 1.05, r * 1.02, 0), Vector4(-thigh * 0.45, r * 0.92, r * 0.9, -r * 0.05),
		Vector4(-thigh * 1.04, r * 0.66, r * 0.68, -r * 0.02)], col, 12, true, true)
	g.surf_override = -1


static func _shin(g: CharGeo, d: Dictionary, shin: float, mass: float, H: float, foot_k: float) -> void:
	var r := 0.031 * H * mass
	var ankle_h := 0.045 * H
	var bare := bool(d["bare_legs"])
	var col: Color = d["skin"] if bare else d["pants_col"]
	g.surf_override = CharGeo.SKIN if bare else -1
	g.loft(Transform3D(), [Vector4(0.02 * H, r * 0.88, r * 0.9, 0), Vector4(-shin * 0.3, r * 0.98, r * 1.0, r * 0.12),
		Vector4(-shin * 0.75, r * 0.72, r * 0.7, 0), Vector4(-(shin - ankle_h), r * 0.6, r * 0.6, 0)], col, 12, true, true)
	g.surf_override = -1
	var ankle := Transform3D(Basis(), Vector3(0, -(shin - ankle_h), 0))
	var fl := foot_k * H
	if d["bare_feet"]:
		g.surf_override = CharGeo.SKIN
		CharParts.bare_foot(g, ankle, fl, r * 0.75, d["skin"], 4)
		g.surf_override = -1
	else:
		g.surf_override = CharGeo.LEATHER
		CharParts.boot(g, ankle, fl, r * 0.66, float(d["boot_h"]) * H, d["boots_col"], true, r * 1.06)
		g.surf_override = -1
