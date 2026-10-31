class_name EnemyBase
extends CharacterBody3D
## Shared enemy / NPC actor (Combat agent).
## Implements the damage contract, a reusable AI state machine
##   IDLE -> PATROL -> INVESTIGATE -> CHASE -> ATTACK -> RECOVER  (+ HURT, RETREAT, RETURN, DEAD)
## perception (radius + FOV + LOS on WORLD), steering with obstacle avoidance,
## attack tokens (max 2 attackers on the player), telegraphs, death and a health bar.
## Subclasses override: _default_type, _build_model, _build_attacks, _animate and hooks.

signal state_changed(old_state: int, new_state: int)
signal attack_performed(attack_id: StringName)

enum State { IDLE, PATROL, INVESTIGATE, CHASE, ATTACK, RECOVER, HURT, RETREAT, RETURN, DEAD }
enum Phase { NONE, WINDUP, ACTIVE }

const STATE_NAMES := ["IDLE", "PATROL", "INVESTIGATE", "CHASE", "ATTACK", "RECOVER", "HURT", "RETREAT", "RETURN", "DEAD"]
const MAX_PLAYER_ATTACKERS := 2
const GRAVITY := 22.0
const SENSE_INTERVAL := 0.18        # ~5.5 Hz perception, staggered per enemy
const AVOID_INTERVAL := 0.12
const SLEEP_DISTANCE := 70.0        # calm enemies further than this from the player sleep
const CALM_DISTANCE := 18.0         # grudges cool down while the offender stays beyond this
const CALM_TIME := 20.0
const DEATH_SINK_AT := 3.0
const DEATH_FREE_AT := 5.0
const BAR_SHOW_TIME := 5.0
const STUCK_WINDOW := 1.5
const STUCK_GIVE_UP := 5.0
const TOKEN_REUSE_DELAY := 0.8
const HIT_FLASH_COLOR := Color(1.0, 0.32, 0.26)  # restrained red hit flash

static var _tokens: Dictionary = {}  # target instance id -> Array[int] attacker ids

var stats: EnemyStats
var enemy_type: StringName = &""
var display_name := ""
var health: HealthComponent
var home_position := Vector3.ZERO
var spawn_tags: Array[StringName] = []
var variant := 0

var state: State = State.IDLE
var target: Node3D
var attacks: Array[EnemyAttack] = []
var current_attack: EnemyAttack
var attack_phase: Phase = Phase.NONE
var blocking := false

var model: Node3D
var hitbox: Hitbox
var health_bar: EnemyHealthBar

var _home_set := false
var _time := 0.0
var _state_time := 0.0
var _phase_time := 0.0
var _state_len := 0.0
var _move_target := Vector3.ZERO
var _investigate_pos := Vector3.ZERO
var _investigate_arrived := -1.0
var _last_seen_pos := Vector3.ZERO
var _unseen_time := 0.0
var _sense_timer := 0.0
var _avoid_timer := 0.0
var _avoid_vec := Vector3.ZERO
var _sep_vec := Vector3.ZERO
var _desired_velocity := Vector3.ZERO
var _face_dir := Vector3.ZERO
var _knockback := Vector3.ZERO
var _lunge_velocity := Vector3.ZERO
var _poise_damage := 0.0
var _poise_timer := 0.0
var _grudges: Dictionary = {}       # instance id -> Node3D
var _calm_time := 0.0
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _has_token := false
var _token_target_id := 0
var _token_free_at := 0.0
var _next_attack_time := 0.0
var _engaged := false
var _last_damage_time := -100.0
var _is_lock_target := false
var _death_time := 0.0
var _death_side := 1.0
var _move_blend := 0.0
var _walk_phase := 0.0
var _fled := false
var _block_time := 0.0
var _block_decide := 0.0
var _circle_until := 0.0
# anti-stuck
var _progress_anchor := Vector3.ZERO
var _progress_time := 0.0
var _stuck_total := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _detour_sign := 1.0
var _detour_count := 0
# feedback
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _flash_time := 0.0
var _flash_len := 0.1
var _overlay_on := false
var _meshes: Array[MeshInstance3D] = []
var _ray_params: PhysicsRayQueryParameters3D


# =============================================================== setup
## Call before add_child(). `home` is the spawn/home position (global).
func configure(p_stats: EnemyStats, home: Vector3, p_tags: Array = []) -> void:
	stats = p_stats
	home_position = home
	_home_set = true
	for t: Variant in p_tags:
		spawn_tags.append(StringName(str(t)))


func _default_type() -> StringName:
	return &"wolf"


func _ready() -> void:
	if stats == null:
		stats = EnemyStats.create(_default_type())
	enemy_type = stats.enemy_type
	if display_name == "":
		display_name = stats.display_name
	if not _home_set:
		home_position = global_position
	collision_layer = Layers.ACTORS
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ACTORS
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_constant_speed = true
	add_to_group(&"actors")
	add_to_group(&"enemies")
	if stats.aggression > 0.0:
		add_to_group(&"lock_targets")  # neutrals become lockable only when provoked
	if stats.is_boss:
		add_to_group(&"boss")
	for t in spawn_tags:
		add_to_group(t)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = stats.body_radius
	cap.height = maxf(stats.body_height, stats.body_radius * 2.0 + 0.01)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)

	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = stats.max_health
	add_child(health)

	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	_build_model(model)
	model.scale = Vector3.ONE * stats.model_scale
	_collect_meshes(model)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	add_child(hitbox)
	hitbox.setup(self, EnemyAttack.sphere(0.5), Vector3(0, 1, -1))
	hitbox.los_height = clampf(stats.body_height * 0.5, 0.5, 2.0)
	hitbox.hit_landed.connect(_on_hit_landed)

	_build_feedback()
	_build_attacks()

	_ray_params = PhysicsRayQueryParameters3D.new()
	_ray_params.collision_mask = Layers.WORLD
	_ray_params.exclude = [get_rid()]

	Events.lock_target_changed.connect(_on_lock_target_changed)
	_sense_timer = randf() * SENSE_INTERVAL
	_avoid_timer = randf() * AVOID_INTERVAL
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	rotation.y = randf() * TAU
	_progress_anchor = global_position
	reset_physics_interpolation.call_deferred()
	_enter_state(State.IDLE)
	_after_ready()


func _build_feedback() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	_ring_mat = EnemyFx._mat(Palette.FIRE, 2.5)
	_ring = MeshInstance3D.new()
	_ring.mesh = EnemyModelKit.torus(0.86, 1.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_disc_mat = EnemyFx._mat(Palette.DANGER, 1.6)
	_disc = MeshInstance3D.new()
	_disc.mesh = EnemyModelKit.cyl(1.0, 1.0, 0.03, 28)
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.visible = false
	add_child(_disc)
	health_bar = EnemyHealthBar.new()
	health_bar.name = "HealthBar"
	add_child(health_bar)
	var title := display_name if (stats.is_elite or stats.is_boss) else ""
	health_bar.setup(0.9 if not stats.is_elite else 1.3, title, not stats.is_boss)
	health_bar.position = Vector3(0, stats.body_height + 0.45, 0)
	health.health_changed.connect(func(c: float, m: float) -> void: health_bar.set_ratio(c / maxf(m, 1.0)))


func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
		_collect_meshes(c)


# =============================================================== overridables
func _build_model(_root: Node3D) -> void:
	pass


func _build_attacks() -> void:
	pass


func _animate(_delta: float) -> void:
	pass


func _after_ready() -> void:
	pass


func _custom_process(_delta: float) -> void:
	pass


func _on_target_acquired(_t: Node3D) -> void:
	pass


func _on_windup_start(_atk: EnemyAttack) -> void:
	pass


func _on_active_start(_atk: EnemyAttack) -> void:
	pass


func _on_recover_start(_atk: EnemyAttack) -> void:
	pass


func _on_damaged(_info: DamageInfo) -> void:
	pass


func _on_death(_info: DamageInfo) -> void:
	pass


## Velocity during RECOVER (wolves back off).
func _recover_velocity() -> Vector3:
	return Vector3.ZERO


## Extra condition for choosing targets (boss only targets the player while engaged).
func _can_target(n: Node) -> bool:
	if n == self or not (n is Node3D) or not is_instance_valid(n):
		return false
	if n.has_method("is_dead") and n.is_dead():
		return false
	if not Factions.is_hostile(self, n):
		return false
	return stats.aggression > 0.0 or has_grudge(n)


# =============================================================== damage contract
func get_faction() -> StringName:
	return stats.faction if stats else &""


func is_dead() -> bool:
	return state == State.DEAD or (health != null and health.is_dead())


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * stats.body_height * 0.62


func has_grudge(node: Object) -> bool:
	return node != null and is_instance_valid(node) and _grudges.has(node.get_instance_id())


func state_name() -> String:
	return STATE_NAMES[state]


func take_damage(info: DamageInfo) -> int:
	if info == null or is_dead():
		return DamageInfo.Result.IGNORED
	var src: Node3D = info.source if (info.source != null and is_instance_valid(info.source)) else null
	# Monsters that are not enemies of each other never hurt one another.
	if src and src != self and src.is_in_group(&"enemies") and not Factions.is_hostile(src, self) and not Factions.is_hostile(self, src):
		return DamageInfo.Result.IGNORED
	_last_damage_time = _time
	# Guard: frontal, blockable hits are negated; heavy hits break the guard.
	if blocking and src and not info.unblockable:
		var to_src := _flat(src.global_position - global_position).normalized()
		if to_src.dot(_forward()) > 0.25:
			if info.is_heavy:
				_set_blocking(false)
				_react_to_attacker(src)
				Audio.play_sfx(&"block", global_position + Vector3.UP)
				_flash(Color(1, 0.8, 0.4), 0.15)
				_enter_hurt(0.9)  # guard break: long stagger
				return DamageInfo.Result.BLOCKED
			Audio.play_sfx(&"block", global_position + Vector3.UP)
			_flash(Color(0.75, 0.85, 1.0), 0.1)
			_knockback = _flat(info.knockback) * 0.3
			_react_to_attacker(src)
			return DamageInfo.Result.BLOCKED
	var killed := health.apply_damage(info.amount)
	Events.actor_damaged.emit(self, info)
	_on_damaged(info)
	_flash(HIT_FLASH_COLOR, 0.13)
	var hp := info.hit_position if info.hit_position != Vector3.ZERO else global_position + Vector3.UP * stats.body_height * 0.6
	EnemyFx.hit_spray(self, hp, info.knockback, clampf(stats.body_height, 0.8, 1.8))
	Audio.play_sfx(&"hit", hp)
	_knockback = _flat(info.knockback) * (1.0 - stats.knockback_resist)
	if killed:
		_die(info)
		return DamageInfo.Result.KILLED
	_react_to_attacker(src)
	_poise_damage += info.stagger * 10.0 + (5.0 if info.is_heavy else 0.0)
	_poise_timer = 2.0
	if _poise_damage >= stats.poise:
		_poise_damage = 0.0
		_enter_hurt(0.45 if not stats.is_boss else 0.8)
	elif stats.flee_health_ratio > 0.0 and not _fled and health.ratio() < stats.flee_health_ratio and state != State.HURT:
		_fled = true
		_set_state(State.RETREAT)
	return DamageInfo.Result.HIT


## Provocation: grudge for neutrals, assist from nearby allies, engage or investigate.
func _react_to_attacker(src: Node3D) -> void:
	if src == null or not src.has_method("get_faction"):
		return
	if not Factions.is_hostile(self, src) or stats.aggression <= 0.0:
		if not has_grudge(src):
			add_grudge(src)
			Events.actor_provoked.emit(self, src)
	_calm_time = 0.0
	if state == State.RETURN and _flat_dist(home_position) > stats.leash_radius * 0.8:
		return  # evading home: keep walking
	if _can_target(src) and (target == null or not _target_valid() or state in [State.IDLE, State.PATROL, State.INVESTIGATE, State.RETURN]):
		if _flat_dist(src.global_position) <= stats.detection_radius or _has_los(src):
			_engage(src)
		else:
			_investigate(src.global_position)
	_call_assist(src)


func add_grudge(node: Node3D) -> void:
	if node == null:
		return
	_grudges[node.get_instance_id()] = node
	_calm_time = 0.0
	if not is_in_group(&"lock_targets"):
		add_to_group(&"lock_targets")


func clear_grudges() -> void:
	_grudges.clear()
	if stats.aggression <= 0.0 and is_in_group(&"lock_targets"):
		remove_from_group(&"lock_targets")


## Same-faction actors within ally_assist_radius join the fight (no one else).
func _call_assist(src: Node3D) -> void:
	if stats.ally_assist_radius <= 0.0:
		return
	var r2 := stats.ally_assist_radius * stats.ally_assist_radius
	for a in get_tree().get_nodes_in_group(&"actors"):
		if a == self or not (a is EnemyBase):
			continue
		var e := a as EnemyBase
		if e.is_dead() or e.get_faction() != get_faction():
			continue
		if e.global_position.distance_squared_to(global_position) > r2:
			continue
		e.assist(src)


## Called by a nearby ally under attack.
func assist(src: Node3D) -> void:
	if is_dead() or src == null or not is_instance_valid(src):
		return
	if not Factions.is_hostile(self, src) or stats.aggression <= 0.0:
		if not has_grudge(src):
			add_grudge(src)
	if state in [State.IDLE, State.PATROL, State.INVESTIGATE] and _can_target(src):
		if _has_los(src) or _flat_dist(src.global_position) < stats.detection_radius:
			_engage(src, false)
		else:
			_investigate(src.global_position)


## Alerted by a howl / call: go look at (or chase) the threat.
func alert(threat: Node3D) -> void:
	if is_dead() or threat == null or state not in [State.IDLE, State.PATROL, State.INVESTIGATE]:
		return
	if not _can_target(threat):
		return
	if _has_los(threat) and _flat_dist(threat.global_position) <= stats.detection_radius * 1.5:
		_engage(threat, false)
	else:
		_investigate(threat.global_position)


# =============================================================== main loop
func _physics_process(delta: float) -> void:
	_time += delta
	if state == State.DEAD:
		_physics_dead(delta)
		return
	if _is_sleeping():
		if not is_on_floor():
			velocity = Vector3(0.0, velocity.y - GRAVITY * delta, 0.0)
			move_and_slide()
		return
	_update_timers(delta)
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer += SENSE_INTERVAL
		_sense()
	_desired_velocity = Vector3.ZERO
	_custom_process(delta)
	if state == State.DEAD:
		return
	match state:
		State.IDLE: _state_idle(delta)
		State.PATROL: _state_patrol(delta)
		State.INVESTIGATE: _state_investigate(delta)
		State.CHASE: _state_chase(delta)
		State.ATTACK: _state_attack(delta)
		State.RECOVER: _state_recover(delta)
		State.HURT: _state_hurt(delta)
		State.RETREAT: _state_retreat(delta)
		State.RETURN: _state_return(delta)
	_apply_movement(delta)
	_animate(delta)
	_update_feedback(delta)


func _is_sleeping() -> bool:
	if state != State.IDLE and state != State.PATROL:
		return false
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return false
	return global_position.distance_squared_to(p.global_position) > SLEEP_DISTANCE * SLEEP_DISTANCE


func _update_timers(delta: float) -> void:
	_state_time += delta
	if (state == State.IDLE or state == State.PATROL) and health.health < health.max_health:
		health.heal(health.max_health * stats.regen_per_sec * delta)  # calm again: reset
	if _poise_timer > 0.0:
		_poise_timer -= delta
		if _poise_timer <= 0.0:
			_poise_damage = 0.0
	if blocking:
		_block_time -= delta
		if _block_time <= 0.0 or state not in [State.CHASE]:
			_set_blocking(false)
	if not _grudges.is_empty():
		var near := false
		for id: int in _grudges.keys():
			var g: Variant = _grudges[id]
			if not is_instance_valid(g):
				_grudges.erase(id)
				continue
			var gn := g as Node3D
			if not (gn.has_method("is_dead") and gn.is_dead()) and _flat_dist(gn.global_position) < CALM_DISTANCE:
				near = true
		_calm_time = 0.0 if near else _calm_time + delta
		if _calm_time >= CALM_TIME or _grudges.is_empty():
			var t := target
			clear_grudges()
			if t != null and not _can_target(t):
				target = null
				if state in [State.CHASE, State.ATTACK, State.RECOVER, State.HURT, State.RETREAT]:
					_set_state(State.RETURN)


# =============================================================== perception
func _sense() -> void:
	if state == State.RETURN or state == State.DEAD:
		return
	if target != null and _target_valid():
		if _flat_dist(target.global_position) <= stats.proximity_radius or \
				(_flat_dist(target.global_position) <= stats.detection_radius * 2.0 and _has_los(target)):
			_unseen_time = 0.0
			_last_seen_pos = target.global_position
		return
	var best: Node3D = null
	var best_d := INF
	var glimpse: Node3D = null
	for group: StringName in [&"player", &"actors"]:
		for c in get_tree().get_nodes_in_group(group):
			if not _can_target(c):
				continue
			var n := c as Node3D
			var d := _flat_dist(n.global_position)
			if d > stats.detection_radius * 1.35 or d >= best_d:
				continue
			var lvl := _perceive(n, d)
			if lvl == 2:
				best = n
				best_d = d
			elif lvl == 1 and glimpse == null:
				glimpse = n
	if best != null:
		_engage(best)
	elif glimpse != null and state in [State.IDLE, State.PATROL]:
		_investigate(glimpse.global_position)


## 2 = clearly detected, 1 = glimpsed / heard, 0 = nothing.
func _perceive(n: Node3D, d: float) -> int:
	if d <= 2.0:
		return 2  # very short range always detects
	var los := _has_los(n)
	if d <= stats.proximity_radius:
		return 2 if los else 0
	var to := _flat(n.global_position - global_position) / maxf(d, 0.001)
	var in_fov := stats.fov_degrees >= 359.0 or to.dot(_forward()) >= cos(deg_to_rad(stats.fov_degrees * 0.5))
	if not in_fov:
		if los and d <= stats.detection_radius * 0.5 and n is CharacterBody3D and _flat((n as CharacterBody3D).velocity).length() > 4.5:
			return 1  # heard running nearby
		return 0
	if not los:
		return 0
	return 2 if d <= stats.detection_radius else 1


func _has_los(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n) or not is_inside_tree():
		return false
	var eye := global_position + Vector3.UP * clampf(stats.body_height * 0.8, 0.5, 2.8)
	var to: Vector3 = n.get_lock_point() if n.has_method("get_lock_point") else n.global_position + Vector3.UP * 0.9
	_ray_params.from = eye
	_ray_params.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray_params).is_empty()


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree() and _can_target(target)


func _engage(t: Node3D, alert_allies: bool = true) -> void:
	if t == null:
		return
	var was := target
	target = t
	_unseen_time = 0.0
	_last_seen_pos = t.global_position
	if state not in [State.ATTACK, State.RECOVER, State.HURT, State.CHASE, State.RETREAT]:
		_set_state(State.CHASE)
	if was != t:
		_circle_until = _time + randf_range(0.3, 1.2)
		_on_target_acquired(t)
		if alert_allies and stats.aggression > 0.0:
			_call_assist(t)
	_update_engaged()


func _investigate(pos: Vector3) -> void:
	_investigate_pos = pos
	_investigate_arrived = -1.0
	if state == State.INVESTIGATE:
		_state_time = 0.0
	else:
		_set_state(State.INVESTIGATE)


func _lose_target(go_home: bool) -> void:
	target = null
	_set_state(State.RETURN if go_home else State.INVESTIGATE)


# =============================================================== states
func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	var old := state
	_exit_state(old, new_state)
	state = new_state
	_state_time = 0.0
	_enter_state(new_state)
	state_changed.emit(old, new_state)
	_update_engaged()


func _exit_state(old: State, new_state: State) -> void:
	if old == State.ATTACK:
		_hide_telegraph()
		if new_state != State.RECOVER:
			_cancel_attack()
	if (old == State.ATTACK or old == State.RECOVER) and new_state != State.ATTACK and new_state != State.RECOVER:
		_release_token()
	if old == State.RETREAT or old == State.HURT:
		_lunge_velocity = Vector3.ZERO


func _enter_state(s: State) -> void:
	_stuck_total = 0.0
	_progress_time = 0.0
	_progress_anchor = global_position
	match s:
		State.IDLE:
			_state_len = randf_range(2.0, 5.0) * (1.6 if stats.aggression <= 0.0 else 1.0)
		State.PATROL:
			var a := randf() * TAU
			var r := sqrt(randf()) * stats.patrol_radius
			_move_target = home_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		State.RETURN:
			target = null
			_release_token()
			_set_blocking(false)
		State.RETREAT:
			_state_len = randf_range(1.6, 2.4)
		State.INVESTIGATE:
			_investigate_arrived = -1.0


func _state_idle(_delta: float) -> void:
	if _state_time >= _state_len and stats.patrol_radius > 0.5:
		_set_state(State.PATROL)


func _state_patrol(_delta: float) -> void:
	var to := _flat(_move_target - global_position)
	if to.length() < 0.8 or _state_time > 14.0:
		_set_state(State.IDLE)
		return
	_desired_velocity = to.normalized() * stats.move_speed
	_face_dir = to


func _state_investigate(delta: float) -> void:
	var to := _flat(_investigate_pos - global_position)
	if _investigate_arrived < 0.0:
		if to.length() < 1.6 or _state_time > 12.0:
			_investigate_arrived = _state_time
		else:
			_desired_velocity = to.normalized() * stats.move_speed * 1.4
			_face_dir = to
	else:
		# look around
		rotation.y += sin(_state_time * 1.7) * delta * 1.2
		_face_dir = Vector3.ZERO
		if _state_time - _investigate_arrived > 3.0:
			if _flat_dist(home_position) > stats.patrol_radius + 2.0:
				_set_state(State.RETURN)
			else:
				_set_state(State.IDLE)
	if _flat_dist(home_position) > stats.leash_radius:
		_set_state(State.RETURN)


func _state_chase(delta: float) -> void:
	if not _target_valid():
		target = null
		_set_state(State.RETURN if _flat_dist(home_position) > stats.patrol_radius + 2.0 else State.IDLE)
		return
	if _flat_dist(home_position) > stats.leash_radius:
		_lose_target(true)
		return
	_unseen_time += delta
	if _unseen_time > stats.lose_target_time:
		var p := _last_seen_pos
		target = null
		_investigate(p)
		return
	var to := _flat(target.global_position - global_position)
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	_face_dir = dir
	_maybe_block(d)
	if not blocking and _time >= _next_attack_time and _time >= _circle_until:
		var atk := _choose_attack(d)
		if atk != null and _unseen_time < 0.25 and _has_los(target) and _acquire_token():
			_start_attack(atk)
			return
	var hold := stats.attack_range * 0.85
	var waiting := not _has_token and _is_token_full()
	if waiting or _time < _circle_until or _time < _next_attack_time:
		hold = stats.hold_distance if waiting else maxf(stats.attack_range * 1.1, 2.0)
	if d > hold + 0.6:
		var spd := lerpf(stats.move_speed * 1.2, stats.chase_speed, clampf((d - hold) / 4.0, 0.0, 1.0))
		_desired_velocity = dir * spd
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(1.4, 3.0)
			_strafe_sign = -_strafe_sign
		var tangent := Vector3(-dir.z, 0.0, dir.x) * _strafe_sign
		var radial := 0.0
		if d < hold - 0.7:
			radial = -0.8
		elif d > hold + 0.3:
			radial = 0.6
		_desired_velocity = (tangent + dir * radial).normalized() * stats.move_speed * (0.5 if blocking else 0.9)


func _maybe_block(d: float) -> void:
	if stats.block_chance <= 0.0 or blocking:
		return
	if _time < _block_decide:
		return
	_block_decide = _time + randf_range(1.2, 2.2)
	if d < stats.attack_range + 2.0 and randf() < stats.block_chance:
		_set_blocking(true, randf_range(0.9, 1.6))


func _set_blocking(on: bool, duration: float = 1.2) -> void:
	blocking = on
	_block_time = duration if on else 0.0


func _state_attack(delta: float) -> void:
	var atk := current_attack
	if atk == null:
		_set_state(State.CHASE)
		return
	_phase_time += delta
	if attack_phase == Phase.WINDUP:
		if target != null and is_instance_valid(target):
			_face_dir = _flat(target.global_position - global_position)
			_turn_rate_mult = atk.track
		if atk.step_back > 0.0:
			_desired_velocity = -_forward() * atk.step_back * (1.0 - _phase_time / maxf(atk.windup, 0.01))
		_update_telegraph(clampf(_phase_time / maxf(atk.windup, 0.01), 0.0, 1.0))
		if _phase_time >= atk.windup:
			_begin_active()
	elif attack_phase == Phase.ACTIVE:
		_face_dir = Vector3.ZERO
		if _phase_time >= atk.active:
			_end_active()


var _turn_rate_mult := 1.0


func _state_recover(_delta: float) -> void:
	_desired_velocity = _recover_velocity()
	if _state_time >= _state_len:
		_next_attack_time = _time + randf_range(0.25, 0.9)
		if _target_valid():
			_set_state(State.CHASE)
			_release_token()
		else:
			target = null
			_set_state(State.RETURN)


func _state_hurt(_delta: float) -> void:
	if _state_time >= _state_len:
		if _target_valid():
			_set_state(State.CHASE)
		elif target != null and is_instance_valid(target):
			_investigate(target.global_position)
		else:
			_set_state(State.IDLE)


func _state_retreat(_delta: float) -> void:
	if not _target_valid() or _state_time >= _state_len:
		_set_state(State.CHASE if _target_valid() else State.RETURN)
		return
	var away := _flat(global_position - target.global_position).normalized()
	_desired_velocity = away * stats.chase_speed * 0.85
	_face_dir = away


func _state_return(delta: float) -> void:
	var to := _flat(home_position - global_position)
	health.heal(health.max_health * stats.regen_per_sec * delta)
	if to.length() < 1.5:
		_set_state(State.IDLE)
		return
	_desired_velocity = to.normalized() * maxf(stats.move_speed * 1.3, 2.5)
	_face_dir = to


func _enter_hurt(duration: float) -> void:
	_state_len = duration
	if state == State.HURT:
		_state_time = 0.0
	else:
		_set_state(State.HURT)


# =============================================================== attacks
func _choose_attack(d: float) -> EnemyAttack:
	var total := 0.0
	for a in attacks:
		if a.is_ready(_time) and d >= a.min_range and d <= a.max_range:
			total += a.weight
	if total <= 0.0:
		return null
	var pick := randf() * total
	for a in attacks:
		if a.is_ready(_time) and d >= a.min_range and d <= a.max_range:
			pick -= a.weight
			if pick <= 0.0:
				return a
	return null


func _start_attack(atk: EnemyAttack) -> void:
	current_attack = atk
	attack_phase = Phase.WINDUP
	_phase_time = 0.0
	_set_blocking(false)
	_set_state(State.ATTACK)
	atk.ready_at = _time + atk.cooldown
	_show_telegraph(atk)
	Audio.play_sfx(&"enemy_warn", global_position + Vector3.UP)
	_flash(_telegraph_color(atk), 0.2)
	_on_windup_start(atk)


func _begin_active() -> void:
	var atk := current_attack
	attack_phase = Phase.ACTIVE
	_phase_time = 0.0
	_turn_rate_mult = 1.0
	_hide_telegraph()
	attack_performed.emit(atk.id)
	hitbox.require_line_of_sight = atk.los_required
	hitbox.setup(self, atk.shape, atk.offset)
	hitbox.activate(atk.make_info(self), atk.active)
	if atk.lunge_speed > 0.0:
		_lunge_velocity = _forward() * atk.lunge_speed
	Audio.play_sfx(&"swing_heavy" if atk.heavy else &"swing_light", global_position + Vector3.UP)
	_on_active_start(atk)


func _end_active() -> void:
	var atk := current_attack
	_lunge_velocity = Vector3.ZERO
	hitbox.deactivate()
	attack_phase = Phase.NONE
	_state_len = atk.recovery if atk else stats.recovery_time
	_set_state(State.RECOVER)
	if atk:
		_on_recover_start(atk)


func _cancel_attack() -> void:
	if hitbox:
		hitbox.deactivate()
	_lunge_velocity = Vector3.ZERO
	attack_phase = Phase.NONE
	_turn_rate_mult = 1.0
	_hide_telegraph()


func _on_hit_landed(t: Node3D, result: int, info: DamageInfo) -> void:
	if result == DamageInfo.Result.IGNORED or t == null:
		return
	if t.is_in_group(&"player"):
		GameFeel.shake(clampf(info.amount / 30.0, 0.12, 1.0) * (0.5 if result == DamageInfo.Result.BLOCKED else 1.0))
		if info.is_heavy and result != DamageInfo.Result.BLOCKED:
			GameFeel.hit_stop(0.06)


# ---- attack tokens (max 2 simultaneous attackers on the player) ----
func _is_token_full() -> bool:
	if target == null or not target.is_in_group(&"player") or stats.is_boss:
		return false
	return _token_holders(target.get_instance_id()).size() >= MAX_PLAYER_ATTACKERS


func _token_holders(id: int) -> Array:
	var holders: Array = _tokens.get(id, [])
	var valid: Array = []
	for h: int in holders:
		if is_instance_id_valid(h):
			var o := instance_from_id(h)
			if o is EnemyBase and (o as EnemyBase)._has_token and not (o as EnemyBase).is_dead():
				valid.append(h)
	_tokens[id] = valid
	return valid


func _acquire_token() -> bool:
	if _has_token:
		return true
	if _time < _token_free_at:
		return false
	if target != null and target.is_in_group(&"player") and not stats.is_boss:
		var id := target.get_instance_id()
		var holders := _token_holders(id)
		if holders.size() >= MAX_PLAYER_ATTACKERS:
			return false
		holders.append(get_instance_id())
		_tokens[id] = holders
		_token_target_id = id
	else:
		_token_target_id = 0
	_has_token = true
	return true


func _release_token() -> void:
	if not _has_token:
		return
	_has_token = false
	_token_free_at = _time + TOKEN_REUSE_DELAY
	if _token_target_id != 0 and _tokens.has(_token_target_id):
		var holders: Array = _tokens[_token_target_id]
		holders.erase(get_instance_id())
	_token_target_id = 0


static func token_count(t: Node) -> int:
	if t == null:
		return 0
	var n := 0
	for h: int in _tokens.get(t.get_instance_id(), []):
		if is_instance_id_valid(h):
			var o := instance_from_id(h)
			if o is EnemyBase and (o as EnemyBase)._has_token and not (o as EnemyBase).is_dead():
				n += 1
	return n


func _update_engaged() -> void:
	var e := state in [State.CHASE, State.ATTACK, State.RECOVER, State.HURT, State.RETREAT] \
		and target != null and is_instance_valid(target) and target.is_in_group(&"player")
	if e != _engaged:
		_engaged = e
		GameState.set_engaged(self, e)


# =============================================================== movement
func _apply_movement(delta: float) -> void:
	var horiz := _desired_velocity
	if horiz.length_squared() > 0.01 and _lunge_velocity == Vector3.ZERO:
		horiz = _steer(horiz, delta)
	else:
		_progress_time = 0.0
		_progress_anchor = global_position
	horiz += _lunge_velocity + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 16.0 * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = maxf(velocity.y, -0.5)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if _face_dir.length_squared() > 0.0001:
		var yaw := atan2(-_face_dir.x, -_face_dir.z)
		rotation.y = rotate_toward(rotation.y, yaw, stats.turn_speed * _turn_rate_mult * delta)
	var spd := Vector2(velocity.x, velocity.z).length()
	_move_blend = lerpf(_move_blend, clampf(spd / maxf(stats.chase_speed, 0.1), 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_walk_phase += delta * spd * (2.6 / maxf(stats.model_scale * stats.body_height, 0.5))


func _steer(v: Vector3, delta: float) -> Vector3:
	var speed := v.length()
	var dir := v / speed
	_avoid_timer -= delta
	if _avoid_timer <= 0.0:
		_avoid_timer = AVOID_INTERVAL
		_update_avoidance(dir)
	# anti-stuck: no progress for STUCK_WINDOW -> detour sideways; STUCK_GIVE_UP -> go home
	_progress_time += delta
	if _progress_time >= STUCK_WINDOW:
		var moved := _flat(global_position - _progress_anchor).length()
		var goal: Variant = _movement_goal()
		if goal is Vector3:
			# progress = how much closer to the goal we got
			moved = _flat((goal as Vector3) - _progress_anchor).length() - _flat_dist(goal as Vector3)
		if moved < 0.35 * speed * STUCK_WINDOW * 0.25:
			_stuck_total += _progress_time
			_detour_count += 1
			if _detour_count % 3 == 0:
				_detour_sign = -_detour_sign  # that side did not work: try the other
			_detour = Vector3(-dir.z, 0.0, dir.x) * _detour_sign
			_detour_time = 1.4
			if _stuck_total >= STUCK_GIVE_UP:
				_on_stuck()
		else:
			_stuck_total = 0.0
		_progress_time = 0.0
		_progress_anchor = global_position
	if _detour_time > 0.0:
		_detour_time -= delta
		dir = (dir * 0.15 + _detour).normalized()
	var out := dir + (_avoid_vec * 1.3 if _detour_time <= 0.0 else Vector3.ZERO) + _sep_vec * 0.9
	out.y = 0.0
	if out.length_squared() < 0.0001:
		return Vector3.ZERO
	out = out.normalized()
	if _water_ahead(out):
		var alt := Vector3(-out.z, 0.0, out.x) * _strafe_sign
		out = alt if not _water_ahead(alt) else Vector3.ZERO
	return out * speed


func _movement_goal() -> Variant:
	match state:
		State.PATROL: return _move_target
		State.RETURN: return home_position
		State.INVESTIGATE: return _investigate_pos if _investigate_arrived < 0.0 else null
	return null


func _on_stuck() -> void:
	_stuck_total = 0.0
	if state == State.RETURN or not _on_screen():
		if not _on_screen():
			teleport_home()
			return
	target = null
	_set_state(State.RETURN)


func teleport_home() -> void:
	global_position = Vector3(home_position.x, GameState.ground_height(home_position.x, home_position.z) + 0.1, home_position.z)
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	target = null
	if state != State.IDLE:
		_set_state(State.IDLE)


func _on_screen() -> bool:
	var cam := GameState.camera
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return false
	return cam.is_position_in_frustum(global_position + Vector3.UP)


func _update_avoidance(dir: Vector3) -> void:
	_avoid_vec = Vector3.ZERO
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * clampf(stats.body_height * 0.45, 0.4, 1.2)
	var look := stats.body_radius + 1.6
	var side := dir.cross(Vector3.UP)
	var blocked_l := false
	var blocked_r := false
	for s: float in [-1.0, 1.0]:
		var ray_dir := dir.rotated(Vector3.UP, 0.45 * -s)  # s=-1 -> left
		_ray_params.from = from
		_ray_params.to = from + ray_dir * look
		var hit := space.intersect_ray(_ray_params)
		if not hit.is_empty() and (hit["normal"] as Vector3).y < 0.7:
			if s < 0.0:
				blocked_l = true
			else:
				blocked_r = true
	if blocked_l and blocked_r:
		_avoid_vec = side * _strafe_sign * 1.5 - dir * 0.3
	elif blocked_l:
		_avoid_vec = side
	elif blocked_r:
		_avoid_vec = -side
	# separation from nearby actors
	_sep_vec = Vector3.ZERO
	for a in get_tree().get_nodes_in_group(&"actors"):
		if a == self:
			continue
		var n := a as Node3D
		var off := _flat(global_position - n.global_position)
		var min_d := stats.body_radius + 1.0
		var dd := off.length()
		if dd < min_d and dd > 0.001:
			_sep_vec += off / dd * (1.0 - dd / min_d)


func _water_ahead(dir: Vector3) -> bool:
	var w := GameState.world
	if w == null or not is_instance_valid(w) or not w.has_method("is_in_water"):
		return false
	return bool(w.is_in_water(global_position + dir * (stats.body_radius + 1.2)))


# =============================================================== death
func _die(info: DamageInfo) -> void:
	_set_state(State.DEAD)
	_cancel_attack()
	_release_token()
	_set_blocking(false)
	if _engaged:
		_engaged = false
		GameState.set_engaged(self, false)
	for g: StringName in [&"lock_targets", &"enemies", &"actors"]:
		if is_in_group(g):
			remove_from_group(g)
	collision_layer = 0
	collision_mask = Layers.WORLD
	health_bar.target_alpha = 0.0
	_death_side = 1.0 if randf() < 0.5 else -1.0
	_death_time = 0.0
	var tags: Array = []
	for t in spawn_tags:
		tags.append(t)
	for t in stats.tags:
		if not tags.has(t):
			tags.append(t)
	tags.append(stats.xp_tag)
	Audio.play_sfx(&"death", global_position + Vector3.UP)
	Events.enemy_killed.emit(self, enemy_type, tags)
	if stats.essence_id != &"":
		Events.essence_dropped.emit(stats.essence_id, global_position + Vector3.UP * 0.8)
	if stats.defeat_flag != &"":
		GameState.set_flag(stats.defeat_flag)
	_on_death(info)


func _physics_dead(delta: float) -> void:
	_death_time += delta
	var horiz := _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 10.0 * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	velocity.y = maxf(velocity.y, -0.5) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	var k := clampf(_death_time / 0.55, 0.0, 1.0)
	model.rotation.z = _death_side * PI * 0.5 * (1.0 - pow(1.0 - k, 3.0))
	model.position.x = -_death_side * stats.body_height * 0.18 * k
	if _death_time > DEATH_SINK_AT:
		model.position.y -= delta * 0.5 * stats.body_height
	_update_feedback(delta)
	if _death_time > DEATH_FREE_AT:
		queue_free()


# =============================================================== feedback
func _flash(color: Color, duration: float) -> void:
	_flash_len = duration
	_flash_time = duration
	_flash_mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	if not _overlay_on:
		_overlay_on = true
		for m in _meshes:
			m.material_overlay = _flash_mat


func _telegraph_color(atk: EnemyAttack) -> Color:
	if atk.unblockable:
		return Color(0.75, 0.3, 1.0)
	if atk.heavy:
		return Palette.DANGER
	return Color(1.0, 0.72, 0.2)


func _show_telegraph(atk: EnemyAttack) -> void:
	var c := _telegraph_color(atk)
	_ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.0)
	_ring_mat.emission = c
	_ring.visible = true
	if atk.marker_radius > 0.0:
		_disc_mat.albedo_color = Color(c.r, c.g, c.b, 0.0)
		_disc_mat.emission = c
		_disc.visible = true
		_disc.position = Vector3(atk.offset.x, 0.06, atk.offset.z)
		_ring.position = _disc.position + Vector3.UP * 0.02
	else:
		_ring.position = Vector3(0, 0.07, 0)


func _update_telegraph(k: float) -> void:
	var atk := current_attack
	if atk == null:
		return
	var pulse := 0.15 * sin(_time * 30.0) if k > 0.8 else 0.0
	if atk.marker_radius > 0.0:
		var r := atk.marker_radius
		_ring.scale = Vector3(r, 1.0, r)
		_ring_mat.albedo_color.a = 0.5 + 0.4 * k + pulse
		var dr := maxf(0.05, r * k)
		_disc.scale = Vector3(dr, 1.0, dr)
		_disc_mat.albedo_color.a = 0.18 + 0.25 * k
	else:
		var rr := atk.ring_radius if atk.ring_radius > 0.0 else atk.max_range
		var s := rr * lerpf(1.6, 1.0, k)
		_ring.scale = Vector3(s, 1.0, s)
		_ring_mat.albedo_color.a = lerpf(0.15, 0.85, k) + pulse


func _hide_telegraph() -> void:
	if _ring:
		_ring.visible = false
	if _disc:
		_disc.visible = false


func _update_feedback(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_mat.albedo_color.a = 0.75 * clampf(_flash_time / maxf(_flash_len, 0.01), 0.0, 1.0)
		if _flash_time <= 0.0 and _overlay_on:
			_overlay_on = false
			for m in _meshes:
				m.material_overlay = null
	if health_bar and state != State.DEAD:
		var show := _is_lock_target or (_time - _last_damage_time < BAR_SHOW_TIME and health.ratio() < 1.0)
		health_bar.target_alpha = 1.0 if show else 0.0


func _on_lock_target_changed(t: Node3D) -> void:
	_is_lock_target = t == self


# =============================================================== helpers
func _forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _exit_tree() -> void:
	_release_token()
	if _engaged:
		_engaged = false
		GameState.set_engaged(self, false)
