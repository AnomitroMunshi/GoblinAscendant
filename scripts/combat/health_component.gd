class_name HealthComponent
extends Node
## Health pool used by the player, enemies and NPCs. Lead-owned.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died
signal revived

@export var max_health := 100.0
var health := 100.0
var _dead := false


func _ready() -> void:
	health = max_health


func set_max_health(value: float, refill: bool = false) -> void:
	var ratio := health / max_health if max_health > 0.0 else 1.0
	max_health = maxf(1.0, value)
	health = max_health if refill else clampf(ratio * max_health, 0.0, max_health)
	health_changed.emit(health, max_health)


## Returns true if this damage killed the owner.
func apply_damage(amount: float) -> bool:
	if _dead or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_dead = true
		died.emit()
		return true
	return false


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	var before := health
	health = minf(max_health, health + amount)
	if health > before:
		healed.emit(health - before)
		health_changed.emit(health, max_health)


func revive(fraction: float = 1.0) -> void:
	_dead = false
	health = clampf(max_health * fraction, 1.0, max_health)
	revived.emit()
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return _dead


func ratio() -> float:
	return health / max_health if max_health > 0.0 else 0.0
