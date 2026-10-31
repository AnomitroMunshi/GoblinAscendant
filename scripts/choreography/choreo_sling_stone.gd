class_name ChoreoSlingStone
extends Node3D
## Player-owned sling projectile. Carries a Hitbox (once per target, LOS and
## faction rules unchanged) and stops at the first body it damages or at WORLD
## geometry. Swept with a ray each physics frame so it cannot tunnel through walls.

const GRAVITY := 4.5   # light arc; stones drop a little over long range

var hitbox: Hitbox
var velocity := Vector3.ZERO
var _life := 1.0
var _owner_actor: Node3D
var _done := false


static func launch(owner_actor: Node3D, from: Vector3, dir: Vector3, speed: float, max_range: float, info: DamageInfo, radius: float = 0.14) -> ChoreoSlingStone:
	var host: Node = owner_actor.get_tree().current_scene if owner_actor.is_inside_tree() else null
	if host == null:
		host = owner_actor.get_parent()
	var s := ChoreoSlingStone.new()
	s.name = "SlingStone"
	s._owner_actor = owner_actor
	s.velocity = dir.normalized() * speed
	s._life = max_range / maxf(speed, 0.1)
	host.add_child(s)
	s.global_position = from
	s.hitbox = Hitbox.new()
	s.hitbox.name = "Hitbox"
	s.add_child(s.hitbox)
	var shape := SphereShape3D.new()
	shape.radius = radius
	s.hitbox.setup(owner_actor, shape, Vector3.ZERO)
	s.hitbox.hit_landed.connect(s._on_hit)
	s.hitbox.activate(info, s._life + 0.1)
	s.add_child(ChoreoWeapons.stone_mesh())
	return s


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		_finish(true)
		return
	global_position = to
	if _life <= 0.0:
		_finish(false)


func _on_hit(_target: Node3D, result: int, _info: DamageInfo) -> void:
	if result != DamageInfo.Result.IGNORED:
		_finish(false)


func _finish(spark: bool) -> void:
	if _done:
		return
	_done = true
	if hitbox:
		hitbox.deactivate()
	if spark and is_instance_valid(_owner_actor):
		PlayerFx.impact(_owner_actor, global_position, false, Color(0.85, 0.8, 0.7))
	queue_free.call_deferred()
