class_name Hitbox
extends Area3D
## Attack volume with an explicit active window. Lead-owned shared primitive.
##
## Usage (attacker):
##     hitbox = Hitbox.new()
##     add_child(hitbox)                         # usually under the attacker's model pivot
##     hitbox.setup(self, SphereShape3D / BoxShape3D, Vector3(0, 1, -1.2))
##     hitbox.activate(DamageInfo.make(12, self, 3.0), 0.12)   # during the swing's active frames
##
## Each activation damages every target at most once, unless rehit_interval > 0
## (intentional multi-hit). Targets must implement take_damage(info) -> int and
## pass Factions.can_damage(owner, target).

signal hit_landed(target: Node3D, result: int, info: DamageInfo)

var owner_actor: Node3D
var rehit_interval := 0.0

var _active := false
var _time_left := 0.0
var _template: DamageInfo
var _hit_times: Dictionary = {}  # instance_id -> time of last hit (seconds into activation)
var _elapsed := 0.0
var _shape_node: CollisionShape3D


func _init() -> void:
	collision_layer = Layers.HITBOX
	collision_mask = Layers.PLAYER | Layers.ACTORS
	monitorable = false
	monitoring = true


func setup(p_owner: Node3D, shape: Shape3D, offset: Vector3 = Vector3.ZERO) -> void:
	owner_actor = p_owner
	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		add_child(_shape_node)
	_shape_node.shape = shape
	_shape_node.position = offset


func activate(info: DamageInfo, duration: float) -> void:
	_template = info
	_hit_times.clear()
	_elapsed = 0.0
	_time_left = duration
	_active = true
	_scan()  # overlaps already tracked: hit immediately if a target is inside


func deactivate() -> void:
	_active = false
	_template = null


func is_active() -> bool:
	return _active


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_scan()
	_time_left -= delta
	if _time_left <= 0.0:
		deactivate()


func _scan() -> void:
	if not _active or not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		if not _active:
			return
		_try_hit(body)


func _try_hit(body: Node3D) -> void:
	if body == owner_actor or not body.has_method("take_damage"):
		return
	var id := body.get_instance_id()
	if _hit_times.has(id):
		if rehit_interval <= 0.0 or _elapsed - float(_hit_times[id]) < rehit_interval:
			return
	if not Factions.can_damage(owner_actor, body):
		return
	_hit_times[id] = _elapsed
	var info := _template.copy()
	info.source = owner_actor
	var origin := owner_actor.global_position if is_instance_valid(owner_actor) else global_position
	var dir := body.global_position - origin
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -global_basis.z
	info.knockback = dir.normalized() * info.knockback_force
	info.hit_position = body.global_position + Vector3.UP * 0.9
	var result: int = body.take_damage(info)
	hit_landed.emit(body, result, info)
