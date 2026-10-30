class_name AbilityLibrary
## Registry of every ability / passive unlock. Add new abilities here (data only);
## AbilityController implements the behaviour per id.

const WOLF_DASH := &"wolf_dash"
const STONE_GUARD := &"stone_guard"
const FLAME_BURST := &"flame_burst"
const SHOCKWAVE_SLAM := &"shockwave_slam"   # passive (Hobgoblin)

# Tuning (also read by AbilityController).
const DASH_SPEED := 18.0
const DASH_DURATION := 0.25
const STONE_GUARD_DURATION := 6.0
const STONE_GUARD_MULTIPLIER := 0.4        # 60 % damage reduction
const FLAME_DAMAGE_MULT := 1.6             # x Progression.attack_power()
const FLAME_RANGE := 4.2
const FLAME_WIDTH := 3.4

static var _all: Dictionary = {}


static func _build() -> void:
	if not _all.is_empty():
		return
	for a: AbilityData in [
		AbilityData.make(WOLF_DASH, "Wolf Dash",
			"A swift forward burst, untouchable while dashing.",
			25.0, 4.0, Color(0.70, 0.88, 1.0), "»", &"dash"),
		AbilityData.make(STONE_GUARD, "Stone Guard",
			"Harden your skin into stone: take 60% less damage for 6 seconds.",
			35.0, 14.0, Color(0.85, 0.62, 0.28), "◆", &"stone_guard"),
		AbilityData.make(FLAME_BURST, "Flame Burst",
			"Exhale a short cone of fire in front of you.",
			30.0, 7.0, Color(1.0, 0.55, 0.15), "▲", &"flame"),
		AbilityData.make(SHOCKWAVE_SLAM, "Shockwave Slam",
			"Passive: heavy attacks send out a shockwave.",
			0.0, 0.0, Color(0.55, 0.85, 1.0), "◎", &"", false),
	]:
		_all[a.id] = a


static func get_ability(id: StringName) -> AbilityData:
	_build()
	return _all.get(id)


static func exists(id: StringName) -> bool:
	_build()
	return _all.has(id)


static func is_slottable(id: StringName) -> bool:
	var a := get_ability(id)
	return a != null and a.slottable


static func all_ids() -> Array[StringName]:
	_build()
	var out: Array[StringName] = []
	for k: StringName in _all:
		out.append(k)
	return out
