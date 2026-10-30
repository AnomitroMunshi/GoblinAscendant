class_name EnemyOgre
extends EnemyHumanoid
## Ogre boss (≈3.3 m). Slow club swings with GENEROUS telegraphs and recovery windows:
##   club_smash (overhead, ground decal + shockwave, heavy shake), club_sweep (wide),
##   stomp (unblockable, short range, purple ring), and below 50 % HP an enraged charge.
## Arena: TriggerZone (radius OGRE_ARENA_RADIUS) at home. Player enters -> boss_engaged;
## player leaves / dies -> boss_disengaged and full reset at home. Never leaves the arena.

var arena: TriggerZone
var boss_engaged := false
var enraged := false
var _roar_time := 0.0
var _charge: EnemyAttack


func _default_type() -> StringName:
	return &"ogre"


func _make_style() -> Dictionary:
	var s := super()
	s.merge({"leg_len": 1.0, "leg_r": 0.3, "hip_w": 0.42, "torso_len": 1.25, "torso_w": 1.5, "torso_d": 1.15,
		"head_r": 0.38, "arm_len": 1.5, "arm_r": 0.25, "shoulder_w": 0.92,
		"skin": Palette.OGRE_SKIN, "top": Palette.OGRE_SKIN, "pants": Palette.OGRE_SKIN.darkened(0.12),
		"boots": Palette.OGRE_SKIN.darkened(0.3), "iris": Color(1.0, 0.45, 0.1), "mood": 1.0,
		"brow": Palette.OGRE_SKIN.darkened(0.45), "weapon": &"ogre_club", "offhand": &""}, true)
	return s


func _build_weapon(w: Node3D, kind: StringName) -> void:
	if kind != &"ogre_club":
		super(w, kind)
		return
	EnemyModelKit.part(w, EnemyModelKit.cyl(0.3, 0.11, 1.9, 10), Palette.BARK, Vector3(0, -0.85, 0), Vector3(180, 0, 0))
	EnemyModelKit.part(w, EnemyModelKit.cyl(0.32, 0.32, 0.12, 10), Palette.RUST.darkened(0.2), Vector3(0, -1.5, 0))
	for i in 5:
		var a := TAU * i / 5.0
		EnemyModelKit.part(w, EnemyModelKit.prism(Vector3(0.12, 0.22, 0.12)), Palette.STEEL.darkened(0.2),
			Vector3(cos(a) * 0.3, -1.65 - (i % 2) * 0.15, sin(a) * 0.3), Vector3(0, -rad_to_deg(a), 90))


func _decorate(s: Dictionary) -> void:
	var hr: float = s["head_r"]
	var tl: float = s["torso_len"]
	var skin: Color = s["skin"]
	# hunch the head forward, big belly, loincloth, fur shoulder, tusks
	_head.position += Vector3(0, -0.12, -0.32)
	EnemyModelKit.part(_torso, EnemyModelKit.sphere(0.85, 16), skin.lightened(0.08), Vector3(0, 0.45, -0.22), Vector3.ZERO, Vector3(1.0, 0.9, 0.9))
	EnemyModelKit.part(_torso, EnemyModelKit.box(Vector3(0.9, 0.7, 0.08)), Palette.LEATHER, Vector3(0, -0.15, -0.72), Vector3(-8, 0, 0))
	EnemyModelKit.part(_torso, EnemyModelKit.cyl(0.78, 0.8, 0.16, 14), Palette.LEATHER.darkened(0.3), Vector3(0, 0.05, -0.1))
	EnemyModelKit.part(_torso, EnemyModelKit.box(Vector3(0.18, tl * 1.25, 0.06)), Palette.LEATHER.darkened(0.2), Vector3(0.1, tl * 0.55, -0.62), Vector3(0, 0, -38))
	EnemyModelKit.part(_torso, EnemyModelKit.sphere(0.42, 12), Color(0.35, 0.28, 0.22), Vector3(-0.85, tl * 0.98, 0.05), Vector3.ZERO, Vector3(1.2, 0.75, 1.2))
	EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(hr * 1.7, hr * 0.28, hr * 0.5)), skin.darkened(0.3), Vector3(0, hr * 0.32, -hr * 0.78))
	EnemyModelKit.part(_head, EnemyModelKit.box(Vector3(hr * 1.6, hr * 0.7, hr * 1.1)), skin.darkened(0.08), Vector3(0, -hr * 0.6, -hr * 0.25))
	for side: float in [-1.0, 1.0]:
		EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.08, 0.2, 0.08)), Color(0.95, 0.9, 0.75), Vector3(side * hr * 0.5, -hr * 0.4, -hr * 0.85))
		EnemyModelKit.part(_head, EnemyModelKit.prism(Vector3(0.1, 0.16, 0.05)), skin.darkened(0.15), Vector3(side * hr * 1.0, hr * 0.1, 0), Vector3(0, 0, -side * 70.0))


func _build_attacks() -> void:
	var d := stats.damage
	var smash := EnemyAttack.make(&"club_smash", &"smash", d * 1.3, 1.6, 0.18, 1.9, 4.6,
		EnemyAttack.sphere(1.5), Vector3(0.35, 0.8, -3.0))
	smash.heavy = true
	smash.knockback = 9.0
	smash.stagger = 1.0
	smash.marker_radius = 1.7
	smash.step_back = 0.6
	smash.track = 0.35
	smash.los_required = false
	smash.weight = 1.4
	attacks.append(smash)
	var sweep := EnemyAttack.make(&"club_sweep", &"sweep", d, 1.25, 0.3, 1.4, 4.0,
		EnemyAttack.box(Vector3(6.0, 1.6, 2.6)), Vector3(0, 1.2, -2.0))
	sweep.knockback = 7.0
	sweep.stagger = 0.7
	sweep.ring_radius = 4.0
	sweep.track = 0.5
	attacks.append(sweep)
	var stomp := EnemyAttack.make(&"stomp", &"stomp", d * 0.6, 1.0, 0.15, 1.1, 2.8,
		EnemyAttack.sphere(3.0), Vector3(0, 0.5, 0))
	stomp.unblockable = true
	stomp.knockback = 10.0
	stomp.stagger = 0.9
	stomp.ring_radius = 3.0
	stomp.cooldown = 4.0
	stomp.los_required = false
	stomp.weight = 1.5
	attacks.append(stomp)
	_charge = EnemyAttack.make(&"charge", &"charge", d * 1.1, 1.3, 1.1, 2.2, 15.0,
		EnemyAttack.box(Vector3(2.4, 2.4, 1.4)), Vector3(0, 1.4, -1.4))
	_charge.min_range = 6.0
	_charge.lunge_speed = 11.0
	_charge.heavy = true
	_charge.knockback = 10.0
	_charge.stagger = 1.0
	_charge.cooldown = 8.0
	_charge.weight = 3.0
	_charge.enabled = false
	attacks.append(_charge)


func _after_ready() -> void:
	hitbox.los_height = 2.0
	arena = TriggerZone.new()
	arena.name = "Arena"
	arena.zone_id = &"ogre_arena"
	arena.radius = WorldLayout.OGRE_ARENA_RADIUS
	arena.top_level = true
	add_child(arena)
	arena.global_position = home_position
	arena.player_entered.connect(engage_boss)
	arena.player_exited.connect(func(_p: Node3D) -> void: disengage_boss())
	Events.player_died.connect(disengage_boss)
	health.health_changed.connect(_on_health_changed)


func _can_target(n: Node) -> bool:
	return boss_engaged and n.is_in_group(&"player") and super(n)


func engage_boss(p: Node3D) -> void:
	if boss_engaged or is_dead() or p == null or (p.has_method("is_dead") and p.is_dead()):
		return
	boss_engaged = true
	GameState.boss_active = true
	Events.boss_engaged.emit(self)
	Events.boss_health_changed.emit(health.health, health.max_health)
	Audio.play_music(&"boss")
	Audio.play_sfx(&"ogre_roar", global_position + Vector3.UP * 3.0)
	GameFeel.shake(0.45)
	_roar_time = 1.8
	_engage(p, false)


func disengage_boss() -> void:
	if not boss_engaged or is_dead():
		return
	boss_engaged = false
	GameState.boss_active = false
	enraged = false
	_charge.enabled = false
	health.heal(health.max_health)  # encounter reset: full HP
	target = null
	_set_state(State.RETURN)
	Events.boss_disengaged.emit(self)
	Audio.play_music(&"explore")


func _on_health_changed(cur: float, mx: float) -> void:
	if not boss_engaged:
		return
	Events.boss_health_changed.emit(cur, mx)
	if not enraged and cur <= mx * 0.5 and cur > 0.0:
		enraged = true
		_charge.enabled = true
		_roar_time = 1.4
		Audio.play_sfx(&"ogre_roar", global_position + Vector3.UP * 3.0)
		_flash(Palette.DANGER, 0.5)
		GameFeel.shake(0.4)


func _custom_process(delta: float) -> void:
	if _roar_time > 0.0:
		_roar_time -= delta
		_circle_until = maxf(_circle_until, _time + 0.1)
	if boss_engaged:
		var p := GameState.player if (GameState.player != null and is_instance_valid(GameState.player)) else target
		if p == null or not is_instance_valid(p) or (p.has_method("is_dead") and p.is_dead()) \
				or Vector2(p.global_position.x - home_position.x, p.global_position.z - home_position.z).length() > WorldLayout.OGRE_ARENA_RADIUS + 1.5:
			disengage_boss()
	# never leave the arena (charge stops at the edge)
	if _lunge_velocity != Vector3.ZERO and _flat_dist(home_position) > WorldLayout.OGRE_ARENA_RADIUS - 1.5:
		var out := _flat(global_position - home_position).normalized()
		if _lunge_velocity.dot(out) > 0.0:
			_lunge_velocity = Vector3.ZERO


func _state_chase(delta: float) -> void:
	super(delta)
	if _roar_time > 0.0 and state == State.CHASE:
		_desired_velocity = Vector3.ZERO
	if enraged:
		_desired_velocity *= 1.25


func _on_windup_start(atk: EnemyAttack) -> void:
	if atk.id == &"charge":
		Audio.play_sfx(&"ogre_roar", global_position + Vector3.UP * 3.0)


func _on_active_start(atk: EnemyAttack) -> void:
	var p := GameState.player
	var dist := 30.0
	if p != null and is_instance_valid(p):
		dist = _flat_dist(p.global_position)
	match atk.id:
		&"club_smash":
			var impact := global_transform * Vector3(atk.offset.x, 0.1, atk.offset.z)
			EnemyFx.shockwave(self, impact, 6.5, Color(1.0, 0.55, 0.15), 0.6)
			EnemyFx.burst(self, impact + Vector3.UP * 0.3, 2.0, Color(0.85, 0.75, 0.55), 0.4)
			Audio.play_sfx(&"ogre_slam", impact)
			GameFeel.shake(clampf(1.0 - dist / 25.0, 0.2, 1.0))
		&"stomp":
			EnemyFx.shockwave(self, global_position, 4.0, Color(0.7, 0.3, 1.0), 0.45)
			Audio.play_sfx(&"ogre_slam", global_position)
			GameFeel.shake(clampf(0.6 - dist / 30.0, 0.1, 0.6))
		&"club_sweep":
			EnemyFx.swing_arc(self, 1.2, 4.5, Color(1.0, 0.85, 0.6), rotation.y, 0.3)
		&"charge":
			EnemyFx.burst(self, global_position + Vector3.UP, 1.5, Color(0.85, 0.75, 0.55), 0.4)


func _on_death(_info: DamageInfo) -> void:
	boss_engaged = false
	GameState.boss_active = false
	Events.boss_defeated.emit(self)
	Audio.play_music(&"explore")
	GameFeel.shake(0.8)


func _windup_pose(anim: StringName) -> Vector4:
	match anim:
		&"smash": return Vector4(3.0, 3.0, 0.35, 0.0)
		&"sweep": return Vector4(1.4, 0.4, 0.1, 1.25)
		&"stomp": return Vector4(0.6, 0.6, 0.25, 0.0)
		&"charge": return Vector4(-0.6, -0.6, -0.45, 0.0)
	return super(anim)


func _strike_pose(anim: StringName) -> Vector4:
	match anim:
		&"smash": return Vector4(0.75, 0.75, -0.6, 0.0)
		&"sweep": return Vector4(1.4, -0.2, -0.15, -1.3)
		&"stomp": return Vector4(0.3, 0.3, -0.15, 0.0)
		&"charge": return Vector4(1.2, 1.0, -0.6, 0.0)
	return super(anim)


func _animate(delta: float) -> void:
	super(delta)
	var r := 1.0 - exp(-12.0 * delta)
	if state == State.ATTACK and current_attack and current_attack.anim == &"stomp":
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 1.1 if attack_phase == Phase.WINDUP else -0.1, r if attack_phase == Phase.WINDUP else 1.0)
	if _roar_time > 0.0:
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -1.2, r)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 1.2, r)
		_head.rotation.x = lerpf(_head.rotation.x, -0.5, r)
