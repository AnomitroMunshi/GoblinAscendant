extends Node
## Integration & QA: drives a real Chapter 1 playthrough of the FULL game
## (real World, Player, Actors, QuestWorld and UI from scenes/main.tscn).
## Run headless (fast, simulated time):
##   godot --headless --fixed-fps 60 --path . res://tests/qa_chapter1.tscn -- --full
## or windowed (real time, saves screenshots to tests/screens/qa/):
##   godot --path . res://tests/qa_chapter1.tscn -- --full
## The `--full` user arg is required (main.gd builds the player-only playground
## without it). Prints PASS/FAIL per check; exit code = number of failures.
## The real user://savegame.json is backed up and restored.

const MAIN := "res://scenes/main.tscn"

var failures := 0
var passes := 0
var notes: Array[String] = []
var main: Node
var player: Player
var actors: Node
var quest_world: Node
var ui: Node
var headless := false
var _save_backup: PackedByteArray
var _had_save := false
var _events: Dictionary = {}          # signal name -> count
var _damage_log: Array = []           # [actor, source, amount]
var _provoked: Array = []             # actors that emitted actor_provoked
var _fps_samples: Array[float] = []


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	if not OS.get_cmdline_user_args().has("--full"):
		print("QA FAIL: launch with the user arg `-- --full` (the full game is not built otherwise)")
		get_tree().quit(1)
		return
	_backup_save()
	SaveManager.delete_save()
	_connect_events()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens/qa"))
	await _run()
	await _wait(1.0)  # let pending autosaves finish before restoring the real save
	_restore_save()
	print("")
	for n in notes:
		print("QA NOTE: ", n)
	if not _fps_samples.is_empty():
		var s := 0.0
		var lo := INF
		for f in _fps_samples:
			s += f
			lo = minf(lo, f)
		print("QA FPS: avg %.1f min %.1f over %d samples (%s)" % [s / _fps_samples.size(), lo, _fps_samples.size(), "headless" if headless else "windowed"])
	print("QA CHAPTER 1: %d passed, %d failed" % [passes, failures])
	get_tree().quit(failures)


func _run() -> void:
	await _boot(false)
	if not _parts_ok():
		return
	await _step_beginning()
	await _step_woods_and_attack()
	await _step_alpha_and_orb()
	await _step_rescue()
	await _step_death_respawn()
	await _step_adventurers()
	await _step_explore()
	await _step_cave_and_supplies()
	await _step_boss()
	await _step_save_load()
	await _step_camera_wall()
	await _step_hearth_and_evolve()
	await _step_bad_saves()
	await _step_title_does_not_autosave()


# ================================================================ helpers
func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func note(text: String) -> void:
	notes.append(text)
	print("  NOTE ", text)


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not headless and Engine.get_frames_per_second() > 0:
			_fps_samples.append(Engine.get_frames_per_second())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _connect_events() -> void:
	for sig in ["boss_engaged", "boss_disengaged", "boss_defeated"]:
		Events.connect(sig, _count.bind(sig).unbind(1))
	for sig in ["chapter_completed", "friend_rescued", "home_claimed", "player_died", "player_respawned",
			"game_saved", "game_loaded"]:
		Events.connect(sig, _count.bind(sig))
	Events.actor_damaged.connect(func(a: Node3D, info: DamageInfo) -> void:
		_damage_log.append([a, info.source, info.amount]))
	Events.actor_provoked.connect(func(a: Node3D, _by: Node3D) -> void: _provoked.append(a))


func _count(sig: String) -> void:
	_events[sig] = int(_events.get(sig, 0)) + 1


func _ev(sig: String) -> int:
	return int(_events.get(sig, 0))


func _boot(load_save: bool) -> void:
	GameState.show_title = false
	GameState.pending_load = load_save
	main = load(MAIN).instantiate()
	add_child(main)
	await _wait(1.5)
	player = GameState.player as Player
	actors = main.get_node_or_null(^"Actors")
	quest_world = main.get_node_or_null(^"QuestWorld")
	ui = main.get_node_or_null(^"UI")


## Mirrors GameState.continue_game() + main.gd: reset providers, then main.tscn
## loads the save in _ready before building any part.
func _reload(load_save: bool) -> void:
	main.queue_free()
	await _frames(3)
	SaveManager.reset_all()
	GameFeel.reset()
	GameState.menu_open = false
	await _boot(load_save)


func _parts_ok() -> bool:
	var ok := true
	for part in ["World", "Player", "Actors", "QuestWorld", "UI"]:
		var has: bool = main.get("parts").has(part)
		check(has, "main built part %s" % part)
		ok = ok and has
	check(GameState.world is WorldRoot, "GameState.world is the real WorldRoot (not the playground)")
	if not ok or not (GameState.world is WorldRoot) or player == null:
		print("QA FAIL: the full game did not build - aborting")
		return false
	return true


func _tp(pos: Vector3, yaw := NAN) -> void:
	player.global_position = GameState.ground_point(pos) + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	if not is_nan(yaw):
		player._facing_yaw = yaw
		player._facing_pivot.rotation.y = yaw
	player.camera_rig.snap_behind()
	await _frames(4)


func _shot(name: String) -> void:
	if headless:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/screens/qa/%s.png" % name)


func _actors_of(type: StringName, tag: StringName = &"") -> Array[EnemyBase]:
	var out: Array[EnemyBase] = []
	if actors == null:
		return out
	for c in actors.get_children():
		var e := c as EnemyBase
		if e and not e.is_dead() and e.enemy_type == type and (tag == &"" or e.spawn_tags.has(tag)):
			out.append(e)
	return out


func _kill(e: Node) -> int:
	var info := DamageInfo.make(e.health.health + 500.0, player, 2.0, 1.0)
	info.unblockable = true
	info.hit_position = e.global_position + Vector3.UP
	return e.take_damage(info)


func _hit(e: Node, amount: float) -> int:
	var info := DamageInfo.make(amount, player, 1.0, 0.1)
	info.unblockable = true
	return e.take_damage(info)


func _interactable(id: StringName) -> Interactable:
	for n in main.find_children("*", "Interactable", true, false):
		var it := n as Interactable
		if it.interact_id == id and it.enabled:
			return it
	return null


## Walks the player up to an Interactable, checks the real detector offers it,
## then uses it through Interactable.interact(player).
func _use(id: StringName, label: String) -> bool:
	var it := _interactable(id)
	check(it != null, "%s: interactable '%s' exists" % [label, id])
	if it == null:
		return false
	var at := it.global_position
	var off := Vector3(1.0, 0, 0.4)
	await _tp(at + off, atan2(off.x, off.z))
	await _wait(0.25)
	check(player._current_interactable == it, "%s: player's detector offers '%s' (prompt '%s')" % [label, id, it.prompt])
	it.interact(player)
	await _wait(0.2)
	return true


func _objective_ok(expect_text: String, expect_pos: Variant, label: String, tol := 2.0) -> void:
	var txt := Quests.get_objective_text()
	check(txt.begins_with(expect_text), "%s: objective '%s'" % [label, txt])
	if ui:
		var hud_txt: String = ui.hud.objective_text.text
		check(hud_txt.begins_with(expect_text), "%s: HUD objective shows '%s'" % [label, hud_txt])
	var pos: Variant = Quests.get_objective_position()
	if expect_pos == null:
		check(pos == null, "%s: no objective marker" % label)
	else:
		var ok: bool = pos is Vector3 and Vector2(pos.x - expect_pos.x, pos.z - expect_pos.z).length() < tol \
			and absf(pos.y - GameState.ground_height(pos.x, pos.z)) < 0.05
		check(ok, "%s: objective marker %s on ground near %s" % [label, pos, expect_pos])


func _near(a: Vector3, b: Vector3, tol: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < tol


func _on_ground() -> bool:
	var p := player.global_position
	var g := GameState.ground_height(p.x, p.z)
	return p.y > g - 0.4 and p.y < g + 1.0


# ================================================================ steps
func _step_beginning() -> void:
	print("--- A Small Beginning")
	check(Quests.is_quest_active(&"a_small_beginning"), "first quest active after boot")
	check(_near(player.global_position, WorldLayout.PLAYER_START, 1.0) and _on_ground(), "player spawned on the ground at the glade start")
	# The spawn point lies inside the glade landmark zone, so step 1 completes on spawn.
	var idx := Quests.get_step_index(&"a_small_beginning")
	if idx == 1:
		note("'Look around the glade' completes the moment the player spawns (spawn is inside the glade zone): design item, see report")
	check(idx >= 0, "first quest has a current step (%d)" % idx)
	_objective_ok("Read the signpost", QuestData.SIGNPOST_POS, "beginning")
	await _shot("01_glade")
	await _use(&"glade_signpost", "signpost")
	check(Quests.is_quest_completed(&"a_small_beginning"), "A Small Beginning completed")
	check(Quests.is_quest_active(&"a_friend_in_trouble"), "A Friend in Trouble active")
	_objective_ok("Find the injured goblin", WorldLayout.RESCUE_SITE, "friend")


func _step_woods_and_attack() -> void:
	print("--- Howling Woods: light attack vs a real wolf")
	var wolves := _actors_of(&"wolf", &"pack_a")
	check(wolves.size() == 3, "pack_a has 3 real wolves (%d)" % wolves.size())
	if wolves.is_empty():
		return
	var w := wolves[0]
	var landed := 0
	var multi := false
	var tries := 0
	while tries < 6 and landed == 0:
		tries += 1
		var to := w.global_position - player.global_position
		var dir := Vector3(to.x, 0, to.z).normalized() if tries > 1 else Vector3(0, 0, 1)
		var spot := w.global_position - dir * 1.05
		await _tp(spot, atan2(-dir.x, -dir.z))  # Player.get_facing() = (-sin, 0, -cos)
		await _frames(2)
		var hp0: float = w.health.health
		_damage_log.clear()
		Input.action_press(&"attack_light")
		await _frames(2)
		Input.action_release(&"attack_light")
		await _wait(0.9)
		var hits := _damage_log.filter(func(e: Array) -> bool: return e[0] == w and e[1] == player).size()
		if hits > 1:
			multi = true
		if hits == 1:
			landed = 1
			check(w.health.health < hp0 or w.is_dead(), "wolf HP dropped %.1f -> %.1f" % [hp0, w.health.health])
	check(landed == 1, "one light swing damaged the real wolf exactly once (tries %d)" % tries)
	check(not multi, "no swing hit the same wolf more than once")
	for e in _actors_of(&"wolf", &"pack_a"):
		_kill(e)
	await _wait(0.3)
	check(_actors_of(&"wolf", &"pack_a").is_empty(), "pack_a cleared")


func _step_alpha_and_orb() -> void:
	print("--- Alpha wolf den: essence orb")
	await _tp(WorldLayout.ALPHA_WOLF_DEN + Vector3(0, 0, 9))
	var alpha := _actors_of(&"alpha_wolf")
	check(alpha.size() == 1, "alpha wolf spawned")
	if alpha.is_empty():
		return
	check(not Progression.has_ability(&"wolf_dash"), "wolf_dash not owned yet")
	var r := _kill(alpha[0])
	check(r == DamageInfo.Result.KILLED, "alpha wolf killed through take_damage")
	for e in _actors_of(&"wolf", &"alpha_den"):
		_kill(e)
	check(GameState.has_flag(&"alpha_wolf_defeated"), "flag alpha_wolf_defeated set")
	await _frames(2)
	var orb: QuestEssenceOrb = quest_world._orbs.get(&"wolf_dash")
	check(is_instance_valid(orb), "essence orb spawned for wolf_dash")
	if not is_instance_valid(orb):
		return
	await _shot("02_essence_orb")
	await _wait(0.7)
	check(not Progression.has_ability(&"wolf_dash"), "orb not absorbed from a distance")
	await _tp(orb.global_position - Vector3.UP * 1.1)
	await _wait(0.8)
	check(Progression.has_ability(&"wolf_dash"), "touching the orb unlocked wolf_dash")
	check(Progression.get_equipped(0) == &"wolf_dash", "wolf_dash auto-equipped in slot 1")
	check(not is_instance_valid(orb) or orb.is_queued_for_deletion() or orb._collected, "orb consumed")


func _step_rescue() -> void:
	print("--- A Friend in Trouble")
	await _tp(WorldLayout.RESCUE_SITE + Vector3(10, 0, 8))
	await _wait(0.3)
	check(Quests.get_step_index(&"a_friend_in_trouble") == 1, "rescue_site zone reached (step 2)")
	check(GameState.checkpoint_id == &"woods_edge", "checkpoint woods_edge")
	var guards := _actors_of(&"goblin_raider", &"rescue_guard")
	check(guards.size() == WorldLayout.RESCUE_GUARD_COUNT, "%d real rescue guards" % guards.size())
	_objective_ok("Defeat the raiders (0/3)", WorldLayout.RESCUE_SITE, "guards")
	await _shot("03_rescue_site")
	# Nib refuses while guards remain.
	var nib: QuestFriend = quest_world.nib
	check(nib.injured and _near(nib.global_position, QuestData.NIB_RESCUE_POS, 0.5), "Nib waits injured at the rescue spot")
	check(not Quests.is_waiting_for(&"nib_rescue"), "Nib cannot be helped while guards remain")
	_kill(guards[0])
	await _frames(2)
	_objective_ok("Defeat the raiders (1/3)", WorldLayout.RESCUE_SITE, "guards 1 down")
	# Save between guard kills, then Continue: guards respawn, so the counter restarts.
	await _wait(1.0)
	check(SaveManager.save_game(), "save between guard kills")
	await _reload(true)
	guards = _actors_of(&"goblin_raider", &"rescue_guard")
	check(guards.size() == WorldLayout.RESCUE_GUARD_COUNT, "after Continue all %d guards are back (%d)" % [WorldLayout.RESCUE_GUARD_COUNT, guards.size()])
	check(Quests.get_step_index(&"a_friend_in_trouble") == 1, "after Continue still on 'Defeat the raiders'")
	_objective_ok("Defeat the raiders (0/3)", WorldLayout.RESCUE_SITE, "guards after Continue")
	check(Progression.has_ability(&"wolf_dash"), "wolf_dash kept across Continue")
	await _tp(WorldLayout.RESCUE_SITE + Vector3(10, 0, 8))
	for g in guards:
		_kill(g)
	await _wait(0.3)
	check(GameState.has_flag(&"rescue_guards_defeated"), "flag rescue_guards_defeated")
	_objective_ok("Help Nib up", QuestData.NIB_RESCUE_POS, "nib")
	var nib2: QuestFriend = quest_world.nib
	await _use(&"nib_rescue", "nib")
	check(GameState.has_flag(&"friend_rescued"), "flag friend_rescued")
	check(Quests.is_quest_completed(&"a_friend_in_trouble"), "A Friend in Trouble completed")
	check(_ev("friend_rescued") >= 1, "Events.friend_rescued fired")
	_objective_ok("Find the cave in the north-east", WorldLayout.CAVE_ENTRANCE, "cave")
	await _wait(6.0)
	check(_near(nib2.global_position, QuestData.NIB_HOME_POS, 1.0), "Nib relocated home (%s)" % nib2.global_position)
	check(not nib2.injured and nib2.interactable.enabled and nib2.interactable.interact_id == &"nib_talk", "Nib at home is talkable")


func _step_death_respawn() -> void:
	print("--- Death and respawn")
	await _tp(WorldLayout.RESCUE_SITE + Vector3(4, 0, -6))
	var died := _ev("player_died")
	var info := DamageInfo.make(player.health.max_health * 5.0, null, 0.0, 0.0)
	info.unblockable = true
	player._invuln_time = 0.0
	player.take_damage(info)
	check(player.is_dead(), "player dies from lethal damage")
	check(_ev("player_died") == died + 1, "Events.player_died fired")
	check(not SaveManager.save_game(), "saving refused while dead")
	await _wait(0.4)
	if ui:
		check(ui.death_screen.visible, "death screen shown")
	await _wait(3.2)
	check(not player.is_dead(), "player respawned")
	check(is_equal_approx(player.health.health, player.health.max_health), "respawn at full HP (%.0f/%.0f)" % [player.health.health, player.health.max_health])
	var cp: Vector3 = WorldLayout.CHECKPOINTS[GameState.checkpoint_id]
	check(GameState.checkpoint_id == &"woods_edge" and _near(player.global_position, cp, 1.5), "respawned at last checkpoint woods_edge")
	await _wait(0.5)
	check(_on_ground() and player.is_on_floor(), "respawn point is valid ground")


func _step_adventurers() -> void:
	print("--- Neutral adventurers")
	var advs := _actors_of(&"adventurer")
	check(advs.size() == 3, "3 adventurers at the camp (%d)" % advs.size())
	if advs.size() < 3:
		return
	var a0 := advs[0]
	await _tp(a0.global_position + Vector3(1.4, 0, 0.6))
	var hp0: float = player.health.health
	_damage_log.clear()
	_provoked.clear()
	await _wait(15.0)
	var dmg_to_player := _damage_log.filter(func(e: Array) -> bool: return e[0] == player).size()
	check(dmg_to_player == 0 and player.health.health >= hp0, "idle player beside adventurers 15 s: never damaged (hp %.0f -> %.0f)" % [hp0, player.health.health])
	check(advs.all(func(a: EnemyBase) -> bool: return not a.has_grudge(player)), "no adventurer holds a grudge")
	check(advs.all(func(a: EnemyBase) -> bool: return not a.is_in_group(&"lock_targets")), "adventurers are not lock targets while neutral")
	await _shot("04_camp")
	# Move one adventurer outside the assist radius, then provoke another.
	var far := advs[2]
	var a1 := advs[1]
	far.global_position = GameState.ground_point(a0.global_position + Vector3(20, 0, -14)) + Vector3.UP * 0.1
	far.reset_physics_interpolation()
	await _frames(2)
	var d_far: float = far.global_position.distance_to(a0.global_position)
	var d_near: float = a1.global_position.distance_to(a0.global_position)
	_hit(a0, 4.0)
	await _frames(2)
	check(a0.has_grudge(player), "attacked adventurer %s holds a grudge" % a0.display_name)
	check(_provoked == [a0], "only the attacked adventurer emitted actor_provoked")
	check(d_near > a0.stats.ally_assist_radius or a1.has_grudge(player), "ally %s within %.1f m assists" % [a1.display_name, d_near])
	check(not far.has_grudge(player), "ally %s %.1f m away (outside %.0f m) stays calm" % [far.display_name, d_far, a0.stats.ally_assist_radius])
	var others := 0
	for c in actors.get_children():
		var e := c as EnemyBase
		if e and e != a0 and e != a1 and e.has_grudge(player):
			others += 1
	check(others == 0, "no other actor anywhere took a grudge")
	await _wait(1.5)
	check(a0.target == player and a0.state_name() in ["CHASE", "ATTACK", "RECOVER", "HURT"], "%s retaliates (%s)" % [a0.display_name, a0.state_name()])
	# Leave: beyond calm distance but not so far that the camp sleeps.
	await _tp(WorldLayout.ADVENTURER_CAMP + Vector3(-45, 0, 0))
	await _wait(24.0)
	check(not a0.has_grudge(player) and not a1.has_grudge(player), "grudges calm down ~20 s after the player leaves")
	# Provoke again and run far away (camp out of the 70 m sleep range).
	_hit(a0, 1.0)
	check(a0.has_grudge(player), "re-provoked")
	await _tp(WorldLayout.ADVENTURER_CAMP + Vector3(-110, 0, 30))
	await _wait(30.0)
	check(not a0.has_grudge(player), "grudge also calms when the player leaves far beyond the sleep range")
	a0.health.heal(a0.health.max_health)


func _step_explore() -> void:
	print("--- Exploration (real landmark zones) + Stone Guard shrine")
	for id: StringName in WorldLayout.LANDMARKS:
		if Progression.is_discovered(id):
			continue
		await _tp(WorldLayout.LANDMARKS[id]["pos"] + Vector3(2, 0, 2))
		await _wait(0.3)
		check(Progression.is_discovered(id), "landmark %s discovered via its real TriggerZone" % id)
	for e in _actors_of(&"goblin_raider", &"ruins"):
		_kill(e)
	await _use(&"ruins_shrine", "shrine")
	check(Progression.has_ability(&"stone_guard"), "shrine unlocked stone_guard")
	check(GameState.has_flag(&"shrine_used"), "shrine spent")


func _step_cave_and_supplies() -> void:
	print("--- A Place to Belong")
	check(Quests.is_quest_active(&"a_place_to_belong"), "A Place to Belong active")
	# 'cave' was discovered during exploration, so the zone step is already satisfied.
	check(Quests.get_step_index(&"a_place_to_belong") == 1, "cave step done (visited)")
	await _tp(WorldLayout.CAVE_ENTRANCE + Vector3(-3, 0, 3))
	await _wait(0.2)
	var order := [0, 1, 2]
	for n in 3:
		var pos: Variant = Quests.get_objective_position()
		var nearest := -1
		var best := INF
		for i in order:
			var d := player.global_position.distance_to(QuestData.SUPPLY_POSITIONS[i])
			if d < best:
				best = d
				nearest = i
		check(pos is Vector3 and _near(pos, QuestData.SUPPLY_POSITIONS[nearest], 0.5), "supply marker points at nearest remaining supply %d" % nearest)
		check(Quests.get_objective_text() == "Gather supplies (%d/3)" % n, "objective '%s'" % Quests.get_objective_text())
		await _use(StringName("supply_%d" % nearest), "supply %d" % nearest)
		order.erase(nearest)
		check(Progression.item_count(QuestData.SUPPLY_ITEM) == n + 1, "supplies in inventory %d" % (n + 1))
	check(Quests.is_quest_completed(&"a_place_to_belong"), "A Place to Belong completed")
	_objective_ok("Defeat the ogre", WorldLayout.OGRE_CLEARING, "ogre")


func _step_boss() -> void:
	print("--- The Ogre's Claim")
	var ogres := _actors_of(&"ogre")
	check(ogres.size() == 1, "ogre spawned")
	if ogres.is_empty():
		return
	var ogre: EnemyBase = ogres[0]
	var e0 := _ev("boss_engaged")
	await _tp(WorldLayout.OGRE_CLEARING + Vector3(14, 0, 6))
	await _wait(0.5)
	check(_ev("boss_engaged") == e0 + 1 and GameState.boss_active, "entering the arena engages the boss")
	if ui:
		check(ui.hud.boss_box.visible, "boss bar visible")
	await _shot("05_boss")
	_hit(ogre, ogre.health.max_health * 0.4)
	check(ogre.health.health < ogre.health.max_health * 0.7, "ogre damaged to %.0f/%.0f" % [ogre.health.health, ogre.health.max_health])
	await _wait(1.0)
	await _tp(WorldLayout.OGRE_CLEARING + Vector3(42, 0, 10))
	await _wait(1.0)
	check(_ev("boss_disengaged") >= 1 and not GameState.boss_active, "leaving the arena disengages")
	check(is_equal_approx(ogre.health.health, ogre.health.max_health), "boss reset to full HP")
	check(SaveManager.save_game(), "saving allowed after disengage")
	await _tp(WorldLayout.OGRE_CLEARING + Vector3(14, 0, 6))
	await _wait(0.5)
	check(GameState.boss_active, "re-engaged")
	await _wait(2.0)
	var r := _kill(ogre)
	check(r == DamageInfo.Result.KILLED, "ogre killed through take_damage")
	await _wait(0.3)
	check(_ev("boss_defeated") >= 1 and GameState.has_flag(&"boss_defeated"), "boss_defeated event + flag")
	check(not GameState.boss_active, "boss_active cleared")
	check(Quests.is_quest_completed(&"the_ogres_claim"), "The Ogre's Claim completed")
	check(GameState.checkpoint_id == &"clearing_edge", "checkpoint clearing_edge")
	_objective_ok("Claim the cave as home", QuestData.HEARTH_POS, "home")


func _step_save_load() -> void:
	print("--- Save / Continue (mid-chain)")
	await _tp(WorldLayout.CHECKPOINTS[&"clearing_edge"] + Vector3(3, 0, 3))
	await _wait(1.5)
	var before := {
		"quests": Quests.get_save_data(), "flags": GameState.flags.duplicate(),
		"level": Progression.level, "xp": Progression.xp, "abilities": Progression.unlocked_abilities.duplicate(),
		"equipped": Progression.equipped.duplicate(), "checkpoint": GameState.checkpoint_id,
		"discovered": Progression.discovered.size(), "inventory": Progression.inventory.duplicate(),
	}
	var saved_pos := player.global_position
	check(SaveManager.save_game(), "save_game() ok")
	check(SaveManager.has_save(), "has_save() after saving")
	await _reload(true)
	await _wait(0.5)
	check(_ev("game_loaded") >= 2, "load_game() ran on Continue")
	check(JSON.stringify(Quests.get_save_data()) == JSON.stringify(before["quests"]), "quest states restored")
	check(Quests.is_quest_active(&"something_greater") and Quests.get_step_index(&"something_greater") == 0, "Something Greater step 1 active")
	var flags_ok := true
	for f: StringName in before["flags"]:
		flags_ok = flags_ok and GameState.has_flag(f) == bool(before["flags"][f])
	check(flags_ok, "flags restored (%d)" % before["flags"].size())
	check(Progression.level == before["level"] and Progression.xp == before["xp"], "level/xp restored (L%d %d xp)" % [Progression.level, Progression.xp])
	check(Progression.unlocked_abilities == before["abilities"] and Progression.equipped == before["equipped"], "abilities + slots restored %s" % [Progression.equipped])
	check(Progression.inventory == before["inventory"] and Progression.discovered.size() == before["discovered"], "inventory + discoveries restored")
	check(GameState.checkpoint_id == before["checkpoint"], "checkpoint restored (%s)" % GameState.checkpoint_id)
	check(_actors_of(&"ogre").is_empty(), "defeated boss not respawned")
	check(_actors_of(&"goblin_raider", &"rescue_guard").is_empty(), "rescue guards not respawned")
	check(_actors_of(&"alpha_wolf").is_empty(), "alpha wolf not respawned")
	check(quest_world._orbs.is_empty(), "absorbed essence orb not respawned")
	check(quest_world._supplies.is_empty(), "collected supplies stay gone")
	var nib: QuestFriend = quest_world.nib
	check(not nib.injured and _near(nib.global_position, QuestData.NIB_HOME_POS, 0.5), "Nib waits at home after Continue")
	check(_near(player.global_position, saved_pos, 1.0), "spawned at the saved position")
	check(_on_ground() and player.is_on_floor(), "spawn position is valid ground (y %.2f, ground %.2f)" % [player.global_position.y, GameState.ground_height(player.global_position.x, player.global_position.z)])
	check(not GameState.world.is_in_water(player.global_position), "spawn not in water")
	_objective_ok("Claim the cave as home", QuestData.HEARTH_POS, "after Continue")


func _step_camera_wall() -> void:
	print("--- Camera spring arm vs the real cave wall")
	await _tp(QuestData.HEARTH_POS)
	var rig: PlayerCamera = player.camera_rig
	var full: float = rig.distance * rig._dist_scale()
	# Find the nearest real WORLD wall around the hearth (chest-height rays).
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3.UP * 1.0
	var wall_dir := Vector3.ZERO
	var wall_d := INF
	for i in 32:
		var a := TAU * i / 32.0
		var d := Vector3(sin(a), 0, cos(a))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + d * 20.0, Layers.WORLD, [player.get_rid()]))
		if not hit.is_empty() and origin.distance_to(hit.position) < wall_d:
			wall_d = origin.distance_to(hit.position)
			wall_dir = d
	check(wall_d < 20.0, "found a cave wall %.1f m from the hearth" % wall_d)
	if wall_d >= 20.0:
		return
	# Stand 1.2 m from the wall with the camera arm pointing into it.
	await _tp(player.global_position + wall_dir * maxf(0.0, wall_d - 1.2), atan2(wall_dir.x, wall_dir.z))
	rig.yaw = atan2(wall_dir.x, wall_dir.z)
	rig.pitch = deg_to_rad(-10.0)
	rig._apply_rotation()
	await _wait(0.3)
	var shortest := rig.get_arm_length()
	check(shortest < full * 0.6, "spring arm shortens against the cave wall (%.2f of %.2f m)" % [shortest, full])
	await _shot("06_cave_camera")
	# open meadow: full length
	await _tp(WorldLayout.START_GLADE + Vector3(6, 0, -6))
	rig.yaw = 0.0
	rig.pitch = deg_to_rad(-12.0)
	rig._apply_rotation()
	await _wait(1.0)
	check(rig.get_arm_length() > full * 0.95, "arm at full length in the open glade (%.2f)" % rig.get_arm_length())


func _step_hearth_and_evolve() -> void:
	print("--- Something Greater")
	await _use(&"cave_hearth", "hearth")
	check(GameState.has_flag(&"home_claimed"), "home claimed")
	check(_ev("home_claimed") >= 1, "Events.home_claimed fired")
	check(GameState.checkpoint_id == &"home", "checkpoint home")
	check(quest_world._hearth_fire.visible, "hearth fire lit")
	if Progression.level < 5:
		var need := Progression.total_xp_for_level(5) - (Progression.total_xp_for_level(Progression.level) + Progression.xp)
		note("real content reached only level %d; topped up %d XP with Progression.add_xp (the test skips most wolves/raiders)" % [Progression.level, need])
		await _wait(0.2)
		check(Quests.get_objective_text().begins_with("Reach level 5 (%d/5)" % Progression.level), "level objective '%s'" % Quests.get_objective_text())
		Progression.add_xp(need, "QA top-up")
	else:
		note("real content reached level %d without any XP top-up" % Progression.level)
	await _wait(0.6)
	check(Progression.level >= 5, "level 5 reached")
	check(Progression.can_evolve(), "can evolve: missing %s" % [Progression.get_missing_requirements()])
	_objective_ok("Evolve at the hearth", QuestData.HEARTH_POS, "evolve")
	var cc := _ev("chapter_completed")
	await _use(ProgressionEvolution.ALTAR_ID, "altar")
	await _wait(1.5)
	check(Progression.stage == &"hobgoblin", "Progression stage is hobgoblin")
	check(player.model.stage == &"hobgoblin", "player model became Hobgoblin")
	check(is_equal_approx(player._scale, 1.3), "player scale 1.3")
	check(Progression.has_unlock(&"shockwave_slam"), "shockwave_slam unlocked")
	check(_ev("chapter_completed") == cc + 1, "Events.chapter_completed fired once")
	check(Quests.is_chapter_complete(), "every Chapter 1 quest completed")
	check(Quests.get_objective_text() == "", "no objective left")
	await _shot("07_hobgoblin")
	await _wait(1.0)
	check(SaveManager.save_game(), "final save")
	await _reload(true)
	check(Progression.stage == &"hobgoblin" and player.model.stage == &"hobgoblin" and is_equal_approx(player._scale, 1.3), "Hobgoblin restored on Continue")
	check(Quests.is_chapter_complete(), "chapter stays complete after Continue")


func _step_bad_saves() -> void:
	print("--- Corrupted / missing save")
	await _wait(1.0)
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"sections\": {\"progression\": {\"level\": 9")
	f.close()
	check(not SaveManager.has_save(), "corrupt save: has_save() false (Continue hidden)")
	check(not SaveManager.load_game(), "corrupt save: load_game() refuses")
	GameState.pending_load = true
	await _reload(SaveManager.has_save())
	check(Quests.is_quest_active(&"a_small_beginning") and Progression.level == 1 and Progression.stage == &"goblin", "corrupt save: Continue falls back to a fresh game")
	check(player != null and _on_ground(), "corrupt save: player spawned on ground")
	# Garbage types inside a structurally valid save.
	await _wait(1.0)
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "sections": {
		"progression": {"level": "x", "xp": -5, "stage": 3, "abilities": [1, "nope"], "inventory": {"supplies": "lots"}},
		"game_state": {"flags": "bad", "checkpoint_id": "nowhere", "position": [1e30, 0, 0]},
		"quests": {"quests": {"the_ogres_claim": {"status": "completed"}}, "zones": 5}}}))
	f.close()
	await _reload(true)
	check(Progression.level == 1 and Progression.unlocked_abilities.is_empty() and GameState.checkpoint_id == &"glade", "malformed fields fall back to defaults")
	check(not Quests.is_quest_completed(&"the_ogres_claim"), "quest without prerequisites is not restored")
	check(_on_ground() and _near(player.global_position, WorldLayout.PLAYER_START, 2.0), "bad position ignored: spawned at the glade")
	await _wait(1.0)
	SaveManager.delete_save()
	check(not SaveManager.has_save(), "missing save: has_save() false")
	check(not SaveManager.load_game(), "missing save: load_game() false")
	await _reload(SaveManager.has_save())
	check(Quests.is_quest_active(&"a_small_beginning") and Progression.level == 1, "missing save: fresh game")


func _step_title_does_not_autosave() -> void:
	print("--- Title screen must not overwrite the save")
	await _wait(1.0)
	var marker := JSON.stringify({"version": 1, "timestamp": "qa-marker", "sections": {
		"progression": {"level": 4}, "game_state": {"checkpoint_id": "camp"}, "quests": {}}})
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(marker)
	f.close()
	main.queue_free()
	await _frames(3)
	SaveManager.reset_all()
	GameState.show_title = true
	GameState.pending_load = false
	main = load(MAIN).instantiate()
	add_child(main)
	await _wait(3.0)
	check(main.get_node(^"UI").mode == UiRoot.Mode.TITLE, "title screen is up")
	await _shot("08_title")
	check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == marker, "the save file is untouched while the title screen is shown")
	GameState.show_title = false


# ================================================================ save backup
func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	else:
		SaveManager.delete_save()
