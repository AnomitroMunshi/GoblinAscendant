extends Node
## Quest state machine (autoload `Quests`). OWNER: Progression & Quest agent.
## Content lives in QuestData (scripts/quests/quest_data.gd); this file only
## interprets it. A quest becomes active when all of its `requires` quests are
## completed. Every step is re-evaluated whenever relevant state changes, so
## steps that are already satisfied (flag set earlier, level already reached,
## zone visited before) complete immediately - also right after loading.
##
## Kill steps count kills made since the game session started (kills before the
## step became active also count; counters are not saved because enemies respawn
## on load).

enum Status { INACTIVE, ACTIVE, COMPLETED }

const STATUS_NAMES := ["inactive", "active", "completed"]

var _state: Dictionary = {}           # quest_id -> {status, step, progress}
var _visited_zones: Array[StringName] = []
var _kills_tag: Dictionary = {}       # tag -> int (session)
var _kills_type: Dictionary = {}      # enemy_type -> int (session)
var _busy := false
var _dirty := false
var _silent := false                  # suppress "new quest" toasts while restoring


func _ready() -> void:
	SaveManager.register("quests", self)
	Events.zone_entered.connect(_on_zone_entered)
	Events.interacted.connect(_on_interacted)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.item_collected.connect(_on_item_collected)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.level_up.connect(func(_l: int) -> void: refresh())
	Events.evolution_changed.connect(func(_s: StringName) -> void: refresh())
	Events.game_started.connect(_on_game_started)
	GameState.flag_changed.connect(func(_f: StringName, _v: bool) -> void: refresh())
	reset()


# ---------------------------------------------------------------- public API
## Compact text for the HUD objective line.
func get_objective_text() -> String:
	var q := _tracked_quest()
	if q.is_empty():
		return ""
	var step := _current_step(q)
	return _step_text(q, step) if not step.is_empty() else ""


## World position of the current objective for the compass, or null.
func get_objective_position() -> Variant:
	var q := _tracked_quest()
	if q.is_empty():
		return null
	var step := _current_step(q)
	if step.is_empty():
		return null
	if step.has("positions"):
		var prefix := String(step.get("position_flag_prefix", ""))
		var best: Variant = null
		var best_d := INF
		var from: Vector3 = GameState.player.global_position if is_instance_valid(GameState.player) else Vector3.ZERO
		var list: Array = step["positions"]
		for i in list.size():
			if prefix != "" and GameState.has_flag(StringName(prefix + str(i))):
				continue
			var d := from.distance_to(list[i])
			if d < best_d:
				best_d = d
				best = list[i]
		return GameState.ground_point(best) if best != null else null
	if step.has("pos"):
		return GameState.ground_point(step["pos"])
	return null


func get_active_quest_title() -> String:
	var q := _tracked_quest()
	return String(q.get("title", "")) if not q.is_empty() else ""


func get_active_quest_id() -> StringName:
	var q := _tracked_quest()
	return q.get("id", &"") if not q.is_empty() else &""


func is_quest_completed(quest_id: StringName) -> bool:
	return _status(quest_id) == Status.COMPLETED


func is_quest_active(quest_id: StringName) -> bool:
	return _status(quest_id) == Status.ACTIVE


func is_chapter_complete() -> bool:
	for q: Dictionary in QuestData.QUESTS:
		if _status(q["id"]) != Status.COMPLETED:
			return false
	return true


## Index of the current step of an active quest (-1 if not active).
func get_step_index(quest_id: StringName) -> int:
	return int(_state[quest_id]["step"]) if is_quest_active(quest_id) else -1


## True when some active quest's current step is waiting for this target id
## (e.g. QuestWorld asks whether `nib_rescue` can be used right now).
func is_waiting_for(target: StringName) -> bool:
	for q: Dictionary in QuestData.QUESTS:
		if is_quest_active(q["id"]):
			var step := _current_step(q)
			if not step.is_empty() and step.get("target", &"") == target:
				return true
	return false


## For the character panel: started/completed quests, newest first.
## [{id, title, summary, active, completed, objective, steps: [{text, done}]}]
func get_quest_log() -> Array:
	var out := []
	for q: Dictionary in QuestData.QUESTS:
		var st := _status(q["id"])
		if st == Status.INACTIVE:
			continue
		var idx := int(_state[q["id"]]["step"])
		var steps := []
		var all_steps: Array = q["steps"]
		for i in all_steps.size():
			if st == Status.COMPLETED or i <= idx:
				steps.append({"text": String(all_steps[i]["text"]), "done": st == Status.COMPLETED or i < idx})
		out.push_front({
			"id": q["id"], "title": String(q["title"]), "summary": String(q.get("summary", "")),
			"active": st == Status.ACTIVE, "completed": st == Status.COMPLETED,
			"objective": _step_text(q, _current_step(q)) if st == Status.ACTIVE else "",
			"steps": steps,
		})
	return out


## Re-evaluates every active quest (safe to call any time).
func refresh() -> void:
	if _busy:
		_dirty = true
		return
	_busy = true
	var guard := 0
	while guard < 64:
		guard += 1
		_dirty = false
		_activate_available()
		for q: Dictionary in QuestData.QUESTS:
			if is_quest_active(q["id"]):
				_advance(q)
		if not _dirty:
			break
	_busy = false


# ---------------------------------------------------------------- internals
func _status(id: StringName) -> int:
	return int(_state[id]["status"]) if _state.has(id) else Status.INACTIVE


func _tracked_quest() -> Dictionary:
	for q: Dictionary in QuestData.QUESTS:
		if is_quest_active(q["id"]):
			return q
	return {}


func _current_step(q: Dictionary) -> Dictionary:
	var steps: Array = q["steps"]
	var idx := int(_state[q["id"]]["step"])
	return steps[idx] if idx >= 0 and idx < steps.size() else {}


func _step_count(step: Dictionary) -> int:
	return maxi(1, int(step.get("count", 1)))


func _step_value(q: Dictionary, step: Dictionary) -> int:
	var target: StringName = step.get("target", &"")
	var progress := int(_state[q["id"]]["progress"])
	match String(step.get("type", "")):
		"zone":
			return 1 if (_visited_zones.has(target) or Progression.discovered.has(target)) else 0
		"interact":
			return progress
		"kill_tag":
			return int(_kills_tag.get(target, 0))
		"kill_type":
			return int(_kills_type.get(target, 0))
		"collect":
			return maxi(progress, Progression.item_count(target))
		"flag":
			return 1 if GameState.has_flag(target) else 0
		"level":
			return Progression.level
		"stage":
			return 1 if ProgressionEvolution.index_of(Progression.stage) >= ProgressionEvolution.index_of(target) else 0
	push_warning("Quests: unknown step type '%s' - auto-completing." % step.get("type", ""))
	return _step_count(step)


func _step_text(q: Dictionary, step: Dictionary) -> String:
	if step.is_empty():
		return ""
	var text := String(step.get("text", ""))
	var count := _step_count(step)
	if count > 1 or step.get("type", "") == "level":
		text += " (%d/%d)" % [mini(_step_value(q, step), count), count]
	return text


func _activate_available() -> void:
	for q: Dictionary in QuestData.QUESTS:
		if _status(q["id"]) != Status.INACTIVE:
			continue
		var ok := true
		for r: StringName in q.get("requires", []):
			if not is_quest_completed(r):
				ok = false
		if ok:
			_state[q["id"]] = {"status": Status.ACTIVE, "step": 0, "progress": 0}
			Events.quest_started.emit(q["id"])
			if not _silent:
				Events.notify.emit("New quest: %s" % q["title"], &"quest")
			_objective_changed()
			_dirty = true


func _advance(q: Dictionary) -> void:
	var id: StringName = q["id"]
	var steps: Array = q["steps"]
	while is_quest_active(id):
		var idx := int(_state[id]["step"])
		if idx >= steps.size():
			_complete_quest(q)
			return
		var step: Dictionary = steps[idx]
		if _step_value(q, step) < _step_count(step):
			return
		_state[id]["step"] = idx + 1
		_state[id]["progress"] = 0
		_run_actions(step.get("on_complete", []))
		Events.quest_updated.emit(id)
		if idx + 1 >= steps.size():
			_complete_quest(q)
			return
		_objective_changed()
		SaveManager.request_autosave()


func _complete_quest(q: Dictionary) -> void:
	var id: StringName = q["id"]
	_state[id]["status"] = Status.COMPLETED
	_state[id]["step"] = (q["steps"] as Array).size()
	Events.notify.emit("Quest complete: %s" % q["title"], &"quest")
	Audio.play_sfx(&"quest_complete")
	Events.quest_completed.emit(id)   # Progression grants q.xp
	_run_actions(q.get("on_complete", []))
	_dirty = true
	_objective_changed()
	SaveManager.request_autosave()


func _run_actions(actions: Array) -> void:
	for a: Dictionary in actions:
		if a.has("set_flag"):
			GameState.set_flag(a["set_flag"])
		if a.has("give_xp"):
			Progression.add_xp(int(a["give_xp"]), "Quest")
		if a.has("checkpoint"):
			GameState.reach_checkpoint(a["checkpoint"])
		if a.has("sfx"):
			Audio.play_sfx(StringName(a["sfx"]))
		if a.has("emit"):
			match String(a["emit"]):
				"friend_rescued": Events.friend_rescued.emit()
				"home_claimed": Events.home_claimed.emit()
				"chapter_completed": Events.chapter_completed.emit()
				_: push_warning("Quests: unknown emit '%s'" % a["emit"])
		if a.has("notify"):
			Events.notify.emit(String(a["notify"]), a.get("kind", &"quest"))


func _objective_changed() -> void:
	Events.objective_changed.emit(get_objective_text())


# ---------------------------------------------------------------- event handlers
func _bump(type: String, target: StringName, amount: int = 1) -> void:
	for q: Dictionary in QuestData.QUESTS:
		if not is_quest_active(q["id"]):
			continue
		var step := _current_step(q)
		if step.get("type", "") == type and step.get("target", &"") == target:
			_state[q["id"]]["progress"] = int(_state[q["id"]]["progress"]) + amount
			Events.quest_updated.emit(q["id"])
			_objective_changed()


func _on_zone_entered(zone_id: StringName) -> void:
	if not _visited_zones.has(zone_id):
		_visited_zones.append(zone_id)
	refresh()


func _on_interacted(interact_id: StringName, _actor: Node) -> void:
	_bump("interact", interact_id)
	refresh()


func _on_enemy_killed(_enemy: Node3D, enemy_type: StringName, tags: Array) -> void:
	_kills_type[enemy_type] = int(_kills_type.get(enemy_type, 0)) + 1
	for t: Variant in tags:
		var tag := StringName(str(t))
		_kills_tag[tag] = int(_kills_tag.get(tag, 0)) + 1
	_objective_changed()
	refresh()


func _on_item_collected(item_id: StringName, amount: int) -> void:
	_bump("collect", item_id, amount)
	refresh()


func _on_boss_defeated(_boss: Node3D) -> void:
	GameState.set_flag(&"boss_defeated")  # Combat sets it too; harmless duplicate
	refresh()


func _on_game_started() -> void:
	_silent = false
	refresh()
	_objective_changed()


# ---------------------------------------------------------------- save / load
func get_save_data() -> Dictionary:
	var qs := {}
	for id: StringName in _state:
		qs[String(id)] = {
			"status": STATUS_NAMES[int(_state[id]["status"])],
			"step": int(_state[id]["step"]),
			"progress": int(_state[id]["progress"]),
		}
	var zones := []
	for z in _visited_zones:
		zones.append(String(z))
	return {"quests": qs, "zones": zones}


func load_save_data(d: Dictionary) -> void:
	_state.clear()
	_visited_zones.clear()
	var qs: Variant = d.get("quests")
	if typeof(qs) == TYPE_DICTIONARY:
		for q: Dictionary in QuestData.QUESTS:
			var e: Variant = qs.get(String(q["id"]))
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var status := STATUS_NAMES.find(str(e.get("status", "")))
			if status <= Status.INACTIVE:
				continue
			var n_steps := (q["steps"] as Array).size()
			var step := clampi(_to_int(e.get("step"), 0), 0, n_steps)
			if status == Status.COMPLETED:
				step = n_steps
			_state[q["id"]] = {"status": status, "step": step, "progress": clampi(_to_int(e.get("progress"), 0), 0, 9999)}
	# A quest can't be active/completed without its prerequisites: repair chains.
	var changed := true
	while changed:
		changed = false
		for q: Dictionary in QuestData.QUESTS:
			if _status(q["id"]) == Status.INACTIVE:
				continue
			for r: StringName in q.get("requires", []):
				if not is_quest_completed(r):
					_state.erase(q["id"])
					changed = true
					break
	var zones: Variant = d.get("zones")
	if typeof(zones) == TYPE_ARRAY:
		for z: Variant in zones:
			if typeof(z) in [TYPE_STRING, TYPE_STRING_NAME] and not _visited_zones.has(StringName(z)):
				_visited_zones.append(StringName(z))
	_silent = true
	_activate_available()
	call_deferred("_after_load")


func _after_load() -> void:
	refresh()
	_silent = false
	_objective_changed()


static func _to_int(v: Variant, fallback: int) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v):
		return int(clampf(v, -1.0e9, 1.0e9))
	return fallback


func reset() -> void:
	_state.clear()
	_visited_zones.clear()
	_kills_tag.clear()
	_kills_type.clear()
	_silent = true
	_activate_available()
	_silent = false
	_objective_changed()
