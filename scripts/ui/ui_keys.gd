class_name UiKeys
extends RefCounted
## Single place for key-hint strings shown in the UI (prompts, ability slots,
## controls list). Reads the live InputMap so rebinding updates every hint.

const ACTION_NAMES := {
	&"move_forward": "Move forward", &"move_back": "Move back", &"move_left": "Move left",
	&"move_right": "Move right", &"sprint": "Sprint", &"jump": "Jump",
	&"attack_light": "Light attack", &"attack_heavy": "Heavy attack", &"dodge": "Dodge roll",
	&"holster": "Draw / holster weapon", &"block": "Block", &"interact": "Interact", &"lock_on": "Lock on / release",
	&"target_next": "Next target", &"target_prev": "Previous target",
	&"ability_1": "Ability 1", &"ability_2": "Ability 2", &"ability_3": "Ability 3",
	&"camera_reset": "Reset camera", &"character_menu": "Character", &"pause": "Pause menu",
	&"quick_save": "Quick save", &"quick_load": "Quick load",
}
const CONTROL_ORDER := [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump",
	&"attack_light", &"attack_heavy", &"holster", &"block", &"dodge", &"interact", &"lock_on",
	&"target_next", &"target_prev", &"ability_1", &"ability_2", &"ability_3",
	&"camera_reset", &"character_menu", &"pause", &"quick_save", &"quick_load",
]

static var _cache: Dictionary = {}


## Short label of the first keyboard/mouse binding of an action ("E", "LMB", "Tab").
static func hint(action: StringName) -> String:
	if _cache.has(action):
		return _cache[action]
	var out := ""
	if InputMap.has_action(action):
		for ev: InputEvent in InputMap.action_get_events(action):
			var s := event_text(ev)
			if s != "" and not (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
				out = s
				break
	_cache[action] = out
	return out


## All keyboard/mouse bindings of an action, joined ("W / Up").
static func hints(action: StringName) -> String:
	var parts: PackedStringArray = []
	if InputMap.has_action(action):
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				continue
			var s := event_text(ev)
			if s != "" and not parts.has(s):
				parts.append(s)
	return " / ".join(parts)


static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		match code:
			KEY_ESCAPE: return "Esc"
			KEY_SPACE: return "Space"
			KEY_CTRL: return "Ctrl"
			KEY_SHIFT: return "Shift"
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
	return ""


static func action_name(action: StringName) -> String:
	return ACTION_NAMES.get(action, String(action).capitalize())


## Splits a prompt such as "[E] Read signpost" into [key, text]. A prompt
## without a bracketed key gets the live `interact` binding.
static func split_prompt(text: String) -> PackedStringArray:
	var t := text.strip_edges()
	if t.begins_with("["):
		var close := t.find("]")
		if close > 0:
			return PackedStringArray([t.substr(1, close - 1), t.substr(close + 1).strip_edges()])
	return PackedStringArray([hint(&"interact"), t])


static func clear_cache() -> void:
	_cache.clear()
