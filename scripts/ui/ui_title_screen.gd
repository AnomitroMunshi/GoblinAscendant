class_name UiTitleScreen
extends Control
## Title screen drawn over the live world (soft dark gradient backdrop is
## provided by UiRoot). Emits `action(id)`: continue, new_game, settings, quit.

signal action(id: StringName)

var continue_button: Button
var new_button: Button
var _confirm_new := false


func _ready() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.anchor_left = 0.08
	col.anchor_right = 0.08
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override(&"separation", 6)
	add_child(col)
	var t := UiTheme.label("Goblin Ascendant", &"TitleLabel")
	col.add_child(t)
	var sub := UiTheme.label("Chapter 1 — A Small Beginning", &"SectionLabel", 26)
	sub.add_theme_color_override(&"font_color", Color(0.93, 0.88, 0.76))
	sub.add_theme_constant_override(&"outline_size", 2)
	col.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(UiTheme.GOLD, 0.6)
	line.custom_minimum_size = Vector2(420, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(line)
	var sp := Control.new()
	sp.custom_minimum_size.y = 26
	col.add_child(sp)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)
	continue_button = UiTheme.button("Continue", 340, 54)
	continue_button.pressed.connect(func() -> void: action.emit(&"continue"))
	buttons.add_child(continue_button)
	new_button = UiTheme.button("New Game", 340, 54)
	new_button.pressed.connect(_on_new)
	buttons.add_child(new_button)
	var settings := UiTheme.button("Settings", 340, 54)
	settings.pressed.connect(func() -> void: action.emit(&"settings"))
	buttons.add_child(settings)
	var quit := UiTheme.button("Quit", 340, 54)
	quit.pressed.connect(func() -> void: action.emit(&"quit"))
	buttons.add_child(quit)
	var ver := UiTheme.label("Chapter 1  ·  Godot %s" % Engine.get_version_info().get("string", ""), &"SmallLabel", 13)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -18
	ver.offset_bottom = -12
	add_child(ver)
	visibility_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not visible:
		return
	_confirm_new = false
	new_button.text = "New Game"
	continue_button.visible = SaveManager.has_save()
	(continue_button if continue_button.visible else new_button).grab_focus.call_deferred()


func _on_new() -> void:
	if SaveManager.has_save() and not _confirm_new:
		_confirm_new = true
		new_button.text = "Start over? Click to confirm"
		return
	action.emit(&"new_game")
