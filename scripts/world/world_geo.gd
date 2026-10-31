class_name WorldGeo
extends RefCounted
## Procedural mesh accumulator used by every world builder.
## Primitives are appended (already transformed) into one non-indexed
## triangle list with per-vertex colours, then committed as a single
## ArrayMesh (one draw call). Vertex colour alpha is a "sway weight"
## (0 = rigid, 1 = moves fully in the wind) used by foliage shaders.
## Triangles are passed counter-clockwise as seen from outside; they are
## stored clockwise because Godot treats clockwise triangles as front faces.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()

static var _ico_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


func is_empty() -> bool:
	return verts.is_empty()


func tri_count() -> int:
	return verts.size() / 3


# ------------------------------------------------------------------ low level
func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color = ca, cc: Color = ca) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	verts.append(a); verts.append(c); verts.append(b)
	norms.append(n); norms.append(n); norms.append(n)
	cols.append(ca); cols.append(cc); cols.append(cb)
	uvs.append(Vector2.ZERO); uvs.append(Vector2.ZERO); uvs.append(Vector2.ZERO)


func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	verts.append(a); verts.append(c); verts.append(b)
	norms.append(na); norms.append(nc); norms.append(nb)
	cols.append(ca); cols.append(cc); cols.append(cb)
	uvs.append(Vector2.ZERO); uvs.append(Vector2.ZERO); uvs.append(Vector2.ZERO)


## Textured quad (leaf/needle card). Corners: c - r - u .. c + r + u.
## n is the shading normal for all four corners (e.g. outward from the canopy).
## uv_rect selects the atlas region. Double-sided materials are expected.
func card(c: Vector3, r: Vector3, u: Vector3, n: Vector3, col: Color, uv_rect: Rect2 = Rect2(0, 0, 1, 1), n_top: Vector3 = Vector3.ZERO) -> void:
	var nt := n_top if n_top != Vector3.ZERO else n
	var p0 := c - r - u
	var p1 := c + r - u
	var p2 := c + r + u
	var p3 := c - r + u
	var u0 := uv_rect.position
	var u1 := uv_rect.end
	# stored clockwise (front face), two triangles
	verts.append(p0); verts.append(p2); verts.append(p1)
	norms.append(n); norms.append(nt); norms.append(n)
	cols.append(col); cols.append(col); cols.append(col)
	uvs.append(Vector2(u0.x, u1.y)); uvs.append(Vector2(u1.x, u0.y)); uvs.append(Vector2(u1.x, u1.y))
	verts.append(p0); verts.append(p3); verts.append(p2)
	norms.append(n); norms.append(nt); norms.append(nt)
	cols.append(col); cols.append(col); cols.append(col)
	uvs.append(Vector2(u0.x, u1.y)); uvs.append(Vector2(u0.x, u0.y)); uvs.append(Vector2(u1.x, u0.y))


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, col_top: Color = col) -> void:
	## a,b,c,d counter-clockwise from outside. col_top used for c,d.
	tri(a, b, c, col, col, col_top)
	tri(a, c, d, col, col_top, col_top)


func append(other: WorldGeo) -> void:
	verts.append_array(other.verts)
	norms.append_array(other.norms)
	cols.append_array(other.cols)
	uvs.append_array(other.uvs)


# ------------------------------------------------------------------ primitives
## Box centred on xf.origin. top_col (if alpha > 0) tints the upward face (moss).
func box(xf: Transform3D, size: Vector3, col: Color, top_col: Color = Color(0, 0, 0, 0), sway: float = 0.0) -> void:
	var h := size * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, -h.y, h.z), xf * Vector3(-h.x, -h.y, h.z),
		xf * Vector3(-h.x, h.y, -h.z), xf * Vector3(h.x, h.y, -h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z),
	]
	var c := Color(col, sway)
	var dark := Color(col.r * 0.82, col.g * 0.82, col.b * 0.82, sway)
	var top := Color(top_col, sway) if top_col.a > 0.0 else Color(col.r * 1.06, col.g * 1.06, col.b * 1.06, sway)
	# sides: bottom edge slightly darker for a soft gradient
	quad(p[0], p[1], p[5], p[4], dark, c)  # -z
	quad(p[1], p[2], p[6], p[5], dark, c)  # +x
	quad(p[2], p[3], p[7], p[6], dark, c)  # +z
	quad(p[3], p[0], p[4], p[7], dark, c)  # -x
	quad(p[4], p[5], p[6], p[7], top, top)  # top
	quad(p[3], p[2], p[1], p[0], dark, dark)  # bottom


## Cylinder / cone / frustum standing on xf.origin along local +Y.
func cylinder(xf: Transform3D, r_bot: float, r_top: float, height: float, segs: int, col: Color,
		col_top: Color = Color(0, 0, 0, 0), cap_top: bool = true, sway_bot: float = 0.0, sway_top: float = 0.0, jitter: float = 0.0, seed_v: int = 0, bot_dark: float = 0.8) -> void:
	var ct := col_top if col_top.a > 0.0 else col
	var cb := Color(col.r * bot_dark, col.g * bot_dark, col.b * bot_dark, sway_bot)
	ct = Color(ct, sway_top)
	var basis := xf.basis
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	var nrm: Array[Vector3] = []
	var slope := (r_bot - r_top) / maxf(height, 0.001)
	for i in segs:
		var a := TAU * float(i) / segs
		var j := 1.0
		if jitter > 0.0:
			j = 1.0 + jitter * sin(float(i) * 2.7 + seed_v * 1.3)
		var dir := Vector3(cos(a), 0, sin(a))
		bot.append(xf * (dir * r_bot * j))
		top.append(xf * (dir * r_top * j + Vector3(0, height, 0)))
		nrm.append((basis * (dir + Vector3(0, slope, 0))).normalized())
	for i in segs:
		var k := (i + 1) % segs
		if r_top <= 0.001:
			tri_smooth(bot[k], bot[i], top[i], nrm[k], nrm[i], (nrm[i] + nrm[k]).normalized(), cb, cb, ct)
		else:
			tri_smooth(bot[k], bot[i], top[i], nrm[k], nrm[i], nrm[i], cb, cb, ct)
			tri_smooth(bot[k], top[i], top[k], nrm[k], nrm[i], nrm[k], cb, ct, ct)
	if cap_top and r_top > 0.001:
		var c := xf * Vector3(0, height, 0)
		for i in segs:
			tri(c, top[(i + 1) % segs], top[i], ct)


## Cylinder between two world points.
func limb(a: Vector3, b: Vector3, r_a: float, r_b: float, segs: int, col: Color, col_b: Color = Color(0, 0, 0, 0), sway_a: float = 0.0, sway_b: float = 0.0) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001 or len > 40.0 or not d.is_finite():
		return
	var up := d / len
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	var xf := Transform3D(Basis(side, up, fwd), a)
	cylinder(xf, r_a, r_b, len, segs, col, col_b, true, sway_a, sway_b, 0.0, 0, 1.0)


static func _icosphere(level: int) -> Array:
	if _ico_cache.has(level):
		return _ico_cache[level]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = []
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		v.append(p.normalized())
	var f: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for _l in level:
		var mid := {}
		var nf: Array = []
		for face: Array in f:
			var m: Array[int] = []
			for e in 3:
				var a: int = face[e]
				var b: int = face[(e + 1) % 3]
				var key := mini(a, b) * 100000 + maxi(a, b)
				if not mid.has(key):
					v.append(((v[a] + v[b]) * 0.5).normalized())
					mid[key] = v.size() - 1
				m.append(mid[key])
			nf.append([face[0], m[0], m[2]])
			nf.append([face[1], m[1], m[0]])
			nf.append([face[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		f = nf
	# icosahedron faces above are CCW seen from outside
	var res := [v, f]
	_ico_cache[level] = res
	return res


static func _bump(v: Vector3, s: float) -> float:
	return sin(v.x * 3.1 + s) * sin(v.y * 2.7 + s * 1.7) * sin(v.z * 3.3 + s * 0.6) \
		+ 0.5 * sin(v.x * 6.3 - s * 2.1) * sin(v.z * 5.9 + s * 0.4)


## Soft lumpy blob (canopies, bushes, moss). Smooth normals, vertical colour
## gradient: bottom = col * dark, top = col_top (or brightened col).
func blob(xf: Transform3D, radii: Vector3, col: Color, level: int = 1, lump: float = 0.15, seed_v: float = 0.0,
		dark: float = 0.6, col_top: Color = Color(0, 0, 0, 0), sway: float = 1.0) -> void:
	var ico: Array = _icosphere(level)
	var v: Array = ico[0]
	var f: Array = ico[1]
	var top := col_top if col_top.a > 0.0 else Color(minf(col.r * 1.14, 1.0), minf(col.g * 1.12, 1.0), minf(col.b * 1.04, 1.0))
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var pc := PackedColorArray()
	pv.resize(v.size()); pn.resize(v.size()); pc.resize(v.size())
	var inv := Vector3(1.0 / radii.x, 1.0 / radii.y, 1.0 / radii.z)
	for i in v.size():
		var u: Vector3 = v[i]
		var d := 1.0 + lump * _bump(u, seed_v)
		pv[i] = xf * (u * radii * d)
		pn[i] = (xf.basis * (u * inv)).normalized()
		var g := clampf(u.y * 0.5 + 0.5, 0.0, 1.0)
		g = g * g * (3.0 - 2.0 * g)
		var c := Color(col.r * dark, col.g * dark, col.b * dark).lerp(top, g)
		c.a = sway
		pc[i] = c
	for face: Array in f:
		var a: int = face[0]
		var b: int = face[1]
		var c2: int = face[2]
		tri_smooth(pv[a], pv[b], pv[c2], pn[a], pn[b], pn[c2], pc[a], pc[b], pc[c2])


## Faceted rock: flat-shaded lumpy icosphere, moss on upward faces.
func rock(xf: Transform3D, radii: Vector3, col: Color, seed_v: float, moss: float = 0.5, level: int = 1, lump: float = 0.22) -> void:
	var ico: Array = _icosphere(level)
	var v: Array = ico[0]
	var f: Array = ico[1]
	var pv: Array[Vector3] = []
	var sn: Array[Vector3] = []
	var inv := Vector3(1.0 / maxf(radii.x, 0.01), 1.0 / maxf(radii.y, 0.01), 1.0 / maxf(radii.z, 0.01))
	for u: Vector3 in v:
		sn.append((xf.basis * (u * inv)).normalized())
		var d := 1.0 + lump * _bump(u * 1.3, seed_v)
		var q := u * radii * d
		if q.y < -radii.y * 0.35:  # flatten underside so rocks sit on the ground
			q.y = -radii.y * 0.35 + (q.y + radii.y * 0.35) * 0.3
		pv.append(xf * q)
	var moss_c := Color(0.36, 0.52, 0.2)
	for face: Array in f:
		var a: Vector3 = pv[face[0]]
		var b: Vector3 = pv[face[1]]
		var c: Vector3 = pv[face[2]]
		var n := (b - a).cross(c - a).normalized()
		var k := 0.88 + 0.12 * sin((a.x + a.z) * 1.7 + seed_v)
		var ccol := Color(col.r * k, col.g * k, col.b * k)
		var hgt := clampf(((a.y + b.y + c.y) / 3.0 - xf.origin.y) / maxf(radii.y, 0.01) * 0.5 + 0.5, 0.0, 1.0)
		ccol = ccol.darkened(0.25 * (1.0 - hgt))
		moss_c = moss_c  # moss is applied in the shaders (noisy, normal based)
		ccol.a = 0.0
		# soften the facets: blend the face normal with smooth spherical normals
		var na := (n * 0.45 + sn[face[0]] * 0.55).normalized()
		var nb := (n * 0.45 + sn[face[1]] * 0.55).normalized()
		var nc := (n * 0.45 + sn[face[2]] * 0.55).normalized()
		tri_smooth(a, b, c, na, nb, nc, ccol, ccol, ccol)


## Triangular prism tent / roof: ridge along local X, base width along Z.
func tent(xf: Transform3D, length: float, width: float, height: float, col: Color, end_col: Color = Color(0, 0, 0, 0)) -> void:
	var l := length * 0.5
	var w := width * 0.5
	var ec := end_col if end_col.a > 0.0 else col.darkened(0.12)
	var a := xf * Vector3(-l, 0, -w)
	var b := xf * Vector3(l, 0, -w)
	var c := xf * Vector3(l, 0, w)
	var d := xf * Vector3(-l, 0, w)
	var r1 := xf * Vector3(-l, height, 0)
	var r2 := xf * Vector3(l, height, 0)
	var lo := col.darkened(0.22)
	quad(b, a, r1, r2, lo, col)
	quad(d, c, r2, r1, lo, col)
	tri(a, d, r1, ec.darkened(0.1), ec.darkened(0.1), ec)
	tri(c, b, r2, ec.darkened(0.1), ec.darkened(0.1), ec)


# ------------------------------------------------------------------ output
func to_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	add_to(mesh)
	return mesh


## Appends this geometry as a new surface of mesh (optionally with a material).
func add_to(mesh: ArrayMesh, material: Material = null) -> void:
	if verts.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func commit(parent: Node, node_name: String, material: Material = null, shadows: bool = true, vis_end: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = to_mesh()
	mi.material_override = material if material else vertex_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = 10.0
	parent.add_child(mi)
	return mi


## Textured prop material: stone / wood / moss / cloth chosen per vertex colour
## (prop.gdshader). double_sided renders back faces (cave shell, hollow log).
static func vertex_mat(_roughness: float = 0.9, double_sided: bool = false) -> Material:
	var key := "prop_%s" % double_sided
	if _mat_cache.has(key):
		return _mat_cache[key]
	var path := "res://shaders/world/prop_ds.gdshader" if double_sided else "res://shaders/world/prop.gdshader"
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("rock_tex", WorldTextures.tex("rock_mossy"))
	m.set_shader_parameter("rock_nrm", WorldTextures.tex("rock_mossy", "normal"))
	m.set_shader_parameter("wood_tex", WorldTextures.tex("bark_oak"))
	m.set_shader_parameter("wood_nrm", WorldTextures.tex("bark_oak", "normal"))
	m.set_shader_parameter("moss_tex", WorldTextures.tex("moss"))
	_mat_cache[key] = m
	return m


static func shader_mat(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var key := path + str(params)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	_mat_cache[key] = m
	return m
