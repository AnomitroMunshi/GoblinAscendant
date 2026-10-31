class_name UiRoot
extends CanvasLayer
## UI entry point (OWNER: UI agent). Built by main.gd via Script.new().
## Owns the HUD, full-screen overlays (vignette, death screen, backdrop),
## the title screen and all menus.
##
## Menus & mouse: every open/close goes through GameState.set_menu_open(),
## which frees the cursor while a menu is open and captures it otherwise.
##   Esc   -> closes the top-most sub panel (Settings/Controls), else the
##            Character panel, else toggles the pause menu (tree paused).
##   Tab   -> toggles the Character panel (menu mode, world keeps running).
##   Click -> recaptures the mouse when no menu is open.

## Set false to skip the title screen during development.
const SHOW_TITLE_SCREEN := true

enum Mode { PLAY, PAUSE, CHARACTER, TITLE }

const VIGNETTE_SHADER := preload("res://shaders/ui/vignette.gdshader")
const BACKDROP_SHADER := preload("res://shaders/ui/backdrop.gdshader")

var hud: HudRoot
var frame: Control           # HUD container (scaled by ui_scale)
var menu_frame: Control      # menus container (scaled by ui_scale)
var fx: Control              # full-screen overlays below the HUD
var backdrop: ColorRect
var vignette: ColorRect
var death_screen: Control
var pause_menu: UiPauseMenu
var settings_panel: UiSettingsPanel
var controls_panel: UiControlsPanel
var character_panel: UiCharacterPanel
var title_screen: UiTitleScreen
var fps_label: Label

var mode := Mode.PLAY
var _sub: UiWindow = null     # settings / controls opened on top of pause or title
var _dead := false
var _damage_flash := 0.0
var _fps_timer := 0.0
var _backdrop_mat: ShaderMaterial
var _vignette_mat: ShaderMaterial


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme := UiTheme.get_theme()
	fx = _layer_control("FX", theme)
	_build_fx()
	frame = _layer_control("HudFrame", theme)
	frame.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud = HudRoot.new()
	hud.name = "HUD"
	frame.add_child(hud)
	fps_label = UiTheme.label("", &"HudLabel", 14)
	fps_label.position = Vector2(10, 6)
	fps_label.process_mode = Node.PROCESS_MODE_ALWAYS
	frame.add_child(fps_label)
	_build_death()
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = BACKDROP_SHADER
	backdrop.material = _backdrop_mat
	backdrop.visible = false
	UiTheme.full_rect(backdrop)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	menu_frame = _layer_control("MenuFrame", theme)
	_build_menus()
	_connect()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply_fps_setting()
	if GameState.show_title and SHOW_TITLE_SCREEN:
		_open_title()
	else:
		GameState.show_title = false
		_set_mode(Mode.PLAY)


func _layer_control(n: String, theme: Theme) -> Control:
	var c := Control.new()
	c.name = n
	c.theme = theme
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _build_fx() -> void:
	vignette = ColorRect.new()
	vignette.name = "Vignette"
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE_SHADER
	vignette.material = _vignette_mat
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.visible = false
	UiTheme.full_rect(vignette)
	fx.add_child(vignette)


func _build_death() -> void:
	death_screen = Control.new()
	death_screen.name = "Death"
	UiTheme.full_rect(death_screen)
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.visible = false
	fx.add_child(death_screen)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.full_rect(dim)
	death_screen.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	death_screen.add_child(v)
	var t := UiTheme.label("You have fallen…", &"TitleLabel", 62)
	t.add_theme_color_override(&"font_color", Color(0.74, 0.24, 0.19))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiTheme.label("Rising again at the last checkpoint", &"HudLabel", 20)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM)
	v.add_child(s)


func _build_menus() -> void:
	title_screen = UiTitleScreen.new()
	title_screen.name = "Title"
	title_screen.visible = false
	title_screen.action.connect(_on_title_action)
	menu_frame.add_child(title_screen)
	pause_menu = UiPauseMenu.new()
	pause_menu.name = "Pause"
	pause_menu.visible = false
	pause_menu.action.connect(_on_pause_action)
	menu_frame.add_child(pause_menu)
	character_panel = UiCharacterPanel.new()
	character_panel.name = "Character"
	character_panel.visible = false
	character_panel.close_requested.connect(close_character)
	menu_frame.add_child(character_panel)
	settings_panel = UiSettingsPanel.new()
	settings_panel.name = "Settings"
	settings_panel.visible = false
	settings_panel.close_requested.connect(close_sub)
	menu_frame.add_child(settings_panel)
	controls_panel = UiControlsPanel.new()
	controls_panel.name = "Controls"
	controls_panel.visible = false
	controls_panel.close_requested.connect(close_sub)
	menu_frame.add_child(controls_panel)


func _connect() -> void:
	Settings.changed.connect(_on_setting_changed)
	Events.player_died.connect(_on_player_died)
	Events.player_respawned.connect(_on_player_respawned)
	Events.player_damaged.connect(func(_i: Variant) -> void:
		_damage_flash = 1.0
		vignette.visible = true)
	if Events.has_signal(&"app_suspended"):
		Events.connect(&"app_suspended", func() -> void:
			if mode == Mode.PLAY or mode == Mode.CHARACTER:
				open_pause())
	Events.game_saved.connect(func() -> void:
		if mode == Mode.PAUSE:
			pause_menu.show_feedback("Game saved.", true))


# ================================================================ layout
func _layout() -> void:
	var vp := get_viewport().get_visible_rect()
	var s := clampf(float(Settings.get_value(&"ui_scale", 1.0)), 0.8, 1.4)
	fx.position = Vector2.ZERO
	fx.size = vp.size
	for f: Control in [frame, menu_frame]:
		f.position = vp.position
		f.scale = Vector2(s, s)
		f.size = vp.size / s


func _on_setting_changed(key: StringName) -> void:
	match key:
		&"ui_scale":
			_layout()
		&"show_fps":
			_apply_fps_setting()


func _apply_fps_setting() -> void:
	fps_label.visible = bool(Settings.get_value(&"show_fps", false))


# ================================================================ mode handling
func _set_mode(m: Mode) -> void:
	mode = m
	var menu := m != Mode.PLAY
	hud.visible = m != Mode.TITLE
	hud.set_overlays_visible(m == Mode.PLAY)
	title_screen.visible = m == Mode.TITLE
	pause_menu.visible = m == Mode.PAUSE and _sub == null
	character_panel.visible = m == Mode.CHARACTER
	backdrop.visible = menu
	_backdrop_mat.set_shader_parameter(&"mode", 1 if m == Mode.TITLE else 0)
	_backdrop_mat.set_shader_parameter(&"strength", 0.75 if m == Mode.CHARACTER else 1.0)
	get_tree().paused = m == Mode.PAUSE
	GameState.set_menu_open(menu)


func _open_title() -> void:
	_close_sub_silent()
	_set_mode(Mode.TITLE)
	Audio.play_music(&"title")


func open_pause() -> void:
	if mode == Mode.PAUSE or mode == Mode.TITLE:
		return
	_close_sub_silent()
	_set_mode(Mode.PAUSE)
	Audio.play_sfx(&"ui_open", null, -4.0, 0.0)


func close_pause() -> void:
	if mode != Mode.PAUSE:
		return
	_close_sub_silent()
	_set_mode(Mode.PLAY)


func toggle_character() -> void:
	if mode == Mode.CHARACTER:
		close_character()
	elif mode == Mode.PLAY and not _dead:
		_set_mode(Mode.CHARACTER)
		Audio.play_sfx(&"ui_open", null, -4.0, 0.0)


func close_character() -> void:
	if mode == Mode.CHARACTER:
		_set_mode(Mode.PLAY)


func open_sub(panel: UiWindow) -> void:
	_close_sub_silent()
	_sub = panel
	pause_menu.visible = false
	title_screen.visible = false
	panel.visible = true
	Audio.play_sfx(&"ui_open", null, -6.0, 0.0)


func close_sub() -> void:
	if _sub == null:
		return
	_close_sub_silent()
	pause_menu.visible = mode == Mode.PAUSE
	title_screen.visible = mode == Mode.TITLE
	if mode == Mode.PAUSE:
		pause_menu.content.get_child(0).grab_focus.call_deferred()


func _close_sub_silent() -> void:
	if _sub:
		_sub.visible = false
	_sub = null


func is_pause_open() -> bool:
	return mode == Mode.PAUSE


func _on_backdrop_input(event: InputEvent) -> void:
	# Click outside a window closes it (never the title screen).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _sub:
			close_sub()
		elif mode == Mode.CHARACTER:
			close_character()


# ================================================================ actions
func _on_pause_action(id: StringName) -> void:
	match id:
		&"resume":
			close_pause()
		&"save":
			if SaveManager.save_game():
				pause_menu.show_feedback("Game saved.", true)
			else:
				pause_menu.show_feedback(SaveManager.last_error if SaveManager.last_error != "" else "Could not save.", false)
		&"load":
			if SaveManager.has_save():
				GameState.continue_game()
		&"settings":
			open_sub(settings_panel)
		&"controls":
			open_sub(controls_panel)
		&"title":
			quit_to_title()
		&"quit":
			get_tree().quit()


func _on_title_action(id: StringName) -> void:
	match id:
		&"continue":
			GameState.continue_game()
		&"new_game":
			GameState.new_game()
		&"settings":
			open_sub(settings_panel)
		&"quit":
			get_tree().quit()


func quit_to_title() -> void:
	SaveManager.reset_all()
	GameState.show_title = true
	GameState.boss_active = false
	GameFeel.reset()
	get_tree().paused = false
	get_tree().call_deferred(&"reload_current_scene")


# ================================================================ death
func _on_player_died() -> void:
	_dead = true
	close_character()
	death_screen.visible = true
	death_screen.modulate.a = 0.0
	var tw := death_screen.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(death_screen, "modulate:a", 1.0, 1.2)


func _on_player_respawned() -> void:
	_dead = false
	var tw := death_screen.create_tween()
	tw.tween_property(death_screen, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		if not _dead:
			death_screen.visible = false)
	hud.refresh_all()


# ================================================================ input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_on_escape()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"character_menu"):
		if _sub == null and (mode == Mode.PLAY or mode == Mode.CHARACTER):
			toggle_character()
			get_viewport().set_input_as_handled()
		return
	# Clicking into the game window recaptures the mouse when no menu is open.
	if event is InputEventMouseButton and event.pressed and mode == Mode.PLAY \
			and not GameState.menu_open and not get_tree().paused \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _on_escape() -> void:
	if _sub:
		close_sub()
	elif mode == Mode.TITLE:
		pass
	elif mode == Mode.CHARACTER:
		close_character()
	elif mode == Mode.PAUSE:
		close_pause()
	else:
		open_pause()


func _touch() -> bool:
	return Settings.has_method(&"use_touch_controls") and Settings.call(&"use_touch_controls")


# ================================================================ per frame
func _process(delta: float) -> void:
	if fps_label.visible:
		_fps_timer -= delta
		if _fps_timer <= 0.0:
			_fps_timer = 0.25
			fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	# vignette: damage flash + low-health pulse
	if vignette.visible or hud.hp_ratio < 0.3:
		_damage_flash = maxf(0.0, _damage_flash - delta * 1.6)
		var low := 0.0
		if hud.hp_ratio < 0.3 and hud.hp_ratio > 0.0:
			low = (1.0 - hud.hp_ratio / 0.3) * (0.35 + 0.12 * sin(Time.get_ticks_msec() * 0.006))
		var v := maxf(_damage_flash * 0.85, low)
		_vignette_mat.set_shader_parameter(&"intensity", v)
		vignette.visible = v > 0.005
