class_name TriggerZone
extends Area3D
## Vertical cylinder that reports the player entering/leaving.
## Emits Events.zone_entered / zone_exited with zone_id. Lead-owned.

signal player_entered(player: Node3D)
signal player_exited(player: Node3D)

@export var zone_id: StringName = &""
@export var radius := 10.0
@export var height := 40.0
@export var once := false

var _fired := false
var player_inside := false


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	if once and _fired:
		return
	_fired = true
	player_entered.emit(body)
	Events.zone_entered.emit(zone_id)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = false
	if once:
		return
	player_exited.emit(body)
	Events.zone_exited.emit(zone_id)
