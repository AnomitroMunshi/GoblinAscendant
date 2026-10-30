extends Node
## Experience, levels, stat upgrades, abilities, essences, discoveries,
## inventory and evolution. OWNER: Progression & Quest agent.
## (Lead stub: this is the public API other agents rely on. Keep signatures.)

var level := 1
var xp := 0
var upgrade_points := 0
var stage: StringName = &"goblin"            # &"goblin" -> &"hobgoblin" (future: more stages)
var unlocked_abilities: Array[StringName] = []
var equipped: Array[StringName] = [&"", &"", &""]  # ability ids in slots 1..3
var discovered: Array[StringName] = []
var inventory: Dictionary = {}               # StringName item_id -> int


func _ready() -> void:
	SaveManager.register("progression", self)


func max_health() -> float: return 100.0
func max_stamina() -> float: return 100.0
func max_energy() -> float: return 100.0
## Base damage for a light attack; heavy attacks multiply this.
func attack_power() -> float: return 12.0
func xp_to_next_level() -> int: return 100
func is_evolved() -> bool: return stage != &"goblin"
func has_ability(id: StringName) -> bool: return unlocked_abilities.has(id)
func get_equipped(slot: int) -> StringName: return equipped[slot] if slot >= 0 and slot < equipped.size() else &""
## Passive unlocks (e.g. &"shockwave_slam" from Hobgoblin evolution).
func has_unlock(_id: StringName) -> bool: return false
func add_xp(_amount: int, _reason: String = "") -> void: pass
func unlock_ability(_id: StringName) -> void: pass
func get_save_data() -> Dictionary: return {}
func load_save_data(_d: Dictionary) -> void: pass
func reset() -> void: pass
