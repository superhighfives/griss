class_name SfxBank
extends RefCounted

## Procedurally synthesised sound effects, built in code at startup rather
## than shipped as audio files.
##
## The project has no art or audio assets yet - docs/PLAN.md parks both as
## "easy to add later" - and six short blips don't justify introducing the
## first binary assets and their .import sidecars into the repo. A few
## hundred lines of arithmetic produce them in well under a millisecond and
## keep every sound tweakable as numbers, which is the same bias as
## game/tuning.gd. Swapping in real recorded audio later means changing
## build_all() to load() six files; nothing else in the chain cares.
##
## Synthesis is deterministic - the one noise source is seeded explicitly -
## so the streams come out identical on every run and platform. That is what
## makes them assertable in tests/test_sfx.gd.

const MOVE: String = "move"
const CAPTURE: String = "capture"
const PROMOTION: String = "promotion"
const CARD: String = "card"
const WIN: String = "win"
const LOSS: String = "loss"

## Every name build_all() is expected to produce, so callers (and the test
## suite) can check coverage without hardcoding the list twice.
const ALL: Array[String] = [MOVE, CAPTURE, PROMOTION, CARD, WIN, LOSS]

## 22.05 kHz rather than 44.1: the highest partial used here is under 2 kHz,
## so the extra bandwidth would only double the buffers for nothing.
const MIX_RATE: int = 22050

## Ramp each tone in over a few milliseconds. A sine that starts at full
## amplitude has a step discontinuity at its first sample, which is audible
## as a click layered on top of the sound that was actually wanted.
const ATTACK: float = 0.004

## The mirror of ATTACK at the other end. Exponential decay approaches zero
## without reaching it, so a buffer that just stops mid-tail has the same
## discontinuity; fade the last few milliseconds out to silence.
const RELEASE: float = 0.006


## The full sound bank, keyed by the constants above. Built once - see
## game/sfx.gd, which holds the result for the lifetime of the app.
static func build_all() -> Dictionary:
	return {
		MOVE: _build_move(),
		CAPTURE: _build_capture(),
		PROMOTION: _build_promotion(),
		CARD: _build_card(),
		WIN: _build_win(),
		LOSS: _build_loss(),
	}


## A piece setting down: a short, soft, wooden "tok". Deliberately the
## quietest and shortest sound in the bank - it fires on every single move,
## so anything with a tail or a pitch sweep becomes grating within a level.
static func _build_move() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.09)
	_add_noise(buf, 0.0, 0.005, 0.10, 420.0, 1)
	_add_tone(buf, 0.0, 0.09, 300.0, 0.45, 38.0)
	_add_tone(buf, 0.0, 0.09, 600.0, 0.16, 55.0)
	return _to_stream(buf)


## A capture: same gesture as a move, but lower, louder and with a noise
## transient, so it reads as the same action with more weight behind it
## rather than as an unrelated event.
static func _build_capture() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.20)
	_add_noise(buf, 0.0, 0.06, 0.28, 45.0, 2)
	_add_tone(buf, 0.0, 0.20, 150.0, 0.50, 16.0)
	_add_tone(buf, 0.0, 0.20, 90.0, 0.32, 12.0)
	return _to_stream(buf)


## Promotion: a rising A major arpeggio. Upward motion for an upgrade.
static func _build_promotion() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.40)
	var notes: Array[float] = [440.0, 554.37, 659.25, 880.0]
	for i in range(notes.size()):
		_add_tone(buf, i * 0.05, 0.22, notes[i], 0.26, 12.0)
	return _to_stream(buf)


## Playing a card: a bright two-step blip, clearly not a board sound. Kept
## well above the move/capture register so a card and a move in the same
## turn stay distinguishable when they land back to back.
static func _build_card() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.18)
	_add_tone(buf, 0.0, 0.07, 660.0, 0.30, 30.0)
	_add_tone(buf, 0.05, 0.13, 990.0, 0.28, 22.0)
	return _to_stream(buf)


## Win: an ascending major triad, the longest sound in the bank. It only
## ever plays once per level, on a screen where nothing else is happening.
static func _build_win() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.80)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	for i in range(notes.size()):
		_add_tone(buf, i * 0.11, 0.45, notes[i], 0.24, 7.0)
	return _to_stream(buf)


## Loss: the same shape as the win, inverted - three descending tones. The
## symmetry is the point; it should land as the other outcome of the same
## game, not as an error buzzer.
static func _build_loss() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.80)
	var notes: Array[float] = [330.0, 246.94, 196.00]
	for i in range(notes.size()):
		_add_tone(buf, i * 0.14, 0.45, notes[i], 0.30, 7.0)
	return _to_stream(buf)


## A silent mono buffer of `duration` seconds, in floats. Sounds are mixed
## additively into one of these and converted to PCM once at the end, so
## overlapping partials sum at full precision and clip (if at all) exactly
## once, in _to_stream().
static func _buffer(duration: float) -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(int(duration * MIX_RATE))
	buf.fill(0.0)
	return buf


## Mix in a sine at `freq`, starting `start_sec` into the buffer, decaying
## exponentially at `decay` (larger is faster: amplitude is scaled by
## e^(-decay * t), so decay=38 is down ~98% after 0.1s).
static func _add_tone(buf: PackedFloat32Array, start_sec: float, duration: float, freq: float, amplitude: float, decay: float) -> void:
	var start: int = int(start_sec * MIX_RATE)
	var count: int = int(duration * MIX_RATE)
	for i in range(count):
		var index: int = start + i
		if index < 0 or index >= buf.size():
			continue
		var t: float = float(i) / MIX_RATE
		buf[index] += sin(TAU * freq * t) * amplitude * exp(-decay * t) * _attack_gain(t)


## Mix in a burst of white noise with the same envelope shape as _add_tone().
## `noise_seed` is explicit so the generated bank is byte-identical run to run.
static func _add_noise(buf: PackedFloat32Array, start_sec: float, duration: float, amplitude: float, decay: float, noise_seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	var start: int = int(start_sec * MIX_RATE)
	var count: int = int(duration * MIX_RATE)
	for i in range(count):
		var index: int = start + i
		if index < 0 or index >= buf.size():
			continue
		var t: float = float(i) / MIX_RATE
		buf[index] += rng.randf_range(-1.0, 1.0) * amplitude * exp(-decay * t) * _attack_gain(t)


static func _attack_gain(t: float) -> float:
	return minf(1.0, t / ATTACK)


## Convert the float buffer to a 16-bit mono AudioStreamWAV, clamping to the
## representable range and fading the tail to silence first.
static func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	_apply_release(buf)
	var data: PackedByteArray = PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		data.encode_s16(i * 2, int(roundf(clampf(buf[i], -1.0, 1.0) * 32767.0)))

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


static func _apply_release(buf: PackedFloat32Array) -> void:
	var ramp: int = mini(int(RELEASE * MIX_RATE), buf.size())
	for i in range(ramp):
		var index: int = buf.size() - ramp + i
		buf[index] *= 1.0 - (float(i) / ramp)
