extends Node3D
## Non-headless UI screenshots (UI agent). Run:
##   "$G" --path . res://tests/ui_screens.tscn
## Builds a small 3D backdrop, instantiates UiRoot and saves PNGs of the HUD,
## pause menu, settings, character panel, title and death screen to
## res://tests/screens/ui_*.png.

const Dummy := preload("res://tests/ui_dummy.gd")
const OUT := "res://tests/screens/"

var ui: UiRoot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var res := Vector2i(1600, 900)
	for a in args:
		if a.begins_with("--res="):
			var p := a.substr(6).split("x")
			res = Vector2i(int(p[0]), int(p[1]))
	DisplayServer.window_set_size(res)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var backup := FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""
	_build_backdrop()
	GameState.show_title = false
	ui = UiRoot.new()
	add_child(ui)
	await _frames(5)
	var player: Node3D = Dummy.new()
	player.energy = 45.0
	add_child(player)
	player.position = Vector3(0, 0, 8)
	GameState.player = player
	GameState.ability_controller = player
	player.cooldowns = [0.0, 0.62, 0.0]
	for id in [&"wolf_dash", &"stone_guard", &"flame_burst"]:
		Progression.unlock_ability(id)
	for id in [&"glade", &"wolf_woods", &"ruins", &"overlook"]:
		if not Progression.discovered.has(id):
			Progression.discovered.append(id)
	Progression.add_xp(60, "test")
	Progression.add_item(&"supplies", 2)
	Events.player_stats_changed.emit(64.0, 100.0, 72.0, 100.0, 45.0, 100.0)
	await _frames(2)
	Events.player_stats_changed.emit(52.0, 100.0, 60.0, 100.0, 45.0, 100.0)
	Events.notify.emit("Discovered: Mossy Ruins", &"info")
	Events.notify.emit("New quest: The Ogre's Claim", &"quest")
	Events.interaction_prompt_changed.emit("[E] Read signpost")
	var boss: Node3D = Dummy.new()
	boss.display_name = "Gorrak, the Clearing Tyrant"
	add_child(boss)
	Events.boss_engaged.emit(boss)
	Events.boss_health_changed.emit(410.0, 600.0)
	Events.ability_unlocked.emit(&"flame_burst")
	await _wait(0.8)
	await _shot("ui_hud")
	Events.boss_disengaged.emit(boss)
	Events.interaction_prompt_changed.emit("")
	await _wait(3.5)
	# pause
	ui.open_pause()
	await _wait(0.3)
	await _shot("ui_pause")
	ui._on_pause_action(&"settings")
	await _wait(0.3)
	await _shot("ui_settings")
	ui.close_sub()
	ui._on_pause_action(&"controls")
	await _wait(0.3)
	await _shot("ui_controls")
	ui.close_sub()
	ui.close_pause()
	if Progression.has_method(&"get_next_stage"):
		Progression.upgrade_points = 2
	ui.toggle_character()
	await _wait(0.4)
	await _shot("ui_character")
	ui.close_character()
	Events.player_died.emit()
	await _wait(2.0)
	await _shot("ui_death")
	Events.player_respawned.emit()
	await _wait(1.0)
	ui._open_title()
	await _wait(0.5)
	await _shot("ui_title")
	if backup != "":
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	get_tree().paused = false
	get_tree().quit()


func _build_backdrop() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.36, 0.55, 0.78)
	psm.sky_horizon_color = Color(0.78, 0.82, 0.80)
	psm.ground_horizon_color = Color(0.5, 0.55, 0.45)
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.7, 0.78, 0.82)
	e.fog_density = 0.008
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	ground.material_override = Palette.mat(Palette.GRASS)
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-80, -6))
		var trunk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.4
		cyl.height = 4.0
		trunk.mesh = cyl
		trunk.material_override = Palette.mat(Palette.BARK)
		trunk.position = p + Vector3(0, 2, 0)
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var sph := SphereMesh.new()
		var r := rng.randf_range(1.8, 3.2)
		sph.radius = r
		sph.height = r * 2.2
		crown.mesh = sph
		crown.material_override = Palette.mat([Palette.LEAF, Palette.LEAF_DARK, Palette.LEAF_WARM][i % 3])
		crown.position = p + Vector3(0, 4.5 + r * 0.6, 0)
		add_child(crown)
	var cam := Camera3D.new()
	cam.position = Vector3(1.5, 2.4, 12)
	cam.rotation_degrees = Vector3(-6, 8, 0)
	cam.fov = 70
	add_child(cam)
	cam.make_current()
	GameState.camera = cam


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + n + ".png")
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
