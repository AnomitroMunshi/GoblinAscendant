class_name InputSetup
## Central input map. Every gameplay action is registered here so that
## keyboard/mouse, controller (and later touch) bindings live in one place.
## Actions already defined in project settings are left untouched.


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


static func bindings() -> Dictionary:
	return {
		&"move_forward": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		&"move_back": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		&"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		&"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		&"camera_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		&"camera_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		&"camera_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		&"camera_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		&"camera_reset": [_mouse(MOUSE_BUTTON_MIDDLE), _key(KEY_C), _joy(JOY_BUTTON_RIGHT_STICK)],
		&"sprint": [_key(KEY_SHIFT), _joy(JOY_BUTTON_LEFT_STICK)],
		&"jump": [_key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		&"attack_light": [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_X)],
		&"attack_heavy": [_mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_Y)],
		&"dodge": [_key(KEY_CTRL), _joy(JOY_BUTTON_B)],
		&"block": [_key(KEY_Q), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		&"interact": [_key(KEY_E), _joy(JOY_BUTTON_DPAD_UP)],
		&"lock_on": [_key(KEY_R), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		&"target_next": [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _joy(JOY_BUTTON_DPAD_RIGHT)],
		&"target_prev": [_mouse(MOUSE_BUTTON_WHEEL_UP), _joy(JOY_BUTTON_DPAD_LEFT)],
		&"ability_1": [_key(KEY_1), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		&"ability_2": [_key(KEY_2), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		&"ability_3": [_key(KEY_3), _joy(JOY_BUTTON_DPAD_DOWN)],
		&"character_menu": [_key(KEY_TAB), _joy(JOY_BUTTON_BACK)],
		&"pause": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		&"quick_save": [_key(KEY_F5)],
		&"quick_load": [_key(KEY_F9)],
	}


static func ensure_actions() -> void:
	var map := bindings()
	for action: StringName in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		for ev: InputEvent in map[action]:
			InputMap.action_add_event(action, ev)
