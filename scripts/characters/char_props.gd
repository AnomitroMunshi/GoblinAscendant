class_name CharProps
## Character Art kit: weapon / prop meshes. Convention: the grip is at the
## origin and the business end points along -Y (EnemyHumanoid weapon joints),
## so a hanging arm carries the weapon pointing down and slightly forward.
## Returns the grip radius so a CharParts.grip_hand can close around it.

const STEEL := Color(0.56, 0.57, 0.58)
const STEEL_DARK := Color(0.36, 0.36, 0.37)
const IRON := Color(0.30, 0.29, 0.28)
const WOOD := Color(0.36, 0.26, 0.17)
const WOOD_DARK := Color(0.24, 0.17, 0.11)
const WRAP := Color(0.22, 0.15, 0.10)
const BRASS := Color(0.55, 0.43, 0.24)


static func build(g: CharGeo, xf: Transform3D, kind: StringName, sc: float = 1.0) -> float:
	match kind:
		&"sword":
			return sword(g, xf, sc, 0.8, 0.052)
		&"broadsword":
			return sword(g, xf, sc, 0.9, 0.075)
		&"axe":
			return axe(g, xf, sc)
		&"spear":
			return spear(g, xf, sc)
		&"club":
			return crude_club(g, xf, sc)
		&"bow":
			return bow(g, xf, sc)
		&"staff":
			return staff(g, xf, sc)
		&"ogre_club":
			return ogre_club(g, xf, sc)
		&"knife":
			return sword(g, xf, sc, 0.26, 0.04)
	return 0.02 * sc


static func sword(g: CharGeo, xf: Transform3D, sc: float, blade: float, width: float) -> float:
	var gr := 0.016 * sc
	g.surf_override = CharGeo.LEATHER
	g.loft(xf, [Vector4(0.1 * sc, gr, gr, 0), Vector4(-0.07 * sc, gr * 1.05, gr * 1.05, 0)], WRAP, 8)
	g.surf_override = -1
	# pommel + guard
	g.ellipsoid(xf * Transform3D(Basis(), Vector3(0, 0.12 * sc, 0)), Vector3(0.026, 0.022, 0.026) * sc, STEEL_DARK, 8, 5, true, CharGeo.METAL)
	g.loft(xf * Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(0, -0.085 * sc, 0)),
		[Vector4(-width * 2.0 * sc, 0.009 * sc, 0.016 * sc, 0), Vector4(0, 0.013 * sc, 0.02 * sc, 0), Vector4(width * 2.0 * sc, 0.009 * sc, 0.016 * sc, 0)],
		STEEL_DARK, 6, true, true, 0.3, CharGeo.METAL)
	# blade: diamond section, tapering to a point (outline extruded with chamfered edges)
	var w := width * 0.5 * sc
	var l := blade * sc
	var outline := PackedVector2Array([Vector2(-w, -0.1 * sc), Vector2(w, -0.1 * sc), Vector2(w * 0.86, -0.1 * sc - l * 0.82),
		Vector2(0, -0.1 * sc - l), Vector2(-w * 0.86, -0.1 * sc - l * 0.82)])
	g.extrude(xf * Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, 0)), Vector3.ZERO), outline, 0.004 * sc, STEEL, CharGeo.METAL, null, 0.0035 * sc)
	return gr


static func axe(g: CharGeo, xf: Transform3D, sc: float) -> float:
	var gr := 0.018 * sc
	g.loft(xf, [Vector4(0.1 * sc, gr, gr, 0), Vector4(-0.55 * sc, gr * 1.05, gr * 1.1, 0), Vector4(-0.82 * sc, gr * 1.15, gr * 1.2, 0)], [WOOD_DARK, WOOD, WOOD], 7)
	g.surf_override = CharGeo.LEATHER
	g.loft(xf, [Vector4(0.06 * sc, gr * 1.15, gr * 1.15, 0), Vector4(-0.08 * sc, gr * 1.15, gr * 1.15, 0)], WRAP, 7)
	g.surf_override = -1
	# bearded head, blade facing forward (-Z)
	var head := PackedVector2Array([Vector2(-0.02, -0.66), Vector2(-0.02, -0.82), Vector2(0.06, -0.86), Vector2(0.17, -0.92),
		Vector2(0.2, -0.78), Vector2(0.18, -0.6), Vector2(0.1, -0.66), Vector2(0.04, -0.7)])
	for i in head.size():
		head[i] = head[i] * sc
	g.extrude(xf * Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, 0)), Vector3.ZERO), head, 0.012 * sc, STEEL_DARK, CharGeo.METAL, null, 0.004 * sc)
	return gr


static func spear(g: CharGeo, xf: Transform3D, sc: float) -> float:
	var gr := 0.016 * sc
	g.loft(xf, [Vector4(0.42 * sc, gr * 0.9, gr * 0.9, 0), Vector4(-1.14 * sc, gr, gr, 0)], WOOD, 7)
	g.surf_override = CharGeo.LEATHER
	g.loft(xf, [Vector4(-1.08 * sc, gr * 1.4, gr * 1.4, 0), Vector4(-1.18 * sc, gr * 1.4, gr * 1.4, 0)], WRAP, 7)
	g.surf_override = -1
	var tip := PackedVector2Array([Vector2(-0.035, -1.16), Vector2(0.035, -1.16), Vector2(0.045, -1.26), Vector2(0, -1.42), Vector2(-0.045, -1.26)])
	for i in tip.size():
		tip[i] = tip[i] * sc
	g.extrude(xf, tip, 0.012 * sc, Color(0.42, 0.36, 0.30), CharGeo.METAL, null, 0.006 * sc)
	return gr


## Goblin cudgel: knotted branch with iron nails.
static func crude_club(g: CharGeo, xf: Transform3D, sc: float) -> float:
	var gr := 0.018 * sc
	g.loft(xf, [Vector4(0.08 * sc, gr, gr, 0), Vector4(-0.2 * sc, gr * 1.3, gr * 1.3, 0), Vector4(-0.45 * sc, gr * 2.2, gr * 2.0, 0.004),
		Vector4(-0.6 * sc, gr * 2.5, gr * 2.4, 0.0), Vector4(-0.66 * sc, gr * 1.6, gr * 1.6, 0)], [WOOD_DARK, WOOD, WOOD, WOOD_DARK, WOOD_DARK], 8)
	for i in 5:
		var a := float(i) * 2.4
		var y := (-0.42 - float(i % 3) * 0.07) * sc
		var p := Vector3(cos(a), 0, sin(a)) * gr * 2.1
		g.tube([xf * Vector3(p.x, y, p.z), xf * Vector3(p.x * 1.9, y + 0.01 * sc, p.z * 1.9)], 0.005 * sc, IRON, 4, false, CharGeo.METAL)
	g.surf_override = CharGeo.LEATHER
	g.loft(xf, [Vector4(0.05 * sc, gr * 1.15, gr * 1.15, 0), Vector4(-0.08 * sc, gr * 1.2, gr * 1.2, 0)], WRAP, 7)
	g.surf_override = -1
	return gr


static func bow(g: CharGeo, xf: Transform3D, sc: float) -> float:
	var gr := 0.017 * sc
	# limbs curve forward (-Z) away from the string; the bow hangs grip-centred
	var pts: Array = []
	var radii: Array = []
	for i in 13:
		var t := float(i) / 12.0 * 2.0 - 1.0
		pts.append(xf * Vector3(0, -t * 0.62 * sc - 0.0, -(1.0 - t * t) * 0.12 * sc + 0.1 * sc))
		radii.append((0.019 - absf(t) * 0.011) * sc)
	g.tube(pts, radii, WOOD, 6)
	g.tube([pts[0], pts[12]], 0.0025 * sc, Color(0.72, 0.68, 0.58), 4)
	g.surf_override = CharGeo.LEATHER
	g.loft(xf * Transform3D(Basis(), Vector3(0, 0, -0.02 * sc)), [Vector4(0.07 * sc, gr * 1.15, gr * 1.15, 0), Vector4(-0.07 * sc, gr * 1.15, gr * 1.15, 0)], WRAP, 7)
	g.surf_override = -1
	return gr


## Long walking staff with an iron-bound knot (mage). Mostly above the hand.
static func staff(g: CharGeo, xf: Transform3D, sc: float) -> float:
	var gr := 0.019 * sc
	g.loft(xf, [Vector4(1.15 * sc, gr * 1.6, gr * 1.6, 0), Vector4(1.0 * sc, gr * 1.1, gr * 1.1, 0), Vector4(-0.55 * sc, gr, gr, 0)], [WOOD_DARK, WOOD, WOOD], 7)
	g.loft(xf, [Vector4(1.02 * sc, gr * 1.5, gr * 1.5, 0), Vector4(1.07 * sc, gr * 1.5, gr * 1.5, 0)], IRON, 7, true, true, 0.0, CharGeo.METAL)
	# a smoky blue stone cradled in the knot (muted, not a glowing toy orb)
	g.ellipsoid(xf * Transform3D(Basis(), Vector3(0, 1.2 * sc, 0)), Vector3(0.045, 0.05, 0.045) * sc, Color(0.24, 0.32, 0.42), 9, 6, true, CharGeo.METAL)
	for i in 3:
		var a := TAU * float(i) / 3.0
		g.tube([xf * Vector3(cos(a) * gr, 1.12 * sc, sin(a) * gr), xf * Vector3(cos(a) * 0.05 * sc, 1.2 * sc, sin(a) * 0.05 * sc),
			xf * Vector3(cos(a) * 0.02 * sc, 1.27 * sc, sin(a) * 0.02 * sc)], 0.008 * sc, WOOD_DARK, 5)
	return gr


static func ogre_club(g: CharGeo, xf: Transform3D, sc: float) -> float:
	var gr := 0.09 * sc
	g.loft(xf, [Vector4(0.2 * sc, gr * 0.9, gr * 0.9, 0), Vector4(-0.4 * sc, gr * 1.15, gr * 1.1, 0), Vector4(-1.0 * sc, gr * 2.2, gr * 2.0, 0.02),
		Vector4(-1.5 * sc, gr * 3.3, gr * 3.0, 0.0), Vector4(-1.8 * sc, gr * 3.0, gr * 2.9, 0), Vector4(-1.9 * sc, gr * 1.8, gr * 1.8, 0)],
		[WOOD_DARK, WOOD, WOOD, WOOD, WOOD_DARK, WOOD_DARK], 11)
	# iron band and driven spikes
	g.loft(xf, [Vector4(-1.42 * sc, gr * 3.35, gr * 3.05, 0), Vector4(-1.52 * sc, gr * 3.4, gr * 3.1, 0)], IRON, 11, true, true, 0.0, CharGeo.METAL)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.3
		var y := (-1.62 - float(i % 2) * 0.14) * sc
		var p := Vector3(cos(a) * gr * 3.0, y, sin(a) * gr * 2.9)
		g.tube([xf * p, xf * (p * Vector3(1.45, 1, 1.45) + Vector3(0, 0.02 * sc, 0))], [0.03 * sc, 0.004 * sc], STEEL_DARK, 5, false, CharGeo.METAL)
	g.surf_override = CharGeo.LEATHER
	g.loft(xf, [Vector4(0.12 * sc, gr * 1.1, gr * 1.1, 0), Vector4(-0.25 * sc, gr * 1.22, gr * 1.22, 0)], WRAP, 9)
	g.surf_override = -1
	return gr


## Round wooden shield, face toward -Z of `xf`, rim + boss.
static func round_shield(g: CharGeo, xf: Transform3D, r: float, face: Color) -> void:
	var b := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	g.loft(xf * Transform3D(b, Vector3.ZERO), [Vector4(-0.03, r * 0.98, r * 0.98, 0), Vector4(0.0, r, r, 0), Vector4(0.012, r * 0.97, r * 0.97, 0)],
		[WOOD_DARK, face, face], 20, false, true, 0.0, CharGeo.MATTE)
	g.loft(xf * Transform3D(b, Vector3.ZERO), [Vector4(-0.022, r * 1.02, r * 1.02, 0), Vector4(0.02, r * 1.02, r * 1.02, 0)], IRON, 20, true, false, 0.0, CharGeo.METAL)
	g.ellipsoid(xf * Transform3D(Basis(), Vector3(0, 0, -0.018)), Vector3(r * 0.24, r * 0.24, r * 0.12), STEEL_DARK, 10, 5, true, CharGeo.METAL)


## Square plank buckler (captain), face toward -Z.
static func plank_shield(g: CharGeo, xf: Transform3D, w: float, h: float) -> void:
	for i in 4:
		var x := lerpf(-w * 0.375, w * 0.375, float(i) / 3.0)
		g.box(xf * Transform3D(Basis(), Vector3(x, 0, 0)), Vector3(w * 0.24, h, 0.03), WOOD.darkened(0.05 * float(i % 2)))
	for y: float in [-h * 0.32, h * 0.32]:
		g.box(xf * Transform3D(Basis(), Vector3(0, y, -0.018)), Vector3(w * 1.02, 0.045, 0.012), IRON, CharGeo.METAL)
	g.ellipsoid(xf * Transform3D(Basis(), Vector3(0, 0, -0.025)), Vector3(0.05, 0.05, 0.025), STEEL_DARK, 8, 4, true, CharGeo.METAL)
