class_name WorldRoot
extends Node3D
## Entry point of the procedural forest valley (World agent).
## Instantiable with WorldRoot.new() / load(path).new(); builds everything
## synchronously in _ready() and registers itself as GameState.world.
##
## Public API (stable):
##   height_at(x, z) -> float          ground height, matches the collision exactly
##   is_in_water(p) -> bool            p inside river / pool / pond water
##   get_area_point(id) -> Vector3     ground-snapped anchor (see AREA_IDS)
##   normal_at(x, z) -> Vector3, slope_at(x, z) -> float (degrees)
##   water_level_at(x, z) -> float     -INF when not over water
##   build_msec, stats                 build time / object counts

const AREA_IDS := {
	&"start_glade": WorldLayout.START_GLADE, &"glade": WorldLayout.START_GLADE,
	&"player_start": WorldLayout.PLAYER_START,
	&"wolf_woods": WorldLayout.WOLF_WOODS, &"alpha_wolf_den": WorldLayout.ALPHA_WOLF_DEN,
	&"rescue_site": WorldLayout.RESCUE_SITE, &"ruins": WorldLayout.RUINS,
	&"ruins_shrine": WorldLayout.RUINS_SHRINE, &"overlook": WorldLayout.OVERLOOK,
	&"adventurer_camp": WorldLayout.ADVENTURER_CAMP, &"camp": WorldLayout.ADVENTURER_CAMP,
	&"raider_outpost": WorldLayout.RAIDER_OUTPOST, &"outpost": WorldLayout.RAIDER_OUTPOST,
	&"ogre_clearing": WorldLayout.OGRE_CLEARING, &"cave_entrance": WorldLayout.CAVE_ENTRANCE,
	&"cave": WorldLayout.CAVE_ENTRANCE, &"cave_interior": WorldLayout.CAVE_INTERIOR,
	&"waterfall": WorldLayout.WATERFALL_POOL, &"waterfall_pool": WorldLayout.WATERFALL_POOL,
	&"bridge": WorldLayout.BRIDGE,
}

## Optional modules, loaded only if present (keeps the world runnable while
## parts are being developed).
const OPTIONAL_MODULES := [
	["Landmarks", "res://scripts/world/world_landmarks.gd"],
	["Cave", "res://scripts/world/world_cave.gd"],
	["Vegetation", "res://scripts/world/world_vegetation.gd"],
]

var terrain: WorldTerrain
var water: WorldWater
var sky: WorldSky
var zones: WorldZones
var atmosphere: WorldAtmosphere
var modules: Dictionary = {}
var extra_trees: Array = []   # [Vector3 pos, kind(int), scale] requested by landmarks
var build_msec := 0.0
var stats: Dictionary = {}

# keep-out circles for scattered decoration: spatial hash of Vector3(x, z, r)
const BLOCK_CELL := 16.0
var _blockers: Dictionary = {}
var _vis_nodes: Array = []   # [GeometryInstance3D, base_end]


func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	name = "World" if name.is_empty() else name
	GameState.world = self
	terrain = WorldTerrain.new()
	add_child(terrain)
	terrain.build()
	stats["terrain_msec"] = (Time.get_ticks_usec() - t0) / 1000.0

	atmosphere = WorldAtmosphere.new()  # created early: others add fires to it
	sky = WorldSky.new()
	add_child(sky)
	sky.build(self)

	water = WorldWater.new()
	add_child(water)
	water.build(self)

	for m: Array in OPTIONAL_MODULES:
		if not ResourceLoader.exists(m[1]):
			continue
		var t1 := Time.get_ticks_usec()
		var node: Node3D = load(m[1]).new()
		add_child(node)
		node.build(self)
		modules[m[0]] = node
		stats["%s_msec" % m[0].to_lower()] = (Time.get_ticks_usec() - t1) / 1000.0
		if "stats" in node:
			stats[String(m[0]).to_lower()] = node.stats

	zones = WorldZones.new()
	add_child(zones)
	zones.build(self)
	if modules.has("Landmarks") and modules["Landmarks"].has_method("build_secrets"):
		modules["Landmarks"].build_secrets(self)

	add_child(atmosphere)
	atmosphere.build(self)

	Settings.changed.connect(_on_setting_changed)
	_apply_quality()
	build_msec = (Time.get_ticks_usec() - t0) / 1000.0
	stats["build_msec"] = build_msec
	print("World built in %.0f ms" % build_msec)


# ------------------------------------------------------------------ API
func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func normal_at(x: float, z: float) -> Vector3:
	return terrain.normal_at(x, z)


func slope_at(x: float, z: float) -> float:
	return terrain.slope_at(x, z)


func water_level_at(x: float, z: float) -> float:
	return terrain.water_level_at(x, z)


func is_in_water(p: Vector3) -> bool:
	return water != null and water.is_in_water(p)


func get_area_point(id: StringName) -> Vector3:
	var p: Vector3 = AREA_IDS.get(id, Vector3.INF)
	if p == Vector3.INF:
		if WorldLayout.CHECKPOINTS.has(id):
			p = WorldLayout.CHECKPOINTS[id]
		elif WorldLayout.LANDMARKS.has(id):
			p = WorldLayout.LANDMARKS[id]["pos"]
		else:
			push_warning("World.get_area_point: unknown id '%s'" % id)
			return Vector3.ZERO
	return Vector3(p.x, height_at(p.x, p.z), p.z)


# ------------------------------------------------------------------ blockers
func add_blocker(x: float, z: float, r: float) -> void:
	var c0 := Vector2i(floori((x - r) / BLOCK_CELL), floori((z - r) / BLOCK_CELL))
	var c1 := Vector2i(floori((x + r) / BLOCK_CELL), floori((z + r) / BLOCK_CELL))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var key := Vector2i(cx, cz)
			if not _blockers.has(key):
				_blockers[key] = PackedVector3Array()
			var arr: PackedVector3Array = _blockers[key]
			arr.append(Vector3(x, z, r))
			_blockers[key] = arr


func is_blocked(x: float, z: float, clearance: float = 0.0) -> bool:
	var key := Vector2i(floori(x / BLOCK_CELL), floori(z / BLOCK_CELL))
	if not _blockers.has(key):
		return false
	for b: Vector3 in _blockers[key]:
		var dx := x - b.x
		var dz := z - b.y
		var rr := b.z + clearance
		if dx * dx + dz * dz < rr * rr:
			return true
	return false


# ------------------------------------------------------------------ quality
## Registers a geometry node whose visibility_range_end scales with view distance.
func register_vis(gi: GeometryInstance3D, base_end: float, base_begin: float = 0.0) -> void:
	_vis_nodes.append([gi, base_end, base_begin])
	_apply_vis(gi, base_end, base_begin)


func _apply_vis(gi: GeometryInstance3D, base_end: float, base_begin: float) -> void:
	var vd := clampf(float(Settings.get_value(&"view_distance", 1.0)), 0.3, 2.0)
	gi.visibility_range_end = base_end * vd
	gi.visibility_range_begin = base_begin * vd
	gi.visibility_range_end_margin = 8.0
	gi.visibility_range_begin_margin = 8.0 if base_begin > 0.0 else 0.0


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		WorldTextures.set_view_pos(cam.global_position)


func _on_setting_changed(key: StringName) -> void:
	if key == &"graphics_quality" or key == &"view_distance":
		_apply_quality()


func _apply_quality() -> void:
	var vd := clampf(float(Settings.get_value(&"view_distance", 1.0)), 0.3, 2.0)
	var q := Settings.quality()
	WorldTextures.set_lod_split((26.0 if q == 0 else (34.0 if q == 1 else 42.0)) * vd)
	for e: Array in _vis_nodes:
		if is_instance_valid(e[0]):
			_apply_vis(e[0], e[1], e[2])
	sky.apply_quality()
	water.apply_quality()
	atmosphere.apply_quality()
	for m: Node in modules.values():
		if m.has_method("apply_quality"):
			m.apply_quality()


func _exit_tree() -> void:
	if GameState.world == self:
		GameState.world = null
