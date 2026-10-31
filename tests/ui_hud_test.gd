extends Node
## Headless UI test (UI agent). Run:
##   "$G" --headless --path . res://tests/ui_hud_test.tscn
## Instantiates UiRoot, drives it with Events and input actions, asserts
## visibility / pause / menu state, and fails on any engine error logged.

const Dummy := preload("res://tests/ui_dummy.gd")


class ErrCounter extends Logger:
	var count := 0
	var messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		count += 1
		messages.append("%s (%s:%d %s) %s" % [code, file, line, function, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var failures := 0
var ui: UiRoot
var logger := ErrCounter.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(logger)
	# Preserve the developer's real save; the test saves through the pause menu.
	var backup := FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""
	GameState.show_title = false
	ui = UiRoot.new()
	add_child(ui)
	await _frames(3)
	check(ui.mode == UiRoot.Mode.PLAY, "starts in PLAY")
	check(ui.hud.visible, "hud visible")
	check(not GameState.menu_open, "menu closed at start")

	# --- stats / bars
	Events.player_stats_changed.emit(40.0, 100.0, 50.0, 100.0, 10.0, 100.0)
	await _frames(2)
	check(is_equal_approx(ui.hud.hp_bar.ratio, 0.4), "hp ratio 0.4")
	check(ui.hud.hp_bar.chip > ui.hud.hp_bar.shown - 0.001, "chip trails behind fill")
	Events.player_stats_changed.emit(10.0, 100.0, 50.0, 100.0, 10.0, 100.0)
	await _frames(2)
	check(ui.hud.hp_bar.pulse, "low hp pulse")
	Events.player_damaged.emit(DamageInfo.new())
	await _frames(2)
	check(ui.vignette.visible, "damage vignette")

	# --- abilities with a fake controller
	var dummy_player: Node3D = Dummy.new()
	add_child(dummy_player)
	GameState.player = dummy_player
	GameState.ability_controller = dummy_player
	Progression.unlock_ability(&"wolf_dash")
	Progression.unlock_ability(&"stone_guard")
	await _frames(3)
	check(ui.hud.slots[0].ability_id == &"wolf_dash", "slot 1 shows wolf_dash")
	check(ui.hud.slots[1]._cd_ratio > 0.5, "slot 2 cooling down")
	check(ui.hud.slots[0]._no_energy == false and ui.hud.slots[1]._no_energy == true, "energy dimming")
	check(ui.hud.slots[2].ability_id == &"", "slot 3 locked")
	Events.ability_used.emit(0, &"wolf_dash")
	Events.ability_failed.emit(1, "Not enough energy")
	await _frames(2)
	check(ui.hud.slots[0]._flash > 0.0, "slot flash on use")
	check(ui.hud.slots[1]._shake > 0.0, "slot shake on fail")

	# --- toasts (max 5 stacked)
	for i in 7:
		Events.notify.emit("Toast %d" % i, [&"info", &"quest", &"xp", &"warning", &"essence"][i % 5])
	await _frames(2)
	check(ui.hud.toasts.get_child_count() <= HudRoot.MAX_TOASTS, "toasts capped")

	# --- banners
	Events.level_up.emit(3)
	await _frames(2)
	check(ui.hud._banner_busy, "banner queued/showing")

	# --- objective + prompt
	Events.objective_changed.emit("Find Nib")
	Events.interaction_prompt_changed.emit("[E] Read signpost")
	await _frames(2)
	check(ui.hud.prompt_panel.visible and ui.hud.prompt_key.text == "E" and ui.hud.prompt_text.text == "Read signpost", "prompt split into keycap + text")
	Events.interaction_prompt_changed.emit("")
	await _frames(1)
	check(not ui.hud.prompt_panel.visible, "prompt hidden")

	# --- boss bar
	var boss: Node3D = Dummy.new()
	boss.display_name = "Gorrak the Ogre"
	boss.add_to_group(&"boss")
	add_child(boss)
	Events.boss_engaged.emit(boss)
	Events.boss_health_changed.emit(300.0, 600.0)
	await _frames(2)
	check(ui.hud.boss_box.visible, "boss bar visible")
	check(is_equal_approx(ui.hud.boss_bar.ratio, 0.5), "boss ratio 0.5")
	check(ui.hud.boss_name.text == "Gorrak the Ogre", "boss name")
	Events.lock_target_changed.emit(boss)
	await _frames(1)
	check(not ui.hud.lock_box.visible, "lock bar suppressed for boss")
	Events.boss_defeated.emit(boss)
	await _wait(2.8)
	check(not ui.hud.boss_box.visible, "boss bar hidden after defeat")

	# --- lock target
	var wolf: Node3D = Dummy.new()
	add_child(wolf)
	wolf.health.apply_damage(60.0)
	Events.lock_target_changed.emit(wolf)
	await _frames(2)
	check(ui.hud.lock_box.visible and ui.hud.lock_name.text == "Grey Wolf", "lock bar visible")
	check(is_equal_approx(ui.hud.lock_bar.ratio, 0.5), "lock ratio 0.5")
	wolf.queue_free()
	await _frames(2)
	check(not ui.hud.lock_box.visible, "lock bar hides when target freed")
	Events.lock_target_changed.emit(null)

	# --- death / respawn
	Events.player_died.emit()
	await _frames(2)
	check(ui.death_screen.visible, "death screen")
	Events.player_respawned.emit()
	await _wait(0.9)
	check(not ui.death_screen.visible, "death screen cleared")

	# --- pause via input action
	_press(&"pause")
	await _frames(2)
	check(ui.mode == UiRoot.Mode.PAUSE and get_tree().paused and GameState.menu_open, "pause opened (tree paused, menu open)")
	check(ui.pause_menu.visible, "pause menu visible")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse visible in pause")
	ui._on_pause_action(&"save")
	await _frames(1)
	check(ui.pause_menu.feedback.text != "", "save feedback shown")
	ui._on_pause_action(&"settings")
	await _frames(2)
	check(ui.settings_panel.visible and not ui.pause_menu.visible, "settings over pause")
	_press(&"pause")
	await _frames(2)
	check(not ui.settings_panel.visible and ui.pause_menu.visible and get_tree().paused, "esc closes settings first")
	ui._on_pause_action(&"controls")
	await _frames(1)
	check(ui.controls_panel.visible, "controls panel")
	_press(&"pause")
	await _frames(1)
	_press(&"pause")
	await _frames(2)
	check(ui.mode == UiRoot.Mode.PLAY and not get_tree().paused and not GameState.menu_open, "resumed")

	# --- settings write-through
	var s := ui.settings_panel._controls[&"fov"][0] as HSlider
	var old_fov: Variant = Settings.get_value(&"fov")
	s.value = 85.0
	check(is_equal_approx(float(Settings.get_value(&"fov")), 85.0), "slider writes Settings")
	Settings.set_value(&"fov", old_fov)
	Settings.set_value(&"show_fps", true)
	await _frames(20)
	check(ui.fps_label.visible, "fps label shown")
	Settings.set_value(&"show_fps", false)

	# --- character panel
	_press(&"character_menu")
	await _frames(3)
	check(ui.mode == UiRoot.Mode.CHARACTER and GameState.menu_open and not get_tree().paused, "character open, world not paused")
	Events.stats_upgraded.emit()
	await _frames(2)
	_press(&"pause")
	await _frames(2)
	check(ui.mode == UiRoot.Mode.PLAY and not GameState.menu_open, "esc closes character panel")
	_press(&"character_menu")
	await _frames(1)
	_press(&"character_menu")
	await _frames(1)
	check(ui.mode == UiRoot.Mode.PLAY, "tab toggles character panel")

	# --- title
	ui._open_title()
	await _frames(2)
	check(ui.title_screen.visible and not ui.hud.visible and GameState.menu_open, "title shown")
	_press(&"pause")
	await _frames(1)
	check(ui.mode == UiRoot.Mode.TITLE, "esc ignored on title")
	ui._on_title_action(&"settings")
	await _frames(1)
	check(ui.settings_panel.visible, "settings from title")
	_press(&"pause")
	await _frames(1)
	check(ui.title_screen.visible and not ui.settings_panel.visible, "back to title")

	await _frames(5)
	OS.remove_logger(logger)
	for m in logger.messages:
		print("  logged error: ", m)
	check(logger.count == 0, "no engine errors logged (%d)" % logger.count)
	print("UI HUD TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	get_tree().paused = false
	SaveManager.delete_save()
	if backup != "":
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	get_tree().quit(1 if failures else 0)


func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
