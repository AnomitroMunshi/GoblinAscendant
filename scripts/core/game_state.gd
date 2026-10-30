extends Node
## Session state shared by all systems. Lead-owned.
## - References to the live player / world / camera (set by those systems).
## - World flags (persisted): GameState.set_flag(&"boss_defeated").
## - Checkpoint + safe spawn position (persisted).
## - Menu / mouse-capture policy and input blocking.
## - Game flow: new_game(), continue_game(), title screen.

signal flag_changed(flag: StringName, value: bool)
signal menu_state_changed(open: bool)

var player: Node3D
var world: Node3D
var camera: Camera3D
var ability_controller: Node

var flags: Dictionary = {}
var checkpoint_id: StringName = &"glade"
var checkpoint_position: Vector3 = WorldLayout.PLAYER_START
var safe_position: Vector3 = WorldLayout.PLAYER_START  # last grounded, out-of-combat spot
var has_safe_position := false

var show_title := true     # title screen shown on first boot only
var pending_load := false  # main.tscn loads the save before building
var boss_active := false
var menu_open := false

var _engaged: Dictionary = {}  # instance_id -> true for enemies currently fighting the player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_actions()
	SaveManager.register("game_state", self)


# ---------------------------------------------------------------- flags
func set_flag(flag: StringName, value: bool = true) -> void:
	if bool(flags.get(flag, false)) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


# ---------------------------------------------------------------- world helpers
func ground_height(x: float, z: float) -> float:
	if is_instance_valid(world) and world.has_method("height_at"):
		return world.height_at(x, z)
	return 0.0


func ground_point(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_height(p.x, p.z), p.z)


func is_player_dead() -> bool:
	return is_instance_valid(player) and player.has_method("is_dead") and player.is_dead()


# ---------------------------------------------------------------- checkpoints / spawn
func reach_checkpoint(id: StringName) -> void:
	if not WorldLayout.CHECKPOINTS.has(id):
		return
	var changed := checkpoint_id != id
	checkpoint_id = id
	checkpoint_position = WorldLayout.CHECKPOINTS[id]
	if changed:
		Events.checkpoint_reached.emit(id)
		SaveManager.request_autosave()


## Where the player should appear when the scene starts (after a load this
## is the last safe position, otherwise the checkpoint).
func get_spawn_position() -> Vector3:
	var p := safe_position if has_safe_position else checkpoint_position
	return ground_point(p) + Vector3.UP * 0.5


func get_respawn_position() -> Vector3:
	return ground_point(checkpoint_position) + Vector3.UP * 0.5


func update_safe_position(p: Vector3) -> void:
	if in_combat() or boss_active:
		return
	safe_position = p
	has_safe_position = true


# ---------------------------------------------------------------- combat tracking
func set_engaged(enemy: Node, engaged: bool) -> void:
	var id := enemy.get_instance_id()
	if engaged:
		_engaged[id] = true
	else:
		_engaged.erase(id)


func in_combat() -> bool:
	for id: int in _engaged.keys():
		if not is_instance_id_valid(id):
			_engaged.erase(id)
	return not _engaged.is_empty()


# ---------------------------------------------------------------- menus / mouse
## UI calls this when any menu opens/closes. Gameplay input must check
## is_input_blocked(). Mouse is captured only while no menu is open.
func set_menu_open(open: bool) -> void:
	menu_open = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	menu_state_changed.emit(open)


func is_input_blocked() -> bool:
	return menu_open or get_tree().paused


# ---------------------------------------------------------------- game flow
func new_game() -> void:
	SaveManager.delete_save()
	_restart(false)


func continue_game() -> void:
	_restart(SaveManager.has_save())


func _restart(load_save: bool) -> void:
	SaveManager.reset_all()
	GameFeel.reset()
	show_title = false
	pending_load = load_save
	menu_open = false
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")


# ---------------------------------------------------------------- save provider
func get_save_data() -> Dictionary:
	var p := safe_position if has_safe_position else checkpoint_position
	return {
		"flags": flags.duplicate(),
		"checkpoint_id": String(checkpoint_id),
		"position": [p.x, p.y, p.z],
	}


func load_save_data(d: Dictionary) -> void:
	if typeof(d.get("flags")) == TYPE_DICTIONARY:
		for k: Variant in d["flags"]:
			flags[StringName(str(k))] = bool(d["flags"][k])
	var cp := StringName(str(d.get("checkpoint_id", "glade")))
	if WorldLayout.CHECKPOINTS.has(cp):
		checkpoint_id = cp
		checkpoint_position = WorldLayout.CHECKPOINTS[cp]
	var pos: Variant = d.get("position")
	if typeof(pos) == TYPE_ARRAY and pos.size() == 3:
		var v := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		var lim := WorldLayout.PLAYABLE_HALF
		if v.is_finite() and absf(v.x) < lim and absf(v.z) < lim:
			safe_position = v
			has_safe_position = true


func reset() -> void:
	flags.clear()
	checkpoint_id = &"glade"
	checkpoint_position = WorldLayout.PLAYER_START
	safe_position = WorldLayout.PLAYER_START
	has_safe_position = false
	boss_active = false
	_engaged.clear()
