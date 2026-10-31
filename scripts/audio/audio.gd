extends Node
## Audio service. OWNER: UI & Audio agent.
## Every call is safe when a sound is missing or not generated yet: it skips.
## All sounds are synthesized procedurally (AudioSynth) on a worker thread at
## startup and cached as 16-bit mono AudioStreamWAV at 22050 Hz.
##
## SFX ids: footstep, jump, land, swing_light, swing_heavy, hit, hit_heavy,
##   block, dodge, player_hurt, death, wolf_growl, wolf_howl, enemy_warn,
##   ogre_roar, ogre_slam, pickup, essence, level_up, quest_complete,
##   ui_click, ui_open, dash, stone_guard, flame, evolve, splash
##   (+ bird_chirp, used by the forest ambience)
## Loop ids (spatial): river_loop, waterfall_loop, fire_loop (+ forest_ambience, 2D bed)
## Music: &"explore", &"boss", &"title", &"none"
##
## Buses (created in code): Master -> Music, SFX, Ambience. Volumes follow
## Settings (*_volume) and update on Settings.changed.
##
## Spatial one-shots use a pool of AudioStreamPlayer3D owned by this autoload
## (not by the scene), so scene reloads never free them; the pools are also
## validated/rebuilt lazily on every use.

signal sounds_ready

const SR := AudioSynth.SR
const POOL_3D := 16
const POOL_2D := 8
const MAX_DISTANCE := 40.0
const MUSIC_FADE := 2.0
const BUS_KEYS := {&"Music": &"music_volume", &"SFX": &"sfx_volume", &"Ambience": &"ambience_volume"}
const AMBIENT_IDS := [&"bird_chirp", &"forest_ambience", &"river_loop", &"waterfall_loop", &"fire_loop", &"marsh_loop"]
const MUSIC_STREAMS := {&"explore": &"music_explore", &"title": &"music_explore", &"boss": &"music_boss"}

var _streams: Dictionary = {}       # StringName -> Array[AudioStreamWAV]
var _ready_all := false
var _thread: Thread
var _gen_start_usec := 0
var generation_msec := 0.0           # wall time of the full background generation
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d_root: Node3D
var _next3d := 0
var _next2d := 0
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_track: StringName = &"none"
var _music_tweens: Array = [null, null]
var _ambience: AudioStreamPlayer
var _ambience_wanted := false
var _bird_timer := 5.0
var _pending_loops: Array = []       # [AudioStreamPlayer3D, StringName]
var _results: Array = []             # [id, datas, loop] produced by the worker thread
var _results_mutex := Mutex.new()
var _thread_done := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_setup_buses()
	_build_players()
	Settings.changed.connect(_on_setting_changed)
	Events.game_started.connect(_on_game_started)
	Events.level_up.connect(func(_l: int) -> void: play_sfx(&"level_up", null, -2.0, 0.0))
	Events.quest_completed.connect(func(_q: StringName) -> void: play_sfx(&"quest_complete", null, -2.0, 0.0))
	Events.ability_unlocked.connect(func(_a: StringName) -> void: play_sfx(&"essence", null, -1.0, 0.0))
	Events.evolution_changed.connect(func(_s: StringName) -> void: play_sfx(&"evolve", null, 0.0, 0.0))
	Events.boss_engaged.connect(func(_b: Node3D) -> void: play_music(&"boss"))
	Events.boss_disengaged.connect(func(_b: Node3D) -> void: play_music(&"explore"))
	Events.boss_defeated.connect(func(_b: Node3D) -> void: play_music(&"explore"))
	start_generation()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	# Stop and detach everything so the AudioServer drops its playbacks before
	# the ObjectDB is torn down (otherwise streams/playbacks leak at exit).
	for n in find_children("*", "", true, false):
		if n is AudioStreamPlayer or n is AudioStreamPlayer3D:
			n.stop()
			n.stream = null
	_streams.clear()


# ================================================================ public API
## Play a one-shot. `position` = Vector3 (or Node3D) for 3D spatial playback, null for 2D.
func play_sfx(id: StringName, position: Variant = null, volume_db: float = 0.0, pitch_variation: float = 0.08) -> void:
	var s := get_stream(id)
	if s == null:
		return
	var bus := &"Ambience" if AMBIENT_IDS.has(id) else &"SFX"
	var pitch := 1.0 + _rng.randf_range(-pitch_variation, pitch_variation) if pitch_variation > 0.0 else 1.0
	var pos: Variant = position
	if pos is Node3D:
		pos = (pos as Node3D).global_position if is_instance_valid(pos) and (pos as Node3D).is_inside_tree() else null
	if pos is Vector3:
		var p3 := _get_3d()
		if p3 == null:
			return
		p3.position = pos
		p3.stream = s
		p3.bus = bus
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.play()
	else:
		var p2 := _get_2d()
		if p2 == null:
			return
		p2.stream = s
		p2.bus = bus
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.play()


## Create a looping spatial emitter parented to `parent` (river, waterfall, campfire).
## Returns the AudioStreamPlayer3D or null if unavailable. If the sound is still
## being generated the emitter is returned anyway and starts once it is ready.
func create_loop(id: StringName, parent: Node3D, unit_size: float = 10.0, volume_db: float = 0.0) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		return null
	if not (AudioSynth.LOOPS.has(id) or AudioSynth.SFX.has(id)):
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "Loop_%s" % id
	p.bus = &"Ambience" if AMBIENT_IDS.has(id) else &"SFX"
	p.unit_size = unit_size
	p.volume_db = volume_db
	p.max_distance = clampf(unit_size * 6.0, 25.0, 90.0)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 0.8
	var s := get_stream(id)
	if s:
		p.stream = s
		p.autoplay = true
	else:
		_pending_loops.append([p, id])
	parent.add_child(p)
	return p


func play_music(track: StringName) -> void:
	if track == _music_track and (track == &"none" or _current_music_playing()):
		return
	_music_track = track
	if track == &"none" or not MUSIC_STREAMS.has(track):
		_fade_out_music()
		return
	var s := get_stream(MUSIC_STREAMS[track])
	if s == null:
		return  # started from _install() once generated
	var cur := _music[_music_idx]
	if cur.playing and cur.stream == s:
		return
	_fade_out_music()
	_music_idx = 1 - _music_idx
	var p := _music[_music_idx]
	p.stream = s
	p.volume_db = -40.0
	p.play()
	_tween_volume(_music_idx, 0.0, MUSIC_FADE * 0.75)


## Starts/stops the 2D forest ambience bed (+ procedural bird chirps).
func set_ambience(enabled: bool) -> void:
	_ambience_wanted = enabled
	if not enabled:
		_ambience.stop()
		return
	var s := get_stream(&"forest_ambience")
	if s and not _ambience.playing:
		_ambience.stream = s
		_ambience.play(_rng.randf() * 4.0)


## Cached stream for an id (random variant), or null when unknown / not generated yet.
func get_stream(id: StringName) -> AudioStream:
	var arr: Array = _streams.get(id, [])
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)] if arr.size() > 1 else arr[0]


func get_variants(id: StringName) -> Array:
	return _streams.get(id, [])


func is_ready() -> bool:
	return _ready_all


## Every id this service can produce (one-shots, loops, music streams).
func get_sound_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in AudioSynth.SFX:
		out.append(k)
	for k: StringName in AudioSynth.LOOPS:
		out.append(k)
	for k: StringName in AudioSynth.MUSIC:
		out.append(k)
	return out


func get_music_track() -> StringName:
	return _music_track


## Kicks off background generation (no-op if already running/done).
func start_generation() -> void:
	if _ready_all or (_thread and _thread.is_started()):
		return
	_gen_start_usec = Time.get_ticks_usec()
	_thread = Thread.new()
	_thread.start(_generate_thread, Thread.PRIORITY_LOW)


## Synchronously generates everything still missing (tests / tools).
## Returns {id: msec} timings.
func generate_all_sync() -> Dictionary:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null
	_drain_results()
	var timings := {}
	for id: StringName in get_sound_ids():
		if _streams.has(id):
			continue
		var t0 := Time.get_ticks_usec()
		var data := _generate_one(id)
		_install(id, data[0], data[1])
		timings[id] = (Time.get_ticks_usec() - t0) / 1000.0
	_finish()
	return timings


# ================================================================ generation
## Returns [Array[PackedByteArray], is_loop].
static func _generate_one(id: StringName) -> Array:
	var datas: Array = []
	if AudioSynth.SFX.has(id):
		for v in int(AudioSynth.SFX[id]):
			datas.append(AudioSynth.to_pcm16(AudioSynth.make_sfx(id, v)))
		return [datas, false]
	if AudioSynth.LOOPS.has(id):
		datas.append(AudioSynth.to_pcm16(AudioSynth.make_loop_sound(id), 0.8))
		return [datas, true]
	if AudioSynth.MUSIC.has(id):
		datas.append(AudioSynth.to_pcm16(AudioSynth.make_music(id), 0.8))
		return [datas, true]
	return [datas, false]


func _generate_thread() -> void:
	var ids: Array[StringName] = []
	for k: StringName in AudioSynth.SFX:
		ids.append(k)
	ids.append_array([&"forest_ambience", &"music_explore", &"river_loop", &"waterfall_loop", &"fire_loop", &"marsh_loop", &"music_boss"])
	for id in ids:
		var data := _generate_one(id)
		_results_mutex.lock()
		_results.append([id, data[0], data[1]])
		_results_mutex.unlock()
	_results_mutex.lock()
	_thread_done = true
	_results_mutex.unlock()


## Installs whatever the worker produced so far (main thread).
func _drain_results() -> void:
	_results_mutex.lock()
	var batch := _results
	_results = []
	var done := _thread_done
	_results_mutex.unlock()
	for r: Array in batch:
		_install(r[0], r[1], r[2])
	if done and not _ready_all:
		if _thread and _thread.is_started():
			_thread.wait_to_finish()
		_thread = null
		_finish()


func _finish() -> void:
	if _ready_all:
		return
	_ready_all = true
	generation_msec = (Time.get_ticks_usec() - _gen_start_usec) / 1000.0
	sounds_ready.emit()


func _install(id: StringName, datas: Array, loop: bool) -> void:
	if _streams.has(id) or datas.is_empty():
		return
	var arr: Array = []
	for d: PackedByteArray in datas:
		if d.is_empty():
			continue
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = SR
		w.stereo = false
		w.data = d
		if loop:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = d.size() / 2
		arr.append(w)
	if arr.is_empty():
		return
	_streams[id] = arr
	# Late starts for things requested before generation finished.
	for i in range(_pending_loops.size() - 1, -1, -1):
		var entry: Array = _pending_loops[i]
		var p: Variant = entry[0]
		if not is_instance_valid(p):
			_pending_loops.remove_at(i)
			continue
		if entry[1] != id:
			continue
		_pending_loops.remove_at(i)
		var pl := p as AudioStreamPlayer3D
		pl.stream = arr[0]
		if pl.is_inside_tree():
			pl.play(_rng.randf() * 3.0)
		else:
			pl.autoplay = true
	if id == &"forest_ambience" and _ambience_wanted:
		set_ambience(true)
	if MUSIC_STREAMS.has(_music_track) and MUSIC_STREAMS[_music_track] == id:
		var t := _music_track
		_music_track = &"none"
		play_music(t)


# ================================================================ buses / players
func _setup_buses() -> void:
	for bus_name: StringName in BUS_KEYS:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")
			if bus_name == &"Music":
				var rev := AudioEffectReverb.new()
				rev.room_size = 0.6
				rev.damping = 0.6
				rev.wet = 0.22
				rev.dry = 0.9
				AudioServer.add_bus_effect(idx, rev)
	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus_volume(&"Master", float(Settings.get_value(&"master_volume", 0.8)))
	for bus_name: StringName in BUS_KEYS:
		_set_bus_volume(bus_name, float(Settings.get_value(BUS_KEYS[bus_name], 0.8)))


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _on_setting_changed(key: StringName) -> void:
	if String(key).ends_with("_volume"):
		_apply_volumes()


func _build_players() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.name = "Music%d" % i
		m.bus = &"Music"
		m.volume_db = -60.0
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.bus = &"Ambience"
	_ambience.volume_db = -3.0
	add_child(_ambience)
	_validate_pools()


## (Re)creates pool players that were freed for any reason.
func _validate_pools() -> void:
	if not is_instance_valid(_pool3d_root):
		_pool3d_root = Node3D.new()
		_pool3d_root.name = "Spatial"
		# Gameplay sounds pause with the game; UI / music keep running.
		_pool3d_root.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(_pool3d_root)
		_pool3d.clear()
	for i in range(_pool3d.size() - 1, -1, -1):
		if not is_instance_valid(_pool3d[i]):
			_pool3d.remove_at(i)
	while _pool3d.size() < POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = MAX_DISTANCE
		p.unit_size = 8.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_pool3d_root.add_child(p)
		_pool3d.append(p)
	for i in range(_pool2d.size() - 1, -1, -1):
		if not is_instance_valid(_pool2d[i]):
			_pool2d.remove_at(i)
	while _pool2d.size() < POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)


func _get_3d() -> AudioStreamPlayer3D:
	if not is_inside_tree():
		return null
	if not is_instance_valid(_pool3d_root) or _pool3d.size() < POOL_3D or not is_instance_valid(_pool3d[_next3d % _pool3d.size()]):
		_validate_pools()
	for k in _pool3d.size():
		var i := (_next3d + k) % _pool3d.size()
		if not _pool3d[i].playing:
			_next3d = i + 1
			return _pool3d[i]
	_next3d = (_next3d + 1) % _pool3d.size()
	return _pool3d[_next3d]


func _get_2d() -> AudioStreamPlayer:
	if not is_inside_tree():
		return null
	if _pool2d.size() < POOL_2D or not is_instance_valid(_pool2d[_next2d % _pool2d.size()]):
		_validate_pools()
	for k in _pool2d.size():
		var i := (_next2d + k) % _pool2d.size()
		if not _pool2d[i].playing:
			_next2d = i + 1
			return _pool2d[i]
	_next2d = (_next2d + 1) % _pool2d.size()
	return _pool2d[_next2d]


# ================================================================ music helpers
func _current_music_playing() -> bool:
	return _music[_music_idx].playing


func _fade_out_music() -> void:
	var p := _music[_music_idx]
	if p.playing:
		_tween_volume(_music_idx, -60.0, MUSIC_FADE, true)


func _tween_volume(idx: int, target_db: float, seconds: float, stop_after: bool = false) -> void:
	var old: Variant = _music_tweens[idx]
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var p := _music[idx]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target_db, seconds).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)
	_music_tweens[idx] = tw


# ================================================================ game hooks
func _on_game_started() -> void:
	_validate_pools()
	set_ambience(true)
	play_music(&"title" if GameState.show_title else &"explore")


func _process(delta: float) -> void:
	if not _ready_all:
		_drain_results()
	if not (_ambience_wanted and _ambience.playing):
		return
	_bird_timer -= delta
	if _bird_timer > 0.0:
		return
	_bird_timer = _rng.randf_range(3.0, 9.0)
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam and is_instance_valid(cam):
		var a := _rng.randf() * TAU
		var off := Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(10.0, 22.0) + Vector3.UP * _rng.randf_range(4.0, 9.0)
		play_sfx(&"bird_chirp", cam.global_position + off, _rng.randf_range(-10.0, -4.0), 0.12)
	else:
		play_sfx(&"bird_chirp", null, -14.0, 0.12)
