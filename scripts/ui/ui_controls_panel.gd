class_name UiControlsPanel
extends UiWindow
## Read-only list of key bindings (from the live InputMap via UiKeys).


func _init() -> void:
	super._init("Controls", Vector2(640, 700))


func _ready() -> void:
	super._ready()
	var list := add_scroll()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	var look := UiTheme.label("Look around")
	look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(look)
	grid.add_child(_keys("Mouse"))
	for action: StringName in UiKeys.CONTROL_ORDER:
		var t := UiKeys.hints(action)
		if t == "":
			continue
		var l := UiTheme.label(UiKeys.action_name(action))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		grid.add_child(_keys(t))
	var back := UiTheme.button("Back", 160)
	back.pressed.connect(func() -> void: close_requested.emit())
	footer.add_child(back)


func _keys(t: String) -> Label:
	var k := UiTheme.label(t)
	k.add_theme_color_override(&"font_color", UiTheme.GOLD)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return k
