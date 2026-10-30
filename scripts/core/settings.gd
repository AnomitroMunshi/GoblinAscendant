extends Node
## Player-facing settings, persisted to user://settings.cfg.
## Lead-owned. Systems read values with get_value() and react to `changed`.
##   Camera reads: mouse_sensitivity, invert_y, camera_distance, fov, camera_shake
##   World reads:  graphics_quality (0 low, 1 medium, 2 high), view_distance
##   Audio reads:  *_volume
## Display values (vsync, fullscreen, render_scale, msaa) are applied here.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	&"mouse_sensitivity": 0.25,   # degrees per pixel of mouse motion
	&"invert_y": false,
	&"camera_distance": 4.6,
	&"fov": 70.0,
	&"camera_shake": 1.0,         # 0..1 multiplier
	&"graphics_quality": 2,       # 0 low, 1 medium, 2 high
	&"view_distance": 1.0,        # 0.5..1.5 multiplier on culling distances
	&"render_scale": 1.0,
	&"vsync": true,
	&"fullscreen": false,
	&"show_fps": false,
	&"master_volume": 0.8,
	&"music_volume": 0.55,
	&"sfx_volume": 0.8,
	&"ambience_volume": 0.7,
	&"touch_controls": 0,         # 0 auto-detect, 1 always on, 2 off
	&"touch_look_sensitivity": 0.18,  # degrees per pixel of touch drag
	&"ui_scale": 1.0,             # 0.8..1.4; larger on phones
	&"lock_on_assist": false,     # auto-acquire a lock target when attacking (mobile-friendly)
}

## Platform-dependent defaults applied before the user's saved values.
const MOBILE_DEFAULTS := {
	&"graphics_quality": 0,
	&"view_distance": 0.7,
	&"render_scale": 0.8,
	&"ui_scale": 1.2,
	&"lock_on_assist": true,
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_mobile():
		for key: StringName in MOBILE_DEFAULTS:
			values[key] = MOBILE_DEFAULTS[key]
	load_settings()
	apply_display()
	InputSetup.apply_touch_profile(use_touch_controls())


## True on Android/iOS builds (and the web on touch devices).
func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Whether the on-screen touch controls should be shown and touch input used.
func use_touch_controls() -> bool:
	match int(get_value(&"touch_controls", 0)):
		1: return true
		2: return false
	return is_mobile() or (DisplayServer.is_touchscreen_available() and not OS.has_feature("pc"))


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return values.get(key, DEFAULTS.get(key, fallback))


func quality() -> int:
	return int(get_value(&"graphics_quality", 2))


func set_value(key: StringName, value: Variant) -> void:
	if values.get(key) == value:
		return
	values[key] = value
	if key in [&"vsync", &"fullscreen", &"render_scale", &"graphics_quality"]:
		apply_display()
	if key == &"touch_controls":
		InputSetup.apply_touch_profile(use_touch_controls())
	changed.emit(key)
	save_settings()


func reset_defaults() -> void:
	values = DEFAULTS.duplicate()
	if is_mobile():
		for key: StringName in MOBILE_DEFAULTS:
			values[key] = MOBILE_DEFAULTS[key]
	InputSetup.apply_touch_profile(use_touch_controls())
	apply_display()
	for key: StringName in values:
		changed.emit(key)
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key: StringName in DEFAULTS:
		var v: Variant = cfg.get_value("settings", String(key), DEFAULTS[key])
		# Reject values of the wrong type (hand-edited or corrupt file).
		if typeof(v) == typeof(DEFAULTS[key]) or (typeof(DEFAULTS[key]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
			values[key] = v


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: StringName in values:
		cfg.set_value("settings", String(key), values[key])
	cfg.save(PATH)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_mobile():
		var vp_m := get_viewport()
		if vp_m:
			vp_m.scaling_3d_scale = clampf(float(get_value(&"render_scale")), 0.5, 1.0)
			vp_m.msaa_3d = Viewport.MSAA_DISABLED if quality() == 0 else Viewport.MSAA_2X
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value(&"vsync") else DisplayServer.VSYNC_DISABLED)
	var want_full: bool = get_value(&"fullscreen")
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(float(get_value(&"render_scale")), 0.5, 1.0)
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(quality(), 0, 2)]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality() == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
