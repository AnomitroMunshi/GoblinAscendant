extends Node
## Integration & QA: the real title-screen flow, windowed, through scene reloads.
##   godot --path . res://tests/qa_title_flow.tscn -- --full
## Boots main.tscn as the current scene with the title shown, presses the real
## title buttons (New Game, then later Continue), saves via SaveManager and goes
## back to the title with UiRoot.quit_to_title(). A driver node attached to the
## root survives the reloads. Screenshots: tests/screens/qa/title_*.png.
## Prints `QA TITLE FLOW: <n> passed, <m> failed`. The real save is backed up/restored.

class Driver extends Node:
	var passes := 0
	var failures := 0
	var backup := PackedByteArray()
	var fps: Array[float] = []

	func check(c: bool, label: String) -> void:
		if c:
			passes += 1
			print("  PASS ", label)
		else:
			failures += 1
			print("  FAIL ", label)

	func wait(sec: float) -> void:
		var t := 0.0
		while t < sec:
			await get_tree().process_frame
			t += get_process_delta_time()
			fps.append(Engine.get_frames_per_second())

	func shot(n: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/screens/qa/title_%s.png" % n)

	func ui() -> UiRoot:
		var m := get_tree().current_scene
		return m.get_node_or_null(^"UI") as UiRoot if m else null

	func run() -> void:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			backup = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens/qa"))
		# Start with a save so both buttons exist.
		GameState.show_title = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		await wait(3.0)
		var u := ui()
		check(u != null and u.mode == UiRoot.Mode.TITLE, "title screen shown on boot")
		await shot("1_title")
		var t := u.title_screen
		check(t.new_button.visible, "New Game button visible")
		t.new_button.pressed.emit()
		if SaveManager.has_save():
			check(t.new_button.text.begins_with("Start over"), "New Game asks to confirm when a save exists")
			t.new_button.pressed.emit()
		await wait(3.0)
		u = ui()
		check(u != null and u.mode == UiRoot.Mode.PLAY and not GameState.show_title, "New Game -> gameplay")
		check(not SaveManager.has_save() or Progression.level == 1, "fresh game")
		check(Quests.is_quest_active(&"a_small_beginning"), "first quest active")
		Input.action_press(&"move_forward")
		await wait(2.0)
		Input.action_release(&"move_forward")
		await shot("2_new_game")
		Progression.add_xp(40, "QA marker")
		GameState.set_flag(&"qa_marker")
		await wait(1.0)
		check(SaveManager.save_game(), "save")
		var xp := Progression.xp
		u.quit_to_title()
		await wait(3.0)
		u = ui()
		check(u != null and u.mode == UiRoot.Mode.TITLE, "back at the title")
		check(u.title_screen.continue_button.visible, "Continue button visible")
		await wait(1.5)
		u.title_screen.continue_button.pressed.emit()
		await wait(3.0)
		u = ui()
		check(u != null and u.mode == UiRoot.Mode.PLAY, "Continue -> gameplay")
		check(GameState.has_flag(&"qa_marker") and Progression.xp == xp, "Continue restored flag + xp (%d)" % Progression.xp)
		await shot("3_continue")
		var s := 0.0
		for f in fps:
			s += f
		print("QA TITLE FPS: avg %.1f over %d frames" % [s / maxi(fps.size(), 1), fps.size()])
		await wait(1.0)
		if backup.is_empty():
			SaveManager.delete_save()
		else:
			var fa := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
			fa.store_buffer(backup)
			fa.close()
		print("QA TITLE FLOW: %d passed, %d failed" % [passes, failures])
		get_tree().quit(failures)


func _ready() -> void:
	var d := Driver.new()
	d.name = "QaTitleDriver"
	get_tree().root.add_child.call_deferred(d)
	d.ready.connect(d.run, CONNECT_ONE_SHOT)
