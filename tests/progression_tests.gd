extends Node
## Headless tests for Progression / Quests / AbilityController.
## Run: "$G" --headless --path . res://tests/progression_tests.tscn
## The real save file (user://savegame.json) is backed up and restored.

const StubPlayer := preload("res://tests/progression_stub_player.gd")
const TargetDummy := preload("res://tests/progression_target_dummy.gd")

var _fails := 0
var _passes := 0
var _chapter_done := 0
var _fail_reasons: Array = []
var _save_backup: Variant = null


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL: ", what)


func eq(a: Variant, b: Variant, what: String) -> void:
	check(a == b, "%s (got %s, expected %s)" % [what, a, b])


func _run() -> void:
	_backup_save()
	Events.chapter_completed.connect(func() -> void: _chapter_done += 1)
	Events.ability_failed.connect(func(_s: int, r: String) -> void: _fail_reasons.append(r))
	print("== test_xp_budget");          test_xp_budget()
	print("== test_quest_chain");        await test_quest_chain()
	print("== test_save_roundtrip");     await test_save_roundtrip()
	print("== test_load_mid_quest");     await test_load_mid_quest()
	print("== test_corrupt_data");       await test_corrupt_data()
	print("== test_abilities");          await test_abilities()
	await get_tree().create_timer(1.0).timeout  # let pending autosaves finish
	_restore_save()
	print("RESULT: %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _backup_save() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		_save_backup = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)


func _restore_save() -> void:
	if _save_backup != null:
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	else:
		SaveManager.delete_save()


func _fresh() -> void:
	SaveManager.reset_all()


func _xp_total() -> int:
	return Progression.total_xp_for_level(Progression.level) + Progression.xp


# ---------------------------------------------------------------- XP budget
func test_xp_budget() -> void:
	var p := Progression
	var t: Dictionary = p.XP_BY_ENEMY
	var quests_1_4 := 0
	for id: StringName in [&"a_small_beginning", &"a_friend_in_trouble", &"a_place_to_belong", &"the_ogres_claim"]:
		quests_1_4 += int(QuestData.get_quest(id)["xp"])
	var mandatory: int = 4 * t[&"wolf"] + 3 * t[&"goblin_raider"] + t[&"ogre"] + p.RESCUE_XP \
		+ quests_1_4 + 50 + 4 * p.LANDMARK_XP
	var exploration: int = t[&"alpha_wolf"] + 2 * t[&"wolf"] + 3 * p.LANDMARK_XP
	var everything: int = 8 * t[&"wolf"] + t[&"alpha_wolf"] + 5 * t[&"goblin_raider"] + 4 * t[&"human_raider"] \
		+ t[&"raider_captain"] + t[&"ogre"] + 9 * p.LANDMARK_XP + p.RESCUE_XP + quests_1_4 + 50
	var need: int = p.total_xp_for_level(5)
	print("  need=%d mandatory=%d (+exploration %d) everything=%d" % [need, mandatory, exploration, everything])
	check(mandatory < need, "mandatory alone should not quite reach level 5")
	check(mandatory + exploration >= need, "mandatory + a little exploration reaches level 5")
	check(everything >= need * 1.2, "full chapter content comfortably exceeds level 5")
	eq(int(t[&"adventurer"]), 0, "adventurers give no XP")


# ---------------------------------------------------------------- quest chain
func test_quest_chain() -> void:
	_fresh()
	_chapter_done = 0
	check(Quests.is_quest_active(&"a_small_beginning"), "q1 active on new game")
	eq(Quests.get_objective_text(), "Walk to the north edge of the glade", "q1 step 1 text")
	check(Quests.get_objective_position() != null, "objective has a compass position")
	Events.zone_entered.emit(&"glade")
	eq(Quests.get_step_index(&"a_small_beginning"), 0, "spawning inside the glade zone doesn't complete step 1")
	Events.zone_entered.emit(&"glade_edge")
	eq(Quests.get_objective_text(), "Read the signpost", "q1 step 2")
	check(Progression.is_discovered(&"glade"), "glade discovered")
	Events.interacted.emit(&"glade_signpost", null)
	check(Quests.is_quest_completed(&"a_small_beginning"), "q1 completed")
	check(Quests.is_quest_active(&"a_friend_in_trouble"), "q2 active")
	eq(Quests.get_active_quest_title(), "A Friend in Trouble", "q2 title")
	for i in 4:
		Events.enemy_killed.emit(null, &"wolf", [])
	Events.zone_entered.emit(&"wolf_woods")
	Events.zone_entered.emit(&"rescue_site")
	eq(Quests.get_objective_text(), "Defeat the raiders (0/3)", "q2 kill step")
	eq(GameState.checkpoint_id, &"woods_edge", "checkpoint after finding Nib")
	Events.interacted.emit(&"nib_rescue", null)
	eq(Quests.get_step_index(&"a_friend_in_trouble"), 1, "helping Nib early does nothing")
	Events.enemy_killed.emit(null, &"goblin_raider", [&"rescue_guard"])
	eq(Quests.get_objective_text(), "Defeat the raiders (1/3)", "kill progress shown")
	for i in WorldLayout.RESCUE_GUARD_COUNT - 1:
		Events.enemy_killed.emit(null, &"goblin_raider", [&"rescue_guard"])
	eq(Quests.get_objective_text(), "Help Nib up", "q2 nib step")
	check(Quests.is_waiting_for(&"nib_rescue"), "is_waiting_for nib_rescue")
	Events.interacted.emit(&"nib_rescue", null)
	check(GameState.has_flag(&"friend_rescued"), "friend_rescued flag")
	check(Quests.is_quest_completed(&"a_friend_in_trouble"), "q2 completed")
	eq(Quests.get_objective_text(), "Find the cave in the north-east", "q3 step 1")
	Events.zone_entered.emit(&"cave")
	eq(Quests.get_objective_text(), "Gather supplies (0/3)", "q3 collect")
	for i in 3:
		GameState.set_flag(StringName("supply_%d" % i))
		Progression.add_item(QuestData.SUPPLY_ITEM, 1)
	check(Quests.is_quest_completed(&"a_place_to_belong"), "q3 completed")
	eq(Quests.get_objective_text(), "Defeat the ogre", "q4")
	Events.zone_entered.emit(&"ogre_clearing")
	Events.enemy_killed.emit(null, &"ogre", [])
	Events.boss_defeated.emit(null)
	check(Quests.is_quest_completed(&"the_ogres_claim"), "q4 completed")
	eq(Quests.get_objective_text(), "Claim the cave as home", "q5 step 1")
	Events.interacted.emit(&"evolution_altar", null)
	eq(Progression.stage, &"goblin", "cannot evolve before requirements")
	Events.interacted.emit(&"cave_hearth", null)
	check(GameState.has_flag(&"home_claimed"), "home_claimed flag")
	eq(GameState.checkpoint_id, &"home", "home checkpoint")
	print("  XP after mandatory content: %d (level %d)" % [_xp_total(), Progression.level])
	eq(_xp_total(), 1005, "mandatory XP total matches budget")
	eq(Progression.level, 4, "level 4 after mandatory content")
	eq(Quests.get_objective_text(), "Reach level 5 (4/5)", "level step text")
	check(not Progression.can_evolve(), "not eligible at level 4")
	# A little exploration.
	Events.enemy_killed.emit(null, &"alpha_wolf", [])
	Events.enemy_killed.emit(null, &"wolf", [])
	Events.enemy_killed.emit(null, &"wolf", [])
	Events.zone_entered.emit(&"ruins")
	Events.zone_entered.emit(&"overlook")
	Events.zone_entered.emit(&"waterfall")
	Events.zone_entered.emit(&"adventurer_never_a_zone")
	eq(Progression.level, 5, "level 5 after a little exploration")
	eq(Quests.get_objective_text(), "Evolve at the hearth", "evolve step")
	check(Progression.can_evolve(), "can_evolve at level 5")
	Events.interacted.emit(&"evolution_altar", null)
	eq(Progression.stage, &"hobgoblin", "evolved")
	check(Progression.has_unlock(&"shockwave_slam"), "shockwave unlocked")
	check(Quests.is_quest_completed(&"something_greater"), "q5 completed")
	check(Quests.is_chapter_complete(), "chapter complete")
	eq(_chapter_done, 1, "chapter_completed emitted once")
	eq(Quests.get_objective_text(), "", "no objective after chapter")
	eq(Quests.get_quest_log().size(), 5, "quest log lists 5 quests")
	check(Progression.max_health() > 100.0 * 1.3, "hobgoblin health multiplier applied")


# ---------------------------------------------------------------- save / load
func _snapshot() -> Dictionary:
	# Through JSON like the real save file (ints become floats, StringNames strings).
	var d := {"game_state": GameState.get_save_data(), "progression": Progression.get_save_data(),
		"quests": Quests.get_save_data()}
	return JSON.parse_string(JSON.stringify(d))


func _restore(d: Dictionary) -> void:
	SaveManager.reset_all()
	GameState.load_save_data(d["game_state"])
	Progression.load_save_data(d["progression"])
	Quests.load_save_data(d["quests"])
	await get_tree().process_frame


func test_save_roundtrip() -> void:
	# Continue from the finished chain, add abilities/points/items.
	Progression.unlock_ability(&"wolf_dash")
	Progression.unlock_ability(&"flame_burst")
	Progression.unlock_ability(&"stone_guard")
	Progression.equip(0, &"stone_guard")   # swap
	check(Progression.spend_point(&"attack"), "spend point")
	var before := {
		"level": Progression.level, "xp": Progression.xp, "points": Progression.upgrade_points,
		"stage": Progression.stage, "abilities": Progression.unlocked_abilities.duplicate(),
		"equipped": Progression.equipped.duplicate(), "discovered": Progression.discovered.duplicate(),
		"supplies": Progression.item_count(&"supplies"), "atk": Progression.attack_power(),
		"flags": GameState.flags.duplicate(),
	}
	var snap := _snapshot()
	SaveManager.reset_all()
	eq(Progression.level, 1, "reset level")
	check(Progression.unlocked_abilities.is_empty(), "reset abilities")
	check(not Quests.is_quest_completed(&"a_small_beginning"), "reset quests")
	await _restore(snap)
	eq(Progression.level, before["level"], "level restored")
	eq(Progression.xp, before["xp"], "xp restored")
	eq(Progression.upgrade_points, before["points"], "points restored")
	eq(Progression.stage, before["stage"], "stage restored")
	eq(Progression.unlocked_abilities, before["abilities"], "abilities restored")
	eq(Progression.equipped, before["equipped"], "equipped restored")
	eq(Progression.discovered, before["discovered"], "discoveries restored")
	eq(Progression.item_count(&"supplies"), before["supplies"], "inventory restored")
	eq(Progression.attack_power(), before["atk"], "attack (upgrades) restored")
	check(Progression.has_unlock(&"shockwave_slam"), "shockwave restored")
	for k: StringName in before["flags"]:
		eq(GameState.has_flag(k), bool(before["flags"][k]), "flag %s restored" % k)
	for q: Dictionary in QuestData.QUESTS:
		check(Quests.is_quest_completed(q["id"]), "quest %s restored completed" % q["id"])
	eq(_chapter_done, 1, "loading a finished chapter does not re-emit chapter_completed")


func test_load_mid_quest() -> void:
	# Save at "Defeat the raiders" with 2 kills; load -> kills restart (guards respawn).
	_fresh()
	Events.zone_entered.emit(&"glade_edge")
	Events.interacted.emit(&"glade_signpost", null)
	Events.zone_entered.emit(&"rescue_site")
	Events.enemy_killed.emit(null, &"goblin_raider", [&"rescue_guard"])
	var snap := _snapshot()
	await _restore(snap)
	eq(Quests.get_objective_text(), "Defeat the raiders (0/3)", "mid-quest load restores step")
	# Save at the level step, then level up while loaded state is fresh -> step completes.
	_fresh()
	var prog := {"level": 3, "xp": 10}
	var qs := {"quests": {
		"a_small_beginning": {"status": "completed"}, "a_friend_in_trouble": {"status": "completed"},
		"a_place_to_belong": {"status": "completed"}, "the_ogres_claim": {"status": "completed"},
		"something_greater": {"status": "active", "step": 1, "progress": 0}}}
	await _restore({"game_state": {"flags": {"home_claimed": true, "boss_defeated": true}}, "progression": prog, "quests": qs})
	eq(Quests.get_objective_text(), "Reach level 5 (3/5)", "level step after load")
	# Already satisfied when loaded: level 5 save at the level step -> jumps to evolve.
	prog["level"] = 5
	await _restore({"game_state": {"flags": {"home_claimed": true, "boss_defeated": true}}, "progression": prog, "quests": qs})
	eq(Quests.get_objective_text(), "Evolve at the hearth", "satisfied level step completes on load")
	# Flag already set before the quest reaches the step.
	_fresh()
	GameState.set_flag(&"boss_defeated")
	qs = {"quests": {"a_small_beginning": {"status": "completed"}, "a_friend_in_trouble": {"status": "completed"},
		"a_place_to_belong": {"status": "completed"}}}
	await _restore({"game_state": {"flags": {"boss_defeated": true}}, "progression": {}, "quests": qs})
	check(Quests.is_quest_completed(&"the_ogres_claim"), "pre-set flag completes ogre quest")


func test_corrupt_data() -> void:
	_fresh()
	Progression.load_save_data({
		"level": "abc", "xp": [1, 2], "upgrade_points": {"x": 1}, "stage": "demon_god",
		"abilities": ["wolf_dash", 5, "not_an_ability", "shockwave_slam", null],
		"equipped": "wolf_dash", "discovered": ["glade", "nowhere", 3, "secret_pool"],
		"inventory": {"supplies": -3, "rope": "many", "gem": 2.0}, "upgrades": {"health": 99},
		"unlocks": ["wolf_dash", "shockwave_slam", 7], "rewards": "x",
	})
	eq(Progression.level, 1, "bad level -> 1")
	eq(Progression.xp, 0, "bad xp -> 0")
	eq(Progression.upgrade_points, 0, "bad points -> 0")
	eq(Progression.stage, &"goblin", "unknown stage -> goblin")
	eq(Progression.unlocked_abilities, [&"wolf_dash"] as Array[StringName], "only known slottable abilities kept")
	eq(Progression.equipped, [&"", &"", &""] as Array[StringName], "bad equipped -> empty")
	eq(Progression.discovered, [&"glade", &"secret_pool"] as Array[StringName], "only valid discoveries")
	eq(Progression.item_count(&"supplies"), 0, "negative item dropped")
	eq(Progression.item_count(&"rope"), 0, "non-numeric item dropped")
	eq(Progression.item_count(&"gem"), 2, "float count accepted")
	eq(Progression.get_upgrade_level(&"health"), 0, "upgrades clamped to level budget")
	check(Progression.has_unlock(&"shockwave_slam") and not Progression.has_unlock(&"wolf_dash"), "unlocks validated")
	Progression.load_save_data({"level": 1e30, "xp": -50, "stage": 12})
	eq(Progression.level, Progression.MAX_LEVEL, "huge level clamped")
	eq(Progression.stage, &"goblin", "non-string stage")
	Progression.load_save_data({})
	eq(Progression.level, 1, "empty dict -> new game")
	# Quests
	Quests.load_save_data({"quests": "garbage", "zones": 5})
	await get_tree().process_frame
	check(Quests.is_quest_active(&"a_small_beginning"), "garbage quests -> q1 active")
	Quests.load_save_data({"quests": {"the_ogres_claim": {"status": "completed"}, "a_small_beginning": {"status": "active", "step": 99, "progress": "x"}, "fake": {"status": "completed"}}})
	await get_tree().process_frame
	check(not Quests.is_quest_completed(&"the_ogres_claim"), "quest without prerequisites is repaired")
	check(not Quests.is_quest_active(&"a_small_beginning") or Quests.get_step_index(&"a_small_beginning") <= 2, "step index clamped")
	Quests.load_save_data({"quests": {"a_small_beginning": {"status": 3, "step": "a"}}})
	await get_tree().process_frame
	check(Quests.is_quest_active(&"a_small_beginning"), "bad status ignored -> fresh")
	eq(Quests.get_step_index(&"a_small_beginning"), 0, "fresh step 0")


# ---------------------------------------------------------------- abilities
func test_abilities() -> void:
	_fresh()
	var stub: Node3D = StubPlayer.new()
	add_child(stub)
	stub.global_position = Vector3(0, 0, 0)
	var ctrl := AbilityController.new()
	stub.add_child(ctrl)
	ctrl.setup(stub)
	eq(GameState.ability_controller, ctrl, "controller registered")
	_fail_reasons.clear()
	check(not ctrl.try_activate(0), "empty slot refuses")
	check(not ctrl.try_activate(7), "invalid slot refuses")
	Progression.equipped[2] = &"flame_burst"   # equipped but not unlocked (corrupt/locked)
	check(not ctrl.try_activate(2), "locked ability refuses")
	eq(_fail_reasons, [AbilityController.REASON_EMPTY, AbilityController.REASON_INVALID, AbilityController.REASON_LOCKED], "failure reasons")
	Progression.equipped[2] = &""
	# Wolf dash
	Progression.unlock_ability(&"wolf_dash")
	eq(Progression.get_equipped(0), &"wolf_dash", "auto-equip slot 1")
	check(ctrl.try_activate(0), "dash activates")
	eq(stub.energy, 75.0, "dash costs 25 energy")
	eq(stub.dash_calls.size(), 1, "begin_dash called")
	eq(stub.dash_calls[0][1], AbilityLibrary.DASH_SPEED, "dash speed")
	check(stub.dash_calls[0][3], "dash invulnerable")
	check(not ctrl.try_activate(0), "dash on cooldown")
	eq(_fail_reasons.back(), AbilityController.REASON_COOLDOWN, "cooldown reason")
	eq(stub.energy, 75.0, "no energy spent on cooldown")
	check(ctrl.get_cooldown_remaining(0) > 3.5 and ctrl.get_cooldown_total(0) == 4.0, "cooldown getters")
	ctrl._process(4.1)
	eq(ctrl.get_cooldown_remaining(0), 0.0, "cooldown expired")
	stub.busy = true
	check(not ctrl.try_activate(0), "busy refuses")
	eq(_fail_reasons.back(), AbilityController.REASON_BUSY, "busy reason")
	stub.busy = false
	# Stone guard: energy gate
	Progression.unlock_ability(&"stone_guard")
	eq(Progression.get_equipped(1), &"stone_guard", "auto-equip slot 2")
	stub.energy = 10.0
	check(not ctrl.try_activate(1), "not enough energy")
	eq(_fail_reasons.back(), AbilityController.REASON_ENERGY, "energy reason")
	eq(stub.energy, 10.0, "energy unchanged on failure")
	eq(ctrl.get_cooldown_remaining(1), 0.0, "no cooldown on failure")
	stub.energy = 100.0
	check(ctrl.try_activate(1), "stone guard activates")
	check(is_equal_approx(stub.damage_taken_multiplier, 0.4), "stone guard 60% reduction")
	check(stub.get_node_or_null("StoneGuardShell") != null, "stone shell visual on player")
	ctrl._process(3.0)
	check(is_equal_approx(stub.damage_taken_multiplier, 0.4), "still active at 3 s")
	ctrl._process(3.1)
	check(is_equal_approx(stub.damage_taken_multiplier, 1.0), "multiplier restored after expiry")
	check(not ctrl.is_stone_guard_active(), "guard inactive")
	# Restore on death
	ctrl._process(10.0)
	check(ctrl.try_activate(1), "stone guard again")
	Events.player_died.emit()
	check(is_equal_approx(stub.damage_taken_multiplier, 1.0), "restored on player death")
	# Another system changed the multiplier meanwhile: only our factor is removed.
	ctrl._process(15.0)
	stub.energy = 100.0
	check(ctrl.try_activate(1), "stone guard third time")
	stub.damage_taken_multiplier *= 2.0
	ctrl._process(6.5)
	check(is_equal_approx(stub.damage_taken_multiplier, 2.0), "foreign change preserved")
	stub.damage_taken_multiplier = 1.0
	# Flame burst
	Progression.unlock_ability(&"flame_burst")
	eq(Progression.get_equipped(2), &"flame_burst", "auto-equip slot 3")
	var dummy: Node3D = TargetDummy.new()
	add_child(dummy)
	dummy.global_position = Vector3(0, 1.0, -2.5)
	stub.energy = 100.0
	var casts_before: int = stub.cast_calls
	check(ctrl.try_activate(2), "flame activates")
	eq(stub.energy, 70.0, "flame costs 30")
	eq(stub.cast_calls, casts_before + 1, "cast animation played")
	await get_tree().create_timer(0.5).timeout
	var hb := stub.get_node_or_null("FlameBurstHitbox") as Hitbox
	check(hb != null, "flame hitbox owned by player")
	eq(dummy.hits.size(), 1, "flame hit the target exactly once")
	if dummy.hits.size() > 0:
		eq(dummy.hits[0].element, &"fire", "fire element")
		eq(dummy.hits[0].source, stub, "player is the source")
	stub.queue_free()
	dummy.queue_free()
