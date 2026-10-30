extends CharacterBody3D
## Hostile target for the Flame Burst hitbox test.

var hits: Array = []


func _init() -> void:
	collision_layer = Layers.ACTORS
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.5
	cs.shape = s
	add_child(cs)


func get_faction() -> StringName: return Factions.WOLF
func is_dead() -> bool: return false


func take_damage(info: DamageInfo) -> int:
	hits.append(info)
	return DamageInfo.Result.HIT
