extends Node3D
## Headless combat / enemy AI tests (Combat agent).
## Run:  Godot --headless --fixed-fps 60 --path . res://tests/combat_test.tscn
## Prints PASS/FAIL per check and quits with exit code = number of failures.

const StandIn := preload("res://tests/combat_standin.gd")

var failures := 0
var passes := 0
var arena: Node3D
var only := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	GameState.flags.clear()
	await get_tree().physics_frame
	var tests := [
		"test_wolf_detect_chase", "test_wolf_end_to_end", "test_leash_return", "test_no_detect_through_wall",
		"test_attack_once_per_activation", "test_token_limit", "test_stuck_recovery", "test_death_signals",
		"test_goblin_retreat", "test_human_block", "test_adventurers_neutral", "test_adventurer_provoked",
		"test_adventurer_vs_wolf", "test_ogre_boss", "test_spawner_flags",
	]
	for t: String in tests:
		if only != "" and not t.contains(only):
			continue
		if not has_method(t):
			continue
		print("--- ", t)
		_new_arena()
		await call(t)
		_clear_arena()
		await wait(0.1)
	print("=== combat tests: %d passed, %d failed ===" % [passes, failures])
	GameState.flags.clear()
	GameState.boss_active = false
	get_tree().quit(failures)


# ------------------------------------------------------------------ helpers
func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func wait(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for i in frames:
		await get_tree().physics_frame


func _new_arena() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	add_child(arena)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	arena.add_child(body)


func _clear_arena() -> void:
	GameState.boss_active = false
	if arena:
		arena.free()
	arena = null
	GameState.player = null


func wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos
	arena.add_child(body)


func player_at(pos: Vector3) -> CharacterBody3D:
	var p: CharacterBody3D = StandIn.new()
	p.position = pos
	arena.add_child(p)
	return p


func spawn(script: Script, type: StringName, pos: Vector3, tags: Array = [], yaw_to: Variant = null) -> EnemyBase:
	var e: EnemyBase = script.new()
	e.configure(EnemyStats.create(type), pos, tags)
	e.position = pos
	arena.add_child(e)
	if yaw_to is Vector3:
		var d: Vector3 = (yaw_to as Vector3) - pos
		e.rotation.y = atan2(-d.x, -d.z)
	return e


func hit(e: Node, src: Node3D, amount: float, stagger: float = 0.3, heavy: bool = false) -> int:
	var info := DamageInfo.make(amount, src, 2.0, stagger)
	info.is_heavy = heavy
	if src:
		info.knockback = (e.global_position - src.global_position).normalized() * 2.0
	return e.take_damage(info)


func flat_dist(a: Node3D, b: Variant) -> float:
	var p: Vector3 = b if b is Vector3 else (b as Node3D).global_position
	return Vector2(a.global_position.x - p.x, a.global_position.z - p.z).length()


# ------------------------------------------------------------------ tests
func test_wolf_detect_chase() -> void:
	var w := spawn(EnemyWolf, &"wolf", Vector3.ZERO, [], Vector3(0, 0, -10))
	var p := player_at(Vector3(0, 0, -10))
	await wait(0.6)
	check(w.target == p, "wolf acquires player in FOV within detection radius")
	check(w.state in [EnemyBase.State.CHASE, EnemyBase.State.ATTACK], "wolf is chasing (%s)" % w.state_name())
	await wait(1.0)
	check(flat_dist(w, p) < 8.0, "wolf closed distance (%.1f m)" % flat_dist(w, p))
	# out of range player is not detected
	var w2 := spawn(EnemyWolf, &"wolf", Vector3(100, 0, 0), [], Vector3(100, 0, -40))
	await wait(0.5)
	check(w2.target == null, "wolf ignores player 100 m away")


func test_wolf_end_to_end() -> void:
	var w := spawn(EnemyWolf, &"wolf", Vector3.ZERO, [], Vector3(0, 0, -8))
	var p := player_at(Vector3(0, 0, -8))
	var states := {}
	w.state_changed.connect(func(_o: int, n: int) -> void: states[n] = true)
	var acts := [0]
	w.attack_performed.connect(func(_id: StringName) -> void: acts[0] += 1)
	await wait(5.0)
	check(states.has(EnemyBase.State.CHASE), "e2e: chased")
	check(states.has(EnemyBase.State.ATTACK) and states.has(EnemyBase.State.RECOVER), "e2e: telegraphed attack + recover")
	check(acts[0] >= 1 and p.hits.size() >= 1, "e2e: attack landed (%d activations, %d hits)" % [acts[0], p.hits.size()])
	check(GameState.in_combat(), "e2e: GameState engaged while fighting the player")
	# hurt
	var r := hit(w, p, 5.0, 0.6)
	check(r == DamageInfo.Result.HIT and w.state == EnemyBase.State.HURT, "e2e: stagger -> HURT")
	check(w.health.health < w.health.max_health, "e2e: damage applied")
	# leash/reset: player teleports far away -> wolf loses it and goes home, regenerating
	p.global_position = Vector3(0, 0, -120)
	await wait(9.0)
	check(w.state in [EnemyBase.State.RETURN, EnemyBase.State.IDLE, EnemyBase.State.PATROL, EnemyBase.State.INVESTIGATE], "e2e: lost target (%s)" % w.state_name())
	await wait(14.0)
	check(flat_dist(w, Vector3.ZERO) < w.stats.patrol_radius + 2.0, "e2e: back home (%.1f m)" % flat_dist(w, Vector3.ZERO))
	check(w.health.ratio() > 0.99, "e2e: regenerated to full")
	check(not GameState.in_combat(), "e2e: disengaged")
	# death
	var killed := []
	Events.enemy_killed.connect(func(e: Node3D, t: StringName, tags: Array) -> void: killed.append([e, t, tags]), CONNECT_ONE_SHOT)
	p.global_position = Vector3(0, 0, -5)
	r = hit(w, p, 999.0)
	check(r == DamageInfo.Result.KILLED and w.is_dead(), "e2e: killed")
	check(killed.size() == 1 and killed[0][1] == &"wolf", "e2e: enemy_killed(wolf)")
	check(not w.is_in_group(&"lock_targets") and w.collision_layer == 0, "e2e: removed from lock_targets, collision off")
	await wait(5.5)
	check(not is_instance_valid(w), "e2e: freed after death")


func test_leash_return() -> void:
	var w := spawn(EnemyWolf, &"wolf", Vector3.ZERO, [], Vector3(0, 0, -6))
	var p := player_at(Vector3(0, 0, -6))
	await wait(0.5)
	check(w.target == p, "leash: engaged")
	# player kites the wolf away, staying 5 m ahead of it
	var t := 0.0
	var went_return := false
	while t < 12.0:
		var ahead := w.global_position + Vector3(0, 0, -5)
		p.global_position = Vector3(0, 0, ahead.z)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if w.state == EnemyBase.State.RETURN:
			went_return = true
			break
	check(went_return, "leash: wolf gives up beyond leash (%.1f m from home)" % flat_dist(w, Vector3.ZERO))
	p.global_position = w.global_position + Vector3(2, 0, 0)  # ignore player while returning
	await wait(0.5)
	check(w.state == EnemyBase.State.RETURN, "leash: ignores player while returning")
	p.global_position = Vector3(0, 0, -150)
	await wait(18.0)
	check(flat_dist(w, Vector3.ZERO) < 2.5 or w.state in [EnemyBase.State.IDLE, EnemyBase.State.PATROL], "leash: returned home (%.1f m, %s)" % [flat_dist(w, Vector3.ZERO), w.state_name()])


func test_no_detect_through_wall() -> void:
	wall(Vector3(0, 2, -4), Vector3(10, 4, 0.5))
	var w := spawn(EnemyWolf, &"wolf", Vector3.ZERO, [], Vector3(0, 0, -8))
	var p := player_at(Vector3(0, 0, -8))
	await wait(2.0)
	check(w.target == null, "wall: wolf does not see player behind a wall (state %s)" % w.state_name())
	check(p.hits.is_empty(), "wall: no hits through wall")
	p.global_position = Vector3(0, 0, -4.8)  # 4.8 m, still behind wall
	await wait(1.5)
	check(w.target == null, "wall: proximity also needs LOS")


func _attack_check(script: Script, type: StringName, dist: float, seconds: float) -> void:
	var e := spawn(script, type, Vector3.ZERO, [], Vector3(0, 0, -dist))
	var p := player_at(Vector3(0, 0, -dist))
	e.stats.block_chance = 0.0
	var marks: Array = []
	e.attack_performed.connect(func(_id: StringName) -> void: marks.append(p.hits.size()))
	if type == &"ogre":
		e.call(&"engage_boss", p)
	await wait(seconds)
	marks.append(p.hits.size())
	var ok := true
	for i in marks.size() - 1:
		if int(marks[i + 1]) - int(marks[i]) > 1:
			ok = false
	check(marks.size() > 1 and p.hits.size() >= 1, "%s: attack connects (%d activations, %d hits)" % [type, marks.size() - 1, p.hits.size()])
	check(ok and p.hits.size() <= marks.size() - 1, "%s: at most one hit per activation" % type)
	e.free()
	p.free()


func test_attack_once_per_activation() -> void:
	await _attack_check(EnemyWolf, &"wolf", 3.0, 6.0)
	await _attack_check(EnemyWolf, &"alpha_wolf", 4.0, 7.0)
	if ClassDB.class_exists("Node"):
		var scripts := {
			&"goblin_raider": "res://scripts/enemies/enemy_humanoid.gd",
			&"human_raider": "res://scripts/enemies/enemy_humanoid.gd",
			&"raider_captain": "res://scripts/enemies/enemy_humanoid.gd",
			&"ogre": "res://scripts/enemies/enemy_ogre.gd",
		}
		for t: StringName in scripts:
			if ResourceLoader.exists(scripts[t]):
				await _attack_check(load(scripts[t]), t, 2.0 if t != &"ogre" else 3.5, 8.0)


func test_token_limit() -> void:
	var p := player_at(Vector3.ZERO)
	var wolves: Array[EnemyBase] = []
	for i in 4:
		var a := TAU * i / 4.0
		var pos := Vector3(cos(a) * 5.0, 0, sin(a) * 5.0)
		wolves.append(spawn(EnemyWolf, &"wolf", pos, [], Vector3.ZERO))
	var max_tokens := 0
	var max_attacking := 0
	for f in 600:
		await get_tree().physics_frame
		max_tokens = maxi(max_tokens, EnemyBase.token_count(p))
		var n := 0
		for w in wolves:
			if w.state == EnemyBase.State.ATTACK:
				n += 1
		max_attacking = maxi(max_attacking, n)
	check(max_tokens <= 2 and max_tokens >= 1, "tokens: max simultaneous token holders = %d" % max_tokens)
	check(max_attacking <= 2, "tokens: max wolves in ATTACK at once = %d" % max_attacking)
	check(p.hits.size() >= 2, "tokens: wolves still attack (%d hits)" % p.hits.size())


func test_stuck_recovery() -> void:
	# A wolf whose home lies behind a U-shaped pocket: walking home it gets stuck.
	var w := spawn(EnemyWolf, &"wolf", Vector3(0, 0, 0))
	w.home_position = Vector3(0, 0, -30)
	wall(Vector3(0, 2, -2.5), Vector3(6, 4, 0.5))
	wall(Vector3(-3, 2, 0), Vector3(0.5, 4, 5.5))
	wall(Vector3(3, 2, 0), Vector3(0.5, 4, 5.5))
	wall(Vector3(0, 2, 2.6), Vector3(6, 4, 0.5))  # fully enclosed -> must teleport (no camera)
	w._set_state(EnemyBase.State.RETURN)
	await wait(8.0)
	check(flat_dist(w, Vector3(0, 0, -30)) < 3.0, "stuck: enclosed wolf recovered home (%.1f m)" % flat_dist(w, Vector3(0, 0, -30)))
	# open obstacle: detour around a wall
	var w2 := spawn(EnemyWolf, &"wolf", Vector3(40, 0, 0))
	w2.home_position = Vector3(40, 0, -20)
	wall(Vector3(40, 2, -4), Vector3(5, 4, 0.5))
	w2._set_state(EnemyBase.State.RETURN)
	var best := INF
	for i in 24:
		await wait(0.5)
		best = minf(best, flat_dist(w2, Vector3(40, 0, -20)))
		if OS.get_cmdline_user_args().has("--trace"):
			print("    t=%.1f pos=%s state=%s stuck=%.1f det=%.1f av=%s" % [i * 0.5, w2.global_position.snapped(Vector3.ONE * 0.1), w2.state_name(), w2._stuck_total, w2._detour_time, w2._avoid_vec.snapped(Vector3.ONE * 0.1)])
	check(best < 2.0, "stuck: wolf detours around wall and reaches home (closest %.1f m)" % best)


func test_death_signals() -> void:
	var p := player_at(Vector3(0, 0, 20))
	var a := spawn(EnemyWolf, &"alpha_wolf", Vector3.ZERO, [&"den"])
	var killed := []
	var essence := []
	var c1 := func(e: Node3D, t: StringName, tags: Array) -> void: killed.append([e, t, tags])
	var c2 := func(id: StringName, _pos: Vector3) -> void: essence.append(id)
	Events.enemy_killed.connect(c1)
	Events.essence_dropped.connect(c2)
	var r := hit(a, p, 60.0)
	check(r == DamageInfo.Result.HIT and not a.is_dead(), "death: survives partial damage")
	hit(a, p, 60.0)
	r = hit(a, p, 60.0)
	check(r == DamageInfo.Result.KILLED, "death: dies from enough damage")
	check(killed.size() == 1 and killed[0][1] == &"alpha_wolf" and (killed[0][2] as Array).has(&"den") and (killed[0][2] as Array).has(&"elite"), "death: enemy_killed type/tags %s" % [killed[0][2] if killed.size() else []])
	check(essence == [&"wolf_dash"], "death: essence_dropped wolf_dash")
	check(GameState.has_flag(&"alpha_wolf_defeated"), "death: flag alpha_wolf_defeated")
	r = hit(a, p, 10.0)
	check(r == DamageInfo.Result.IGNORED, "death: dead enemy ignores damage")
	Events.enemy_killed.disconnect(c1)
	Events.essence_dropped.disconnect(c2)
	GameState.flags.clear()


func test_goblin_retreat() -> void:
	var g := spawn(EnemyHumanoid, &"goblin_raider", Vector3.ZERO, [], Vector3(0, 0, -3))
	var p := player_at(Vector3(0, 0, -3))
	await wait(0.5)
	check(g.target == p, "retreat: goblin engaged")
	var seen := [false]
	g.state_changed.connect(func(_o: int, n: int) -> void:
		if n == EnemyBase.State.RETREAT:
			seen[0] = true)
	hit(g, p, g.health.max_health * 0.75, 0.0)
	await wait(0.2)
	check(seen[0], "retreat: wounded goblin (<30%) retreats")
	var d0 := flat_dist(g, p)
	await wait(1.2)
	check(flat_dist(g, p) > d0 + 1.0, "retreat: gained distance (%.1f -> %.1f m)" % [d0, flat_dist(g, p)])
	await wait(3.0)
	check(g.state in [EnemyBase.State.CHASE, EnemyBase.State.ATTACK, EnemyBase.State.RECOVER], "retreat: returns to the fight (%s)" % g.state_name())


func test_human_block() -> void:
	var h := spawn(EnemyHumanoid, &"human_raider", Vector3.ZERO, [], Vector3(0, 0, -2.5))
	var p := player_at(Vector3(0, 0, -2.5))
	await wait(0.5)
	h.rotation.y = 0.0  # facing -Z, toward the player
	h._set_blocking(true, 2.0)
	var hp := h.health.health
	var r := hit(h, p, 10.0)
	check(r == DamageInfo.Result.BLOCKED and is_equal_approx(h.health.health, hp), "block: frontal light hit negated")
	h._set_blocking(true, 2.0)
	r = hit(h, p, 10.0, 0.6, true)
	check(r == DamageInfo.Result.BLOCKED and not h.blocking and h.state == EnemyBase.State.HURT, "block: heavy hit breaks guard -> HURT")
	await wait(1.2)
	h.rotation.y = PI  # back turned
	h._set_blocking(true, 2.0)
	r = hit(h, p, 10.0)
	check(r == DamageInfo.Result.HIT, "block: hit from behind not blocked")
	var blocks := [0]
	for i in 600:
		await get_tree().physics_frame
		if h.blocking:
			blocks[0] += 1
	check(blocks[0] > 0, "block: raider raises its guard during the fight")


func _camp(adv_positions: Array) -> Array[EnemyBase]:
	var script: Script = load("res://scripts/enemies/enemy_adventurer.gd")
	var out: Array[EnemyBase] = []
	var i := 0
	for pos: Vector3 in adv_positions:
		var e: EnemyBase = script.new()
		e.configure(EnemyStats.create(&"adventurer"), pos, [])
		e.variant = i
		e.position = pos
		arena.add_child(e)
		out.append(e)
		i += 1
	return out


func test_adventurers_neutral() -> void:
	var advs := _camp([Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(0, 0, 3)])
	var p := player_at(Vector3(1.5, 0, 1.5))
	var attacked := [false]
	for a in advs:
		a.state_changed.connect(func(_o: int, n: int) -> void:
			if n == EnemyBase.State.ATTACK or n == EnemyBase.State.CHASE:
				attacked[0] = true)
	var notes := []
	var c := func(text: String, _k: StringName) -> void: notes.append(text)
	Events.notify.connect(c)
	advs[0].get(&"talk").interact(p)
	Events.notify.disconnect(c)
	check(notes.size() == 1, "adventurers: Talk pops a line %s" % [notes])
	await wait(15.0)
	check(p.hits.is_empty() and not attacked[0], "adventurers: never attack the goblin standing next to them for 15 s")
	check(not advs[0].is_in_group(&"lock_targets"), "adventurers: not lockable while neutral")


func test_adventurer_provoked() -> void:
	# two close together (assist radius 12 m), one far away (25 m)
	var advs := _camp([Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(25, 0, 0)])
	var p := player_at(Vector3(0, 0, -2))
	var provoked := []
	var c := func(a: Node3D, by: Node3D) -> void: provoked.append([a, by])
	Events.actor_provoked.connect(c)
	await wait(0.3)
	hit(advs[0], p, 5.0, 0.1)
	Events.actor_provoked.disconnect(c)
	check(provoked.size() >= 1 and provoked[0][0] == advs[0] and provoked[0][1] == p, "provoke: actor_provoked(adventurer, player)")
	check(advs[0].has_grudge(p) and Factions.is_hostile(advs[0], p), "provoke: victim holds a grudge")
	check(advs[1].has_grudge(p), "provoke: ally within 12 m assists")
	check(not advs[2].has_grudge(p), "provoke: distant adventurer stays neutral")
	await wait(6.0)
	check(p.hits_from(advs[0]) >= 1, "provoke: victim fights back (%d hits)" % p.hits_from(advs[0]))
	check(p.hits_from(advs[2]) == 0 and advs[2].target == null, "provoke: distant adventurer never attacks")
	p.global_position = Vector3(0, 0, -80)
	await wait(24.0)
	check(not advs[0].has_grudge(p) and not advs[1].has_grudge(p), "provoke: grudges calm down after the player leaves")
	check(not Factions.is_hostile(advs[0], p), "provoke: neutral again")


func test_adventurer_vs_wolf() -> void:
	var advs := _camp([Vector3(0, 0, 0)])
	var w := spawn(EnemyWolf, &"wolf", Vector3(0, 0, -9), [], Vector3.ZERO)
	var p := player_at(Vector3(60, 0, 60))
	await wait(8.0)
	var wolf_alive := is_instance_valid(w) and not w.is_dead()
	check(not wolf_alive or w.target == advs[0], "adv-vs-wolf: wolf attacks adventurer")
	check(not wolf_alive or advs[0].has_grudge(w), "adv-vs-wolf: adventurer defends itself")
	check(not wolf_alive or w.health.health < w.health.max_health, "adv-vs-wolf: adventurer damaged the wolf")
	check(advs[0].health.health < advs[0].health.max_health or not wolf_alive, "adv-vs-wolf: wolf damaged the adventurer")
	check(p.hits.is_empty(), "adv-vs-wolf: bystander player untouched")
	var w2 := spawn(EnemyWolf, &"wolf", Vector3(0, 0, -80), [], Vector3.ZERO)
	await wait(1.0)
	check(w2.target == null, "adv-vs-wolf: distant wolf stays local")


func test_ogre_boss() -> void:
	var o: EnemyBase = spawn(load("res://scripts/enemies/enemy_ogre.gd"), &"ogre", Vector3.ZERO)
	var p := player_at(Vector3(0, 0, -60))
	var ev := {"engaged": 0, "dis": 0, "hp": 0, "def": 0}
	var c1 := func(_b: Node3D) -> void: ev["engaged"] += 1
	var c2 := func(_b: Node3D) -> void: ev["dis"] += 1
	var c3 := func(_c: float, _m: float) -> void: ev["hp"] += 1
	var c4 := func(_b: Node3D) -> void: ev["def"] += 1
	Events.boss_engaged.connect(c1)
	Events.boss_disengaged.connect(c2)
	Events.boss_health_changed.connect(c3)
	Events.boss_defeated.connect(c4)
	check(o.is_in_group(&"boss"), "ogre: in group boss")
	await wait(1.0)
	check(ev["engaged"] == 0 and o.target == null, "ogre: idle while player outside arena")
	p.global_position = Vector3(0, 0, -10)
	await wait(0.5)
	check(ev["engaged"] == 1 and GameState.boss_active, "ogre: boss_engaged on arena enter")
	await wait(4.0)
	check(o.target == p and o.state in [EnemyBase.State.CHASE, EnemyBase.State.ATTACK, EnemyBase.State.RECOVER], "ogre: fights the player (%s)" % o.state_name())
	hit(o, p, 200.0, 0.0)
	check(ev["hp"] >= 1 and o.health.health < o.health.max_health, "ogre: boss_health_changed on damage")
	p.global_position = Vector3(0, 0, -70)
	await wait(0.5)
	check(ev["dis"] == 1 and not GameState.boss_active, "ogre: boss_disengaged when player leaves")
	check(is_equal_approx(o.health.health, o.health.max_health), "ogre: reset to full HP")
	await wait(12.0)
	check(flat_dist(o, Vector3.ZERO) < o.stats.patrol_radius + 1.0, "ogre: walked back home (%.1f m)" % flat_dist(o, Vector3.ZERO))
	p.global_position = Vector3(0, 0, -6)
	await wait(0.5)
	check(ev["engaged"] == 2, "ogre: re-engages")
	hit(o, p, 400.0, 0.0)
	check(o.get(&"enraged") == true, "ogre: enraged below 50%")
	var r := hit(o, p, 400.0, 0.0)
	check(r == DamageInfo.Result.KILLED and ev["def"] == 1, "ogre: boss_defeated on death")
	check(GameState.has_flag(&"boss_defeated") and not GameState.boss_active, "ogre: flag boss_defeated, boss inactive")
	Events.boss_engaged.disconnect(c1)
	Events.boss_disengaged.disconnect(c2)
	Events.boss_health_changed.disconnect(c3)
	Events.boss_defeated.disconnect(c4)
	GameState.flags.clear()


func _spawn_world(flags: Array) -> Node3D:
	GameState.flags.clear()
	for f: StringName in flags:
		GameState.set_flag(f)
	var s: Node3D = load("res://scripts/enemies/enemy_spawner.gd").new()
	arena.add_child(s)
	return s


func _count(s: Node3D, type: StringName) -> int:
	var n := 0
	for c in s.get_children():
		if c is EnemyBase and (c as EnemyBase).enemy_type == type:
			n += 1
	return n


func test_spawner_flags() -> void:
	var s := _spawn_world([])
	check(get_tree().get_nodes_in_group(&"rescue_guard").size() == WorldLayout.RESCUE_GUARD_COUNT, "spawner: %d rescue guards" % WorldLayout.RESCUE_GUARD_COUNT)
	check(get_tree().get_nodes_in_group(&"boss").size() == 1, "spawner: boss spawned")
	check(_count(s, &"alpha_wolf") == 1 and _count(s, &"raider_captain") == 1, "spawner: alpha + captain spawned")
	check(_count(s, &"adventurer") == 3, "spawner: 3 adventurers")
	print("    counts: wolf=%d alpha=%d goblin=%d human=%d captain=%d adv=%d ogre=%d" % [_count(s, &"wolf"), _count(s, &"alpha_wolf"),
		_count(s, &"goblin_raider"), _count(s, &"human_raider"), _count(s, &"raider_captain"), _count(s, &"adventurer"), _count(s, &"ogre")])
	s.free()
	s = _spawn_world([&"boss_defeated", &"friend_rescued", &"alpha_wolf_defeated", &"raider_captain_defeated"])
	check(get_tree().get_nodes_in_group(&"rescue_guard").is_empty(), "spawner: no rescue guards after friend_rescued")
	check(get_tree().get_nodes_in_group(&"boss").is_empty(), "spawner: no boss after boss_defeated")
	check(_count(s, &"alpha_wolf") == 0 and _count(s, &"raider_captain") == 0, "spawner: no alpha/captain after their flags")
	s.free()
	s = _spawn_world([&"rescue_guards_defeated"])
	check(get_tree().get_nodes_in_group(&"rescue_guard").is_empty(), "spawner: no rescue guards after rescue_guards_defeated")
	s.free()
	GameState.flags.clear()
