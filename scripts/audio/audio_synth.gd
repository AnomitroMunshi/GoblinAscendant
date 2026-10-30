class_name AudioSynth
extends RefCounted
## Procedural sound synthesis (no audio files). OWNER: UI & Audio agent.
## All functions are static and thread-safe: they only build packed arrays,
## so the Audio autoload can run them on a worker thread. Output is mono
## float PCM at SR Hz; `to_pcm16()` converts to AudioStreamWAV 16-bit data.

const SR := 22050

enum Wave { SINE, TRI, SAW, SQUARE }

## id -> variant count (one-shots).
const SFX := {
	&"footstep": 4, &"jump": 1, &"land": 1, &"swing_light": 3, &"swing_heavy": 2,
	&"hit": 3, &"hit_heavy": 2, &"block": 2, &"dodge": 2, &"player_hurt": 3,
	&"death": 1, &"wolf_growl": 2, &"wolf_howl": 1, &"enemy_warn": 1,
	&"ogre_roar": 1, &"ogre_slam": 1, &"pickup": 1, &"essence": 1,
	&"level_up": 1, &"quest_complete": 1, &"ui_click": 1, &"ui_open": 1,
	&"dash": 1, &"stone_guard": 1, &"flame": 1, &"evolve": 1, &"splash": 2,
	&"bird_chirp": 4,
}
## Seamless loops.
const LOOPS := [&"forest_ambience", &"river_loop", &"waterfall_loop", &"fire_loop"]
## Seamless music loops.
const MUSIC := [&"music_explore", &"music_boss"]


# ------------------------------------------------------------------ primitives
static func buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(1, int(seconds * SR)))
	b.fill(0.0)
	return b


static func midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Filtered noise: 2-pole lowpass with cutoff gliding f0 -> f1 (exponential),
## optional one-pole highpass, attack (s) then exponential decay (time const s).
static func noise(seconds: float, f0: float, f1: float, attack: float, decay: float, hp: float = 0.0, seed_v: int = 1, amp: float = 1.0) -> PackedFloat32Array:
	var b := buf(seconds)
	var n := b.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var y1 := 0.0
	var y2 := 0.0
	var hp_y := 0.0
	var hp_x := 0.0
	var hp_a := exp(-TAU * hp / SR) if hp > 0.0 else 0.0
	var att := maxi(1, int(attack * SR))
	var k := exp(-1.0 / maxf(0.001, decay * SR))
	var fc := f0
	var fr := pow(f1 / f0, 1.0 / n)
	var a := 1.0 - exp(-TAU * fc / SR)
	var e := 0.0
	var fade := mini(n, int(0.004 * SR))
	for i in n:
		if (i & 15) == 0:
			fc = f0 * pow(f1 / f0, float(i) / n)
			a = 1.0 - exp(-TAU * minf(fc, SR * 0.45) / SR)
		var x := rng.randf() * 2.0 - 1.0
		y1 += a * (x - y1)
		y2 += a * (y1 - y2)
		var v := y2
		if hp > 0.0:
			var hy := hp_a * (hp_y + v - hp_x)
			hp_x = v
			hp_y = hy
			v = hy
		if i < att:
			e = float(i) / att
		else:
			e *= k
		if i > n - fade:
			v *= float(n - i) / fade
		b[i] = v * e * amp
	return b


## Oscillator with exponential pitch glide f0 -> f1, optional vibrato,
## attack (s) then exponential decay (time constant s; <=0 means sustain).
static func tone(seconds: float, f0: float, f1: float, wave: int = Wave.SINE, attack: float = 0.005, decay: float = 0.2, amp: float = 1.0, vib_hz: float = 0.0, vib_depth: float = 0.0) -> PackedFloat32Array:
	var b := buf(seconds)
	var n := b.size()
	var f := f0
	var r := pow(f1 / f0, 1.0 / n)
	var ph := 0.0
	var vph := 0.0
	var att := maxi(1, int(attack * SR))
	var k := exp(-1.0 / maxf(0.001, decay * SR)) if decay > 0.0 else 1.0
	var e := 0.0
	var fade := mini(n, int(0.006 * SR))
	for i in n:
		var ff := f
		if vib_depth > 0.0:
			vph += TAU * vib_hz / SR
			ff *= 1.0 + vib_depth * sin(vph)
		ph += ff / SR
		ph -= floorf(ph)
		var v := 0.0
		match wave:
			Wave.SINE:
				v = sin(TAU * ph)
			Wave.TRI:
				v = 4.0 * absf(ph - 0.5) - 1.0
			Wave.SAW:
				v = 2.0 * ph - 1.0
			_:
				v = clampf(sin(TAU * ph) * 3.0, -1.0, 1.0)
		f *= r
		if i < att:
			e = float(i) / att
		else:
			e *= k
		if i > n - fade:
			v *= float(n - i) / fade
		b[i] = v * e * amp
	return b


## Inharmonic/harmonic bell: partial ratios with own amplitudes and decays.
static func bell(freq: float, seconds: float, ratios: Array, amps: Array, decays: Array, amp: float = 1.0) -> PackedFloat32Array:
	var b := buf(seconds)
	var n := b.size()
	var att := int(0.002 * SR)
	for p in ratios.size():
		var w := TAU * freq * float(ratios[p]) / SR
		if w >= PI:
			continue
		var k := exp(-1.0 / (float(decays[p]) * SR))
		var e := float(amps[p]) * amp
		# recursive sine oscillator: y[n] = 2cos(w) y[n-1] - y[n-2]
		var c := 2.0 * cos(w)
		var y1 := sin(-w)
		var y2 := sin(-2.0 * w)
		for i in n:
			var y0 := c * y1 - y2
			y2 = y1
			y1 = y0
			var v := y0 * e
			if i < att:
				v *= float(i) / att
			b[i] += v
			e *= k
			if e < 0.0005:
				break
	return b


## Karplus-Strong plucked string.
static func pluck(freq: float, seconds: float, damping: float = 0.996, brightness: float = 0.5, seed_v: int = 7) -> PackedFloat32Array:
	var b := buf(seconds)
	var n := b.size()
	var period := maxi(2, int(SR / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var y := 0.0
	for j in period:
		y += brightness * ((rng.randf() * 2.0 - 1.0) - y)
		ring[j] = y
	for i in n:
		var j := i % period
		var nx := j + 1 if j + 1 < period else 0
		var v := ring[j]
		b[i] = v
		ring[j] = damping * 0.5 * (v + ring[nx])
	var fade := mini(n, int(0.02 * SR))
	for i in fade:
		b[n - 1 - i] *= float(i) / fade
	return b


## Sustained pad voice: detuned triangles with attack/release envelope.
static func pad(freq: float, hold: float, attack: float, release: float, amp: float = 1.0) -> PackedFloat32Array:
	var b := buf(hold + release)
	var n := b.size()
	var hold_n := int(hold * SR)
	var att := maxi(1, int(attack * SR))
	var rel := maxi(1, n - hold_n)
	var p1 := 0.0
	var p2 := 0.37
	var d1 := freq * 1.0025 / SR
	var d2 := freq * 0.9975 / SR
	for i in n:
		p1 += d1
		p1 -= floorf(p1)
		p2 += d2
		p2 -= floorf(p2)
		var v := (4.0 * absf(p1 - 0.5) - 1.0) + (4.0 * absf(p2 - 0.5) - 1.0)
		var e := 1.0
		if i < att:
			e = float(i) / att
		if i > hold_n:
			e *= 1.0 - float(i - hold_n) / rel
		b[i] = v * 0.5 * e * amp
	return b


static func lowpass(b: PackedFloat32Array, fc: float, passes: int = 1) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / SR)
	for _p in passes:
		var y := 0.0
		for i in b.size():
			y += a * (b[i] - y)
			b[i] = y
	return b


static func highpass(b: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := exp(-TAU * fc / SR)
	var y := 0.0
	var px := 0.0
	for i in b.size():
		var x := b[i]
		y = a * (y + x - px)
		px = x
		b[i] = y
	return b


## Adds src into dst at offset (seconds); grows dst when needed.
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float = 1.0, offset: float = 0.0) -> PackedFloat32Array:
	var o := int(offset * SR)
	var need := o + src.size()
	if need > dst.size():
		var old := dst.size()
		dst.resize(need)
		for i in range(old, need):
			dst[i] = 0.0
	for i in src.size():
		dst[o + i] += src[i] * gain
	return dst


## Adds src into a loop buffer at sample offset, wrapping tails to the start.
static func mix_wrap(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, offset_samples: int) -> void:
	var n := dst.size()
	var j := offset_samples % n
	for i in src.size():
		dst[j] += src[i] * gain
		j += 1
		if j >= n:
			j = 0


static func echo(b: PackedFloat32Array, delay: float, feedback: float, wet: float) -> PackedFloat32Array:
	var d := maxi(1, int(delay * SR))
	var out := b.duplicate()
	for i in range(d, b.size()):
		out[i] += out[i - d] * feedback
	for i in b.size():
		b[i] = b[i] * (1.0 - wet) + out[i] * wet
	return b


static func soft_clip(b: PackedFloat32Array, drive: float = 1.5) -> PackedFloat32Array:
	var norm := 1.0 / tanh(drive)
	for i in b.size():
		b[i] = tanh(b[i] * drive) * norm
	return b


## Crossfades the tail into the head so the buffer loops seamlessly.
static func make_loop(b: PackedFloat32Array, xfade: float) -> PackedFloat32Array:
	var xf := int(xfade * SR)
	var l := b.size() - xf
	for i in xf:
		var t := float(i) / xf
		b[i] = b[i] * sqrt(t) + b[l + i] * sqrt(1.0 - t)
	b.resize(l)
	return b


## Float PCM -> 16-bit little-endian bytes, normalised to `peak`.
static func to_pcm16(b: PackedFloat32Array, peak: float = 0.89) -> PackedByteArray:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var g := peak / m
	var out := PackedByteArray()
	out.resize(b.size() * 2)
	for i in b.size():
		out.encode_s16(i * 2, int(clampf(b[i] * g, -1.0, 1.0) * 32767.0))
	return out


# ------------------------------------------------------------------ recipes
## Builds one variant of a one-shot sound. Unknown ids return an empty array.
static func make_sfx(id: StringName, v: int = 0) -> PackedFloat32Array:
	match id:
		&"footstep":
			var b := noise(0.13 + 0.02 * v, 900.0 + 150.0 * v, 160.0, 0.003, 0.035, 60.0, 11 + v)
			mix(b, tone(0.1, 110.0 - 8.0 * v, 55.0, Wave.SINE, 0.002, 0.03), 0.7)
			mix(b, noise(0.07, 3500.0, 1800.0, 0.008, 0.02, 1500.0, 31 + v), 0.12)
			return b
		&"jump":
			var b := noise(0.22, 500.0, 2200.0, 0.03, 0.07, 200.0, 3)
			mix(b, tone(0.12, 230.0, 300.0, Wave.TRI, 0.005, 0.05), 0.15)
			return b
		&"land":
			var b := noise(0.25, 700.0, 120.0, 0.002, 0.06, 40.0, 5)
			mix(b, tone(0.2, 95.0, 45.0, Wave.SINE, 0.002, 0.07), 1.0)
			return b
		&"swing_light":
			return noise(0.24, 700.0, 3200.0 + 400.0 * v, 0.08 + 0.01 * v, 0.06, 300.0, 21 + v)
		&"swing_heavy":
			var b := noise(0.42, 300.0, 1900.0, 0.16, 0.1, 120.0, 25 + v)
			mix(b, tone(0.36, 150.0, 85.0, Wave.TRI, 0.12, 0.1), 0.15)
			return b
		&"hit":
			var b := tone(0.18, 165.0 + 20.0 * v, 55.0, Wave.SINE, 0.001, 0.05)
			mix(b, noise(0.08, 5200.0, 1400.0, 0.0005, 0.014, 800.0, 41 + v), 0.8)
			mix(b, noise(0.2, 900.0, 200.0, 0.001, 0.05, 40.0, 44 + v), 0.5)
			return soft_clip(b, 1.3)
		&"hit_heavy":
			var b := tone(0.36, 125.0, 38.0, Wave.SINE, 0.001, 0.1)
			mix(b, noise(0.12, 4600.0, 900.0, 0.0005, 0.03, 500.0, 51 + v), 0.9)
			mix(b, noise(0.4, 600.0, 110.0, 0.001, 0.12, 30.0, 54 + v), 0.8)
			return soft_clip(b, 2.0)
		&"block":
			var f := 1150.0 + 110.0 * v
			var b := bell(f, 0.45, [1.0, 2.76, 5.4, 8.93], [1.0, 0.6, 0.4, 0.25], [0.32, 0.2, 0.11, 0.06])
			mix(b, noise(0.03, 8000.0, 3000.0, 0.0005, 0.008, 2000.0, 61 + v), 0.8)
			mix(b, tone(0.1, 200.0, 90.0, Wave.SINE, 0.001, 0.03), 0.4)
			return b
		&"dodge":
			var b := noise(0.3, 400.0 + 100.0 * v, 2500.0, 0.05, 0.09, 300.0, 71 + v)
			mix(b, noise(0.12, 300.0, 150.0, 0.002, 0.04, 40.0, 75 + v), 0.3, 0.16)
			return b
		&"player_hurt":
			var b := lowpass(tone(0.26, 215.0 + 18.0 * v, 140.0, Wave.SAW, 0.01, 0.1), 900.0, 2)
			mix(b, noise(0.1, 2000.0, 600.0, 0.002, 0.04, 200.0, 81 + v), 0.3)
			mix(b, tone(0.12, 120.0, 60.0, Wave.SINE, 0.001, 0.04), 0.5)
			return b
		&"death":
			var b := lowpass(tone(1.2, 220.0, 70.0, Wave.SAW, 0.02, 0.45), 700.0, 2)
			mix(b, tone(1.2, 110.0, 40.0, Wave.SINE, 0.01, 0.5), 0.7)
			mix(b, noise(1.0, 400.0, 100.0, 0.05, 0.4, 30.0, 91), 0.3)
			return b
		&"wolf_growl":
			return _growl(0.9, 78.0 + 9.0 * v, 26.0, 650.0, 101 + v)
		&"ogre_roar":
			var b := _growl(1.5, 56.0, 17.0, 900.0, 111)
			mix(b, noise(1.4, 700.0, 250.0, 0.2, 0.6, 60.0, 112), 0.5)
			return soft_clip(b, 1.6)
		&"wolf_howl":
			return _howl()
		&"enemy_warn":
			var b := tone(0.28, 480.0, 980.0, Wave.SQUARE, 0.01, 0.15, 0.5)
			mix(b, tone(0.28, 960.0, 1960.0, Wave.SINE, 0.01, 0.12), 0.25)
			return lowpass(b, 3500.0)
		&"ogre_slam":
			var b := tone(1.0, 72.0, 28.0, Wave.SINE, 0.001, 0.3)
			mix(b, noise(0.9, 1300.0, 80.0, 0.001, 0.25, 20.0, 121), 0.9)
			mix(b, noise(0.15, 4000.0, 900.0, 0.001, 0.04, 400.0, 122), 0.3)
			return soft_clip(b, 2.2)
		&"pickup":
			var b := _chime(880.0, 0.35)
			mix(b, _chime(1318.5, 0.4), 0.9, 0.07)
			return b
		&"essence":
			var b := buf(0.2)
			var notes := [74, 78, 81, 86, 88, 93]
			for i in notes.size():
				mix(b, _chime(midi_hz(notes[i]), 0.8), 0.8, 0.08 * i)
				mix(b, _chime(midi_hz(notes[i]) * 1.004, 0.8), 0.4, 0.08 * i + 0.01)
			mix(b, tone(1.2, 587.3, 587.3, Wave.TRI, 0.25, 0.5), 0.15)
			return echo(b, 0.16, 0.35, 0.35)
		&"level_up":
			var b := buf(0.2)
			var notes := [72, 76, 79, 84]
			for i in notes.size():
				mix(b, _chime(midi_hz(notes[i]), 0.9), 0.9, 0.1 * i)
			mix(b, tone(1.1, midi_hz(88), midi_hz(88), Wave.TRI, 0.02, 0.45), 0.3, 0.4)
			mix(b, tone(1.1, midi_hz(84), midi_hz(84), Wave.TRI, 0.02, 0.45), 0.3, 0.4)
			return echo(b, 0.18, 0.3, 0.3)
		&"quest_complete":
			var b := buf(0.2)
			var notes := [67, 72, 76]
			for i in notes.size():
				mix(b, _chime(midi_hz(notes[i]), 0.6), 0.8, 0.12 * i)
			for m in [79, 84, 88]:
				mix(b, _chime(midi_hz(m), 1.2), 0.6, 0.4)
				mix(b, tone(1.1, midi_hz(m), midi_hz(m), Wave.TRI, 0.05, 0.5), 0.18, 0.4)
			return echo(b, 0.2, 0.3, 0.3)
		&"ui_click":
			var b := tone(0.05, 1800.0, 1400.0, Wave.SINE, 0.0005, 0.012)
			mix(b, noise(0.02, 6000.0, 3000.0, 0.0005, 0.004, 2000.0, 131), 0.3)
			return b
		&"ui_open":
			var b := _chime(659.3, 0.25, 0.12)
			mix(b, _chime(987.8, 0.3, 0.14), 0.7, 0.05)
			return b
		&"dash":
			var b := noise(0.36, 1200.0, 5000.0, 0.02, 0.12, 400.0, 141)
			mix(b, tone(0.3, 300.0, 900.0, Wave.TRI, 0.01, 0.1), 0.15)
			mix(b, noise(0.3, 600.0, 300.0, 0.01, 0.1, 60.0, 142), 0.4)
			return b
		&"stone_guard":
			var b := tone(0.8, 82.0, 60.0, Wave.SINE, 0.01, 0.35)
			mix(b, _grit(0.6, 151), 0.6)
			mix(b, bell(220.0, 0.9, [1.0, 2.4, 3.9], [1.0, 0.5, 0.3], [0.4, 0.25, 0.15]), 0.25)
			return b
		&"flame":
			var b := noise(0.8, 600.0, 2600.0, 0.04, 0.3, 150.0, 161)
			mix(b, _crackles(0.7, 30.0, 162), 0.5)
			mix(b, tone(0.5, 95.0, 50.0, Wave.SINE, 0.01, 0.15), 0.6)
			return b
		&"evolve":
			var b := buf(2.4)
			for f in [146.83, 220.0, 293.66, 440.0]:
				mix(b, tone(2.4, f * 0.75, f, Wave.TRI, 1.3, 0.5), 0.3)
			mix(b, noise(2.0, 300.0, 4000.0, 1.2, 0.3, 200.0, 171), 0.4)
			var notes := [74, 78, 81, 86, 90]
			for i in notes.size():
				mix(b, _chime(midi_hz(notes[i]), 1.0), 0.6, 1.25 + 0.07 * i)
			return echo(b, 0.21, 0.35, 0.3)
		&"splash":
			var b := noise(0.5, 3200.0, 400.0, 0.002, 0.12, 300.0, 181 + v)
			var rng := RandomNumberGenerator.new()
			rng.seed = 183 + v
			for i in 4:
				var f0 := rng.randf_range(500.0, 900.0)
				mix(b, tone(0.06, f0, f0 * 2.2, Wave.SINE, 0.003, 0.02), 0.25, rng.randf_range(0.03, 0.3))
			return b
		&"bird_chirp":
			var b := buf(0.05)
			var rng := RandomNumberGenerator.new()
			rng.seed = 191 + v * 7
			var t := 0.0
			var base := rng.randf_range(2500.0, 3800.0)
			for i in rng.randi_range(2, 5):
				var d := rng.randf_range(0.05, 0.1)
				var f1 := base + rng.randf_range(-900.0, 900.0)
				mix(b, tone(d, base, f1, Wave.SINE, 0.006, d * 0.4), 1.0, t)
				t += d + rng.randf_range(0.02, 0.08)
			return b
	return PackedFloat32Array()


static func _chime(f: float, seconds: float, decay: float = 0.3) -> PackedFloat32Array:
	return bell(f, seconds, [1.0, 2.0, 3.0, 4.2], [1.0, 0.35, 0.12, 0.05], [decay, decay * 0.5, decay * 0.3, decay * 0.2])


static func _growl(seconds: float, f: float, am_hz: float, cutoff: float, seed_v: int) -> PackedFloat32Array:
	var b := buf(seconds)
	var n := b.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := 0.0
	var am := 0.0
	var att := int(0.12 * SR)
	var jitter := 0.0
	for i in n:
		if (i & 63) == 0:
			jitter = rng.randf_range(-0.08, 0.08)
		var t := float(i) / n
		var ff := f * (1.0 + 0.15 * sin(PI * t) + jitter)
		ph += ff / SR
		ph -= floorf(ph)
		am += TAU * am_hz / SR
		var v := (2.0 * ph - 1.0) * (0.55 + 0.45 * sin(am))
		v += (rng.randf() * 2.0 - 1.0) * 0.35 * (0.5 + 0.5 * sin(am))
		var e := minf(1.0, float(i) / att) * (1.0 - t) * (1.0 - t * 0.3)
		b[i] = v * e
	return lowpass(b, cutoff, 2)


static func _howl() -> PackedFloat32Array:
	var seconds := 1.9
	var b := buf(seconds)
	var n := b.size()
	var ph := 0.0
	var vph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var y := 0.0
	for i in n:
		var t := float(i) / SR
		var f := 0.0
		if t < 0.35:
			f = lerpf(360.0, 560.0, smoothstep(0.0, 0.35, t))
		elif t < 1.35:
			f = 560.0 + 10.0 * (t - 0.35)
		else:
			f = lerpf(570.0, 410.0, smoothstep(1.35, seconds, t))
		vph += TAU * 5.5 / SR
		f *= 1.0 + 0.012 * sin(vph) * minf(1.0, t * 2.0)
		ph += f / SR
		ph -= floorf(ph)
		var v := sin(TAU * ph) + 0.3 * sin(2.0 * TAU * ph) + 0.1 * sin(3.0 * TAU * ph)
		y += 0.2 * ((rng.randf() * 2.0 - 1.0) - y)
		v += y * 0.4
		var e := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(seconds - 0.5, seconds, t))
		b[i] = v * e
	return echo(b, 0.23, 0.35, 0.35)


## Gritty rock crunch: dense random clicks through a lowpass.
static func _grit(seconds: float, seed_v: int) -> PackedFloat32Array:
	var b := noise(seconds, 900.0, 200.0, 0.005, seconds * 0.3, 60.0, seed_v)
	mix(b, _crackles(seconds, 60.0, seed_v + 1), 0.6)
	return b


## Random short crackle impulses (density per second), fading over the length.
static func _crackles(seconds: float, density: float, seed_v: int, fade_out: bool = true) -> PackedFloat32Array:
	var b := buf(seconds)
	var n := b.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var count := int(seconds * density)
	for c in count:
		var start := rng.randi_range(0, n - 1)
		var len_s := rng.randi_range(int(0.002 * SR), int(0.009 * SR))
		var a := rng.randf_range(0.3, 1.0)
		if fade_out:
			a *= 1.0 - float(start) / n
		var y := 0.0
		for i in len_s:
			var j := start + i
			if j >= n:
				break
			y = rng.randf() * 2.0 - 1.0 - y * 0.5
			b[j] += y * a * (1.0 - float(i) / len_s)
	return b


# ------------------------------------------------------------------ loops
static func make_loop_sound(id: StringName) -> PackedFloat32Array:
	match id:
		&"forest_ambience":
			var seconds := 12.0
			var b := buf(seconds + 1.0)
			var n := b.size()
			var rng := RandomNumberGenerator.new()
			rng.seed = 201
			var y1 := 0.0
			var y2 := 0.0
			var h1 := 0.0
			var hp := 0.0
			var px := 0.0
			for i in n:
				var t := float(i) / SR
				var gust := 0.55 + 0.25 * sin(TAU * t / 6.5) + 0.2 * sin(TAU * t / 2.9 + 1.3)
				var a := 1.0 - exp(-TAU * (220.0 + 260.0 * gust) / SR)
				var x := rng.randf() * 2.0 - 1.0
				y1 += a * (x - y1)
				y2 += a * (y1 - y2)
				# leaf rustle: highpassed noise riding the gusts
				h1 += 0.5 * (x - h1)
				var hy := 0.93 * (hp + h1 - px)
				px = h1
				hp = hy
				b[i] = y2 * gust * 1.4 + hy * 0.05 * gust * gust
			return make_loop(b, 1.0)
		&"river_loop":
			var b := noise(6.0, 1100.0, 1100.0, 0.001, 1000.0, 80.0, 211)
			var spark := noise(6.0, 4500.0, 4500.0, 0.001, 1000.0, 1500.0, 212)
			var rng := RandomNumberGenerator.new()
			rng.seed = 213
			var m := 0.5
			for i in b.size():
				if (i & 255) == 0:
					m = clampf(m + rng.randf_range(-0.25, 0.25), 0.1, 1.0)
				b[i] += spark[i] * 0.35 * m
			return make_loop(b, 0.6)
		&"waterfall_loop":
			var b := noise(6.0, 2400.0, 2400.0, 0.001, 1000.0, 60.0, 221)
			mix(b, noise(6.0, 220.0, 220.0, 0.001, 1000.0, 0.0, 222), 2.0)
			return make_loop(b, 0.6)
		&"fire_loop":
			var b := noise(5.0, 260.0, 260.0, 0.001, 1000.0, 30.0, 231, 0.6)
			mix(b, _crackles(5.0, 14.0, 232, false), 0.5)
			mix(b, noise(5.0, 1800.0, 1800.0, 0.001, 1000.0, 600.0, 233, 0.12))
			return make_loop(b, 0.4)
	return PackedFloat32Array()


# ------------------------------------------------------------------ music
static func make_music(id: StringName) -> PackedFloat32Array:
	match id:
		&"music_explore":
			return _music_explore()
		&"music_boss":
			return _music_boss()
	return PackedFloat32Array()


## Gentle pentatonic exploration theme: soft pads, plucked melody, bass.
## 12 bars at 80 BPM (36 s), tails wrap so the loop is seamless.
static func _music_explore() -> PackedFloat32Array:
	var beat := 60.0 / 80.0
	var bar := beat * 4.0
	var chords := {
		&"D": [50, 57, 62, 66], &"Bm": [47, 54, 59, 62], &"G": [43, 50, 55, 59],
		&"A": [45, 52, 57, 61], &"Em": [40, 47, 52, 55], &"F#m": [42, 49, 54, 57],
	}
	var prog := [&"D", &"Bm", &"G", &"A", &"D", &"F#m", &"G", &"A", &"Bm", &"G", &"Em", &"A"]
	var out := buf(bar * prog.size())
	# Pads: render each chord once, place per bar.
	var pad_cache := {}
	for c: StringName in chords:
		if not prog.has(c):
			continue
		var p := buf(0.1)
		var notes: Array = chords[c]
		for ni in range(1, notes.size()):
			mix(p, pad(midi_hz(notes[ni]), bar, 0.9, 1.2), 0.25)
		pad_cache[c] = lowpass(p, 1500.0)
	var pluck_cache := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var scale := [62, 64, 66, 69, 71, 74, 76, 78, 81]
	var rhythms := [[0.0, 1.0, 2.0, 3.0], [0.0, 1.5, 2.0, 3.0], [0.0, 2.0, 2.5, 3.0], [0.0, 0.5, 1.0, 2.0], [0.0, 3.0], [0.0, 1.0, 1.5, 2.5]]
	var idx := 4
	var motif: Array = []
	for b_i in prog.size():
		var chord: Array = chords[prog[b_i]]
		var bar_off := int(b_i * bar * SR)
		mix_wrap(out, pad_cache[prog[b_i]], 1.0, bar_off)
		# bass pluck on beats 1 and 3
		for beat_i in [0, 2]:
			var bm: int = chord[0] - 12 if chord[0] >= 45 else chord[0]
			var bp: PackedFloat32Array = pluck_cache.get(bm, PackedFloat32Array())
			if bp.is_empty():
				bp = pluck(midi_hz(bm), 1.6, 0.997, 0.3, bm)
				pluck_cache[bm] = bp
			mix_wrap(out, bp, 0.5 if beat_i == 0 else 0.3, bar_off + int(beat_i * beat * SR))
		# melody: motif repeats every 4 bars with small variations
		var rhythm: Array
		if b_i % 4 == 0 or motif.is_empty():
			motif = []
			for k in 4:
				motif.append(rhythms[rng.randi_range(0, rhythms.size() - 1)])
		rhythm = motif[b_i % 4]
		if b_i == prog.size() - 1:
			rhythm = [0.0, 2.0]
		for k in rhythm.size():
			idx = clampi(idx + rng.randi_range(-2, 2), 0, scale.size() - 1)
			var m: int = scale[idx]
			if k == 0:
				# snap downbeats to a chord tone (pitch class)
				var best := m
				var bd := 99
				for cm: int in chord:
					for octave in [0, 12, 24]:
						var cand: int = cm + octave
						if absi(cand - m) < bd and cand >= 60 and cand <= 83:
							bd = absi(cand - m)
							best = cand
				m = best
			var mp: PackedFloat32Array = pluck_cache.get(m, PackedFloat32Array())
			if mp.is_empty():
				mp = pluck(midi_hz(m), 1.4, 0.996, 0.55, m)
				pluck_cache[m] = mp
			var t: float = rhythm[k]
			mix_wrap(out, mp, 0.42 if k == 0 else 0.32, bar_off + int(t * beat * SR))
			# gentle echo of the note an octave up, quietly, on long notes
			if rng.randf() < 0.25 and m + 12 <= 93:
				var hm := m + 12
				var hp: PackedFloat32Array = pluck_cache.get(hm, PackedFloat32Array())
				if hp.is_empty():
					hp = pluck(midi_hz(hm), 1.0, 0.995, 0.5, hm)
					pluck_cache[hm] = hp
				mix_wrap(out, hp, 0.12, bar_off + int((t + 0.75) * beat * SR))
	return out


## Tense boss track: low drums, D-minor ostinato, drone, brass stabs.
## 8 bars at 112 BPM (~17 s).
static func _music_boss() -> PackedFloat32Array:
	var beat := 60.0 / 112.0
	var bar := beat * 4.0
	var bars := 8
	var out := buf(bar * bars)
	var n := out.size()
	# Drone: low D with slow swell (one continuous voice, wraps exactly).
	var ph := 0.0
	var ph2 := 0.0
	var f := midi_hz(38)
	for i in n:
		ph += f / SR
		ph -= floorf(ph)
		ph2 += f * 0.5 / SR
		ph2 -= floorf(ph2)
		var sw := 0.6 + 0.4 * sin(TAU * float(i) / n * 2.0)
		out[i] = ((2.0 * ph - 1.0) * 0.25 + sin(TAU * ph2) * 0.6) * sw * 0.35
	lowpass(out, 400.0, 2)
	var kick := tone(0.5, 115.0, 40.0, Wave.SINE, 0.001, 0.14)
	mix(kick, noise(0.03, 3000.0, 1000.0, 0.0005, 0.006, 300.0, 301), 0.3)
	var tom := tone(0.4, 160.0, 95.0, Wave.SINE, 0.001, 0.12)
	mix(tom, noise(0.15, 800.0, 300.0, 0.001, 0.05, 80.0, 302), 0.5)
	var rim := noise(0.06, 5000.0, 2500.0, 0.0005, 0.012, 1200.0, 303)
	var shifts := [0, 0, -4, -5, 0, 0, -2, -5]
	var pattern := [50, 50, 53, 50, 57, 50, 56, 53]
	var osti_cache := {}
	for b_i in bars:
		var off := int(b_i * bar * SR)
		for t in [0.0, 1.5, 2.0]:
			mix_wrap(out, kick, 1.0, off + int(t * beat * SR))
		if b_i % 2 == 1:
			mix_wrap(out, tom, 0.8, off + int(3.0 * beat * SR))
			mix_wrap(out, tom, 0.6, off + int(3.5 * beat * SR))
		for t in [1.0, 3.0]:
			mix_wrap(out, rim, 0.25, off + int(t * beat * SR))
		for k in 8:
			var m: int = pattern[k] + shifts[b_i]
			var o: PackedFloat32Array = osti_cache.get(m, PackedFloat32Array())
			if o.is_empty():
				o = lowpass(tone(0.3, midi_hz(m), midi_hz(m), Wave.SAW, 0.004, 0.11), 1300.0, 2)
				osti_cache[m] = o
			mix_wrap(out, o, 0.32 if k % 2 == 0 else 0.24, off + int(k * 0.5 * beat * SR))
		if b_i % 2 == 0:
			var root: int = 62 + int(shifts[b_i])
			var stab := buf(0.1)
			for m in [root, root + 3, root + 7]:
				mix(stab, tone(1.4, midi_hz(m), midi_hz(m), Wave.SAW, 0.06, 0.5), 0.2)
			mix_wrap(out, lowpass(stab, 1100.0, 2), 0.7, off)
	return soft_clip(out, 1.2)
