class_name UiPauseMenu
extends UiWindow
## Pause menu. Emits `action(id)`; UiRoot performs it.
## ids: resume, save, load, settings, controls, title, quit

signal action(id: StringName)

var feedback: Label
var load_button: Button
var save_button: Button


func _init() -> void:
	super._init("Paused", Vector2(420, 0))


func _ready() -> void:
	super._ready()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "Resume (Esc)"
	close_requested.connect(func() -> void: action.emit(&"resume"))
	for entry: Array in [
		[&"resume", "Resume"], [&"save", "Save Game"], [&"load", "Load Game"],
		[&"settings", "Settings"], [&"controls", "Controls"],
		[&"title", "Quit to Title"], [&"quit", "Quit Game"],
	]:
		var id: StringName = entry[0]
		var b := UiTheme.button(entry[1], 0, 50)
		b.pressed.connect(func() -> void: action.emit(id))
		content.add_child(b)
		if id == &"load":
			load_button = b
		elif id == &"save":
			save_button = b
	feedback = UiTheme.label("", &"SmallLabel", 16)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.custom_minimum_size.y = 24
	content.add_child(feedback)
	visibility_changed.connect(_on_shown)


func _on_shown() -> void:
	if not visible:
		return
	feedback.text = ""
	load_button.disabled = not SaveManager.has_save()
	save_button.disabled = GameState.is_player_dead()
	content.get_child(0).grab_focus.call_deferred()


func show_feedback(text: String, ok: bool) -> void:
	feedback.text = text
	feedback.add_theme_color_override(&"font_color", UiTheme.GOOD if ok else UiTheme.BAD)
	load_button.disabled = not SaveManager.has_save()
