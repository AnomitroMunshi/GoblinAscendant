class_name EnemyModelKit
## Static helpers to build articulated primitive enemy models (cached meshes).

static var _meshes: Dictionary = {}
const VIS_RANGE := 170.0


static func joint(parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	j.rotation = rot
	parent.add_child(j)
	return j


## `look` is a Material or a Color (resolved through Palette.mat).
static func part(parent: Node3D, mesh: Mesh, look: Variant, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if look is Material:
		mi.material_override = look
	else:
		mi.material_override = Palette.mat(look as Color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.visibility_range_end = VIS_RANGE
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func sphere(r: float, seg: int = 14) -> SphereMesh:
	var key := "s%.3f_%d" % [r, seg]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		_meshes[key] = m
	return _meshes[key]


static func capsule(r: float, h: float) -> CapsuleMesh:
	h = maxf(h, r * 2.0 + 0.001)
	var key := "c%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 12
		m.rings = 4
		_meshes[key] = m
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, seg: int = 10) -> CylinderMesh:
	var key := "y%.3f_%.3f_%.3f_%d" % [top, bottom, h, seg]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func prism(size: Vector3) -> PrismMesh:
	var key := "p%s" % size
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "t%.3f_%.3f" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 40
		m.ring_segments = 6
		_meshes[key] = m
	return _meshes[key]


## Anime-style eye: white, coloured iris, pupil and a highlight. Faces -Z.
## `mood` tilts the brow: > 0 angry (inner end down), < 0 worried/calm.
static func eye(head: Node3D, pos: Vector3, r: float, iris: Color, side: float, mood: float, brow_color: Color) -> Node3D:
	var e := joint(head, pos)
	part(e, sphere(r, 12), Palette.mat(Color(0.98, 0.96, 0.9), 0.4), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.1 - absf(mood) * 0.25, 0.6))
	part(e, sphere(r * 0.62, 10), Palette.mat(iris, 0.35), Vector3(0, -r * 0.05, -r * 0.5), Vector3.ZERO, Vector3(1, 1.1, 0.5))
	part(e, sphere(r * 0.32, 8), Palette.mat(Color(0.04, 0.03, 0.03), 0.3), Vector3(0, -r * 0.05, -r * 0.75), Vector3.ZERO, Vector3(1, 1.1, 0.5))
	part(e, sphere(r * 0.17, 6), Palette.glow(Color(1, 1, 1), 1.2), Vector3(-r * 0.2, r * 0.25, -r * 0.92))
	var brow := part(head, box(Vector3(r * 2.0, r * 0.4, r * 0.5)), brow_color,
		pos + Vector3(0, r * 1.25, -r * 0.1), Vector3(0, 0, side * mood * 26.0))
	brow.position.y -= mood * r * 0.25
	return e
