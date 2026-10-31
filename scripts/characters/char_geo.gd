class_name CharGeo
extends RefCounted
## Character Art kit: triangle accumulator that merges every static piece of one
## bone into a single vertex-coloured ArrayMesh (one draw call per bone).
##
## All primitives take a Transform3D (bone-local placement) and a colour. Colours
## get a subtle deterministic value/hue jitter ("weathering") so large flat
## areas never read as plastic toy colours. Surfaces: MATTE (skin, cloth,
## hair: fully rough), METAL (steel, iron, gold), GLOW (unshaded), SKIN (soft
## sheen, roughness ~0.65), LEATHER (slightly glossy).
##
## Winding: Godot treats clockwise triangles as front faces. Every primitive
## orients its triangles from an outward reference, so callers never think
## about winding.

enum { MATTE, METAL, GLOW, SKIN, LEATHER }

const SURFACES := 5

var weather := 0.045          # strength of value jitter (0 = flat colour)
## When >= 0, primitives requested on MATTE go to this surface instead
## (e.g. set SKIN while building a face, LEATHER for boots).
var surf_override := -1
var _v: Array = []           # per surface Array[Vector3] (plain arrays append in place)
var _n: Array = []
var _c: Array = []

static var _mats: Dictionary = {}


func _init() -> void:
	for i in SURFACES:
		_v.append([])
		_n.append([])
		_c.append([])


func is_empty() -> bool:
	for i in SURFACES:
		if not (_v[i] as Array).is_empty():
			return false
	return true


func triangle_count() -> int:
	var n := 0
	for i in SURFACES:
		n += (_v[i] as Array).size() / 3
	return n


# ------------------------------------------------------------------ materials
static func material(surface: int) -> StandardMaterial3D:
	if _mats.has(surface):
		return _mats[surface]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	# open cloth, armour lames and hair shells are visible from inside
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match surface:
		METAL:
			m.metallic = 0.6
			m.roughness = 0.38
			m.metallic_specular = 0.5
		GLOW:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		SKIN:
			m.roughness = 0.66
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			m.metallic_specular = 0.35
			m.rim_enabled = true
			m.rim = 0.12
			m.rim_tint = 0.6
		LEATHER:
			m.roughness = 0.58
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			m.metallic_specular = 0.4
		_:
			m.roughness = 0.97
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			m.metallic_specular = 0.2
	_mats[surface] = m
	return m


## Builds the merged mesh. Returns null when nothing was added.
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in SURFACES:
		if (_v[i] as Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(_v[i])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(_n[i])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(_c[i])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(i))
	return mesh if mesh.get_surface_count() > 0 else null


## Commits into a MeshInstance3D under `parent` (nothing when empty).
func instance(parent: Node3D, node_name: String = "Mesh", vis_range: float = 170.0) -> MeshInstance3D:
	var mesh := commit()
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.visibility_range_end = vis_range
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ colour
static func _hash(p: Vector3) -> float:
	var h := sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7) * 43758.5453
	return h - floor(h)


func _tint(c: Color, p: Vector3) -> Color:
	if weather <= 0.0:
		return c
	var n := _hash(p * 9.0) - 0.5
	var n2 := _hash(p * 3.1 + Vector3(5.2, 1.3, 7.7)) - 0.5
	var k := 1.0 + n * weather * 1.2 + n2 * weather * 0.8
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k * (1.0 - n2 * weather * 0.15), 0, 1), clampf(c.b * k, 0, 1), c.a)


# ------------------------------------------------------------------ raw triangles
## Adds one triangle; `out` is any vector pointing to the outside.
func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, out: Vector3, surf: int = MATTE,
		na: Vector3 = Vector3.ZERO, nb: Vector3 = Vector3.ZERO, nc: Vector3 = Vector3.ZERO) -> void:
	if surf == MATTE and surf_override >= 0:
		surf = surf_override
	var fn := (c - a).cross(b - a)
	if fn.length_squared() < 1e-14:
		return
	if fn.dot(out) < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		var tn := nb
		nb = nc
		nc = tn
		fn = -fn
	fn = fn.normalized()
	var vv: Array = _v[surf]
	var nn: Array = _n[surf]
	var cl: Array = _c[surf]
	vv.append(a)
	vv.append(b)
	vv.append(c)
	nn.append(na if na != Vector3.ZERO else fn)
	nn.append(nb if nb != Vector3.ZERO else fn)
	nn.append(nc if nc != Vector3.ZERO else fn)
	cl.append(_tint(ca, a))
	cl.append(_tint(cb, b))
	cl.append(_tint(cc, c))


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3, surf: int = MATTE) -> void:
	tri(a, b, c, col, col, col, out, surf)
	tri(a, c, d, col, col, col, out, surf)


# ------------------------------------------------------------------ grid surface
## Generic surface: `rows` is an Array of PackedVector3Array (same length each).
## `cols` is a Color, an Array of Colors (one per row) or a Callable(p: Vector3, row: int, col: int) -> Color.
## The outward direction is taken from each row's centroid (lofts, heads), or
## from `out_dir` when it is non-zero (flat shells such as ears or capes).
## `double` emits the back side too (thin cloth, ears).
func grid(rows: Array, cols: Variant, wrap: bool, smooth: bool = true, surf: int = MATTE,
		out_dir: Vector3 = Vector3.ZERO, double: bool = false, flip: bool = false) -> void:
	var nr := rows.size()
	if nr < 2:
		return
	var nc: int = (rows[0] as PackedVector3Array).size()
	var cent: Array[Vector3] = []
	for r in nr:
		var pr: PackedVector3Array = rows[r]
		var s := Vector3.ZERO
		for p in pr:
			s += p
		cent.append(s / float(maxi(pr.size(), 1)))
	var gc := Vector3.ZERO
	for cc in cent:
		gc += cc
	gc /= float(nr)
	var colors: Array = []
	for r in nr:
		var pr2: PackedVector3Array = rows[r]
		var rc := PackedColorArray()
		for ci in nc:
			var col: Color
			if cols is Callable:
				col = (cols as Callable).call(pr2[ci], r, ci)
			elif cols is Array:
				col = (cols as Array)[mini(r, (cols as Array).size() - 1)]
			else:
				col = cols
			rc.append(col)
		colors.append(rc)
	var span := nc if wrap else nc - 1
	# Orientation: every quad uses the same topological winding; one global sign
	# (from the summed outward flux) decides whether the whole grid flips. This is
	# robust on caps, poles and tight curves where a local reference is ambiguous.
	var flux := 0.0
	for r in nr - 1:
		for ci in span:
			var c2 := (ci + 1) % nc
			var a: Vector3 = rows[r][ci]
			var d: Vector3 = rows[r + 1][c2]
			var b: Vector3 = rows[r][c2]
			var c: Vector3 = rows[r + 1][ci]
			var fn := (d - a).cross(b - a) + (c - a).cross(d - a)
			var center := (a + b + c + d) * 0.25
			var ref := out_dir if out_dir != Vector3.ZERO else center - gc
			flux += fn.dot(ref)
	var sgn := 1.0 if flux >= 0.0 else -1.0
	if flip:
		sgn = -sgn
	var normals: Array = []
	if smooth:
		normals.resize(nr * nc)
		normals.fill(Vector3.ZERO)
	for r in nr - 1:
		for ci in span:
			var c2 := (ci + 1) % nc
			var a: Vector3 = rows[r][ci]
			var b: Vector3 = rows[r][c2]
			var c: Vector3 = rows[r + 1][ci]
			var d: Vector3 = rows[r + 1][c2]
			var fn := ((d - a).cross(b - a) + (c - a).cross(d - a)) * sgn
			if smooth:
				for idx: int in [r * nc + ci, r * nc + c2, (r + 1) * nc + ci, (r + 1) * nc + c2]:
					normals[idx] = (normals[idx] as Vector3) + fn
	for r in nr - 1:
		for ci in span:
			var c2 := (ci + 1) % nc
			var pa: Vector3 = rows[r][ci]
			var pb: Vector3 = rows[r][c2]
			var pc: Vector3 = rows[r + 1][ci]
			var pd: Vector3 = rows[r + 1][c2]
			var ka: Color = colors[r][ci]
			var kb: Color = colors[r][c2]
			var kc: Color = colors[r + 1][ci]
			var kd: Color = colors[r + 1][c2]
			var na := Vector3.ZERO
			var nb := Vector3.ZERO
			var nc2 := Vector3.ZERO
			var nd := Vector3.ZERO
			if smooth:
				na = (normals[r * nc + ci] as Vector3).normalized()
				nb = (normals[r * nc + c2] as Vector3).normalized()
				nc2 = (normals[(r + 1) * nc + ci] as Vector3).normalized()
				nd = (normals[(r + 1) * nc + c2] as Vector3).normalized()
			# per-triangle outward = its own topological normal times the grid sign
			var o1 := (pd - pa).cross(pb - pa) * sgn
			var o2 := (pc - pa).cross(pd - pa) * sgn
			tri(pa, pb, pd, ka, kb, kd, o1, surf, na, nb, nd)
			tri(pa, pd, pc, ka, kd, kc, o2, surf, na, nd, nc2)
			if double:
				tri(pa, pb, pd, ka, kb, kd, -o1, surf, -na, -nb, -nd)
				tri(pa, pd, pc, ka, kd, kc, -o2, surf, -na, -nd, -nc2)


# ------------------------------------------------------------------ lofts
## Lofted tube along local Y. Each ring: Vector4(y, half_width_x, half_depth_z, z_offset).
## `sq` (0..1) squares the cross-section (0 = ellipse, 1 = rounded box).
## `caps` closes both ends with a centre point. Front of the ring is -Z.
func loft(xf: Transform3D, rings: Array, cols: Variant, seg: int = 10, smooth: bool = true,
		caps: bool = true, sq: float = 0.0, surf: int = MATTE, x_off: Array = []) -> void:
	var rows: Array = []
	var ring_cols: Array = []
	var single := not (cols is Array)
	if caps:
		var r0: Vector4 = rings[0]
		var x0: float = x_off[0] if not x_off.is_empty() else 0.0
		rows.append(_ring(xf, Vector4(r0.x, 0.0, 0.0, r0.w), seg, sq, x0))
		ring_cols.append(cols if single else (cols as Array)[0])
	for i in rings.size():
		var xo: float = x_off[i] if i < x_off.size() else 0.0
		rows.append(_ring(xf, rings[i], seg, sq, xo))
		ring_cols.append(cols if single else (cols as Array)[mini(i, (cols as Array).size() - 1)])
	if caps:
		var rl: Vector4 = rings[rings.size() - 1]
		var xl: float = x_off[rings.size() - 1] if rings.size() - 1 < x_off.size() else 0.0
		rows.append(_ring(xf, Vector4(rl.x, 0.0, 0.0, rl.w), seg, sq, xl))
		ring_cols.append(ring_cols[ring_cols.size() - 1])
	if cols is Callable:
		grid(rows, cols, true, smooth, surf)
	else:
		grid(rows, ring_cols, true, smooth, surf)


func _ring(xf: Transform3D, r: Vector4, seg: int, sq: float, x_off: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var e := 1.0 - sq * 0.65
	for i in seg:
		var a := TAU * float(i) / float(seg)
		var s := sin(a)
		var c := cos(a)
		s = signf(s) * pow(absf(s), e)
		c = signf(c) * pow(absf(c), e)
		pts.append(xf * Vector3(s * r.y + x_off, r.x, -c * r.z + r.w))
	return pts


## Ellipsoid (sphere when radii are equal) with `seg` columns and `rows` rings.
func ellipsoid(xf: Transform3D, radii: Vector3, cols: Variant, seg: int = 10, rows: int = 7,
		smooth: bool = true, surf: int = MATTE) -> void:
	var rings: Array = []
	for i in rows:
		var t := float(i + 1) / float(rows + 1)
		var a := PI * t
		rings.append(Vector4(-cos(a) * radii.y, sin(a) * radii.x, sin(a) * radii.z, 0.0))
	var ring_cols: Variant = cols
	loft(xf, rings, ring_cols, seg, smooth, true, 0.0, surf)


## Box with bevel-free flat faces.
func box(xf: Transform3D, size: Vector3, col: Color, surf: int = MATTE) -> void:
	var h := size * 0.5
	var p := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var w: Array[Vector3] = []
	for q: Vector3 in p:
		w.append(xf * q)
	var c := xf.origin
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		var a: Vector3 = w[f[0]]
		var b: Vector3 = w[f[1]]
		var cc: Vector3 = w[f[2]]
		var d: Vector3 = w[f[3]]
		quad(a, b, cc, d, col, (a + b + cc + d) * 0.25 - c, surf)


## Tapered box (frustum): bottom size `b` (x, z) at y = -h/2, top size `t` at +h/2.
func frustum(xf: Transform3D, h: float, b: Vector2, t: Vector2, col: Color, surf: int = MATTE, top_off: Vector3 = Vector3.ZERO) -> void:
	var y0 := -h * 0.5
	var y1 := h * 0.5
	var p := [Vector3(-b.x, y0, -b.y), Vector3(b.x, y0, -b.y), Vector3(b.x, y0, b.y), Vector3(-b.x, y0, b.y),
		Vector3(-t.x, y1, -t.y) + top_off, Vector3(t.x, y1, -t.y) + top_off, Vector3(t.x, y1, t.y) + top_off, Vector3(-t.x, y1, t.y) + top_off]
	var w: Array[Vector3] = []
	for q: Vector3 in p:
		w.append(xf * (q * 0.5 * Vector3(2, 1, 2)))
	var c := Vector3.ZERO
	for q in w:
		c += q
	c /= 8.0
	for f in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]:
		var a: Vector3 = w[f[0]]
		var bb: Vector3 = w[f[1]]
		var cc: Vector3 = w[f[2]]
		var d: Vector3 = w[f[3]]
		quad(a, bb, cc, d, col, (a + bb + cc + d) * 0.25 - c, surf)


## Extruded 2D outline (XY plane) with thickness along Z. Flat shaded.
## Good for blades, ear plates, buckles, shield faces, cloth tabs.
func extrude(xf: Transform3D, outline: PackedVector2Array, depth: float, col: Color, surf: int = MATTE,
		back_col: Variant = null, bevel: float = 0.0) -> void:
	var idx := Geometry2D.triangulate_polygon(outline)
	if idx.is_empty():
		return
	var hz := depth * 0.5
	var bc: Color = col if back_col == null else back_col
	var front_z := -hz
	var back_z := hz
	var center2 := Vector2.ZERO
	for p in outline:
		center2 += p
	center2 /= float(outline.size())
	for i in range(0, idx.size(), 3):
		var a := outline[idx[i]]
		var b := outline[idx[i + 1]]
		var c := outline[idx[i + 2]]
		var fz := front_z - bevel
		var bz := back_z + bevel
		tri(xf * Vector3(a.x, a.y, fz), xf * Vector3(b.x, b.y, fz), xf * Vector3(c.x, c.y, fz), col, col, col, xf.basis * Vector3(0, 0, -1), surf)
		tri(xf * Vector3(a.x, a.y, bz), xf * Vector3(b.x, b.y, bz), xf * Vector3(c.x, c.y, bz), bc, bc, bc, xf.basis * Vector3(0, 0, 1), surf)
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var mid := (a + b) * 0.5
		var edge := b - a
		var out2 := Vector2(edge.y, -edge.x)
		if out2.dot(mid - center2) < 0.0:
			out2 = -out2
		var side_col := col.darkened(0.12)
		if bevel > 0.0:
			# chamfered edge: front face -> edge ridge -> back face
			quad(xf * Vector3(a.x, a.y, front_z - bevel), xf * Vector3(b.x, b.y, front_z - bevel), xf * Vector3(b.x, b.y, 0), xf * Vector3(a.x, a.y, 0), side_col, xf.basis * Vector3(out2.x, out2.y, -0.5), surf)
			quad(xf * Vector3(a.x, a.y, 0), xf * Vector3(b.x, b.y, 0), xf * Vector3(b.x, b.y, back_z + bevel), xf * Vector3(a.x, a.y, back_z + bevel), side_col, xf.basis * Vector3(out2.x, out2.y, 0.5), surf)
		else:
			quad(xf * Vector3(a.x, a.y, front_z), xf * Vector3(b.x, b.y, front_z), xf * Vector3(b.x, b.y, back_z), xf * Vector3(a.x, a.y, back_z), side_col, xf.basis * Vector3(out2.x, out2.y, 0), surf)


## Tube along a polyline / curve. `radii` per point (or a float). Ends capped.
## `flat_k` squashes the cross-section along the curve's side normal (0..1).
func tube(points: Array, radii: Variant, cols: Variant, seg: int = 6, smooth: bool = true,
		surf: int = MATTE, up_hint: Vector3 = Vector3.FORWARD, flat_k: float = 1.0) -> void:
	var n := points.size()
	if n < 2:
		return
	var rows: Array = []
	var row_cols: Array = []
	var prev_side := Vector3.ZERO
	for i in n:
		var p: Vector3 = points[i]
		var tan: Vector3
		if i == 0:
			tan = (points[1] as Vector3) - p
		elif i == n - 1:
			tan = p - (points[i - 1] as Vector3)
		else:
			tan = (points[i + 1] as Vector3) - (points[i - 1] as Vector3)
		tan = tan.normalized()
		var side := tan.cross(up_hint)
		if side.length_squared() < 1e-6:
			side = tan.cross(Vector3.RIGHT if absf(tan.x) < 0.9 else Vector3.UP)
		side = side.normalized()
		if prev_side != Vector3.ZERO and side.dot(prev_side) < 0.0:
			side = -side
		prev_side = side
		var up := side.cross(tan).normalized()
		var r: float = (radii as Array)[i] if radii is Array else float(radii)
		var ring := PackedVector3Array()
		for k in seg:
			var a := TAU * float(k) / float(seg)
			ring.append(p + side * cos(a) * r + up * sin(a) * r * flat_k)
		if i == 0:
			var cap := PackedVector3Array()
			for k in seg:
				cap.append(p - tan * r * 0.15)
			rows.append(cap)
			row_cols.append(_col_at(cols, 0, n))
		rows.append(ring)
		row_cols.append(_col_at(cols, i, n))
		if i == n - 1:
			var cap2 := PackedVector3Array()
			for k in seg:
				cap2.append(p + tan * r * 0.35)
			rows.append(cap2)
			row_cols.append(_col_at(cols, i, n))
	grid(rows, row_cols, true, smooth, surf)


static func _col_at(cols: Variant, i: int, _n: int) -> Color:
	if cols is Array:
		return (cols as Array)[mini(i, (cols as Array).size() - 1)]
	return cols


## Quadratic Bezier sample helper.
static func bez(a: Vector3, b: Vector3, c: Vector3, steps: int) -> Array:
	var out: Array = []
	for i in steps + 1:
		var t := float(i) / float(steps)
		out.append(a * (1.0 - t) * (1.0 - t) + b * 2.0 * t * (1.0 - t) + c * t * t)
	return out


## Transform helper: position + euler degrees + scale.
static func xf(pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))) * Basis.from_scale(scl)
	return Transform3D(b, pos)
