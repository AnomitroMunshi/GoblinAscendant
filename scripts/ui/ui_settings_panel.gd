class_name UiSettingsPanel
extends UiWindow
## Settings menu: reads/writes Settings.get_value/set_value, Reset to defaults.

## [key, label, type, min, max, step, format]; type: slider / check / option / header
const ROWS := [
	["", "Controls", "header"],
	[&"mouse_sensitivity", "Mouse sensitivity", "slider", 0.05, 1.0, 0.01, "%.2f"],
	[&"invert_y", "Invert camera Y", "check"],
	["", "Camera", "header"],
	[&"camera_distance", "Camera distance", "slider", 2.5, 8.0, 0.1, "%.1f m"],
	[&"fov", "Field of view", "slider", 55.0, 100.0, 1.0, "%d°"],
	[&"camera_shake", "Camera shake", "slider", 0.0, 1.0, 0.05, "pct"],
	["", "Graphics", "header"],
	[&"graphics_quality", "Quality", "option", ["Low", "Medium", "High"]],
	[&"view_distance", "View distance", "slider", 0.5, 1.5, 0.05, "pct"],
	[&"render_scale", "Render scale", "slider", 0.5, 1.0, 0.05, "pct"],
	[&"vsync", "V-Sync", "check"],
	[&"fullscreen", "Fullscreen", "check"],
	[&"show_fps", "Show FPS", "check"],
	[&"ui_scale", "Interface scale", "slider", 0.8, 1.4, 0.05, "pct"],
	["", "Audio", "header"],
	[&"master_volume", "Master volume", "slider", 0.0, 1.0, 0.01, "pct"],
	[&"music_volume", "Music volume", "slider", 0.0, 1.0, 0.01, "pct"],
	[&"sfx_volume", "Effects volume", "slider", 0.0, 1.0, 0.01, "pct"],
	[&"ambience_volume", "Ambience volume", "slider", 0.0, 1.0, 0.01, "pct"],
]

var _controls: Dictionary = {}   # key -> [control, value_label, format]
var _refreshing := false


func _init() -> void:
	super._init("Settings", Vector2(760, 720))


func _ready() -> void:
	super._ready()
	var list := add_scroll()
	for row: Array in ROWS:
		_add_row(list, row)
	var reset := UiTheme.button("Reset to Defaults", 220)
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		refresh())
	footer.add_child(reset)
	var back := UiTheme.button("Back", 160)
	back.pressed.connect(func() -> void: close_requested.emit())
	footer.add_child(back)
	Settings.changed.connect(func(_k: StringName) -> void:
		if visible and not _refreshing:
			refresh())
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())
	refresh()


func _add_row(list: VBoxContainer, row: Array) -> void:
	var type: String = row[2]
	if type == "header":
		var h := UiTheme.label(row[1], &"SectionLabel")
		if list.get_child_count() > 0:
			var sp := Control.new()
			sp.custom_minimum_size.y = 6
			list.add_child(sp)
		list.add_child(h)
		return
	var key: StringName = row[0]
	var hb := HBoxContainer.new()
	hb.custom_minimum_size.y = 44
	hb.add_theme_constant_override(&"separation", 14)
	list.add_child(hb)
	var l := UiTheme.label(row[1])
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(l)
	match type:
		"slider":
			var s := HSlider.new()
			s.min_value = row[3]
			s.max_value = row[4]
			s.step = row[5]
			s.custom_minimum_size = Vector2(280, 32)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			s.focus_mode = Control.FOCUS_ALL
			hb.add_child(s)
			var vl := UiTheme.label("", &"SmallLabel")
			vl.custom_minimum_size.x = 64
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hb.add_child(vl)
			_controls[key] = [s, vl, row[6]]
			s.value_changed.connect(func(v: float) -> void:
				vl.text = _fmt(row[6], v)
				# Interface scale is applied when the drag ends (the panel would rescale under the cursor).
				if key == &"ui_scale" and s.has_meta(&"dragging"):
					return
				_write(key, v))
			s.drag_started.connect(func() -> void: s.set_meta(&"dragging", true))
			s.drag_ended.connect(func(_c: bool) -> void:
				s.remove_meta(&"dragging")
				_write(key, s.value))
		"check":
			var c := CheckButton.new()
			c.focus_mode = Control.FOCUS_ALL
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			c.toggled.connect(func(on: bool) -> void:
				Audio.play_sfx(&"ui_click", null, -8.0, 0.03)
				_write(key, on))
			hb.add_child(c)
			var sp := Control.new()
			sp.custom_minimum_size.x = 64
			hb.add_child(sp)
			_controls[key] = [c, null, ""]
		"option":
			var o := OptionButton.new()
			for item: String in row[3]:
				o.add_item(item)
			o.custom_minimum_size = Vector2(200, 44)
			o.item_selected.connect(func(i: int) -> void: _write(key, i))
			hb.add_child(o)
			var sp2 := Control.new()
			sp2.custom_minimum_size.x = 64
			hb.add_child(sp2)
			_controls[key] = [o, null, ""]


func _fmt(f: String, v: float) -> String:
	if f == "pct":
		return "%d%%" % roundi(v * 100.0)
	if f.contains("%d"):
		return f % roundi(v)
	return f % v


func _write(key: StringName, v: Variant) -> void:
	if _refreshing:
		return
	var cur: Variant = Settings.get_value(key)
	if typeof(cur) == TYPE_INT:
		v = int(v)
	elif typeof(cur) == TYPE_FLOAT:
		v = float(v)
	elif typeof(cur) == TYPE_BOOL:
		v = bool(v)
	_refreshing = true
	Settings.set_value(key, v)
	_refreshing = false


func refresh() -> void:
	_refreshing = true
	for key: StringName in _controls:
		var entry: Array = _controls[key]
		var v: Variant = Settings.get_value(key)
		var c: Control = entry[0]
		if c is HSlider:
			(c as HSlider).set_value_no_signal(float(v))
			(entry[1] as Label).text = _fmt(entry[2], float(v))
		elif c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(bool(v))
		elif c is OptionButton:
			(c as OptionButton).select(clampi(int(v), 0, (c as OptionButton).item_count - 1))
	_refreshing = false
