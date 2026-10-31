class_name ChoreoWeapons
## Procedural weapon meshes in grip-socket space, matching the Goblin's faceted,
## worn, primitive-built style. Socket = the right fist centre (model joint
## "sword"); the weapon axis points along socket -Z. Edged heads face socket -Y
## (downward when the arm hangs), so overhead cuts lead with the edge
## and horizontal cuts roll the socket around Z.
##
## Grip points along the axis (metres, -Z positive toward the tip):
##   sword  main hand 0.0
##   sling  cords hang from the fist; "SlingArm" is posed by the model

const SLING_CORD := 0.22

const WOOD := Color(0.36, 0.25, 0.15)
const WRAP := Color(0.25, 0.16, 0.09)
const IRON := Color(0.44, 0.45, 0.43)
const STEEL_DARK := Color(0.33, 0.34, 0.33)
const CORD := Color(0.55, 0.47, 0.33)
const STONE := Color(0.50, 0.49, 0.46)


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _sphere(r: float, seg: int = 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(5, seg / 2)
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _metal(c: Color, rough: float) -> StandardMaterial3D:
	var m := Palette.mat(c, rough).duplicate() as StandardMaterial3D
	m.metallic = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Flat double-bevel blade in the socket YZ plane: outline points are (y, z);
## the ridge bulges along +-X by `thick`.
static func _blade_yz(outline: Array[Vector2], ridge_center: Vector2, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var ridge := Vector3(thick * side, ridge_center.x, ridge_center.y)
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			st.add_vertex(ridge)
			if side > 0:
				st.add_vertex(Vector3(0, a.x, a.y))
				st.add_vertex(Vector3(0, b.x, b.y))
			else:
				st.add_vertex(Vector3(0, b.x, b.y))
				st.add_vertex(Vector3(0, a.x, a.y))
	st.generate_normals()
	return st.commit()


## Cylinder along socket Z between z0 and z1.
static func _rod(parent: Node3D, r0: float, r1: float, z0: float, z1: float, mat: Material) -> MeshInstance3D:
	return _mi(parent, _cyl(r1, r0, absf(z1 - z0), 10), mat, Vector3(0, 0, (z0 + z1) * 0.5), Vector3(-90 if z1 < z0 else 90, 0, 0))


static func build(type: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = String(type).capitalize().replace(" ", "")
	match type:
		&"sword":
			_build_sword(root)
		&"sling":
			_build_sling(root)
	return root


static func _build_sword(root: Node3D) -> void:
	var wood := Palette.mat(WRAP, 0.9)
	var iron := _metal(IRON, 0.55)
	var steel := _metal(Color(0.52, 0.54, 0.53), 0.5)
	_mi(root, _sphere(0.022), iron, Vector3(0, 0, 0.068), Vector3.ZERO, Vector3(1, 1, 0.8))
	_rod(root, 0.017, 0.016, 0.055, -0.045, wood)
	for i in 4:
		_mi(root, _cyl(0.019, 0.019, 0.008, 8), Palette.mat(WOOD, 0.9), Vector3(0, 0, 0.035 - 0.024 * i), Vector3(90, 0, 0))
	_mi(root, _box(Vector3(0.026, 0.13, 0.026)), iron, Vector3(0, 0, -0.055))
	var outline: Array[Vector2] = [Vector2(-0.024, -0.065), Vector2(0.024, -0.065), Vector2(0.021, -0.36), Vector2(0.013, -0.43), Vector2(0.0, -0.48), Vector2(-0.013, -0.43), Vector2(-0.021, -0.36)]
	var blade := _mi(root, _blade_yz(outline, Vector2(0.0, -0.27), 0.007), steel, Vector3.ZERO)
	blade.name = "Blade"


static func _build_sling(root: Node3D) -> void:
	var cord := Palette.mat(CORD, 0.95)
	var leather := Palette.mat(Color(0.33, 0.22, 0.13), 0.9)
	_mi(root, _sphere(0.014), cord, Vector3(0, -0.01, 0.0), Vector3.ZERO, Vector3(1.4, 0.7, 1.4))
	var arm := Node3D.new()
	arm.name = "SlingArm"
	root.add_child(arm)
	for side in [-1.0, 1.0]:
		var top := Vector3(0.006 * side, -0.012, 0)
		var bottom := Vector3(0.026 * side, -SLING_CORD, 0)
		var mid := (top + bottom) * 0.5
		var mi := _mi(arm, _cyl(0.0035, 0.0035, top.distance_to(bottom), 5), cord, mid)
		mi.rotation = Vector3(0, 0, atan2(bottom.x - top.x, top.y - bottom.y))
	var pouch := _mi(arm, _sphere(0.032), leather, Vector3(0, -SLING_CORD - 0.012, 0), Vector3.ZERO, Vector3(1.15, 0.7, 0.9))
	pouch.name = "Pouch"
	var stone := _mi(arm, _sphere(0.02, 8), Palette.mat(STONE, 0.9), Vector3(0, -SLING_CORD - 0.004, 0))
	stone.name = "Stone"


static func stone_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(0.024, 8)
	mi.material_override = Palette.mat(STONE, 0.9)
	return mi
