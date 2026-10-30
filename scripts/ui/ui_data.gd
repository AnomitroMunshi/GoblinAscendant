class_name UiData
extends RefCounted
## Read-only lookups the UI needs from other systems, accessed defensively
## (other agents own those scripts; everything is guarded so the UI never
## errors if an API is missing or still a stub).

const ABILITY_LIBRARY := "res://scripts/abilities/ability_library.gd"

## Fallback display data when AbilityLibrary is unavailable.
const FALLBACK_ABILITIES := {
	&"wolf_dash": {"name": "Wolf Dash", "desc": "A swift forward burst, untouchable while dashing.", "color": Color(0.70, 0.88, 1.0), "glyph": "»"},
	&"stone_guard": {"name": "Stone Guard", "desc": "Harden your skin into stone to shrug off blows.", "color": Color(0.85, 0.62, 0.28), "glyph": "◆"},
	&"flame_burst": {"name": "Flame Burst", "desc": "Exhale a short cone of fire.", "color": Color(1.0, 0.55, 0.15), "glyph": "▲"},
	&"shockwave_slam": {"name": "Shockwave Slam", "desc": "Passive: heavy attacks send out a shockwave.", "color": Color(0.55, 0.85, 1.0), "glyph": "◎"},
}

static var _lib: Script
static var _lib_checked := false
static var _info_cache: Dictionary = {}


## {name, desc, color, glyph, cost, cooldown} for an ability / passive id.
static func ability_info(id: StringName) -> Dictionary:
	if id == &"":
		return {}
	if _info_cache.has(id):
		return _info_cache[id]
	var info: Dictionary = FALLBACK_ABILITIES.get(id, {"name": String(id).capitalize(), "desc": "", "color": Color(0.8, 0.8, 0.8), "glyph": "?"}).duplicate()
	info["cost"] = 0.0
	info["cooldown"] = 0.0
	var lib := _library()
	if lib:
		var d: Variant = lib.call(&"get_ability", id)
		if d is Resource:
			var r := d as Resource
			info["name"] = str(r.get(&"display_name"))
			info["desc"] = str(r.get(&"description"))
			if r.get(&"icon_color") is Color:
				info["color"] = r.get(&"icon_color")
			info["glyph"] = str(r.get(&"icon_glyph"))
			info["cost"] = float(r.get(&"energy_cost"))
			info["cooldown"] = float(r.get(&"cooldown"))
	_info_cache[id] = info
	return info


static func _library() -> Script:
	if not _lib_checked:
		_lib_checked = true
		if ResourceLoader.exists(ABILITY_LIBRARY):
			var s: Variant = load(ABILITY_LIBRARY)
			if s is Script:
				_lib = s
	return _lib


static func item_name(id: StringName) -> String:
	if Progression.has_method(&"get_item_name"):
		return str(Progression.call(&"get_item_name", id))
	return String(id).replace("_", " ").capitalize()


static func stage_name() -> String:
	if Progression.has_method(&"get_stage_name"):
		return str(Progression.call(&"get_stage_name"))
	return String(Progression.stage).capitalize()


static func quest_title(id: StringName) -> String:
	if Quests.has_method(&"get_quest_log"):
		for q: Variant in Quests.call(&"get_quest_log"):
			if q is Dictionary and (q as Dictionary).get("id") == id:
				return str((q as Dictionary).get("title", ""))
	return String(id).replace("_", " ").capitalize()


static func ability_controller() -> Node:
	var ac: Node = GameState.ability_controller
	return ac if is_instance_valid(ac) else null


static func equipped(slot: int) -> StringName:
	var ac := ability_controller()
	if ac and ac.has_method(&"get_ability_id"):
		return ac.call(&"get_ability_id", slot)
	if Progression.has_method(&"get_equipped"):
		return Progression.get_equipped(slot)
	return &""
