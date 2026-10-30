class_name Player
extends CharacterBody3D
## The goblin. Builds its own model, collision, camera rig, hitboxes,
## interaction detector and AbilityController in _ready().
## See docs/ARCHITECTURE.md "Player API".
##
## State machine (one state at a time, transitions only through _set_state):
##   IDLE / MOVE  grounded locomotion (walk / run / sprint)
##   AIR          jumping / falling (coyote time + jump buffer)
##   ATTACK       light chain (3) or heavy; windup -> active (hitbox) -> recovery
##   DODGE        directional roll or backstep; i-frames inside DODGE_IFRAMES
##   BLOCK        hold block: frontal damage reduction, costs stamina per hit
##   HURT         staggered (stagger >= 0.5 or guard break)
##   CAST         short ability cast pose
##   DASH         begin_dash() movement (Wolf Dash)
##   DEAD         ignores everything until respawn()

enum State { IDLE, MOVE, AIR, ATTACK, DODGE, BLOCK, HURT, CAST, DASH, DEAD }

# ---- locomotion tuning ----------------------------------------------------------
const WALK_SPEED := 2.4
const RUN_SPEED := 5.2
const SPRINT_SPEED := 7.6
const BLOCK_SPEED := 1.8
const WATER_SPEED_MULT := 0.6
const GROUND_ACCEL := 46.0          # ~0.11 s to run speed
const GROUND_DECEL := 40.0          # ~0.13 s from run to stop
const TURN_ACCEL := 70.0            # used when reversing direction
const AIR_ACCEL := 11.0
const TURN_RATE := 15.0             # facing slerp rate (1/s)
const JUMP_VELOCITY := 7.0
const GRAVITY := 21.0
const FALL_GRAVITY_MULT := 1.7
const JUMP_CUT_GRAVITY_MULT := 2.3  # released jump early -> shorter hop
const MAX_FALL_SPEED := 32.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const STEP_HEIGHT := 0.32
const KILL_Y := -50.0

# ---- stamina / energy ---------------------------------------------------------------
const SPRINT_DRAIN := 16.0
const STAMINA_REGEN := 30.0
const STAMINA_REGEN_DELAY := 0.75
const EXHAUST_THRESHOLD := 20.0     # sprint locked after running dry until this much regenerates
const ENERGY_REGEN := 4.0
const DODGE_COST := 22.0
const LIGHT_COST := 5.0
const HEAVY_COST := 14.0

# ---- dodge ----------------------------------------------------------------------------
const DODGE_TIME := 0.45
const DODGE_RECOVERY := 0.1        # after DODGE_TIME, slow movement and cancel window
const DODGE_SPEED := 10.5
const BACKSTEP_SPEED := 7.0
const DODGE_IFRAMES := Vector2(0.05, 0.32)

# ---- combat ---------------------------------------------------------------------------
const ATTACK_BUFFER := 0.35
const HURT_INVULN := 0.4
const BLOCK_REDUCTION := 0.8
const BLOCK_ARC_COS := 0.342        # cos(70 deg)
const BLOCK_STAMINA_BASE := 8.0
const BLOCK_STAMINA_PER_DMG := 0.8
const AUTO_AIM_RANGE := 3.0
const AUTO_AIM_COS := 0.866         # 60 deg cone (+-30)
const SHOCKWAVE_RADIUS := 3.6
const DEATH_RESPAWN_TIME := 3.0

## Attack data: windup / active / recovery seconds, damage multiplier, lunge
## speed, stagger, knockback, chain window start (fraction of recovery
## after which a buffered next input starts the next step).
const ATTACKS := {
	&"light1": {"windup": 0.13, "active": 0.1, "recovery": 0.27, "mult": 1.0, "lunge": 3.2, "stagger": 0.3, "knock": 2.5},
	&"light2": {"windup": 0.11, "active": 0.1, "recovery": 0.27, "mult": 1.1, "lunge": 3.2, "stagger": 0.3, "knock": 2.5},
	&"light3": {"windup": 0.2, "active": 0.12, "recovery": 0.42, "mult": 1.5, "lunge": 4.2, "stagger": 0.6, "knock": 5.0},
	&"heavy": {"windup": 0.42, "active": 0.14, "recovery": 0.52, "mult": 2.2, "lunge": 3.6, "stagger": 0.95, "knock": 8.0},
}
const LIGHT_CHAIN := [&"light1", &"light2", &"light3"]
const PHASE_KEYS := ["windup", "active", "recovery"]

# ---- public state ---------------------------------------------------------------------
var health: HealthComponent
var stamina := 100.0
var energy := 100.0
var max_stamina := 100.0
var max_energy := 100.0
var damage_taken_multiplier: float = 1.0
var abilities: AbilityController
var camera_rig: PlayerCamera
var model: PlayerGoblinModel
var state: State = State.IDLE

# ---- internals ------------------------------------------------------------------------
var _facing_pivot: Node3D           # rotates with facing; model + melee hitboxes live here
var _facing_yaw := 0.0
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _hitbox: Hitbox
var _shock_hitbox: Hitbox
var _interact_area: Area3D
var _current_interactable: Interactable
var _prompt_text := ""

var _move_input := Vector2.ZERO     # raw stick/keys
var _sprinting := false
var _exhausted := false
var _stamina_delay := 0.0
var _time_since_floor := 0.0
var _jump_buffer := 0.0
var _jumped := false
var _jump_held := false
var _was_on_floor := true
var _fall_speed := 0.0

var _state_time := 0.0
var _attack_name: StringName = &""
var _attack_phase := 0              # 0 windup, 1 active, 2 recovery
var _attack_phase_time := 0.0
var _chain_index := 0
var _chain_reset := 0.0
var _attack_buffer := 0.0
var _attack_buffer_heavy := false
var _attack_hit_once := false
var _dodge_dir := Vector3.ZERO
var _dodge_backstep := false
var _dodge_buffer := 0.0
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_time := 0.0
var _dash_invuln := false
var _hurt_time := 0.0
var _invuln_time := 0.0
var _death_time := 0.0
var _cast_time := 0.0
var _safe_timer := 0.0
var _scale := 1.0
var _last_emitted := PackedFloat32Array([-1, -1, -1, -1, -1, -1])
var _interact_timer := 0.0
var _emit_cooldown := 0.0
var _hit_this_swing: Dictionary = {}


func _init() -> void:
	name = "Player"


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ACTORS
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	max_slides = 6
	safe_margin = 0.02

	_capsule = CapsuleShape3D.new()
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = _capsule
	add_child(_collision)
	_apply_collision_size(1.0)

	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = Progression.max_health()
	add_child(health)
	health.health_changed.connect(func(_c: float, _m: float) -> void: _emit_stats(true))

	_facing_pivot = Node3D.new()
	_facing_pivot.name = "Facing"
	add_child(_facing_pivot)
	model = PlayerGoblinModel.new()
	model.name = "Model"
	_facing_pivot.add_child(model)

	_hitbox = Hitbox.new()
	_hitbox.name = "MeleeHitbox"
	_facing_pivot.add_child(_hitbox)
	_hitbox.setup(self, _light_shape(), Vector3(0, 0.6, -0.85))
	_hitbox.hit_landed.connect(_on_hit_landed)
	_shock_hitbox = Hitbox.new()
	_shock_hitbox.name = "ShockwaveHitbox"
	add_child(_shock_hitbox)
	var shock_shape := CylinderShape3D.new()
	shock_shape.radius = SHOCKWAVE_RADIUS
	shock_shape.height = 1.6
	_shock_hitbox.setup(self, shock_shape, Vector3(0, 0.6, 0))
	_shock_hitbox.hit_landed.connect(_on_shock_landed)

	_interact_area = Area3D.new()
	_interact_area.name = "InteractDetector"
	_interact_area.collision_layer = 0
	_interact_area.collision_mask = Layers.INTERACT
	_interact_area.monitorable = false
	var ics := CollisionShape3D.new()
	var isph := SphereShape3D.new()
	isph.radius = 0.6
	ics.shape = isph
	ics.position = Vector3(0, 0.6, 0)
	_interact_area.add_child(ics)
	add_child(_interact_area)

	abilities = AbilityController.new()
	abilities.name = "Abilities"
	add_child(abilities)
	abilities.setup(self)

	# spawn
	global_position = GameState.get_spawn_position()
	_facing_yaw = WorldLayout.PLAYER_START_YAW
	_facing_pivot.rotation.y = _facing_yaw
	GameState.player = self
	_refresh_stats(true)
	model.set_stage(Progression.stage, false)
	_apply_stage_scale(Progression.stage)

	camera_rig = PlayerCamera.new()
	camera_rig.name = "CameraRig"
	camera_rig.setup(self)
	add_child(camera_rig)
	camera_rig.set_character_scale(_scale)
	camera_rig.snap_behind()

	Events.stats_upgraded.connect(_on_stats_upgraded)
	Events.level_up.connect(_on_level_up)
	Events.evolution_changed.connect(_on_evolution_changed)
	_emit_spawned.call_deferred()


func _exit_tree() -> void:
	if GameState.player == self:
		GameState.player = null


func _emit_spawned() -> void:
	Events.player_spawned.emit(self)
	_emit_stats(true)


func _light_shape() -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = Vector3(1.5, 1.3, 1.5)
	return b


func _heavy_shape() -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = Vector3(2.0, 1.5, 1.9)
	return b


func _apply_collision_size(s: float) -> void:
	_capsule.radius = 0.3 * s
	_capsule.height = 1.08 * s
	_collision.position = Vector3(0, _capsule.height * 0.5, 0)


func _apply_stage_scale(stage: StringName) -> void:
	_scale = 1.3 if stage != &"goblin" else 1.0
	_apply_collision_size(_scale)
	if camera_rig:
		camera_rig.set_character_scale(_scale)


# ================================================================ Player API
func get_faction() -> StringName:
	return Factions.PLAYER


func is_dead() -> bool:
	return state == State.DEAD or (health != null and health.is_dead())


func get_lock_target() -> Node3D:
	return camera_rig.get_lock_target() if camera_rig else null


func get_facing() -> Vector3:
	return Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))


func get_facing_yaw() -> float:
	return _facing_yaw


func get_cast_origin() -> Vector3:
	return global_position + Vector3.UP * 0.7 * _scale + get_facing() * 0.6 * _scale


func is_busy() -> bool:
	return state in [State.ATTACK, State.DODGE, State.HURT, State.DEAD, State.DASH]


func is_sprinting() -> bool:
	return _sprinting


func is_blocking() -> bool:
	return state == State.BLOCK


func is_invulnerable() -> bool:
	if _invuln_time > 0.0:
		return true
	if state == State.DODGE and _state_time >= DODGE_IFRAMES.x and _state_time <= DODGE_IFRAMES.y:
		return true
	return state == State.DASH and _dash_invuln


func get_state_name() -> String:
	return State.keys()[state]


func spend_energy(amount: float) -> bool:
	if is_dead() or energy < amount:
		return false
	energy -= amount
	_emit_stats()
	return true


func spend_stamina(amount: float) -> bool:
	if is_dead() or stamina < amount:
		return false
	_use_stamina(amount)
	return true


func begin_dash(direction: Vector3, speed: float, duration: float, invulnerable: bool) -> void:
	if is_dead():
		return
	var d := Vector3(direction.x, 0.0, direction.z)
	if d.length_squared() < 0.0001:
		d = get_facing()
	_end_attack()
	_dash_dir = d.normalized()
	_dash_speed = speed
	_dash_time = maxf(0.05, duration)
	_dash_invuln = invulnerable
	_facing_yaw = atan2(-_dash_dir.x, -_dash_dir.z)
	_set_state(State.DASH)


func play_cast_animation() -> void:
	if is_dead() or state in [State.HURT, State.DODGE, State.DASH]:
		return
	_end_attack()
	_cast_time = 0.4
	_set_state(State.CAST)


func respawn() -> void:
	_end_attack()
	global_position = GameState.get_respawn_position()
	velocity = Vector3.ZERO
	_refresh_stats(true)
	if health.is_dead():
		health.revive(1.0)
	else:
		health.set_max_health(Progression.max_health(), true)
	stamina = max_stamina
	energy = max_energy
	_invuln_time = 1.0
	_exhausted = false
	_set_state(State.IDLE)
	model.reset_pose()
	camera_rig.snap_behind()
	reset_physics_interpolation()
	_emit_stats(true)
	Events.player_respawned.emit()


# ================================================================ damage
func take_damage(info: DamageInfo) -> int:
	if info == null or is_dead():
		return DamageInfo.Result.IGNORED
	if is_invulnerable():
		return DamageInfo.Result.IGNORED
	var amount := info.amount * damage_taken_multiplier
	var result: int = DamageInfo.Result.HIT
	var guard_break := false
	if state == State.BLOCK and not info.unblockable and _is_frontal(info):
		var cost := BLOCK_STAMINA_BASE + info.amount * BLOCK_STAMINA_PER_DMG
		amount *= 1.0 - BLOCK_REDUCTION
		if stamina >= cost:
			_use_stamina(cost)
			result = DamageInfo.Result.BLOCKED
			Audio.play_sfx(&"block", global_position + Vector3.UP * 0.6)
			PlayerFx.impact(self, info.hit_position if info.hit_position != Vector3.ZERO else get_cast_origin(), false, Color(0.75, 0.9, 1.0))
			model.flinch(0.4)
			velocity += info.knockback * 0.35
		else:
			_use_stamina(stamina)
			guard_break = true
	var dealt := info.copy()
	dealt.amount = amount
	var killed := health.apply_damage(amount) if amount > 0.0 else false
	if result == DamageInfo.Result.HIT:
		Audio.play_sfx(&"player_hurt", global_position + Vector3.UP * 0.6)
		GameFeel.shake(0.25 if info.is_heavy else 0.12)
		velocity += info.knockback * (0.6 if not guard_break else 0.9)
		_invuln_time = HURT_INVULN
		if killed:
			result = DamageInfo.Result.KILLED
		elif guard_break or info.stagger >= 0.5:
			_end_attack()
			_hurt_time = 0.8 if guard_break else lerpf(0.3, 0.55, clampf(info.stagger, 0.5, 1.0) * 2.0 - 1.0)
			_set_state(State.HURT)
		else:
			model.flinch(0.8)
	elif killed:
		result = DamageInfo.Result.KILLED
	Events.player_damaged.emit(dealt)
	Events.actor_damaged.emit(self, dealt)
	_emit_stats(true)
	if killed:
		_die()
	return result


func _is_frontal(info: DamageInfo) -> bool:
	var dir := Vector3.ZERO
	if is_instance_valid(info.source):
		dir = info.source.global_position - global_position
	elif info.knockback.length_squared() > 0.0001:
		dir = -info.knockback
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return true
	return get_facing().dot(dir.normalized()) >= BLOCK_ARC_COS


func _die() -> void:
	_end_attack()
	_set_state(State.DEAD)
	_death_time = DEATH_RESPAWN_TIME
	if camera_rig:
		camera_rig.release_lock()
	Audio.play_sfx(&"death", global_position)
	Events.player_died.emit()


# ================================================================ stats
func _refresh_stats(refill: bool) -> void:
	health.set_max_health(Progression.max_health(), refill)
	var ms := Progression.max_stamina()
	var me := Progression.max_energy()
	stamina = ms if refill else clampf(stamina + maxf(0.0, ms - max_stamina), 0.0, ms)
	energy = me if refill else clampf(energy + maxf(0.0, me - max_energy), 0.0, me)
	max_stamina = ms
	max_energy = me
	_emit_stats(true)


func _on_stats_upgraded() -> void:
	_refresh_stats(false)


func _on_level_up(_lvl: int) -> void:
	if not is_dead():
		_refresh_stats(true)


func _on_evolution_changed(stage: StringName) -> void:
	model.set_stage(stage, true)
	_apply_stage_scale(stage)
	Audio.play_sfx(&"evolve", global_position)
	GameFeel.shake(0.3)
	if not is_dead():
		_refresh_stats(true)


func _use_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_stamina_delay = STAMINA_REGEN_DELAY
	if stamina <= 0.0:
		_exhausted = true
	_emit_stats()


func _emit_stats(force: bool = false) -> void:
	if health == null:
		return
	if not force:
		if _emit_cooldown > 0.0:
			return
		if absf(health.health - _last_emitted[0]) <= 0.05 and absf(health.max_health - _last_emitted[1]) <= 0.05 				and absf(stamina - _last_emitted[2]) <= 0.05 and absf(max_stamina - _last_emitted[3]) <= 0.05 				and absf(energy - _last_emitted[4]) <= 0.05 and absf(max_energy - _last_emitted[5]) <= 0.05:
			return
	_last_emitted[0] = health.health
	_last_emitted[1] = health.max_health
	_last_emitted[2] = stamina
	_last_emitted[3] = max_stamina
	_last_emitted[4] = energy
	_last_emitted[5] = max_energy
	_emit_cooldown = 0.05
	Events.player_stats_changed.emit(health.health, health.max_health, stamina, max_stamina, energy, max_energy)


func _regen(delta: float) -> void:
	if state == State.DEAD:
		return
	_stamina_delay = maxf(0.0, _stamina_delay - delta)
	if _stamina_delay <= 0.0 and not _sprinting and stamina < max_stamina:
		var rate := STAMINA_REGEN * (0.45 if state == State.BLOCK else 1.0)
		stamina = minf(max_stamina, stamina + rate * delta)
	if _exhausted and stamina >= EXHAUST_THRESHOLD:
		_exhausted = false
	if energy < max_energy:
		energy = minf(max_energy, energy + ENERGY_REGEN * delta)
	_emit_cooldown = maxf(0.0, _emit_cooldown - delta)
	_emit_stats()


# ================================================================ main loop
func _physics_process(delta: float) -> void:
	_state_time += delta
	_invuln_time = maxf(0.0, _invuln_time - delta)
	var blocked := GameState.is_input_blocked() or state == State.DEAD
	_read_input(blocked, delta)

	match state:
		State.IDLE, State.MOVE, State.AIR:
			_update_locomotion(delta)
		State.BLOCK:
			_update_block(delta)
		State.ATTACK:
			_update_attack(delta)
		State.DODGE:
			_update_dodge(delta)
		State.HURT:
			_update_hurt(delta)
		State.CAST:
			_update_cast(delta)
		State.DASH:
			_update_dash(delta)
		State.DEAD:
			_update_dead(delta)

	_apply_gravity(delta)
	_move(delta)
	_post_move(delta)
	_update_facing(delta)
	_regen(delta)
	_interact_timer -= delta
	if _interact_timer <= 0.0:
		_interact_timer = 0.1
		_update_interaction()
	_feed_model()


func _read_input(blocked: bool, delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_attack_buffer = maxf(0.0, _attack_buffer - delta)
	_dodge_buffer = maxf(0.0, _dodge_buffer - delta)
	if blocked:
		_move_input = Vector2.ZERO
		_jump_held = false
		return
	_move_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_jump_held = Input.is_action_pressed(&"jump")
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer = JUMP_BUFFER
	if Input.is_action_just_pressed(&"attack_light"):
		_attack_buffer = ATTACK_BUFFER
		_attack_buffer_heavy = false
	if Input.is_action_just_pressed(&"attack_heavy"):
		_attack_buffer = ATTACK_BUFFER
		_attack_buffer_heavy = true
	if Input.is_action_just_pressed(&"dodge"):
		_dodge_buffer = 0.2
	if Input.is_action_just_pressed(&"interact") and _current_interactable and state != State.DEAD:
		_current_interactable.interact(self)
	for i in 3:
		if Input.is_action_just_pressed(StringName("ability_%d" % (i + 1))) and abilities:
			abilities.try_activate(i)


## Camera-relative wish direction (flat, length 0..1).
func get_move_direction() -> Vector3:
	var yaw := camera_rig.get_yaw() if camera_rig else _facing_yaw
	var v := Vector3(_move_input.x, 0.0, _move_input.y).rotated(Vector3.UP, yaw)
	return v.limit_length(1.0)


func _set_state(s: State) -> void:
	if s == state and s != State.ATTACK:
		return
	if state == State.ATTACK and s != State.ATTACK:
		_hitbox.deactivate()
	state = s
	_state_time = 0.0


func _speed_mult() -> float:
	var m := 1.0
	var w := GameState.world
	if is_instance_valid(w) and w.has_method("is_in_water") and w.is_in_water(global_position):
		m *= WATER_SPEED_MULT
	return m


func _in_water() -> bool:
	var w := GameState.world
	return is_instance_valid(w) and w.has_method("is_in_water") and bool(w.is_in_water(global_position))


# ---------------------------------------------------------------- locomotion
func _update_locomotion(delta: float) -> void:
	var on_floor := is_on_floor()
	# transitions into actions
	if _try_start_actions():
		return
	if on_floor and Input.is_action_pressed(&"block") and not GameState.is_input_blocked():
		_set_state(State.BLOCK)
		_update_block(delta)
		return
	var wish := get_move_direction()
	var mag := wish.length()
	var want_sprint := on_floor and mag > 0.3 and not _exhausted and stamina > 0.0 \
		and Input.is_action_pressed(&"sprint") and not GameState.is_input_blocked()
	if not on_floor:
		want_sprint = _sprinting  # keep momentum style mid-air, no drain
	_sprinting = want_sprint
	if _sprinting and on_floor:
		_use_stamina(SPRINT_DRAIN * delta)
		if stamina <= 0.0:
			_sprinting = false
	var target_speed := 0.0
	if mag > 0.05:
		if _sprinting:
			target_speed = SPRINT_SPEED
		elif mag < 0.6:
			target_speed = WALK_SPEED * clampf(mag / 0.6, 0.3, 1.0)
		else:
			target_speed = RUN_SPEED
	target_speed *= _speed_mult()
	var dir := wish.normalized() if mag > 0.0 else Vector3.ZERO
	_accelerate(dir * target_speed, delta, on_floor)
	if on_floor:
		_set_state(State.MOVE if Vector2(velocity.x, velocity.z).length() > 0.15 or mag > 0.05 else State.IDLE)
	else:
		_set_state(State.AIR)
	# jump (coyote + buffer)
	if _jump_buffer > 0.0 and _time_since_floor <= COYOTE_TIME and not _jumped:
		_do_jump()


func _accelerate(target_h: Vector3, delta: float, on_floor: bool) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if not on_floor:
		rate = AIR_ACCEL
	elif target_h.length_squared() < 0.0001:
		rate = GROUND_DECEL
	elif h.length_squared() > 0.25 and h.normalized().dot(target_h.normalized()) < 0.0:
		rate = TURN_ACCEL
	else:
		rate = GROUND_ACCEL
	h = h.move_toward(target_h, rate * delta)
	velocity.x = h.x
	velocity.z = h.z


func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	_jumped = true
	_jump_buffer = 0.0
	_time_since_floor = COYOTE_TIME + 1.0
	_set_state(State.AIR)
	Audio.play_sfx(&"jump", global_position)


## Starts buffered dodge / attack if allowed. Returns true if the state changed.
func _try_start_actions() -> bool:
	if not is_on_floor() and state != State.ATTACK:
		return false
	if _dodge_buffer > 0.0 and _start_dodge():
		return true
	if _attack_buffer > 0.0:
		return _start_attack(_attack_buffer_heavy)
	return false


func _apply_gravity(delta: float) -> void:
	if state == State.DASH and is_on_floor():
		return
	if is_on_floor() and velocity.y <= 0.0:
		return
	var g := GRAVITY
	if velocity.y < 0.0:
		g *= FALL_GRAVITY_MULT
	elif not _jump_held and _jumped:
		g *= JUMP_CUT_GRAVITY_MULT
	velocity.y = maxf(velocity.y - g * delta, -MAX_FALL_SPEED)


func _move(delta: float) -> void:
	var desired_h := Vector3(velocity.x, 0.0, velocity.z)
	var was_floor := is_on_floor()
	move_and_slide()
	if was_floor and is_on_wall() and desired_h.length() > 0.5 and velocity.y <= 0.1:
		_try_step_up(desired_h, delta)


func _try_step_up(desired_h: Vector3, delta: float) -> void:
	var low_wall := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if n.y < 0.7 and col.get_position().y - global_position.y < STEP_HEIGHT and n.dot(desired_h.normalized()) < -0.3:
			low_wall = true
			break
	if not low_wall:
		return
	var motion := desired_h.normalized() * maxf(desired_h.length() * delta, 0.12)
	var t := global_transform
	if test_move(t, Vector3.UP * STEP_HEIGHT):
		return
	var up := t.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(up, motion):
		return
	var fwd := up.translated(motion)
	var col := KinematicCollision3D.new()
	if not test_move(fwd, Vector3.DOWN * STEP_HEIGHT * 1.5, col):
		return
	if col.get_normal().y < cos(floor_max_angle):
		return
	global_position = fwd.origin + col.get_travel()
	velocity.x = desired_h.x
	velocity.z = desired_h.z
	apply_floor_snap()


func _post_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		if not _was_on_floor:
			_on_landed()
		_time_since_floor = 0.0
		_jumped = false
		_fall_speed = 0.0
		if state == State.AIR:
			_set_state(State.IDLE)
	else:
		_time_since_floor += delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
		if state in [State.IDLE, State.MOVE, State.BLOCK] and _time_since_floor > COYOTE_TIME:
			_set_state(State.AIR)
	_was_on_floor = on_floor
	if global_position.y < KILL_Y:
		_rescue_from_fall()
	_safe_timer += delta
	if _safe_timer >= 2.0:
		_safe_timer = 0.0
		if on_floor and state != State.DEAD and not _in_water() and not GameState.in_combat():
			GameState.update_safe_position(global_position)


func _on_landed() -> void:
	if _fall_speed > 3.0:
		var impact := clampf((_fall_speed - 3.0) / 12.0, 0.15, 1.0)
		model.land(impact)
		Audio.play_sfx(&"land", global_position, lerpf(-8.0, 0.0, impact))
		if _in_water():
			Audio.play_sfx(&"splash", global_position)


func _rescue_from_fall() -> void:
	global_position = GameState.get_spawn_position()
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	if camera_rig:
		camera_rig.snap_behind()


func _update_facing(delta: float) -> void:
	var target := _facing_yaw
	var lock := get_lock_target()
	var h := Vector3(velocity.x, 0.0, velocity.z)
	match state:
		State.IDLE, State.MOVE, State.AIR, State.BLOCK:
			if lock and not _sprinting:
				var to := lock.global_position - global_position
				if Vector2(to.x, to.z).length_squared() > 0.01:
					target = atan2(-to.x, -to.z)
			elif state == State.BLOCK:
				pass
			elif _move_input.length_squared() > 0.01 and h.length_squared() > 0.04:
				var wish := get_move_direction()
				target = atan2(-wish.x, -wish.z)
		_:
			pass  # actions set _facing_yaw explicitly
	var rate := TURN_RATE * (0.45 if state == State.AIR else 1.0)
	if state in [State.IDLE, State.MOVE, State.AIR, State.BLOCK]:
		_facing_yaw = lerp_angle(_facing_yaw, target, 1.0 - exp(-rate * delta))
	_facing_yaw = wrapf(_facing_yaw, -PI, PI)
	_facing_pivot.rotation.y = _facing_yaw


# ---------------------------------------------------------------- block
func _update_block(delta: float) -> void:
	if not Input.is_action_pressed(&"block") or GameState.is_input_blocked() or not is_on_floor():
		_set_state(State.IDLE)
		return
	if _dodge_buffer > 0.0 and _start_dodge():
		return
	if _attack_buffer > 0.0 and _start_attack(_attack_buffer_heavy):
		return
	_sprinting = false
	var wish := get_move_direction()
	_accelerate(wish * BLOCK_SPEED * _speed_mult(), delta, true)
	if _jump_buffer > 0.0 and _time_since_floor <= COYOTE_TIME:
		_do_jump()


# ---------------------------------------------------------------- dodge
func _start_dodge() -> bool:
	if stamina < DODGE_COST:
		_dodge_buffer = 0.0
		return false
	_dodge_buffer = 0.0
	_use_stamina(DODGE_COST)
	_end_attack()
	var wish := get_move_direction()
	_dodge_backstep = wish.length() < 0.2
	if _dodge_backstep:
		_dodge_dir = -get_facing()
	else:
		_dodge_dir = wish.normalized()
		_facing_yaw = atan2(-_dodge_dir.x, -_dodge_dir.z)
	_sprinting = false
	_set_state(State.DODGE)
	velocity.x = _dodge_dir.x * (BACKSTEP_SPEED if _dodge_backstep else DODGE_SPEED)
	velocity.z = _dodge_dir.z * (BACKSTEP_SPEED if _dodge_backstep else DODGE_SPEED)
	Audio.play_sfx(&"dodge", global_position)
	return true


func _update_dodge(delta: float) -> void:
	var total := DODGE_TIME + DODGE_RECOVERY
	var t := _state_time
	var base := BACKSTEP_SPEED if _dodge_backstep else DODGE_SPEED
	var dur := DODGE_TIME * (0.75 if _dodge_backstep else 1.0)
	var speed := 0.0
	if t < dur:
		var k := t / dur
		speed = base * (1.0 - k * k * 0.85)
	velocity.x = _dodge_dir.x * speed * _speed_mult()
	velocity.z = _dodge_dir.z * speed * _speed_mult()
	# recovery: allow buffered attack after the i-frames end
	if t > DODGE_IFRAMES.y + 0.04 and _attack_buffer > 0.0 and is_on_floor():
		if _start_attack(_attack_buffer_heavy):
			return
	if t >= total:
		_set_state(State.IDLE)


# ---------------------------------------------------------------- attacks
func _start_attack(heavy: bool) -> bool:
	if not is_on_floor():
		return false
	var cost := HEAVY_COST if heavy else LIGHT_COST
	if stamina <= 0.0:
		return false
	var next: StringName
	if heavy:
		next = &"heavy"
	else:
		if _chain_reset <= 0.0:
			_chain_index = 0
		next = LIGHT_CHAIN[_chain_index % LIGHT_CHAIN.size()]
		_chain_index = (_chain_index + 1) % LIGHT_CHAIN.size()
	_attack_buffer = 0.0
	_use_stamina(cost)
	_attack_name = next
	_attack_phase = 0
	_attack_phase_time = 0.0
	_attack_hit_once = false
	_sprinting = false
	_hit_this_swing.clear()
	_auto_aim()
	_set_state(State.ATTACK)
	Audio.play_sfx(&"swing_heavy" if heavy else &"swing_light", global_position + Vector3.UP * 0.7)
	return true


func _attack_data() -> Dictionary:
	return ATTACKS.get(_attack_name, ATTACKS[&"light1"])


func _auto_aim() -> void:
	var lock := get_lock_target()
	var target: Node3D = null
	if lock:
		target = lock
	else:
		var wish := get_move_direction()
		var fwd := wish.normalized() if wish.length() > 0.2 else get_facing()
		var rng := AUTO_AIM_RANGE
		var cone := AUTO_AIM_COS
		var best := INF
		for group in [&"enemies", &"lock_targets"]:
			for n in get_tree().get_nodes_in_group(group):
				if not (n is Node3D) or n == self:
					continue
				var e := n as Node3D
				if e.has_method("is_dead") and e.is_dead():
					continue
				if not Factions.is_hostile(self, e):
					continue  # never auto-target neutrals / friends
				var to := e.global_position - global_position
				to.y = 0.0
				var d := to.length()
				if d > rng or d < 0.01:
					continue
				if fwd.dot(to / d) < cone:
					continue
				if d < best:
					best = d
					target = e
		if target == null and wish.length() > 0.2:
			_facing_yaw = atan2(-fwd.x, -fwd.z)
	if target:
		var to2 := target.global_position - global_position
		if Vector2(to2.x, to2.z).length_squared() > 0.0001:
			_facing_yaw = atan2(-to2.x, -to2.z)
	_facing_pivot.rotation.y = _facing_yaw


func _update_attack(delta: float) -> void:
	var d := _attack_data()
	_attack_phase_time += delta
	var heavy := _attack_name == &"heavy"
	var h := Vector3(velocity.x, 0.0, velocity.z)
	match _attack_phase:
		0:  # windup: slide to a stop, then hold the anticipation pose
			h = h.move_toward(Vector3.ZERO, GROUND_DECEL * 1.2 * delta)
			# dodge may cancel windup
			if _dodge_buffer > 0.0 and _start_dodge():
				return
			if _attack_phase_time >= float(d["windup"]):
				_attack_phase = 1
				_attack_phase_time = 0.0
				_begin_active(d, heavy)
				h = get_facing() * float(d["lunge"])
		1:  # active: lunge, hitbox live
			h = h.move_toward(Vector3.ZERO, 10.0 * delta)
			if _attack_phase_time >= float(d["active"]):
				_hitbox.deactivate()
				_attack_phase = 2
				_attack_phase_time = 0.0
		2:  # recovery: can be cancelled by dodge or chained into the next light
			h = h.move_toward(Vector3.ZERO, GROUND_DECEL * delta)
			if _dodge_buffer > 0.0 and _start_dodge():
				return
			var rec := float(d["recovery"])
			if _attack_buffer > 0.0 and _attack_phase_time >= rec * 0.25:
				if _attack_buffer_heavy or (not heavy and _chain_index != 0):
					_chain_reset = 0.6
					if _start_attack(_attack_buffer_heavy):
						return
			if _attack_phase_time >= rec:
				_chain_reset = 0.35 if not heavy and _chain_index != 0 else 0.0
				if heavy:
					_chain_index = 0
				_end_attack()
				_set_state(State.IDLE)
	velocity.x = h.x * _speed_mult()
	velocity.z = h.z * _speed_mult()


func _begin_active(d: Dictionary, heavy: bool) -> void:
	var info := DamageInfo.make(Progression.attack_power() * float(d["mult"]), self, float(d["knock"]), float(d["stagger"]))
	info.is_heavy = heavy
	info.attack_id = _attack_name
	_hitbox.setup(self, _heavy_shape() if heavy else _light_shape(), Vector3(0, 0.6, -0.95 if heavy else -0.85) * _scale)
	_hitbox.activate(info, float(d["active"]))
	PlayerFx.swing_arc(self, _facing_pivot.global_transform, _attack_name, _scale)
	if heavy and Progression.has_unlock(&"shockwave_slam"):
		var sw := DamageInfo.make(Progression.attack_power() * 1.2, self, 7.0, 0.7)
		sw.is_heavy = true
		sw.attack_id = &"shockwave_slam"
		var center := global_position + get_facing() * 0.9 * _scale
		_shock_hitbox.position = get_facing() * 0.9 * _scale
		_shock_hitbox.activate(sw, 0.12)
		PlayerFx.shockwave(self, center, SHOCKWAVE_RADIUS)
		Audio.play_sfx(&"ogre_slam", center, -4.0)
		GameFeel.shake(0.3)


func _end_attack() -> void:
	if _hitbox:
		_hitbox.deactivate()
	_attack_phase = 0
	_attack_phase_time = 0.0


func _chain_tick(delta: float) -> void:
	_chain_reset = maxf(0.0, _chain_reset - delta)


func _on_hit_landed(target: Node3D, result: int, info: DamageInfo) -> void:
	if result == DamageInfo.Result.IGNORED:
		return
	_attack_hit_once = true
	var heavy := info.is_heavy
	PlayerFx.impact(self, info.hit_position, heavy)
	if result == DamageInfo.Result.BLOCKED:
		Audio.play_sfx(&"block", info.hit_position)
	else:
		Audio.play_sfx(&"hit_heavy" if heavy else &"hit", info.hit_position)
	if heavy:
		GameFeel.hit_stop(0.07)
		GameFeel.shake(0.35)
	else:
		GameFeel.hit_stop(0.03)
		GameFeel.shake(0.08)
	_hit_this_swing[target.get_instance_id()] = true


func _on_shock_landed(_target: Node3D, result: int, info: DamageInfo) -> void:
	if result != DamageInfo.Result.IGNORED:
		PlayerFx.impact(self, info.hit_position, true, PlayerFx.HEAVY_ARC)


# ---------------------------------------------------------------- hurt / cast / dash / dead
func _update_hurt(delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	if _state_time >= _hurt_time:
		_set_state(State.IDLE)


func _update_cast(delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, GROUND_DECEL * delta)
	velocity.x = h.x
	velocity.z = h.z
	if _state_time >= _cast_time:
		_set_state(State.IDLE)


func _update_dash(_delta: float) -> void:
	velocity.x = _dash_dir.x * _dash_speed
	velocity.z = _dash_dir.z * _dash_speed
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	if _state_time >= _dash_time:
		var h := _dash_dir * minf(_dash_speed, RUN_SPEED)
		velocity.x = h.x
		velocity.z = h.z
		_set_state(State.IDLE)


func _update_dead(delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 12.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	_death_time -= delta
	if _death_time <= 0.0:
		respawn()


# ---------------------------------------------------------------- interaction
func _update_interaction() -> void:
	var best: Interactable = null
	if state != State.DEAD:
		var best_score := INF
		var fwd := get_facing()
		for a in _interact_area.get_overlapping_areas():
			var it := a as Interactable
			if it == null or not it.can_interact(self):
				continue
			var to := it.global_position - global_position
			to.y = 0.0
			var dist := to.length()
			var front := fwd.dot(to / dist) if dist > 0.01 else 1.0
			var score := dist - front * 0.75
			if score < best_score:
				best_score = score
				best = it
	_current_interactable = best
	var text := ("[E] " + best.prompt) if best else ""
	if text != _prompt_text:
		_prompt_text = text
		Events.interaction_prompt_changed.emit(text)


# ---------------------------------------------------------------- model feed
func _feed_model() -> void:
	_chain_tick(get_physics_process_delta_time() * Engine.time_scale)
	model.anim_speed = Vector2(velocity.x, velocity.z).length()
	model.anim_vertical = velocity.y
	model.anim_grounded = is_on_floor()
	model.anim_sprinting = _sprinting and state == State.MOVE
	match state:
		State.IDLE:
			model.anim_state = &"idle"
		State.MOVE:
			model.anim_state = &"move" if model.anim_speed > 0.2 else &"idle"
		State.AIR:
			model.anim_state = &"air"
		State.ATTACK:
			model.anim_state = &"attack"
			model.anim_action = _attack_name
			var d := _attack_data()
			var dur := float(d[PHASE_KEYS[_attack_phase]])
			model.anim_phase = float(_attack_phase) + clampf(_attack_phase_time / maxf(dur, 0.001), 0.0, 1.0)
		State.DODGE:
			model.anim_state = &"backstep" if _dodge_backstep else &"dodge"
			model.anim_t = _state_time / DODGE_TIME
		State.BLOCK:
			model.anim_state = &"block"
		State.HURT:
			model.anim_state = &"hurt"
		State.CAST:
			model.anim_state = &"cast"
			model.anim_t = _state_time / maxf(_cast_time, 0.01)
		State.DASH:
			model.anim_state = &"dash"
		State.DEAD:
			model.anim_state = &"dead"
