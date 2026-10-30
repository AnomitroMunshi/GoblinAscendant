class_name AbilityController
extends Node
## Executes equipped essence abilities for the player.
## OWNER: Progression & Quest agent.
## The Player creates one as a child and calls setup(self), then
## try_activate(slot) on ability_1/2/3. UI reads cooldowns via
## GameState.ability_controller.
##
## Only the documented Player API is used, always behind has_method / property
## guards: is_busy, is_dead, spend_energy, begin_dash, get_facing,
## get_cast_origin, play_cast_animation, damage_taken_multiplier.

const REASON_INVALID := "Invalid slot"
const REASON_EMPTY := "No ability in this slot"
const REASON_LOCKED := "Ability locked"
const REASON_UNAVAILABLE := "Can't use abilities now"
const REASON_BUSY := "Busy"
const REASON_COOLDOWN := "On cooldown"
const REASON_ENERGY := "Not enough energy"

const FLAME_WINDUP := 0.12
const FLAME_ACTIVE := 0.25

var player: Node3D

var _cooldowns: Dictionary = {}      # ability id -> seconds remaining
var _guard_time := 0.0               # > 0 while Stone Guard is active
var _guard_player: Node3D            # player the multiplier was applied to
var _guard_base := 1.0               # multiplier before Stone Guard
var _guard_applied := 1.0            # multiplier we set
var _guard_shell: Node3D
var _flame_hitbox: Hitbox


func setup(p_player: Node3D) -> void:
	player = p_player
	GameState.ability_controller = self
	if not Events.player_died.is_connected(_on_player_died):
		Events.player_died.connect(_on_player_died)
		Events.player_respawned.connect(_on_player_respawned)


func get_ability_id(slot: int) -> StringName: return Progression.get_equipped(slot)


func get_ability_data(slot: int) -> AbilityData:
	return AbilityLibrary.get_ability(get_ability_id(slot))


func get_cooldown_remaining(slot: int) -> float:
	return float(_cooldowns.get(get_ability_id(slot), 0.0))


func get_cooldown_total(slot: int) -> float:
	var a := get_ability_data(slot)
	return a.cooldown if a else 0.0


func get_energy_cost(slot: int) -> float:
	var a := get_ability_data(slot)
	return a.energy_cost if a else 0.0


## 0..1 fraction of the cooldown still remaining (for radial UI).
func get_cooldown_ratio(slot: int) -> float:
	var total := get_cooldown_total(slot)
	return clampf(get_cooldown_remaining(slot) / total, 0.0, 1.0) if total > 0.0 else 0.0


func is_stone_guard_active() -> bool:
	return _guard_time > 0.0


func try_activate(slot: int) -> bool:
	if slot < 0 or slot >= Progression.SLOT_COUNT:
		return _fail(slot, REASON_INVALID)
	var id := get_ability_id(slot)
	if id == &"":
		return _fail(slot, REASON_EMPTY)
	var data := AbilityLibrary.get_ability(id)
	if data == null or not data.slottable or not Progression.has_ability(id):
		return _fail(slot, REASON_LOCKED)
	if not is_instance_valid(player) or not player.is_inside_tree() \
			or (player.has_method("is_dead") and player.call("is_dead")):
		return _fail(slot, REASON_UNAVAILABLE)
	if player.has_method("is_busy") and player.call("is_busy"):
		return _fail(slot, REASON_BUSY)
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		return _fail(slot, REASON_COOLDOWN)
	if data.energy_cost > 0.0:
		if not player.has_method("spend_energy") or not player.call("spend_energy", data.energy_cost):
			return _fail(slot, REASON_ENERGY)
	match id:
		AbilityLibrary.WOLF_DASH: _do_wolf_dash()
		AbilityLibrary.STONE_GUARD: _do_stone_guard()
		AbilityLibrary.FLAME_BURST: _do_flame_burst()
	_cooldowns[id] = data.cooldown
	if data.sfx != &"":
		Audio.play_sfx(data.sfx, player.global_position)
	Events.ability_used.emit(slot, id)
	return true


func _fail(slot: int, reason: String) -> bool:
	Events.ability_failed.emit(slot, reason)
	return false


func _process(delta: float) -> void:
	for id: StringName in _cooldowns.keys():
		var t := float(_cooldowns[id]) - delta
		if t <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = t
	if _guard_time > 0.0:
		_guard_time -= delta
		if _guard_time <= 0.0:
			_end_stone_guard()


func _exit_tree() -> void:
	_end_stone_guard()


# ---------------------------------------------------------------- helpers
func _facing() -> Vector3:
	var f := Vector3.ZERO
	if player.has_method("get_facing"):
		f = player.call("get_facing")
	if f.length_squared() < 0.001:
		f = -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.001 else Vector3.FORWARD


func _cast_origin() -> Vector3:
	if player.has_method("get_cast_origin"):
		return player.call("get_cast_origin")
	return player.global_position + Vector3.UP * 1.0 + _facing() * 0.6


func _fx_parent() -> Node:
	var p := player.get_parent()
	return p if p else player


# ---------------------------------------------------------------- Wolf Dash
func _do_wolf_dash() -> void:
	var dir := _facing()
	if player.has_method("begin_dash"):
		player.call("begin_dash", dir, AbilityLibrary.DASH_SPEED, AbilityLibrary.DASH_DURATION, true)
	AbilityEffects.dash_streak(_fx_parent(), player.global_position, dir,
		AbilityLibrary.DASH_SPEED * AbilityLibrary.DASH_DURATION)


# ---------------------------------------------------------------- Stone Guard
func _do_stone_guard() -> void:
	_end_stone_guard()  # never stack
	if player.has_method("play_cast_animation"):
		player.call("play_cast_animation")
	if not (&"damage_taken_multiplier" in player):
		return
	_guard_player = player
	_guard_base = float(player.get(&"damage_taken_multiplier"))
	_guard_applied = _guard_base * AbilityLibrary.STONE_GUARD_MULTIPLIER
	player.set(&"damage_taken_multiplier", _guard_applied)
	_guard_time = AbilityLibrary.STONE_GUARD_DURATION
	_guard_shell = AbilityEffects.stone_shell(player)


## Restores the multiplier safely: if something else changed it meanwhile,
## only our factor is removed.
func _end_stone_guard() -> void:
	_guard_time = 0.0
	if is_instance_valid(_guard_player) and &"damage_taken_multiplier" in _guard_player:
		var cur := float(_guard_player.get(&"damage_taken_multiplier"))
		if is_equal_approx(cur, _guard_applied):
			_guard_player.set(&"damage_taken_multiplier", _guard_base)
		else:
			_guard_player.set(&"damage_taken_multiplier", cur / AbilityLibrary.STONE_GUARD_MULTIPLIER)
	_guard_player = null
	if is_instance_valid(_guard_shell):
		AbilityEffects.dissolve_shell(_guard_shell)
	_guard_shell = null


func _on_player_died() -> void:
	if _guard_player != null:
		_end_stone_guard()
	if _flame_hitbox and is_instance_valid(_flame_hitbox):
		_flame_hitbox.deactivate()


func _on_player_respawned() -> void:
	if _guard_player != null:
		_end_stone_guard()


# ---------------------------------------------------------------- Flame Burst
func _do_flame_burst() -> void:
	if player.has_method("play_cast_animation"):
		player.call("play_cast_animation")
	AbilityEffects.flame_charge(_fx_parent(), _cast_origin(), FLAME_WINDUP)
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(FLAME_WINDUP, false).timeout
	if not is_instance_valid(player) or not player.is_inside_tree() \
			or (player.has_method("is_dead") and player.call("is_dead")):
		return
	var dir := _facing()
	var origin := _cast_origin()
	var hb := _ensure_flame_hitbox()
	hb.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), origin)
	var info := DamageInfo.make(Progression.attack_power() * AbilityLibrary.FLAME_DAMAGE_MULT, player, 4.0, 0.6)
	info.element = &"fire"
	info.attack_id = &"flame_burst"
	hb.activate(info, FLAME_ACTIVE)
	AbilityEffects.flame_cone(_fx_parent(), origin, dir, AbilityLibrary.FLAME_RANGE, AbilityLibrary.FLAME_WIDTH)


func _ensure_flame_hitbox() -> Hitbox:
	if _flame_hitbox and is_instance_valid(_flame_hitbox) and _flame_hitbox.get_parent() == player:
		return _flame_hitbox
	_flame_hitbox = Hitbox.new()
	_flame_hitbox.name = "FlameBurstHitbox"
	_flame_hitbox.top_level = true
	player.add_child(_flame_hitbox)
	var box := BoxShape3D.new()
	box.size = Vector3(AbilityLibrary.FLAME_WIDTH, 2.2, AbilityLibrary.FLAME_RANGE)
	_flame_hitbox.setup(player, box, Vector3(0, 0, -AbilityLibrary.FLAME_RANGE * 0.5))
	return _flame_hitbox

