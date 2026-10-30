extends Node
## Hit-stop and camera shake helpers. Lead-owned.
## Hit-stop scales Engine.time_scale briefly, so every timer, tween,
## animation and physics step slows uniformly and nothing desyncs.
## The restore is measured in real time and is safe to call repeatedly.

const MAX_HITSTOP := 0.15

var _restore_at_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func hit_stop(duration: float = 0.06, time_scale: float = 0.05) -> void:
	duration = clampf(duration, 0.0, MAX_HITSTOP)
	if duration <= 0.0:
		return
	Engine.time_scale = minf(Engine.time_scale, time_scale)
	_restore_at_msec = maxi(_restore_at_msec, Time.get_ticks_msec() + int(duration * 1000.0))


func shake(strength: float) -> void:
	var mult := float(Settings.get_value(&"camera_shake", 1.0))
	if mult > 0.0 and strength > 0.0:
		Events.camera_shake.emit(strength * mult)


func reset() -> void:
	_restore_at_msec = 0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if _restore_at_msec != 0 and Time.get_ticks_msec() >= _restore_at_msec:
		_restore_at_msec = 0
		Engine.time_scale = 1.0
