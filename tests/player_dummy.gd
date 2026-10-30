extends CharacterBody3D
## Minimal damage target for player tests.

var hits := 0
var total_damage := 0.0
var faction: StringName = Factions.WOLF
var display_name := "Dummy"
var health: HealthComponent


func _init() -> void:
	collision_layer = Layers.ACTORS
	collision_mask = Layers.WORLD
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.2
	cs.shape = cap
	cs.position.y = 0.6
	add_child(cs)
	health = HealthComponent.new()
	health.max_health = 1000.0
	add_child(health)


func take_damage(info: DamageInfo) -> int:
	hits += 1
	total_damage += info.amount
	return DamageInfo.Result.HIT


func get_faction() -> StringName:
	return faction


func is_dead() -> bool:
	return false


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * 0.8
