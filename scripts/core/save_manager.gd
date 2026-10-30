extends Node
## Local save/load coordinator. Lead-owned.
##
## Persistent systems register as providers:
##     SaveManager.register("progression", self)
## A provider implements:
##     get_save_data() -> Dictionary
##     load_save_data(data: Dictionary) -> void   # must validate its own fields
##     reset() -> void                            # back to new-game state
##
## Loading happens at the START of main.tscn (before the world and actors
## spawn), so spawners simply read the restored state (GameState flags,
## Quests, Progression). See GameState.continue_game().

const SAVE_PATH := "user://savegame.json"
const VERSION := 1

var _providers: Dictionary = {}  # key -> Object
var _autosave_pending := false
var last_error := ""


func register(key: String, provider: Object) -> void:
	_providers[key] = provider


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and not read_save_file().is_empty()


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Saves now. Refuses while the player is dead (prevents death loops).
func save_game() -> bool:
	if GameState.is_player_dead():
		last_error = "Cannot save while defeated."
		return false
	var sections := {}
	for key: String in _providers:
		var p: Object = _providers[key]
		if is_instance_valid(p) and p.has_method("get_save_data"):
			sections[key] = p.get_save_data()
	var data := {
		"version": VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"sections": sections,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		last_error = "Could not write save: %s" % error_string(FileAccess.get_open_error())
		push_warning(last_error)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	Events.game_saved.emit()
	return true


## Debounced autosave; call after meaningful progress (quest step, essence, checkpoint).
func request_autosave() -> void:
	if _autosave_pending:
		return
	_autosave_pending = true
	await get_tree().create_timer(0.5, true).timeout
	_autosave_pending = false
	if not GameState.is_player_dead() and not GameState.boss_active:
		save_game()


## Returns {} when there is no valid save.
func read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Save file is corrupt."
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != VERSION or typeof(d.get("sections")) != TYPE_DICTIONARY:
		last_error = "Save file version is not supported."
		return {}
	return d


## Applies the save to every registered provider. Returns false when no valid save.
func load_game() -> bool:
	var d := read_save_file()
	if d.is_empty():
		return false
	var sections: Dictionary = d["sections"]
	for key: String in _providers:
		var p: Object = _providers[key]
		if not is_instance_valid(p):
			continue
		if p.has_method("reset"):
			p.reset()
		if sections.has(key) and typeof(sections[key]) == TYPE_DICTIONARY and p.has_method("load_save_data"):
			p.load_save_data(sections[key])
	Events.game_loaded.emit()
	return true


func reset_all() -> void:
	for key: String in _providers:
		var p: Object = _providers[key]
		if is_instance_valid(p) and p.has_method("reset"):
			p.reset()
