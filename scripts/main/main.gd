extends Node3D
## Integration root. Lead-owned.
## Loads the save (if continuing) BEFORE anything spawns, then builds each
## system in dependency order. A missing part is skipped with a warning so
## the project stays runnable while parts are in development.

## Player-only build: the movement playground replaces the world and nothing
## else is spawned. Launch with `-- --full` (user arg) to build the full game,
## e.g. `godot --path . -- --full`. Set false to make the full game the default.
const PLAYER_ONLY := true

static func player_only() -> bool:
	return PLAYER_ONLY and not OS.get_cmdline_user_args().has("--full")

const PARTS := [
	["World", "res://scripts/world/world.gd"],          # World agent
	["Player", "res://scripts/player/player.gd"],       # Player & Camera agent
	["Actors", "res://scripts/enemies/enemy_spawner.gd"],  # Combat & AI agent
	["QuestWorld", "res://scripts/quests/quest_world.gd"],  # Progression & Quest agent
	["UI", "res://scripts/ui/ui_root.gd"],              # UI & Audio agent
]

var parts: Dictionary = {}


func _ready() -> void:
	GameFeel.reset()
	if GameState.pending_load:
		GameState.pending_load = false
		if not SaveManager.load_game():
			push_warning("Continue requested but no valid save; starting fresh.")
	if player_only():
		# Spawn/respawn inside the playground, not at the valley's glade.
		GameState.checkpoint_position = Vector3(0, 0, 8)
		GameState.has_safe_position = false
		_add_part("World", "res://scripts/main/movement_playground.gd")
		_add_part("Player", "res://scripts/player/player.gd")
	else:
		for entry: Array in PARTS:
			_add_part(entry[0], entry[1])
	if not parts.has("World"):
		_add_fallback_ground()
	if not parts.has("UI"):
		GameState.show_title = false
	if not GameState.show_title:
		GameState.set_menu_open(false)
	Events.game_started.emit()


func _add_part(part_name: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Main: part '%s' missing (%s), skipping." % [part_name, path])
		return
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		push_error("Main: part '%s' failed to load (%s)." % [part_name, path])
		return
	var node: Node = script.new()
	node.name = part_name
	add_child(node)
	parts[part_name] = node


func _add_fallback_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(512, 1, 512)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(512, 512)
	mi.mesh = plane
	mi.material_override = Palette.mat(Palette.GRASS)
	body.add_child(mi)
	add_child(body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _unhandled_input(event: InputEvent) -> void:
	# Without the UI there is no pause menu: Esc releases the mouse, click recaptures it.
	if not parts.has("UI"):
		if event.is_action_pressed(&"pause"):
			GameState.set_menu_open(not GameState.menu_open)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and GameState.menu_open:
			GameState.set_menu_open(false)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"quick_save") and not GameState.show_title:
		if SaveManager.save_game():
			Events.notify.emit("Game saved", &"info")
	elif event.is_action_pressed(&"quick_load") and SaveManager.has_save():
		GameState.continue_game()
