class_name WorldTextures
extends RefCounted
## Texture + material factory for the realistic environment.
## - CC0 PBR textures from assets/textures/world/<name>/{albedo,normal}.jpg (see docs/ASSETS_WORLD.md)
## - A procedural 2x2 foliage alpha atlas generated once at runtime:
##     cell (0,0) broadleaf leaf cluster   cell (1,0) small round leaves (birch/beech)
##     cell (0,1) conifer needle spray     cell (1,1) fern frond
## Materials are cached; all are ShaderMaterials from shaders/world/.

const ROOT := "res://assets/textures/world/"
const ATLAS_SIZE := 512
const CELL_BROAD := Rect2(0.0, 0.0, 0.5, 0.5)
const CELL_SMALL := Rect2(0.5, 0.0, 0.5, 0.5)
const CELL_NEEDLE := Rect2(0.0, 0.5, 0.5, 0.5)
const CELL_FERN := Rect2(0.5, 0.5, 0.5, 0.5)

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
static var _atlas: ImageTexture


static func tex(name: String, kind: String = "albedo") -> Texture2D:
	var key := name + "/" + kind
	if not _tex.has(key):
		var path := ROOT + name + "/" + kind + ".jpg"
		_tex[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex[key]


# ------------------------------------------------------------------ atlas
static func foliage_atlas() -> ImageTexture:
	if _atlas:
		return _atlas
	var n := ATLAS_SIZE
	var data := PackedByteArray()
	data.resize(n * n * 4)
	# fill with an average foliage colour at alpha 0 (avoids dark mip fringes)
	for i in range(0, data.size(), 4):
		data[i] = 70; data[i + 1] = 92; data[i + 2] = 44; data[i + 3] = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var h := n / 2
	_draw_cluster(data, n, Rect2i(0, 0, h, h), rng, 70, 30.0, 52.0, 0.42, Color(0.30, 0.42, 0.16), Color(0.46, 0.52, 0.22))
	_draw_cluster(data, n, Rect2i(h, 0, h, h), rng, 110, 16.0, 26.0, 0.62, Color(0.40, 0.50, 0.20), Color(0.58, 0.60, 0.26))
	_draw_needles(data, n, Rect2i(0, h, h, h), rng, false)
	_draw_needles(data, n, Rect2i(h, h, h, h), rng, true)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


static func _plot(data: PackedByteArray, n: int, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= n or y >= n:
		return
	var i := (y * n + x) * 4
	data[i] = int(clampf(c.r, 0.0, 1.0) * 255.0)
	data[i + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
	data[i + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)
	data[i + 3] = 255


static func _line(data: PackedByteArray, n: int, a: Vector2, b: Vector2, w: float, c: Color, clip: Rect2i) -> void:
	var steps := int(a.distance_to(b)) + 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for oy in range(-int(w), int(w) + 1):
			for ox in range(-int(w), int(w) + 1):
				var q := Vector2i(int(p.x) + ox, int(p.y) + oy)
				if clip.has_point(q) and Vector2(ox, oy).length() <= w:
					_plot(data, n, q.x, q.y, c)


## Leaf spray: twigs from the cell's lower centre, leaves along them.
static func _draw_cluster(data: PackedByteArray, n: int, cell: Rect2i, rng: RandomNumberGenerator, count: int,
		lmin: float, lmax: float, wratio: float, c0: Color, c1: Color) -> void:
	var cs := float(cell.size.x)
	var origin := Vector2(cell.position) + Vector2(cs * 0.5, cs * 0.96)
	var twig := Color(0.30, 0.24, 0.16)
	var tips: Array[Vector2] = []
	for t in 7:
		var ang := -PI * 0.5 + rng.randf_range(-1.1, 1.1)
		var tip := origin + Vector2(cos(ang), sin(ang)) * cs * rng.randf_range(0.35, 0.5)
		_line(data, n, origin, tip, 1.2, twig, cell)
		tips.append(tip)
	for k in count:
		var tip: Vector2 = tips[k % tips.size()]
		var along := rng.randf_range(0.25, 1.05)
		var base := origin.lerp(tip, along) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)) * (cs / 256.0)
		var ang := (tip - origin).angle() + rng.randf_range(-1.3, 1.3)
		var L := rng.randf_range(lmin, lmax) * (cs / 256.0)
		var W := L * wratio
		var col := c0.lerp(c1, rng.randf()) * rng.randf_range(0.85, 1.12)
		var dir := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-dir.y, dir.x)
		var bb := int(L) + 2
		for oy in range(-bb, bb + 1):
			for ox in range(-bb, bb + 1):
				var q := Vector2(ox, oy)
				var u := q.dot(dir) / L
				if u < 0.0 or u > 1.0:
					continue
				var v := q.dot(nrm)
				var half := W * 0.5 * pow(sin(PI * clampf(u * 0.95 + 0.03, 0.0, 1.0)), 0.75)
				if absf(v) > half:
					continue
				var px := Vector2i(int(base.x) + ox, int(base.y) + oy)
				if not cell.has_point(px):
					continue
				var shade := 0.82 + 0.25 * u - 0.12 * absf(v) / maxf(half, 0.01)
				var cc := col * shade
				if absf(v) < 0.8:
					cc = cc * 0.8  # midrib
				_plot(data, n, px.x, px.y, cc)


## Conifer spray (drooping branchlet) or fern frond.
static func _draw_needles(data: PackedByteArray, n: int, cell: Rect2i, rng: RandomNumberGenerator, fern: bool) -> void:
	var cs := float(cell.size.x)
	var stems := 5 if not fern else 1
	for s in stems:
		var spread := (s - (stems - 1) * 0.5) if not fern else 0.0
		var start := Vector2(cell.position) + Vector2(cs * 0.5 + spread * cs * 0.06, cs * 0.97)
		var end := Vector2(cell.position) + Vector2(cs * 0.5 + spread * cs * 0.19, cs * 0.06 + absf(spread) * cs * 0.08)
		var stem_col := Color(0.32, 0.30, 0.16) if not fern else Color(0.30, 0.40, 0.16)
		_line(data, n, start, end, 1.4, stem_col, cell)
		var segs := 80 if not fern else 34
		for k in segs:
			var t := float(k) / segs
			var p := start.lerp(end, t)
			var dir := (end - start).normalized()
			var side_len := cs * (0.11 if not fern else 0.36) * (1.0 - t * 0.6)
			for side: float in [-1.0, 1.0]:
				var ang := dir.angle() + side * rng.randf_range(0.7, 1.1)
				var e := p + Vector2(cos(ang), sin(ang)) * side_len * rng.randf_range(0.7, 1.0)
				var col: Color
				if fern:
					col = Color(0.30, 0.46, 0.16).lerp(Color(0.44, 0.54, 0.22), rng.randf())
					# fern pinna: a thin leaflet
					var pn := Vector2(-sin(ang), cos(ang))
					for m in 8:
						var q := p.lerp(e, float(m) / 8.0)
						var w := 3.0 * sin(PI * float(m) / 8.0) * (cs / 256.0)
						_line(data, n, q - pn * w, q + pn * w, 0.6, col * (0.85 + 0.2 * float(m) / 8.0), cell)
				else:
					col = Color(0.14, 0.24, 0.13).lerp(Color(0.26, 0.36, 0.19), rng.randf())
					_line(data, n, p, e, 1.0, col, cell)


# ------------------------------------------------------------------ materials
static func _shader_mat(key: String, path: String, params: Dictionary) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	_mats[key] = m
	return m


static func terrain_mat() -> ShaderMaterial:
	return _shader_mat("terrain", "res://shaders/world/terrain.gdshader", {
		"grass_tex": tex("grass"), "grass_nrm": tex("grass", "normal"),
		"forest_tex": tex("forest_floor"), "forest_nrm": tex("forest_floor", "normal"),
		"dirt_tex": tex("dirt_path"), "dirt_nrm": tex("dirt_path", "normal"),
		"mud_tex": tex("mud"), "mud_nrm": tex("mud", "normal"),
		"rock_tex": tex("rock_cliff"), "rock_nrm": tex("rock_cliff", "normal"),
		"pebble_tex": tex("shore_pebbles"), "pebble_nrm": tex("shore_pebbles", "normal"),
	})


## Triplanar stone (boulders, cliffs, ruins, cave). moss = amount on upward faces.
static func rock_mat(kind: String = "rock_mossy", moss: float = 0.6, scale: float = 0.35, tint: float = 0.5) -> ShaderMaterial:
	return _shader_mat("rock_%s_%.2f_%.2f_%.2f" % [kind, moss, scale, tint], "res://shaders/world/rock.gdshader", {
		"albedo_tex": tex(kind), "normal_tex": tex(kind, "normal"),
		"moss_tex": tex("moss"), "moss_nrm": tex("moss", "normal"),
		"moss_amount": moss, "tex_scale": scale, "tint_strength": tint,
	})


## Triplanar bark / wood with wind sway (COLOR.a weight).
static func bark_mat(kind: String = "bark_oak", scale: float = 0.6, moss: float = 0.15) -> ShaderMaterial:
	return _shader_mat("bark_%s_%.2f_%.2f" % [kind, scale, moss], "res://shaders/world/bark.gdshader", {
		"albedo_tex": tex(kind), "normal_tex": tex(kind, "normal"),
		"moss_tex": tex("moss"), "tex_scale": scale, "moss_amount": moss,
	})


static func leaf_mat(name: String = "leaves", sway: float = 1.0) -> ShaderMaterial:
	return _shader_mat("leaf_%s_%.2f" % [name, sway], "res://shaders/world/leaves.gdshader", {
		"atlas": foliage_atlas(), "sway_strength": sway,
	})


static func grass_mat() -> ShaderMaterial:
	return _shader_mat("grass", "res://shaders/world/grass.gdshader", {
		"ground_tex": tex("grass"),
	})
