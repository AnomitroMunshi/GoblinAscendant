extends Node3D
## Stand-in implementing the documented Player API for AbilityController tests.

var energy := 100.0
var damage_taken_multiplier := 1.0
var busy := false
var dead := false
var dash_calls: Array = []
var cast_calls := 0


func get_faction() -> StringName: return Factions.PLAYER
func is_dead() -> bool: return dead
func is_busy() -> bool: return busy
func get_facing() -> Vector3: return Vector3.FORWARD
func get_cast_origin() -> Vector3: return global_position + Vector3.UP + Vector3.FORWARD * 0.6
func play_cast_animation() -> void: cast_calls += 1
func take_damage(_info: DamageInfo) -> int: return DamageInfo.Result.IGNORED


func spend_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


func begin_dash(direction: Vector3, speed: float, duration: float, invulnerable: bool) -> void:
	dash_calls.append([direction, speed, duration, invulnerable])
