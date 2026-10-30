extends CharacterBody3D
## Minimal stand-in player for combat tests (Combat agent).

var hits: Array = []          # [{source, amount, time, attack_id}]
var dead := false
var faction: StringName = Factions.PLAYER
var health: HealthComponent


func _init() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ACTORS
	add_to_group(&"player")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.1
	cs.shape = cap
	cs.position.y = 0.55
	add_child(cs)
	health = HealthComponent.new()
	health.max_health = 100000.0
	add_child(health)


func get_faction() -> StringName:
	return faction


func is_dead() -> bool:
	return dead


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * 0.8


func take_damage(info: DamageInfo) -> int:
	if dead:
		return DamageInfo.Result.IGNORED
	hits.append({"source": info.source, "amount": info.amount, "time": Time.get_ticks_msec(), "attack_id": info.attack_id})
	return DamageInfo.Result.HIT


func hits_from(src: Node) -> int:
	var n := 0
	for h: Dictionary in hits:
		if h["source"] == src:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
