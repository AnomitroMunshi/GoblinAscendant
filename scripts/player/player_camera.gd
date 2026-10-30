class_name PlayerCamera
extends Node3D
## Third-person camera rig. top_level, follows the player.
##   rig (this, follows player) -> yaw -> pitch -> SpringArm3D (query only) + Camera3D
## Rotation from mouse/stick is applied immediately; only the follow
## position is lightly smoothed. The SpringArm3D (mask WORLD) is used as a
## collision query; the camera snaps in instantly on obstruction and eases
## back out, so it never clips into terrain or walls.
## Lock-on: R toggles, target_next/prev switch by screen angle.

const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(35.0)
const DEFAULT_PITCH := deg_to_rad(-12.0)
const LOOK_HEIGHT := 0.95          # pivot height above the player's feet (goblin scale)
const GOBLIN_DIST_SCALE := 0.85    # the goblin is small: frame it a bit closer than the setting
const SHOULDER := 0.42             # over-the-shoulder offset (right)
const STICK_YAW_SPEED := deg_to_rad(200.0)
const STICK_PITCH_SPEED := deg_to_rad(120.0)
const LOCK_RANGE := 22.0
const LOCK_BREAK_RANGE := 30.0
const LOCK_LOS_GRACE := 1.5        # seconds a target may stay hidden before release
const SPRING_MARGIN := 0.2

var player: Node3D
var yaw := 0.0
var pitch := DEFAULT_PITCH
var distance := 4.6
var base_fov := 70.0
var invert_y := false
var sensitivity := 0.25            # degrees per pixel

var yaw_node: Node3D
var pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D
var reticle: Sprite3D

var lock_target: Node3D
var _lock_hidden_time := 0.0
var _arm_len := 4.6
var _shoulder := SHOULDER
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0
var _reset_time := 0.0
var _follow := Vector3.ZERO
var _scale := 1.0


func setup(p_player: Node3D) -> void:
	player = p_player


func _ready() -> void:
	top_level = true
	process_physics_priority = 10  # after the player has moved
	yaw_node = Node3D.new()
	yaw_node.name = "Yaw"
	add_child(yaw_node)
	pitch_node = Node3D.new()
	pitch_node.name = "Pitch"
	yaw_node.add_child(pitch_node)
	spring = SpringArm3D.new()
	spring.name = "SpringArm"
	spring.collision_mask = Layers.WORLD
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	spring.shape = sphere
	spring.margin = 0.05
	spring.position = Vector3(SHOULDER, 0, 0)
	spring.spring_length = distance
	pitch_node.add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.far = 1200.0
	pitch_node.add_child(camera)
	camera.current = true
	_build_reticle()
	_noise.seed = randi()
	_noise.frequency = 0.9
	_apply_settings()
	Settings.changed.connect(_on_setting_changed)
	Events.camera_shake.connect(add_trauma)
	Events.look_input.connect(_on_look_input)
	GameState.camera = camera
	snap_behind()


func _exit_tree() -> void:
	if GameState.camera == camera:
		GameState.camera = null


func _apply_settings() -> void:
	sensitivity = float(Settings.get_value(&"mouse_sensitivity", 0.25))
	invert_y = bool(Settings.get_value(&"invert_y", false))
	distance = clampf(float(Settings.get_value(&"camera_distance", 4.6)), 1.5, 12.0)
	base_fov = clampf(float(Settings.get_value(&"fov", 70.0)), 40.0, 120.0)
	if camera:
		camera.fov = base_fov


func _on_setting_changed(_key: StringName) -> void:
	_apply_settings()


## Model scale (Hobgoblin) raises the pivot and pushes the camera back a bit.
func set_character_scale(s: float) -> void:
	_scale = s


# =============================================================== public helpers
func get_yaw() -> float:
	return yaw


func get_lock_target() -> Node3D:
	return lock_target if is_instance_valid(lock_target) else null


func snap_behind() -> void:
	if player == null:
		return
	if player.has_method("get_facing_yaw"):
		yaw = player.get_facing_yaw()
	pitch = DEFAULT_PITCH
	_follow = _pivot_target()
	global_position = _follow
	_apply_rotation()
	_arm_len = distance * _dist_scale()
	_update_camera_transform(0.0)
	if is_inside_tree():
		reset_physics_interpolation()


func request_reset() -> void:
	_reset_time = 0.45


func add_trauma(strength: float) -> void:
	_trauma = clampf(_trauma + strength, 0.0, 1.0)


func get_trauma() -> float:
	return _trauma


func get_arm_length() -> float:
	return _arm_len


# =============================================================== input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.is_input_blocked():
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		apply_look(rel * sensitivity)


## Device-agnostic look input (e.g. future touch drag), already in degrees.
func _on_look_input(delta_degrees: Vector2) -> void:
	if not GameState.is_input_blocked():
		apply_look(delta_degrees)


## Look input in degrees (x = yaw right, y = pitch down). Ignored for yaw while locked on.
func apply_look(deg: Vector2) -> void:
	if get_lock_target() != null:
		return
	_reset_time = 0.0
	yaw -= deg_to_rad(deg.x)
	var dy := deg_to_rad(deg.y) * (-1.0 if invert_y else 1.0)
	pitch = clampf(pitch - dy, PITCH_MIN, PITCH_MAX)
	_apply_rotation()


func _apply_rotation() -> void:
	yaw = wrapf(yaw, -PI, PI)
	yaw_node.rotation = Vector3(0, yaw, 0)
	pitch_node.rotation = Vector3(pitch, 0, 0)


func _dist_scale() -> float:
	return GOBLIN_DIST_SCALE * lerpf(1.0, 1.25, clampf((_scale - 1.0) / 0.3, 0.0, 1.0))


func _pivot_target() -> Vector3:
	if player == null:
		return global_position
	return player.global_position + Vector3.UP * LOOK_HEIGHT * _scale


# =============================================================== per-frame
func _process(delta: float) -> void:
	if player == null:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)  # look input ignores hit-stop
	if not GameState.is_input_blocked():
		var stick := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		if stick.length_squared() > 0.0 and get_lock_target() == null:
			_reset_time = 0.0
			yaw -= stick.x * STICK_YAW_SPEED * real_delta
			var sy := stick.y * (-1.0 if invert_y else 1.0)
			pitch = clampf(pitch - sy * STICK_PITCH_SPEED * real_delta, PITCH_MIN, PITCH_MAX)
	if _reset_time > 0.0 and get_lock_target() == null:
		_reset_time -= real_delta
		var k := 1.0 - exp(-12.0 * real_delta)
		var target_yaw: float = player.get_facing_yaw() if player.has_method("get_facing_yaw") else yaw
		yaw = lerp_angle(yaw, target_yaw, k)
		pitch = lerpf(pitch, DEFAULT_PITCH, k)
	_apply_rotation()
	# FOV kick while sprinting
	var target_fov := base_fov
	if player.has_method("is_sprinting") and player.is_sprinting():
		target_fov += 7.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * real_delta))
	# shake (decaying trauma, squared for a restrained feel)
	_trauma = maxf(0.0, _trauma - real_delta * 1.8)
	_noise_t += real_delta * 60.0
	var amt := _trauma * _trauma
	camera.h_offset = _noise.get_noise_2d(_noise_t, 0.0) * 0.12 * amt
	camera.v_offset = _noise.get_noise_2d(0.0, _noise_t) * 0.1 * amt
	camera.rotation.z = _noise.get_noise_2d(_noise_t, 50.0) * deg_to_rad(2.2) * amt
	_update_reticle(delta)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not GameState.is_input_blocked():
		if Input.is_action_just_pressed(&"camera_reset"):
			request_reset()
		if Input.is_action_just_pressed(&"lock_on"):
			toggle_lock()
		elif get_lock_target() != null:
			if Input.is_action_just_pressed(&"target_next"):
				switch_target(1)
			elif Input.is_action_just_pressed(&"target_prev"):
				switch_target(-1)
	_validate_lock(delta)
	# follow: horizontal is tight, vertical slightly softer (smooths stairs/jumps)
	var target := _pivot_target()
	var tl := get_lock_target()
	if tl != null:
		var lp := _lock_point(tl)
		target = target.lerp((target + lp) * 0.5, 0.3)
		var to := lp - player.global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			var want_yaw := atan2(-to.x, -to.z)
			var k := 1.0 - exp(-9.0 * delta)
			yaw = lerp_angle(yaw, want_yaw, k)
			var horiz := maxf(to.length(), 0.5)
			var dy := lp.y - (player.global_position.y + LOOK_HEIGHT * _scale)
			var want_pitch := clampf(-atan2(-dy, horiz) - deg_to_rad(16.0), PITCH_MIN, deg_to_rad(10.0))
			pitch = lerpf(pitch, want_pitch, 1.0 - exp(-5.0 * delta))
			_apply_rotation()
	var kh := 1.0 - exp(-22.0 * delta)
	var kv := 1.0 - exp(-12.0 * delta)
	if _follow.distance_squared_to(target) > 64.0:
		_follow = target  # teleport / respawn
	_follow.x = lerpf(_follow.x, target.x, kh)
	_follow.z = lerpf(_follow.z, target.z, kh)
	_follow.y = lerpf(_follow.y, target.y, kv)
	global_position = _follow
	_update_camera_transform(delta)


func _update_camera_transform(delta: float) -> void:
	# shoulder offset shrinks if a wall is right beside the pivot
	var want_shoulder := SHOULDER
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		var from := global_position
		var side := pitch_node.global_basis.x.normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + side * (SHOULDER + 0.25), Layers.WORLD)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			want_shoulder = clampf(from.distance_to(hit.position) - 0.25, 0.0, SHOULDER)
	_shoulder = want_shoulder if want_shoulder < _shoulder or delta <= 0.0 else lerpf(_shoulder, want_shoulder, 1.0 - exp(-4.0 * delta))
	spring.position = Vector3(_shoulder, 0, 0)
	var full := distance * _dist_scale()
	spring.spring_length = full
	var hit_len := full
	if is_inside_tree():
		hit_len = _spring_hit(full)
	# snap in on obstruction, ease out when it clears
	if hit_len < _arm_len or delta <= 0.0:
		_arm_len = hit_len
	else:
		_arm_len = move_toward(_arm_len, hit_len, delta * 6.0)
	camera.position = Vector3(_shoulder, 0, _arm_len)


## Sphere-cast along the arm (same as SpringArm3D, but synchronous so the
## camera never lags a frame behind an obstruction).
func _spring_hit(full: float) -> float:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = spring.shape
	params.collision_mask = Layers.WORLD
	params.margin = spring.margin
	var origin := spring.global_position
	params.transform = Transform3D(Basis.IDENTITY, origin)
	var dir := spring.global_basis.z.normalized()
	params.motion = dir * full
	var res := space.cast_motion(params)
	if res.is_empty():
		return full
	var safe: float = res[0]
	if safe >= 1.0:
		return full
	return maxf(0.2, full * safe - SPRING_MARGIN * 0.25)


# =============================================================== lock-on
func _lock_point(t: Node3D) -> Vector3:
	if t.has_method("get_lock_point"):
		return t.get_lock_point()
	return t.global_position + Vector3.UP


func _is_lockable(t: Node, max_range: float) -> bool:
	if not (t is Node3D) or not is_instance_valid(t) or not t.is_inside_tree():
		return false
	if t == player or not t.is_in_group(&"lock_targets"):
		return false
	if t.has_method("is_dead") and t.is_dead():
		return false
	return (t as Node3D).global_position.distance_to(player.global_position) <= max_range


func _has_los(p: Vector3) -> bool:
	var from := player.global_position + Vector3.UP * LOOK_HEIGHT * _scale
	var q := PhysicsRayQueryParameters3D.create(from, p, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func get_candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if player == null or not is_inside_tree():
		return out
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for n in get_tree().get_nodes_in_group(&"lock_targets"):
		if not _is_lockable(n, LOCK_RANGE):
			continue
		var t := n as Node3D
		var lp := _lock_point(t)
		var to := lp - player.global_position
		to.y = 0.0
		if to.length() > 1.5 and fwd.dot(to.normalized()) < 0.1:
			continue  # behind the camera
		if not _has_los(lp):
			continue
		out.append(t)
	return out


func _screen_angle(t: Node3D) -> float:
	var local := camera.global_transform.affine_inverse() * _lock_point(t)
	return atan2(local.x, -local.z)


func toggle_lock() -> void:
	if get_lock_target() != null:
		set_lock_target(null)
		return
	if not acquire_lock():
		request_reset()  # nothing to lock: recentre behind the goblin


## Locks the best candidate. Returns false when none is available.
func acquire_lock() -> bool:
	var best: Node3D = null
	var best_score := INF
	for t in get_candidates():
		var score := absf(_screen_angle(t)) * 2.0 + t.global_position.distance_to(player.global_position) / LOCK_RANGE
		if score < best_score:
			best_score = score
			best = t
	if best:
		set_lock_target(best)
	return best != null


func switch_target(dir: int) -> void:
	var cur := get_lock_target()
	if cur == null:
		return
	var cur_a := _screen_angle(cur)
	var cands := get_candidates()
	var best: Node3D = null
	var best_d := INF
	var wrap: Node3D = null
	var wrap_a := INF
	for t in cands:
		if t == cur:
			continue
		var d := (_screen_angle(t) - cur_a) * float(dir)
		if d > 0.0 and d < best_d:
			best_d = d
			best = t
		if d <= 0.0 and d < wrap_a:  # furthest the other way, for wrap-around
			wrap_a = d
			wrap = t
	if best == null:
		best = wrap
	if best:
		set_lock_target(best)


func set_lock_target(t: Node3D) -> void:
	if t == lock_target and (t == null or is_instance_valid(t)):
		return
	lock_target = t
	_lock_hidden_time = 0.0
	if reticle:
		reticle.visible = t != null
	Events.lock_target_changed.emit(t)


func release_lock() -> void:
	if lock_target != null:
		set_lock_target(null)


func _validate_lock(delta: float) -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not _is_lockable(lock_target, LOCK_BREAK_RANGE):
		lock_target = null
		if reticle:
			reticle.visible = false
		Events.lock_target_changed.emit(null)
		return
	if _has_los(_lock_point(lock_target)):
		_lock_hidden_time = 0.0
	else:
		_lock_hidden_time += delta
		if _lock_hidden_time > LOCK_LOS_GRACE:
			release_lock()


func _build_reticle() -> void:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var r := p.length()
			var a := 0.0
			# thin ring
			a = maxf(a, clampf(1.0 - absf(r - 20.0) / 2.2, 0.0, 1.0))
			# four inward ticks
			var ax := absf(p.x)
			var ay := absf(p.y)
			if (ax < 2.0 and ay > 22.0 and ay < 30.0) or (ay < 2.0 and ax > 22.0 and ax < 30.0):
				a = 1.0
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	reticle = Sprite3D.new()
	reticle.name = "LockReticle"
	reticle.texture = ImageTexture.create_from_image(img)
	reticle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reticle.no_depth_test = true
	reticle.fixed_size = true
	reticle.pixel_size = 0.00075
	reticle.shaded = false
	reticle.double_sided = true
	reticle.render_priority = 10
	reticle.modulate = Color(1.0, 0.82, 0.35, 0.95)
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reticle.top_level = true
	reticle.visible = false
	add_child(reticle)


func _update_reticle(delta: float) -> void:
	var t := get_lock_target()
	if t == null:
		reticle.visible = false
		return
	reticle.visible = true
	reticle.global_position = _lock_point(t)
	reticle.rotation.z += delta * 1.5
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	reticle.scale = Vector3.ONE * pulse
