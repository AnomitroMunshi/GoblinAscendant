class_name WorldZones
extends Node3D
## Discovery TriggerZones (one per WorldLayout.LANDMARKS key), checkpoint
## zones ("checkpoint_<key>") and the invisible boundary wall.

var zones: Dictionary = {}   # zone_id -> TriggerZone


func build(world: Node3D) -> void:
	name = "Zones"
	for key: StringName in WorldLayout.LANDMARKS:
		var d: Dictionary = WorldLayout.LANDMARKS[key]
		_zone(world, key, d["pos"], float(d["radius"]))
	for key: StringName in WorldLayout.CHECKPOINTS:
		var z := _zone(world, StringName("checkpoint_%s" % key), WorldLayout.CHECKPOINTS[key], 6.0)
		z.player_entered.connect(_on_checkpoint.bind(key))
	_boundary()


func add_secret(world: Node3D, id: StringName, pos: Vector3, radius: float) -> TriggerZone:
	return _zone(world, id, pos, radius)


func _zone(world: Node3D, id: StringName, pos: Vector3, radius: float) -> TriggerZone:
	var z := TriggerZone.new()
	z.name = "Zone_%s" % id
	z.zone_id = id
	z.radius = radius
	z.height = 40.0
	z.once = false
	z.position = Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	add_child(z)
	zones[id] = z
	return z


func _on_checkpoint(_player: Node3D, key: StringName) -> void:
	GameState.reach_checkpoint(key)


func _boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "BoundaryWall"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var lim := WorldLayout.PLAYABLE_HALF
	var t := 4.0
	var span := lim * 2.0 + t * 2.0
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(t, 600.0, span) if side.x != 0.0 else Vector3(span, 600.0, t)
		cs.shape = bs
		cs.position = side * (lim + t * 0.5) + Vector3(0, 100.0, 0)
		body.add_child(cs)
	add_child(body)
