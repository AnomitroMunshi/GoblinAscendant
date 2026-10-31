class_name CharParts
## Character Art kit: anatomy builders that write into a CharGeo.
##
## Heads are authored in HEAD UNITS (chin = 0, crown = 1) and scaled by the
## head height, so one parametric face serves humans, elves, goblins and ogres.
## Face params (all optional, see DEFAULT_FACE): skull width/depth, jaw width,
## brow ridge, eye placement/size, nose length/width, mouth width, tusks, etc.

const DEFAULT_FACE := {
	"w": 0.33, "df": 0.40, "db": 0.50, "jaw_w": 0.74, "jaw_drop": 0.0, "chin": 0.03, "brow": 0.035,
	"socket": 0.03, "cheek": 0.02, "muzzle": 0.0, "eye_y": 0.49, "eye_x": 0.14, "eye_w": 0.058,
	"eye_h": 0.021, "eye_tilt": 0.006, "iris": Color(0.32, 0.26, 0.18), "sclera": Color(0.80, 0.77, 0.70),
	"brow_col": Color(0.22, 0.15, 0.10), "brow_w": 0.014, "stern": 0.4, "nose_len": 0.105, "nose_w": 0.05,
	"nose_y": 0.31, "nose_hook": 0.0, "mouth_y": 0.2, "mouth_w": 0.085, "mouth_curve": 0.0, "lip": 0.0,
	"tusks": 0.0, "tusk_col": Color(0.82, 0.78, 0.64), "underbite": 0.0, "age": 0.0, "ear": &"human",
	"ear_len": 1.0, "ear_inner": Color(0.0, 0.0, 0.0, 0.0), "paint": Color(0, 0, 0, 0), "scar": false,
	"female": false, "cranium": 1.0, "top_flat": 0.0,
}


static func _f(p: Dictionary, k: String) -> Variant:
	return p[k] if p.has(k) else DEFAULT_FACE[k]


static func _g2(x: float, y: float, cx: float, cy: float, sx: float, sy: float) -> float:
	return exp(-pow((x - cx) / sx, 2.0) - pow((y - cy) / sy, 2.0))


# ================================================================== HEAD
## Point on the skull surface for latitude `lat` (-PI/2 chin/neck .. PI/2 crown)
## and longitude `phi` (0 = front, -Z). Head units.
static func head_point(p: Dictionary, lat: float, phi: float, offset: float = 0.0) -> Vector3:
	var w: float = _f(p, "w")
	var df: float = _f(p, "df")
	var db: float = _f(p, "db") * float(_f(p, "cranium"))
	var sl := sin(lat)
	var cl := cos(lat)
	var y := 0.5 + sl * 0.5
	var sp := sin(phi)
	var cp := cos(phi)
	var front := maxf(cp, 0.0)
	var back := maxf(-cp, 0.0)
	# width: narrower jaw below the cheekbones, slightly narrower temples
	var width := w * pow(cl, 0.62)
	var jaw_k := smoothstep(0.05, -0.85, sl)
	width *= lerpf(1.0, float(_f(p, "jaw_w")), jaw_k * (0.4 + 0.6 * front))
	width *= 1.0 - 0.06 * smoothstep(0.3, 0.9, sl) * front
	# depth: flat face plane in front, rounder cranium behind
	var dfront := df * pow(cl, 0.32)
	var dback := db * pow(maxf(cl, 0.0), 0.75)
	dback *= lerpf(1.0, 0.35, smoothstep(-0.15, -0.95, sl))  # nape / underside tucks in
	var e := 0.78 if cp > 0.0 else 1.0
	var sx := signf(sp) * pow(absf(sp), e)
	var cx := signf(cp) * pow(absf(cp), e)
	var x := sx * width
	var z := -cx * (dfront if cp > 0.0 else dback)
	# jaw underside slopes up toward the neck; chin stays the lowest point
	y += back * maxf(-sl, 0.0) * 0.28 * (1.0 + float(_f(p, "jaw_drop")))
	y -= front * maxf(-sl, 0.0) * float(_f(p, "jaw_drop")) * 0.25
	if sl > 0.6:
		y -= float(_f(p, "top_flat")) * (sl - 0.6)
	# facial relief (only on the front)
	var fw := front * front
	if fw > 0.0:
		var ax := absf(x)
		var ey: float = _f(p, "eye_y")
		var ex: float = _f(p, "eye_x")
		var bump := 0.0
		bump += float(_f(p, "brow")) * _g2(ax, y, ex * 0.7, ey + 0.085, 0.16, 0.04)
		bump -= float(_f(p, "socket")) * _g2(ax, y, ex, ey - 0.005, 0.075, 0.045)
		bump += float(_f(p, "cheek")) * _g2(ax, y, ex + 0.04, ey - 0.13, 0.08, 0.06)
		bump += 0.018 * _g2(ax, y, 0.0, ey - 0.03, 0.045, 0.07)
		bump += float(_f(p, "muzzle")) * _g2(ax, y, 0.0, float(_f(p, "mouth_y")) + 0.02, 0.16, 0.11)
		bump += float(_f(p, "chin")) * _g2(ax, y, 0.0, 0.05, 0.11, 0.07)
		bump += float(_f(p, "underbite")) * _g2(ax, y, 0.0, 0.1, 0.22, 0.1)
		z -= bump * fw
	var pt := Vector3(x, y, z + 0.04)
	if offset != 0.0:
		var c := Vector3(0, 0.55, 0.06)
		pt = c + (pt - c) * (1.0 + offset / maxf((pt - c).length(), 0.05))
	return pt


## Front surface z at head-unit (x, y) (used to seat facial features).
static func face_z(p: Dictionary, x: float, y: float) -> float:
	var best := 0.0
	var best_d := 1e9
	var lat0 := asin(clampf((y - 0.5) / 0.5, -0.999, 0.999))
	var span := 0.5
	var lat_c := lat0
	var phi_c := 0.0
	for it in 4:
		for i in 9:
			for j in 9:
				var lat := lat_c + span * (float(i) / 8.0 - 0.5)
				var phi := phi_c + span * 2.0 * (float(j) / 8.0 - 0.5)
				var q := head_point(p, lat, phi)
				var d := Vector2(q.x - x, q.y - y).length_squared()
				if d < best_d:
					best_d = d
					best = q.z
					lat_c = lat
					phi_c = phi
		span *= 0.35
	return best


## Skull + neck + face. `xf` places head units (chin at local y 0) in bone space,
## usually xf = Transform3D(Basis().scaled(Vector3.ONE * head_h), pos).
static func head(g: CharGeo, xf: Transform3D, p: Dictionary, skin: Color, neck_len: float = 0.3,
		neck_r: float = 0.2) -> void:
	var cols := 26
	var rows := 22
	var stubble: Color = p.get("stubble", Color(0, 0, 0, 0))
	var paint: Color = _f(p, "paint")
	var mouth_y: float = _f(p, "mouth_y")
	var age: float = _f(p, "age")
	var grid: Array = []
	for r in rows + 1:
		var lat := -PI * 0.5 + PI * float(r) / float(rows)
		lat = clampf(lat, -PI * 0.5 + 0.02, PI * 0.5 - 0.02)
		var ring := PackedVector3Array()
		for c in cols:
			ring.append(xf * head_point(p, lat, TAU * float(c) / float(cols)))
		grid.append(ring)
	var inv := xf.affine_inverse()
	var warm := Color(skin.r * 1.04 + 0.02, skin.g * 0.97, skin.b * 0.95)
	var shade := skin.darkened(0.12)
	var colfn := func(wp: Vector3, _r: int, _c: int) -> Color:
		var q := inv * wp
		var k := skin
		var front := q.z < 0.0
		if front:
			# subtle warmth on cheeks / nose, shade under the jaw
			var cw := _g2(absf(q.x), q.y, 0.17, 0.36, 0.08, 0.07)
			k = k.lerp(warm, cw * 0.6)
			if stubble.a > 0.0 and q.y < mouth_y + 0.06 and q.y > -0.02:
				var sk := smoothstep(mouth_y + 0.06, mouth_y - 0.02, q.y) * smoothstep(0.31, 0.2, absf(q.x))
				k = k.lerp(stubble, sk * stubble.a)
			if paint.a > 0.0:
				var band := _g2(absf(q.x), q.y, 0.15, float(_f(p, "eye_y")) - 0.02, 0.14, 0.035)
				k = k.lerp(paint, clampf(band * 1.6, 0.0, 1.0) * paint.a)
			if age > 0.0:
				k = k.lerp(shade, _g2(absf(q.x), q.y, 0.12, 0.27, 0.03, 0.08) * age * 0.6)
		if q.y < 0.12 and not front:
			k = k.lerp(shade, 0.5)
		return k
	var prev := g.surf_override
	g.surf_override = CharGeo.SKIN
	g.grid(grid, colfn, true, true)
	# neck (inside the skull's underside, down into the collar)
	if neck_len > 0.0:
		g.loft(xf, [Vector4(-neck_len, neck_r * 1.12, neck_r * 1.08, 0.1), Vector4(-neck_len * 0.4, neck_r, neck_r * 0.98, 0.1),
			Vector4(0.12, neck_r * 0.98, neck_r * 0.95, 0.12), Vector4(0.3, neck_r * 0.9, neck_r * 0.9, 0.16)],
			[skin.darkened(0.1), skin.darkened(0.06), skin, skin], 10, true, false)
	_face_features(g, xf, p, skin)
	_ears(g, xf, p, skin)
	g.surf_override = prev


static func _face_features(g: CharGeo, xf: Transform3D, p: Dictionary, skin: Color) -> void:
	var ey: float = _f(p, "eye_y")
	var ex: float = _f(p, "eye_x")
	var ew: float = _f(p, "eye_w")
	var eh: float = _f(p, "eye_h")
	var tilt: float = _f(p, "eye_tilt")
	var stern: float = _f(p, "stern")
	var lid := skin.darkened(0.16)
	var lash := Color(0.10, 0.07, 0.05)
	var age: float = _f(p, "age")
	for side: float in [-1.0, 1.0]:
		var cx := side * ex
		var cz := face_z(p, cx, ey)
		# eyeball sunk into the socket: only an almond slit reads
		var ec := Vector3(cx, ey, cz + eh * 0.9)
		g.ellipsoid(xf * Transform3D(Basis(), ec), Vector3(ew * 0.95, eh * 1.25, eh * 1.4), _f(p, "sclera"), 10, 5)
		var iris_c := ec + Vector3(-side * ew * 0.06, -eh * 0.05, -eh * 1.3)
		g.ellipsoid(xf * Transform3D(Basis(), iris_c), Vector3(eh * 1.05, eh * 1.05, eh * 0.3), _f(p, "iris"), 8, 4)
		g.ellipsoid(xf * Transform3D(Basis(), iris_c + Vector3(0, 0, -eh * 0.22)), Vector3(eh * 0.45, eh * 0.48, eh * 0.15), Color(0.05, 0.04, 0.04), 6, 3)
		# upper lid fold + lash line, lower lid: almond outline, outer corner raised
		var upper: Array = []
		var lash_pts: Array = []
		var lower: Array = []
		for i in 7:
			var t := float(i) / 6.0 * 2.0 - 1.0      # -1 inner .. 1 outer
			var dx := t * ew * 1.08
			var x := cx + side * dx
			var arch := 1.0 - t * t
			var yy := ey + (t * 0.5 + 0.5) * tilt
			var zs := face_z(p, x, yy)
			upper.append(Vector3(x, yy + eh * (0.55 + 0.75 * arch) - stern * eh * 0.25 * (1.0 - t) * 0.5, zs - eh * 0.15))
			lash_pts.append(Vector3(x, yy + eh * (0.25 + 0.7 * arch), zs - eh * 0.35))
			lower.append(Vector3(x, yy - eh * (0.45 + 0.65 * arch), zs - eh * 0.1))
		g.tube(_xfa(xf, upper), _scale_r(xf, eh * 0.75), lid, 6)
		g.tube(_xfa(xf, lash_pts), _scale_r(xf, eh * 0.28), lash, 5)
		g.tube(_xfa(xf, lower), _scale_r(xf, eh * 0.38), skin.darkened(0.06 + age * 0.08), 5)
		# brow: inner end lowered for a stern / hard look
		var bw: float = _f(p, "brow_w")
		var brow_pts: Array = []
		for i in 5:
			var t := float(i) / 4.0
			var x := cx + side * (-ew * 1.15 + t * ew * 2.45)
			var yy := ey + eh * 2.6 + 0.012 * sin(t * PI) - stern * 0.03 * (1.0 - t) + t * 0.006
			brow_pts.append(Vector3(x, yy, face_z(p, x, yy) - bw * 0.35))
		var brow_r: Array = []
		for i in 5:
			brow_r.append(xf.basis.get_scale().x * bw * (1.15 - 0.5 * float(i) / 4.0))
		g.tube(_xfa(xf, brow_pts), brow_r, _f(p, "brow_col"), 5, true, CharGeo.MATTE, Vector3.FORWARD, 0.5)
		if age > 0.3:
			# crow's feet / under-eye bag
			var bx := cx + side * ew * 0.2
			g.tube(_xfa(xf, [Vector3(bx - side * ew * 0.6, ey - eh * 2.0, face_z(p, bx - side * ew * 0.6, ey - eh * 2.0) - 0.004),
				Vector3(bx + side * ew * 0.7, ey - eh * 2.3, face_z(p, bx + side * ew * 0.7, ey - eh * 2.3) - 0.004)]),
				_scale_r(xf, 0.006), skin.darkened(0.14), 4)
	# nose: bridge -> tip -> base, plus nostril wings
	var nl: float = _f(p, "nose_len")
	var nw: float = _f(p, "nose_w")
	var ny: float = _f(p, "nose_y")
	var hook: float = _f(p, "nose_hook")
	var bridge := Vector3(0, ey + 0.01, face_z(p, 0, ey + 0.01) + 0.006)
	var mid := Vector3(0, lerpf(ey, ny, 0.55), face_z(p, 0, lerpf(ey, ny, 0.55)) - nl * (0.55 + hook * 0.4))
	var tip := Vector3(0, ny + 0.03, face_z(p, 0, ny + 0.03) - nl)
	var base := Vector3(0, ny, face_z(p, 0, ny) - nl * 0.25)
	var nose_col := skin.lerp(Color(skin.r * 1.05 + 0.02, skin.g * 0.95, skin.b * 0.92), 0.6)
	g.tube(_xfa(xf, [bridge, mid, tip, base]), [_s(xf, nw * 0.22), _s(xf, nw * 0.3), _s(xf, nw * 0.42), _s(xf, nw * 0.3)], nose_col, 7)
	for side: float in [-1.0, 1.0]:
		var wing := Vector3(side * nw * 0.62, ny + 0.025, face_z(p, side * nw * 0.62, ny + 0.025) - nl * 0.25)
		g.ellipsoid(xf * Transform3D(Basis(), wing), Vector3(nw * 0.42, nw * 0.36, nw * 0.4), nose_col.darkened(0.03), 7, 4)
	# mouth: thin lip line, restrained (no grin)
	var my: float = _f(p, "mouth_y")
	var mw: float = _f(p, "mouth_w")
	var curve: float = _f(p, "mouth_curve")
	var lip_col := skin.lerp(Color(0.42, 0.22, 0.2), 0.45).darkened(0.25)
	var mpts: Array = []
	for i in 5:
		var t := float(i) / 4.0 * 2.0 - 1.0
		var x := t * mw
		var yy := my + curve * (t * t) * 0.02
		mpts.append(Vector3(x, yy, face_z(p, x, yy) - 0.004))
	g.tube(_xfa(xf, mpts), _scale_r(xf, 0.009), lip_col, 5, true, CharGeo.MATTE, Vector3.FORWARD, 0.6)
	var lip: float = _f(p, "lip")
	if lip > 0.0:
		var lc := Vector3(0, my - 0.022, face_z(p, 0, my - 0.022) + 0.004)
		g.ellipsoid(xf * Transform3D(Basis(), lc), Vector3(mw * 0.75, 0.018 * lip + 0.006, 0.02), skin.lerp(Color(0.55, 0.3, 0.28), 0.35), 8, 4)
	# lower tusks rising from the jaw at the mouth corners
	var tusks: float = _f(p, "tusks")
	if tusks > 0.0:
		for side: float in [-1.0, 1.0]:
			var tx := side * mw * 0.72
			var root := Vector3(tx, my - 0.04, face_z(p, tx, my - 0.04) + 0.004)
			var tipp := root + Vector3(side * tusks * 0.12, tusks, -tusks * 0.3)
			g.tube(_xfa(xf, [root, root.lerp(tipp, 0.55) + Vector3(0, 0, -tusks * 0.08), tipp]),
				[_s(xf, tusks * 0.3), _s(xf, tusks * 0.22), _s(xf, tusks * 0.04)], _f(p, "tusk_col"), 6)
	if bool(_f(p, "scar")):
		var sx := ex + 0.03
		var spts: Array = []
		for i in 4:
			var t := float(i) / 3.0
			var x := sx - t * 0.02
			var yy := ey + 0.1 - t * 0.2
			spts.append(Vector3(x, yy, face_z(p, x, yy) - 0.003))
		g.tube(_xfa(xf, spts), _scale_r(xf, 0.007), skin.lerp(Color(0.62, 0.42, 0.38), 0.55), 4)


static func _ears(g: CharGeo, xf: Transform3D, p: Dictionary, skin: Color) -> void:
	var kind: StringName = _f(p, "ear")
	var ey: float = _f(p, "eye_y")
	var inner: Color = _f(p, "ear_inner")
	if inner.a <= 0.0:
		inner = skin.lerp(Color(0.55, 0.32, 0.28), 0.3).darkened(0.12)
	var el: float = _f(p, "ear_len")
	for side: float in [-1.0, 1.0]:
		var lat := asin(clampf((ey - 0.06 - 0.5) / 0.5, -0.99, 0.99))
		var at := head_point(p, lat, side * PI * 0.5)
		at.x -= side * 0.02
		at.z += 0.03
		match kind:
			&"human":
				var e := xf * Transform3D(Basis.from_euler(Vector3(0.0, side * 0.25, side * -0.08)), at + Vector3(side * 0.025, 0, 0.0))
				g.ellipsoid(e, Vector3(0.035, 0.13 * el, 0.08), skin.darkened(0.04), 8, 6)
				g.ellipsoid(e * Transform3D(Basis(), Vector3(side * 0.018, -0.005, -0.01)), Vector3(0.02, 0.085 * el, 0.05), inner, 6, 4)
			&"elf":
				leaf_ear(g, xf * Transform3D(Basis(), at), side, 0.42 * el, 0.13, 0.04, skin, inner, 32.0, 38.0, 0.0)
			&"goblin":
				leaf_ear(g, xf * Transform3D(Basis(), at), side, 0.95 * el, 0.3, 0.07, skin, inner, 14.0, 22.0, 6.0)
			&"ogre":
				leaf_ear(g, xf * Transform3D(Basis(), at), side, 0.22 * el, 0.16, 0.04, skin, inner, 10.0, 25.0, -20.0)


## Long pointed ear leaf: root at the origin of `xf`, sweeping out (+X * side),
## raised `lift` degrees and swept back `sweep` degrees. Cupped inner face toward the front.
static func leaf_ear(g: CharGeo, xf: Transform3D, side: float, length: float, width: float, cup: float,
		skin: Color, inner: Color, lift: float, sweep: float, droop: float) -> void:
	var b := Basis.from_euler(Vector3(0, deg_to_rad(sweep) * side, deg_to_rad(lift) * side))
	var along := b * Vector3(side, 0, 0)
	var across := b * Vector3(0, 1, 0)
	var normal := b * Vector3(0, 0, -1)
	var outer_rows: Array = []
	var inner_rows: Array = []
	var nr := 9
	var ncols := 7
	for i in nr:
		var t := float(i) / float(nr - 1)
		var wdt := width * pow(sin(PI * (0.12 + t * 0.88)), 0.75) * (1.0 - t * 0.35)
		if t > 0.9:
			wdt *= (1.0 - t) / 0.1
		var dro := droop * 0.01 * t * t
		var ro := PackedVector3Array()
		var ri := PackedVector3Array()
		for j in ncols:
			var u := float(j) / float(ncols - 1) * 2.0 - 1.0
			var c := cup * (1.0 - u * u) * sin(PI * minf(t * 1.15, 1.0))
			var pos := along * t * length + across * (u * wdt * 0.5 + (t * t) * length * 0.08 - dro * length) + normal * (-c * 0.4)
			ro.append(xf * (pos - normal * 0.012))
			ri.append(xf * (pos + normal * (0.004 - c * 0.35)))
		outer_rows.append(ro)
		inner_rows.append(ri)
	var n_world := xf.basis * normal
	g.grid(outer_rows, skin, false, true, CharGeo.MATTE, -n_world)
	g.grid(inner_rows, [inner.lerp(skin, 0.5), inner, inner, inner, inner, inner, inner.lerp(skin, 0.4), skin, skin], false, true, CharGeo.MATTE, n_world)
	# rim between both skins so the leaf has thickness
	for side_j: int in [0, ncols - 1]:
		var rim: Array = []
		for i in nr:
			var r := PackedVector3Array()
			r.append(outer_rows[i][side_j])
			r.append(inner_rows[i][side_j])
			rim.append(r)
		var a: Vector3 = outer_rows[nr / 2][side_j]
		var bmid: Vector3 = outer_rows[nr / 2][ncols / 2]
		g.grid(rim, skin.darkened(0.05), false, false, CharGeo.MATTE, a - bmid)


## Hair / hood / helmet shell over the skull. `hairline` = latitude (radians)
## of the lower edge at the front, sides and back. `thick` in head units.
static func skull_shell(g: CharGeo, xf: Transform3D, p: Dictionary, col: Variant, thick: float,
		front_lat: float, side_lat: float, back_lat: float, surf: int = CharGeo.MATTE, cols: int = 24,
		top_lift: float = 0.0, side_out: float = 0.0) -> void:
	var rows := 10
	var grid: Array = []
	for r in rows + 2:
		var ring := PackedVector3Array()
		for c in cols:
			var phi := TAU * float(c) / float(cols)
			var cp := cos(phi)
			var lo: float
			if cp >= 0.0:
				lo = lerpf(side_lat, front_lat, pow(cp, 1.5))
			else:
				lo = lerpf(side_lat, back_lat, pow(-cp, 1.2))
			var t := clampf(float(r - 1) / float(rows), 0.0, 1.0)
			var lat := lerpf(lo, PI * 0.5 - 0.03, t)
			var off := 0.0 if r == 0 else thick * (1.0 + top_lift * t * t)
			var q := head_point(p, lat, phi, off)
			if side_out != 0.0 and r > 0:
				q.x *= 1.0 + side_out * (1.0 - t) * absf(sin(phi))
			ring.append(xf * q)
		grid.append(ring)
	g.grid(grid, col, true, true, surf)


## Hair styles: &"crop", &"short", &"swept", &"bob", &"bun", &"long", &"white_short", &"cap" (ranger cap),
## &"hood", &"bald".
static func hair(g: CharGeo, xf: Transform3D, p: Dictionary, style: StringName, col: Color, extra: Dictionary = {}) -> void:
	var dark := col.darkened(0.18)
	match style:
		&"crop":
			skull_shell(g, xf, p, [col, col, col], 0.012, 0.95, 0.35, -0.2)
		&"short", &"white_short":
			skull_shell(g, xf, p, [dark, col, col], 0.03, 0.9, 0.3, -0.35, CharGeo.MATTE, 24, 0.6)
			# a few swept locks break the helmet-like silhouette
			for i in 5:
				var a := -0.5 + float(i) * 0.25
				var root := head_point(p, 1.0, a, 0.03)
				var tip := head_point(p, 0.75, a + 0.15, 0.045) + Vector3(0, 0, -0.04)
				g.tube(_xfa(xf, [root, root.lerp(tip, 0.5) + Vector3(0, 0.02, 0), tip]), [_s(xf, 0.05), _s(xf, 0.04), _s(xf, 0.012)], col, 5)
		&"swept":
			skull_shell(g, xf, p, [dark, col, col], 0.035, 0.85, 0.25, -0.4, CharGeo.MATTE, 24, 0.9)
		&"bob":
			skull_shell(g, xf, p, [dark, col, col], 0.04, 0.82, -0.55, -0.75, CharGeo.MATTE, 24, 0.5, 0.25)
		&"bun":
			skull_shell(g, xf, p, [dark, col, col], 0.018, 0.93, 0.2, -0.45, CharGeo.MATTE, 24, 0.3)
			var bc := head_point(p, 0.55, PI, 0.1)
			g.ellipsoid(xf * Transform3D(Basis(), bc), Vector3(0.14, 0.13, 0.13), col, 10, 6)
			# a couple of loose strands framing the face
			for side: float in [-1.0, 1.0]:
				var r0 := head_point(p, 0.55, side * 1.05, 0.02)
				var r1 := head_point(p, -0.2, side * 1.0, 0.03)
				g.tube(_xfa(xf, [r0, r0.lerp(r1, 0.5) + Vector3(0, 0, -0.02), r1]), [_s(xf, 0.025), _s(xf, 0.02), _s(xf, 0.008)], dark, 5)
		&"long":
			skull_shell(g, xf, p, [dark, col, col], 0.035, 0.85, -0.3, -0.9, CharGeo.MATTE, 24, 0.4, 0.15)
			var drape := [head_point(p, -0.2, PI, 0.05), head_point(p, -0.9, PI, 0.08) + Vector3(0, -0.25, 0.05)]
			g.tube(_xfa(xf, drape), [_s(xf, 0.2), _s(xf, 0.14)], col, 8, true, CharGeo.MATTE, Vector3.UP, 0.45)
		&"cap":
			# soft cloth cap with a short peak swept back (ranger)
			var cc: Color = extra.get("cap_col", Color(0.3, 0.38, 0.22))
			skull_shell(g, xf, p, [dark, col, col], 0.035, 0.75, -0.45, -0.7, CharGeo.MATTE, 24, 0.3, 0.2)
			skull_shell(g, xf, p, [cc.darkened(0.15), cc, cc], 0.07, 1.0, 0.55, 0.15, CharGeo.MATTE, 20, 0.5)
			var tipb := head_point(p, 0.75, PI, 0.12) + Vector3(0, 0.02, 0.12)
			var r0b := head_point(p, 1.2, PI * 0.8, 0.06)
			g.tube(_xfa(xf, [r0b, r0b.lerp(tipb, 0.5) + Vector3(0, 0.04, 0), tipb]), [_s(xf, 0.11), _s(xf, 0.07), _s(xf, 0.01)], cc.darkened(0.08), 6)
		&"hood":
			var hc: Color = extra.get("hood_col", Color(0.28, 0.34, 0.22))
			skull_shell(g, xf, p, [hc.darkened(0.25), hc.darkened(0.08), hc], 0.09, 0.62, -0.95, -1.2, CharGeo.MATTE, 24, 0.55, 0.35)
			# peak at the back of the hood
			var r0h := head_point(p, 0.9, PI, 0.12)
			g.tube(_xfa(xf, [r0h, r0h + Vector3(0, 0.08, 0.12), r0h + Vector3(0, 0.02, 0.26)]), [_s(xf, 0.12), _s(xf, 0.07), _s(xf, 0.01)], hc.darkened(0.05), 6)
		_:
			pass


## Beards: &"stubble" (handled as skin tint), &"short", &"full", &"pointed", &"goatee".
static func beard(g: CharGeo, xf: Transform3D, p: Dictionary, style: StringName, col: Color) -> void:
	if style == &"" or style == &"stubble":
		return
	var my: float = _f(p, "mouth_y")
	var len_k := 0.0
	var thick := 0.03
	match style:
		&"short":
			len_k = 0.05
			thick = 0.035
		&"full":
			len_k = 0.16
			thick = 0.05
		&"pointed":
			len_k = 0.28
			thick = 0.045
		&"goatee":
			len_k = 0.1
			thick = 0.03
	var cols := 13
	var grid: Array = []
	var phi_span := 1.55 if style != &"goatee" else 0.55
	for r in 7:
		var t := float(r) / 6.0
		var ring := PackedVector3Array()
		for c in cols:
			var u := float(c) / float(cols - 1) * 2.0 - 1.0
			var phi := u * phi_span
			var lat := lerpf(asin(clampf((my + 0.07 - 0.5) / 0.5, -1, 1)), -PI * 0.5 + 0.1, t)
			var q := head_point(p, lat, phi, 0.0 if r == 0 else thick)
			# beard hangs below the chin, tapered at the sides
			var hang := len_k * t * t * (1.0 - absf(u) * (0.9 if style == &"pointed" else 0.55))
			q.y -= hang
			q.z -= hang * 0.35
			if style == &"pointed":
				q.x *= 1.0 - t * 0.55
			ring.append(xf * q)
		grid.append(ring)
	g.grid(grid, [col.darkened(0.1), col, col, col, col, col.darkened(0.05), col.darkened(0.1)], false, true, CharGeo.MATTE, Vector3.ZERO, true)
	# moustache
	var mpts: Array = []
	for i in 5:
		var t := float(i) / 4.0 * 2.0 - 1.0
		var x := t * float(_f(p, "mouth_w")) * 1.25
		var yy := my + 0.035 - absf(t) * 0.035
		mpts.append(Vector3(x, yy, face_z(p, x, yy) - 0.012))
	g.tube(_xfa(xf, mpts), _scale_r(xf, 0.022), col, 6, true, CharGeo.MATTE, Vector3.FORWARD, 0.6)


# ================================================================== HANDS
## Relaxed hand at the wrist (`xf` origin), fingers along -Y, palm toward -X
## for side = +1 (right hand); mirrored for side = -1. `hl` = hand length.
## `curl` 0 = open, 1 = loose fist. Fingers are joined to the palm (no beads).
static func hand(g: CharGeo, xf: Transform3D, side: float, hl: float, col: Color, curl: float = 0.35, glove: Color = Color(0, 0, 0, 0)) -> void:
	var c := col if glove.a <= 0.0 else glove
	var pw := hl * 0.23   # half palm width (along Z)
	var pt := hl * 0.11   # half palm thickness (along X)
	g.loft(xf, [Vector4(0.0, pt * 0.95, pw * 0.75, 0), Vector4(-hl * 0.2, pt, pw * 0.95, 0), Vector4(-hl * 0.45, pt * 0.95, pw, 0),
		Vector4(-hl * 0.52, pt * 0.8, pw * 0.92, 0)], c, 8, true, true, 0.55, CharGeo.MATTE, [side * pt * 0.1, 0.0, 0.0, -side * pt * 0.1])
	var fr := hl * 0.052
	for i in 4:
		var fz := lerpf(-pw * 0.72, pw * 0.72, float(i) / 3.0)
		var flen: float = hl * [0.48, 0.52, 0.5, 0.4][i]
		var pts: Array = []
		var p := Vector3(0, -hl * 0.48, fz)
		var dir := Vector3(0, -1, 0)
		pts.append(p)
		for k in 3:
			var ang := curl * (0.5 + float(k) * 0.35)
			dir = dir.rotated(Vector3(0, 0, 1), side * ang * 0.95)
			p += dir * flen / 3.0
			pts.append(p)
		g.tube(_xfa(xf, pts), [fr * 1.1, fr, fr * 0.92, fr * 0.8], c, 6)
	# thumb from the palm heel, front side, folded toward the palm
	var t0 := Vector3(-side * pt * 0.5, -hl * 0.12, -pw * 0.75)
	var t1 := t0 + Vector3(-side * hl * 0.1, -hl * 0.14, -hl * 0.06)
	var t2 := t1 + Vector3(-side * hl * 0.06 * (0.5 + curl), -hl * 0.14, hl * 0.02)
	g.tube(_xfa(xf, [t0, t1, t2]), [fr * 1.35, fr * 1.15, fr * 0.9], c, 6)


## Fist closed around a handle running along local Y through `xf` origin.
## Palm/back of hand on +X (side = +1, right hand; mirrored for -1).
## `gr` = handle radius. Returns nothing; the wrist sits above at +Y.
static func grip_hand(g: CharGeo, xf: Transform3D, side: float, hl: float, gr: float, col: Color, glove: Color = Color(0, 0, 0, 0)) -> void:
	var c := col if glove.a <= 0.0 else glove
	var fr := hl * 0.056
	var rr := gr + fr * 0.95
	# four fingers wrapping the handle, stacked down the grip
	for i in 4:
		var y := hl * 0.15 - float(i) * fr * 1.95
		var pts: Array = []
		for k in 6:
			var a := deg_to_rad(-15.0 - float(k) * 50.0)
			pts.append(Vector3(side * cos(a) * rr, y, sin(a) * rr))
		pts[0] = pts[0] + Vector3(side * fr * 0.8, 0, 0)
		g.tube(_xfa(xf, pts), fr * (1.0 if i < 3 else 0.85), c, 6)
	# back of the hand / palm block bridging fingers to wrist
	var px := side * (rr + fr * 0.2)
	g.loft(xf * Transform3D(Basis(), Vector3(px, 0, 0)), [Vector4(-hl * 0.18, fr * 1.25, hl * 0.17, -hl * 0.02), Vector4(hl * 0.05, fr * 1.4, hl * 0.2, -hl * 0.02),
		Vector4(hl * 0.3, fr * 1.6, hl * 0.17, 0.0)], c, 8, true, true, 0.5)
	# thumb over the index finger from the far side
	var th: Array = []
	for k in 5:
		var a := deg_to_rad(80.0 - float(k) * 45.0)
		th.append(Vector3(side * cos(a) * (rr + fr * 0.4), hl * 0.2 + fr * 0.6, -sin(a) * (rr + fr * 0.3) + 0.0))
	th[0] = th[0] + Vector3(side * fr * 1.2, -fr * 0.8, fr * 0.5)
	g.tube(_xfa(xf, th), [fr * 1.35, fr * 1.2, fr * 1.05, fr * 0.95, fr * 0.85], c, 6)


# ================================================================== FEET
## Boot (or bare foot) from the ankle down; the toe points -Z. `top` = shaft
## height above the ankle; `cuff` adds a folded cuff ring.
static func boot(g: CharGeo, xf: Transform3D, fl: float, r: float, top: float, col: Color, cuff: bool = true,
		top_r: float = 0.0, sole: Color = Color(0.16, 0.12, 0.09)) -> void:
	var dark := col.darkened(0.2)
	if top_r <= 0.0:
		top_r = r * 1.25
	if top > 0.0:
		g.loft(xf, [Vector4(-r * 0.9, r * 1.12, r * 1.2, 0.0), Vector4(top * 0.35, lerpf(r * 1.15, top_r, 0.45), lerpf(r * 1.2, top_r, 0.45), 0.0),
			Vector4(top, top_r, top_r, 0.0)], [dark, col, col], 12, true, true)
		if cuff:
			g.loft(xf, [Vector4(top - top_r * 0.7, top_r * 1.1, top_r * 1.1, 0.0), Vector4(top + top_r * 0.12, top_r * 1.16, top_r * 1.16, 0.0)], col.lightened(0.04), 12, true, true)
	# foot: lofted along -Z, low and wide at the toe
	var fx := xf * Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, -r * 0.55, fl * 0.12))
	g.loft(fx, [Vector4(-fl * 0.05, r * 0.95, r * 0.95, 0.0), Vector4(fl * 0.3, r * 1.0, r * 0.85, r * 0.15),
		Vector4(fl * 0.7, r * 1.05, r * 0.62, r * 0.32), Vector4(fl * 0.92, r * 0.85, r * 0.5, r * 0.36)], [col, col, col, dark], 9, true, true, 0.4)
	g.frustum(xf * Transform3D(Basis(), Vector3(0, -r * 1.12, -fl * 0.33)), r * 0.24, Vector2(r * 1.0, fl * 0.53), Vector2(r * 1.02, fl * 0.53), sole)


## Bare goblin/ogre foot with toes.
static func bare_foot(g: CharGeo, xf: Transform3D, fl: float, r: float, col: Color, toes: int = 4) -> void:
	var fx := xf * Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, -r * 0.6, fl * 0.15))
	g.loft(fx, [Vector4(-fl * 0.05, r * 0.85, r * 0.8, 0.0), Vector4(fl * 0.35, r * 0.95, r * 0.7, r * 0.1),
		Vector4(fl * 0.72, r * 1.05, r * 0.5, r * 0.28)], col, 9, true, true, 0.3)
	for i in toes:
		var tx := lerpf(-r * 0.75, r * 0.75, float(i) / float(maxi(toes - 1, 1)))
		var p0 := Vector3(tx, -r * 1.0, -fl * 0.5)
		g.tube(_xfa(xf, [p0, p0 + Vector3(tx * 0.1, -r * 0.1, -fl * 0.16)]), r * (0.3 if i > 0 else 0.36), col, 6)


# ================================================================== utilities
static func _xfa(xf: Transform3D, pts: Array) -> Array:
	var out: Array = []
	for q: Vector3 in pts:
		out.append(xf * q)
	return out


static func _s(xf: Transform3D, r: float) -> float:
	return r * xf.basis.get_scale().x


static func _scale_r(xf: Transform3D, r: float) -> float:
	return r * xf.basis.get_scale().x
