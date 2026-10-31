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

## Choreography data: same format as EnemyHumanoid.POSES (generous, heavy anticipation).
const OGRE_POSES := {
	&"smash":  {"windup": Vector4(3.0, 3.0, 0.35, 0.0), "strike": Vector4(0.75, 0.75, -0.6, 0.0), "reach": 0.45, "follow": 0.55, "windup_rate": 6.0, "strike_rate": 24.0, "recover_rate": 3.0},
	&"sweep":  {"windup": Vector4(1.4, 0.4, 0.1, 1.25), "strike": Vector4(1.4, -0.2, -0.15, -1.3), "reach": 0.5, "follow": 0.5, "windup_rate": 6.0, "strike_rate": 18.0, "recover_rate": 3.0},
	&"stomp":  {"windup": Vector4(0.6, 0.6, 0.25, 0.0), "strike": Vector4(0.3, 0.3, -0.15, 0.0), "reach": 0.5, "follow": 0.4, "windup_rate": 7.0, "strike_rate": 30.0, "recover_rate": 4.0},
	&"charge": {"windup": Vector4(-0.6, -0.6, -0.45, 0.0), "strike": Vector4(1.2, 1.0, -0.6, 0.0), "reach": 0.5, "follow": 0.3, "windup_rate": 6.0, "strike_rate": 12.0, "recover_rate": 3.0},
}
## Stomp leg lift (right hip pitch) during wind-up / at impact.
const STOMP_LEG := {"windup": 1.1, "strike": -0.1}


func _default_type() -> StringName:
	return &"ogre"


func _make_style() -> Dictionary:
	return CharDefs.ogre()


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


func _pose_data(anim: StringName) -> Dictionary:
	return OGRE_POSES[anim] if OGRE_POSES.has(anim) else super(anim)


func _animate(delta: float) -> void:
	super(delta)
	var r := 1.0 - exp(-12.0 * delta)
	if state == State.ATTACK and current_attack and current_attack.anim == &"stomp":
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, float(STOMP_LEG["windup"]) if attack_phase == Phase.WINDUP else float(STOMP_LEG["strike"]), r if attack_phase == Phase.WINDUP else 1.0)
	if _roar_time > 0.0:
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -1.2, r)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 1.2, r)
		_head.rotation.x = lerpf(_head.rotation.x, -0.5, r)
