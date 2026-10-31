extends Node3D
## Stand-in actor / player / ability controller for UI tests (UI agent).

var display_name := "Grey Wolf"
var health: HealthComponent
var stamina := 80.0
var energy := 20.0
var cooldowns := [0.0, 0.55, 0.0]


func _init() -> void:
	health = HealthComponent.new()
	health.max_health = 120.0
	add_child(health)


func is_dead() -> bool:
	return health.is_dead()


# --- AbilityController-like API ---
func get_ability_id(slot: int) -> StringName:
	return Progression.get_equipped(slot)


func get_cooldown_ratio(slot: int) -> float:
	return cooldowns[slot]


func get_cooldown_remaining(slot: int) -> float:
	return cooldowns[slot] * 10.0


func get_cooldown_total(_slot: int) -> float:
	return 10.0


func get_energy_cost(slot: int) -> float:
	return [15.0, 30.0, 40.0][slot]
