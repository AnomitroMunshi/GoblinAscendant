extends Node
## Headless player/camera tests. Run:
##   "$G" --headless --path . res://tests/player_test.tscn
## Drives the Player through Input.action_press/release over physics frames.

const DummyScript := preload("res://tests/player_dummy.gd")

var player: Player
var fails := 0
var passes := 0
var world: Node3D


func _ready() -> void:
	GameState.set_menu_open(false)
	world = Node3D.new()
	add_child(world)
	_box(Vector3(0, -0.5, 0), Vector3(600, 1, 600), Vector3.ZERO)          # floor
	# 30 deg ramp rising toward -Z, starting at z=0, x=40
	var ramp_len := 14.0
	var ang := deg_to_rad(30.0)
	_box(Vector3(40, sin(ang) * ramp_len * 0.5 - 0.25, -cos(ang) * ramp_len * 0.5), Vector3(6, 0.5, ramp_len), Vector3(ang, 0, 0))
	# small 0.2 m step
	_box(Vector3(-60, 0.1, -3), Vector3(6, 0.2, 4), Vector3.ZERO)
	player = Player.new()
	add_child(player)
	await _run()
	release_all()
	print("PLAYER TESTS: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _box(pos: Vector3, size: Vector3, rot: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	world.add_child(b)
	b.position = pos
	b.rotation = rot
	return b


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func place(pos: Vector3, cam_yaw: float = 0.0) -> void:
	release_all()
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = cam_yaw
	player.camera_rig._apply_rotation()
	await frames(10)


func release_all() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"block", &"dodge", &"attack_light", &"attack_heavy"]:
		Input.action_release(a)


func tap(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)


func hspeed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _run() -> void:
	await frames(5)
	check(GameState.player == player and player.is_in_group(&"player"), "player registered in GameState and group")
	check(GameState.camera == player.camera_rig.camera, "GameState.camera set")
	check(player.health != null and player.get_node_or_null("Health") == player.health, "HealthComponent child 'Health'")

	print("-- movement")
	await place(Vector3(0, 0.1, 0), PI * 0.5)  # camera looks toward -X
	var start := player.global_position
	Input.action_press(&"move_forward")
	await wait(0.13)
	check(hspeed() >= Player.RUN_SPEED * 0.85, "accelerates to run speed in ~0.13 s (%.2f)" % hspeed())
	await wait(0.5)
	var moved := player.global_position - start
	check(moved.x < -2.0 and absf(moved.z) < 0.3, "moves camera-relative (toward -X): %s" % moved)
	check(player.get_facing().x < -0.9, "turns to face movement direction")
	Input.action_release(&"move_forward")
	await wait(0.18)
	check(hspeed() < 0.3, "decelerates to stop in ~0.15 s (%.2f)" % hspeed())

	print("-- sprint")
	var st0 := player.stamina
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await wait(0.4)
	check(hspeed() > Player.RUN_SPEED + 1.0 and player.stamina < st0, "sprint is faster and drains stamina")
	release_all()
	var st1 := player.stamina
	await wait(1.6)
	check(player.stamina > st1 + 10.0 or player.stamina >= player.max_stamina - 0.1, "stamina regenerates after delay")

	print("-- jump")
	await place(Vector3(0, 0.1, 0), 0.0)
	var y0 := player.global_position.y
	Input.action_press(&"jump")
	var max_y := y0
	for i in 20:
		await get_tree().physics_frame
		max_y = maxf(max_y, player.global_position.y)
	Input.action_release(&"jump")
	var landed := false
	for i in 90:
		await get_tree().physics_frame
		max_y = maxf(max_y, player.global_position.y)
		if player.is_on_floor() and player.velocity.y <= 0.0:
			landed = true
			break
	check(max_y - y0 > 0.8, "jump rises (%.2f m)" % (max_y - y0))
	check(landed and absf(player.global_position.y - y0) < 0.1, "jump lands back on floor")

	print("-- slope")
	await place(Vector3(40, 0.1, 2.0), 0.0)
	Input.action_press(&"move_forward")
	await wait(2.2)
	Input.action_release(&"move_forward")
	check(player.global_position.y > 3.0, "climbs 30 deg slope (y=%.2f)" % player.global_position.y)
	await wait(0.4)
	var ys := player.global_position.y
	await wait(0.5)
	check(absf(player.global_position.y - ys) < 0.05, "stands still on slope without sliding")

	print("-- small step")
	await place(Vector3(-60, 0.1, 1.0), 0.0)
	Input.action_press(&"move_forward")
	await wait(0.8)
	Input.action_release(&"move_forward")
	check(player.global_position.y > 0.15 and player.global_position.z < -1.5, "walks up a 0.2 m step (%s)" % player.global_position)

	print("-- camera spring arm")
	await place(Vector3(-40, 0.1, 0), 0.0)
	await frames(20)
	var free_len := player.camera_rig.get_arm_length()
	var wall := _box(Vector3(-40, 2, 2.0), Vector3(8, 6, 0.5), Vector3.ZERO)
	await frames(6)
	var blocked_len := player.camera_rig.get_arm_length()
	check(free_len > 3.5 and blocked_len < 2.2, "spring arm shortens behind wall (%.2f -> %.2f)" % [free_len, blocked_len])
	var cam_pos := player.camera_rig.camera.global_position
	check(cam_pos.z < 1.75, "camera stays in front of wall (z=%.2f)" % cam_pos.z)
	wall.queue_free()
	await frames(60)
	check(player.camera_rig.get_arm_length() > free_len - 0.05, "spring arm extends again when clear")

	print("-- dodge i-frames")
	await place(Vector3(0, 0.1, 20), 0.0)
	await wait(1.5)  # full stamina
	var hp := player.health.health
	await tap(&"dodge")
	await wait(0.1)
	check(player.state == Player.State.DODGE, "dodge state entered")
	var r := player.take_damage(DamageInfo.make(10.0))
	check(r == DamageInfo.Result.IGNORED and player.health.health == hp, "damage ignored during i-frames")
	await wait(0.5)
	r = player.take_damage(DamageInfo.make(10.0))
	check(r == DamageInfo.Result.HIT and absf(player.health.health - (hp - 10.0)) < 0.01, "damage applies after dodge")
	await wait(0.6)

	print("-- block")
	await place(Vector3(0, 0.1, 30), 0.0)
	await wait(1.0)
	var src := Node3D.new()
	add_child(src)
	src.global_position = player.global_position + player.get_facing() * 2.0
	Input.action_press(&"block")
	await frames(4)
	check(player.state == Player.State.BLOCK, "block state entered")
	hp = player.health.health
	var stam := player.stamina
	r = player.take_damage(DamageInfo.make(20.0, src))
	check(r == DamageInfo.Result.BLOCKED, "frontal hit blocked")
	check(absf((hp - player.health.health) - 4.0) < 0.01, "block reduces damage by 80%% (took %.1f)" % (hp - player.health.health))
	check(player.stamina < stam - 5.0, "block costs stamina")
	src.global_position = player.global_position - player.get_facing() * 2.0
	hp = player.health.health
	r = player.take_damage(DamageInfo.make(20.0, src))
	check(r == DamageInfo.Result.HIT and absf(hp - player.health.health - 20.0) < 0.01, "hit from behind not blocked")
	Input.action_release(&"block")
	src.queue_free()
	await wait(0.8)

	print("-- light attack")
	await place(Vector3(20, 0.1, 0), 0.0)
	await wait(0.6)
	var dummy: CharacterBody3D = DummyScript.new()
	add_child(dummy)
	dummy.global_position = player.global_position + Vector3(0.3, 0, -1.1)
	await frames(4)
	await tap(&"attack_light")
	check(player.state == Player.State.ATTACK, "attack state entered")
	await wait(0.8)
	check(dummy.hits == 1, "light attack hits dummy exactly once (hits=%d)" % dummy.hits)
	check(absf(dummy.total_damage - Progression.attack_power()) < 0.01, "damage = attack_power x 1.0 (%.1f)" % dummy.total_damage)
	await wait(0.6)  # let the combo window lapse so the chain starts at light1
	dummy.hits = 0
	for i in 3:
		await tap(&"attack_light")
		print("    tap %d -> %s %s phase=%d hits=%d dist=%.2f" % [i, player.get_state_name(), player._attack_name, player._attack_phase, dummy.hits, player.global_position.distance_to(dummy.global_position)])
		await wait(0.3)
	await wait(0.9)
	check(dummy.hits == 3, "3-step chain lands 3 hits (hits=%d)" % dummy.hits)
	dummy.hits = 0
	await tap(&"attack_heavy")
	await wait(1.4)
	check(dummy.hits == 1, "heavy attack hits once (hits=%d)" % dummy.hits)

	print("-- holster and unarmed")
	await wait(0.3)
	await tap(&"holster")
	check(player.is_weapon_holstered() and not player.model.sword.visible, "H holsters knife")
	check(player.model.get_node("ScaleRoot/roll/hips/StowedKnife").visible, "holstered knife visible at waist")
	await wait(0.2)
	check(player.model.fore_l.to_global(Vector3(0, -0.178, 0)).y < player.global_position.y + 0.6, "unarmed idle hands rest below chest")
	Input.action_press(&"block")
	await wait(0.3)
	check(player.state == Player.State.BLOCK, "unarmed Q enters guard")
	check(player.model.fore_l.to_global(Vector3(0, -0.178, 0)).y > player.global_position.y + 0.72, "boxing guard raises fist near jaw")
	Input.action_release(&"block")
	await wait(0.3)
	check(player.model.fore_l.to_global(Vector3(0, -0.178, 0)).y < player.global_position.y + 0.6, "releasing Q lowers hands")
	dummy.global_position = player.global_position + player.get_facing() * 0.55
	dummy.hits = 0
	dummy.total_damage = 0.0
	player.stamina = player.max_stamina
	await tap(&"attack_light")
	check(player.model.anim_action == &"punch1", "unarmed LMB starts punch")
	check(not player.toggle_holster(), "cannot draw during punch")
	await wait(0.6)
	check(dummy.hits == 1, "punch hits once")
	check(dummy.total_damage > 0.0 and dummy.total_damage < Progression.attack_power(), "punch deals less damage than knife")
	dummy.global_position = player.global_position + player.get_facing() * 0.6
	dummy.hits = 0
	await tap(&"attack_heavy")
	check(player.model.anim_action == &"kick", "unarmed RMB starts kick")
	await wait(1.3)
	check(dummy.hits == 1, "kick hits once")
	GameState.set_menu_open(true)
	check(not player.toggle_holster(), "menu blocks holster")
	GameState.set_menu_open(false)
	await tap(&"holster")
	check(not player.is_weapon_holstered() and player.model.sword.visible, "H draws knife again")
	check(not player.model.get_node("ScaleRoot/roll/hips/StowedKnife").visible, "drawing hides waist copy")

	print("-- weapon movesets (choreography data)")
	for t: StringName in ChoreoLibrary.types():
		var errs := ChoreoLibrary.validate(t)
		check(errs.is_empty(), "moveset %s valid %s" % [t, errs])
	check(not ChoreoLibrary.has(&"spear") and not ChoreoLibrary.has(&"axe"), "only knife/sword/sling/unarmed authored")
	check(ChoreoLibrary.reach(ChoreoLibrary.light_chain(&"sword")[0]) > ChoreoLibrary.reach(ChoreoLibrary.light_chain(&"knife")[0]), "sword out-reaches knife")
	await place(Vector3(80, 0.1, 60), 0.0)
	player.stamina = player.max_stamina
	check(player.equip_weapon(&"sword") and player.get_weapon_type() == &"sword" and player.model.weapon_type == &"sword", "equip_weapon readies sword")
	check(not player.model._knife_node.visible and player.model.get_node("ScaleRoot/roll/hips/StowedKnife").visible, "knife stowed at waist while sword drawn")
	var d2: CharacterBody3D = DummyScript.new()
	add_child(d2)
	d2.global_position = player.global_position + player.get_facing() * 1.05
	await frames(4)
	await tap(&"attack_light")
	var mv := player.get_attack_move()
	check(mv.get("id") == &"sword_cut1" and player.model.anim_action == &"sword_cut1", "LMB uses sword moveset (cut1)")
	check(not player.equip_weapon(&"knife"), "cannot switch weapon mid-attack")
	await wait(float(mv["windup"]) + 0.03)
	var box := player._hitbox.get_child(0) as CollisionShape3D
	check(((box.shape as BoxShape3D).size - (mv["hitbox"]["size"] as Vector3)).length() < 0.001, "hitbox size comes from move data")
	await wait(0.6)
	check(d2.hits == 1, "sword cut reaches 1.05 m target once (hits=%d)" % d2.hits)
	# reach: knife misses a target that the sword thrust can reach
	await wait(0.5)
	player.equip_weapon(&"knife")
	d2.global_position = player.global_position + player.get_facing() * 1.75
	d2.hits = 0
	await frames(3)
	await tap(&"attack_light")
	await wait(0.7)
	check(d2.hits == 0, "knife cut cannot reach 1.75 m (hits=%d)" % d2.hits)
	# sling projectile
	await wait(0.6)
	check(player.equip_weapon(&"sling"), "equip sling")
	d2.global_position = player.global_position + player.get_facing() * 6.0
	d2.hits = 0
	await frames(3)
	await tap(&"attack_light")
	await wait(1.2)
	check(d2.hits == 1, "sling stone hits 6 m target once (hits=%d)" % d2.hits)
	check(get_tree().get_nodes_in_group(&"player").size() == 1 and find_children("SlingStone", "", true, false).is_empty(), "stone removed after hit")
	# hit reactions
	await wait(0.5)
	player.equip_weapon(&"knife")
	var behind := Node3D.new()
	add_child(behind)
	behind.global_position = player.global_position - player.get_facing() * 2.0
	var hinfo := DamageInfo.make(1.0, behind, 3.0, 0.6)
	player.take_damage(hinfo)
	check(player.state == Player.State.HURT and player.model.hurt_kind == &"stagger" and player.model.hurt_dir.y < -0.9, "stagger from behind is direction-aware")
	await wait(0.9)
	var front := Node3D.new()
	add_child(front)
	front.global_position = player.global_position + player.get_facing() * 2.0
	var heavy_hit := DamageInfo.make(1.0, front, 8.0, 1.0)
	heavy_hit.is_heavy = true
	player.take_damage(heavy_hit)
	check(player.model.hurt_kind == &"knockdown" and player._hurt_time <= 0.55 + 0.001, "heavy hit = knockdown within existing hurt time")
	await wait(1.0)
	behind.queue_free()
	front.queue_free()
	# grip-aware cast keeps the weapon in hand
	player.equip_weapon(&"sword")
	await wait(0.3)
	player.play_cast_animation_for(&"flame_burst")
	check(player.state == Player.State.CAST and player.model.cast_skill == &"flame_burst", "skill-specific cast pose selected")
	await wait(0.15)
	check(player.model.sword.visible and player.model.anim_state == &"cast", "weapon stays in hand while casting")
	await wait(0.5)
	check(player.state != Player.State.CAST, "cast ends on time")
	check(player.debug_set_weapon(&"knife") == OS.is_debug_build(), "debug_set_weapon works in debug builds")
	d2.queue_free()
	await wait(0.3)

	print("-- lock-on")
	player.camera_rig.yaw = 0.0
	player.camera_rig._apply_rotation()
	dummy.add_to_group(&"lock_targets")
	dummy.global_position = player.global_position + Vector3(1.5, 0, -6.0)
	await frames(4)
	await tap(&"lock_on")
	await frames(2)
	check(player.get_lock_target() == dummy, "lock-on acquires target in front")
	await wait(0.6)
	var to := dummy.global_position - player.global_position
	check(player.get_facing().dot(Vector3(to.x, 0, to.z).normalized()) > 0.95, "player faces lock target")
	dummy.remove_from_group(&"lock_targets")
	await frames(3)
	check(player.get_lock_target() == null, "lock released when target leaves group")
	dummy.queue_free()
	await wait(0.3)

	print("-- interaction")
	await place(Vector3(-20, 0.1, 40), 0.0)
	var prompts: Array[String] = []
	var cb := func(t: String) -> void: prompts.append(t)
	Events.interaction_prompt_changed.connect(cb)
	var it := Interactable.new()
	it.prompt = "Read signpost"
	it.interact_id = &"test_sign"
	add_child(it)
	it.global_position = player.global_position + Vector3(0, 0.5, -1.0)
	await wait(0.4)
	check(prompts.has("[E] Read signpost"), "interaction prompt shown (%s)" % [prompts])
	it.queue_free()
	await wait(0.4)
	check(prompts.size() > 0 and prompts[-1] == "", "prompt cleared when out of range")
	Events.interaction_prompt_changed.disconnect(cb)

	print("-- death and respawn")
	var flags := {"died": false, "respawned": false}
	Events.player_died.connect(func() -> void: flags["died"] = true)
	Events.player_respawned.connect(func() -> void: flags["respawned"] = true)
	r = player.take_damage(DamageInfo.make(9999.0))
	check(r == DamageInfo.Result.KILLED and player.is_dead() and flags["died"], "lethal damage kills")
	check(player.take_damage(DamageInfo.make(5.0)) == DamageInfo.Result.IGNORED, "dead ignores damage")
	await wait(3.4)
	check(flags["respawned"] and not player.is_dead(), "respawns after ~3 s")
	check(player.health.health == player.health.max_health, "respawn restores full health")
	var rp := GameState.get_respawn_position()
	check(Vector2(player.global_position.x - rp.x, player.global_position.z - rp.z).length() < 0.5, "respawn at checkpoint")

	print("-- evolution")
	Events.evolution_changed.emit(&"hobgoblin")
	await wait(1.2)
	check(player.model.scale_root.scale.y > 1.25, "hobgoblin model grows (%.2f)" % player.model.scale_root.scale.y)

	print("-- fall safety")
	player.global_position = Vector3(0, -60, 0)
	await frames(3)
	check(player.global_position.y > -10.0, "rescued from falling out of world")
