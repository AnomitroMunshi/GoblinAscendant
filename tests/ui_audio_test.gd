extends Node
## Audio self-test (UI & Audio agent). Run:
##   "$G" --headless --path . res://tests/ui_audio_test.tscn
## Generates every procedural sound synchronously, checks each stream is
## non-empty, reports per-id timings, and exercises the playback API.

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	Audio.generate_all_sync()
	var total := (Time.get_ticks_usec() - t0) / 1000.0
	var sfx_ms := 0.0
	for id: StringName in Audio.get_sound_ids():
		var arr: Array = Audio.get_variants(id)
		if arr.is_empty():
			_fail("no stream for %s" % id)
			continue
		for s: AudioStreamWAV in arr:
			if s == null or s.data.size() < 200:
				_fail("empty stream for %s" % id)
		var w: AudioStreamWAV = arr[0]
		var secs := w.data.size() / 2.0 / w.mix_rate
		var tt := Time.get_ticks_usec()
		var raw: Array = Audio._generate_one(id)
		var ms := (Time.get_ticks_usec() - tt) / 1000.0
		if (raw[0] as Array).is_empty():
			_fail("regeneration empty for %s" % id)
		if AudioSynth.SFX.has(id):
			sfx_ms += ms
		print("  %-16s variants=%d len=%.2fs loop=%s gen=%.1fms" % [id, arr.size(), secs, w.loop_mode != AudioStreamWAV.LOOP_DISABLED, ms])
	print("AUDIO: wait for background generation %.0f ms (thread wall %.0f ms); one-shots regenerate in %.0f ms" % [total, Audio.generation_msec, sfx_ms])
	# Playback API must never error.
	for id: StringName in AudioSynth.SFX:
		Audio.play_sfx(id)
		Audio.play_sfx(id, Vector3(1, 2, 3))
	Audio.play_sfx(&"does_not_exist")
	Audio.play_sfx(&"hit", Vector3.ZERO)
	var parent := Node3D.new()
	add_child(parent)
	for id in [&"river_loop", &"waterfall_loop", &"fire_loop"]:
		var p := Audio.create_loop(id, parent)
		if p == null:
			_fail("create_loop returned null for %s" % id)
	if Audio.create_loop(&"bogus", parent) != null:
		_fail("bogus loop should be null")
	parent.queue_free()
	Audio.play_music(&"explore")
	Audio.play_music(&"boss")
	Audio.play_music(&"title")
	Audio.play_music(&"none")
	Audio.play_music(&"explore")
	if Audio.get_music_track() != &"explore":
		_fail("music track not explore")
	Settings.set_value(&"music_volume", 0.3)
	Settings.set_value(&"music_volume", 0.55)
	for i in 30:
		await get_tree().process_frame
	print("AUDIO TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("AUDIO TEST: " + msg)
