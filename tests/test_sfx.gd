extends TestCase

## Tests for the sound effect chain: SfxBank's synthesis, SoundHooks' wiring,
## and the Sfx node's voice pool.
##
## These exist because this chain's failure mode is silence, which no other
## test would notice - and silence is exactly the bug they follow up. M4 left
## six no-op `pass` hooks in place, so the game made no sound on any platform
## while every test stayed green.
##
## Nothing here asserts that audio is audible; the headless runner has no
## audio device. They assert what was actually wrong, or could quietly break
## the same way again: that each hook reaches a real stream, that the streams
## carry signal rather than silence, and that the hooks stay harmless when
## nothing has been attached to them.

## A stream peaking below this is silence for practical purposes - the
## threshold only has to separate "real sound" from "all zeros".
const MIN_PEAK: float = 0.05

## How long _release_sfx() gives the audio server to let go of the playbacks
## it was handed. Empirical: 0.05s is enough for one voice but not for a full
## pool of six, so this leaves room. Getting it wrong costs a leak warning at
## exit, never a failed test.
const RELEASE_TICK_SECONDS: float = 0.2

## Tolerance for the samples at each end of a buffer, which the attack ramp
## and release fade should bring to (near) zero.
const EDGE_SILENCE: float = 0.01


## Stands in for the real Sfx node: a genuine Sfx (so the typed attach()
## accepts it) that records instead of sounding. It is never added to the
## tree, so _ready() never runs and no voices or streams are built - these
## tests only care which name each hook asks for.
class RecordingSfx:
	extends Sfx

	var played: Array[String] = []

	func play(sound_name: String) -> void:
		played.append(sound_name)


## Run `body` with `stand_in` (which may be null) attached to SoundHooks, then
## restore whatever was attached before. Restoring matters: the reference is
## static, so leaving a stand-in in place would follow the suite around.
func _with_sfx_attached(stand_in: Sfx, body: Callable) -> void:
	var previous: Sfx = SoundHooks.attached()
	SoundHooks.attach(stand_in)
	body.call()
	SoundHooks.attach(previous)


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Decode a generated stream back to floats, so tests can look at the signal
## rather than at the PackedByteArray it is stored as.
static func _samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = stream.data
	var sample_count: int = data.size() >> 1
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(sample_count)
	for i in range(sample_count):
		out[i] = float(data.decode_s16(i * 2)) / 32767.0
	return out


static func _peak(stream: AudioStreamWAV) -> float:
	var peak: float = 0.0
	for sample in _samples(stream):
		peak = maxf(peak, absf(sample))
	return peak


func test_bank_covers_every_declared_sound() -> bool:
	var bank: Dictionary = SfxBank.build_all()
	if not assert_eq(bank.size(), SfxBank.ALL.size(), "bank size should match SfxBank.ALL"):
		return false
	for sound_name in SfxBank.ALL:
		if not assert_has(bank, sound_name, "bank is missing '%s'" % sound_name):
			return false
		if not assert_true(bank[sound_name] is AudioStreamWAV, "'%s' should be an AudioStreamWAV" % sound_name):
			return false
	return true


## The regression that matters most: a sound that exists but is silent is,
## from the player's side, indistinguishable from the stubs this replaced.
func test_every_sound_is_audible_signal() -> bool:
	var bank: Dictionary = SfxBank.build_all()
	for sound_name in SfxBank.ALL:
		var stream: AudioStreamWAV = bank[sound_name]
		if not assert_true(stream.data.size() > 0, "'%s' has no sample data" % sound_name):
			return false
		if not assert_true(_peak(stream) > MIN_PEAK, "'%s' peaks at %f - effectively silent" % [sound_name, _peak(stream)]):
			return false
	return true


func test_streams_are_16_bit_mono_at_the_bank_mix_rate() -> bool:
	var bank: Dictionary = SfxBank.build_all()
	for sound_name in SfxBank.ALL:
		var stream: AudioStreamWAV = bank[sound_name]
		if not assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "'%s' format" % sound_name):
			return false
		if not assert_false(stream.stereo, "'%s' should be mono" % sound_name):
			return false
		if not assert_eq(stream.mix_rate, SfxBank.MIX_RATE, "'%s' mix rate" % sound_name):
			return false
		if not assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "'%s' should not loop" % sound_name):
			return false
	return true


## Both ends of every buffer must sit at silence. A tone that starts or stops
## on a non-zero sample has a step discontinuity there, heard as a click on
## top of the intended sound - what SfxBank's ATTACK and RELEASE ramps are for.
func test_sounds_start_and_end_at_silence() -> bool:
	var bank: Dictionary = SfxBank.build_all()
	for sound_name in SfxBank.ALL:
		var samples: PackedFloat32Array = _samples(bank[sound_name])
		if not assert_true(samples.size() > 0, "'%s' has no samples" % sound_name):
			return false
		if not assert_true(absf(samples[0]) < EDGE_SILENCE, "'%s' starts at %f, not silence" % [sound_name, samples[0]]):
			return false
		var last: float = samples[samples.size() - 1]
		if not assert_true(absf(last) < EDGE_SILENCE, "'%s' ends at %f, not silence" % [sound_name, last]):
			return false
	return true


## Synthesis is seeded, so two builds must agree byte for byte. Without the
## explicit seed the noise in the move and capture sounds would drift run to
## run, and the assertions above would be testing a different sound each time.
func test_synthesis_is_deterministic() -> bool:
	var first: Dictionary = SfxBank.build_all()
	var second: Dictionary = SfxBank.build_all()
	for sound_name in SfxBank.ALL:
		if not assert_eq(first[sound_name].data, second[sound_name].data, "'%s' differs between builds" % sound_name):
			return false
	return true


## Each hook must reach the sound it means, and that sound must be one the
## bank actually provides. A typo'd constant would otherwise surface only as
## a push_error at runtime, on device, in the path nobody is watching.
##
## A recorder is attached in place of whatever is there, so this asserts the
## hook -> bank mapping without needing an audio device.
func test_each_hook_plays_its_own_sound() -> bool:
	var recorder: RecordingSfx = RecordingSfx.new()
	_with_sfx_attached(recorder, func() -> void:
		SoundHooks.on_move()
		SoundHooks.on_capture()
		SoundHooks.on_promotion()
		SoundHooks.on_card_played("promote")
		SoundHooks.on_win()
		SoundHooks.on_loss())

	var played: Array[String] = recorder.played.duplicate()
	recorder.free()

	var expected: Array[String] = [
		SfxBank.MOVE,
		SfxBank.CAPTURE,
		SfxBank.PROMOTION,
		SfxBank.CARD,
		SfxBank.WIN,
		SfxBank.LOSS,
	]
	if not assert_eq(played, expected, "hooks should play their own sounds, in order"):
		return false

	var bank: Dictionary = SfxBank.build_all()
	for sound_name in played:
		if not assert_has(bank, sound_name, "hook played '%s', which the bank has no stream for" % sound_name):
			return false
	return true


## An open board with room to walk forward, for driving a real move through
## GameController.
static func _open_level() -> Level:
	var level: Level = Level.new()
	level.level_name = "Sfx Wiring"
	level.width = 4
	level.height = 6
	level.move_budget = 10
	level.players = [{"kind": PieceKind.Kind.ROOK, "pos": Vector2i(0, 0)}]
	level.walls = []
	level.powerups = []
	level.enemies = []
	return level


## End to end: a real move through GameController has to reach the sound
## chain. The hooks being correct is not enough if nothing calls them - which
## is the shape of the original bug, just one layer up. Nothing else covers
## the GameController -> SoundHooks wiring, so removing a hook call from
## try_move() would otherwise leave every test green and the game quieter.
func test_a_real_move_reaches_the_sound_chain() -> bool:
	var recorder: RecordingSfx = RecordingSfx.new()
	_with_sfx_attached(recorder, func() -> void:
		var controller: GameController = GameController.new()
		controller.load_level(_open_level())
		# load_level() itself fires nothing on an ongoing level; clear anyway so
		# the assertion below is about the move and not about setup.
		recorder.played.clear()
		controller.try_move(controller.state.get_player_pieces()[0].id, Vector2i(0, 1)))

	var played: Array[String] = recorder.played.duplicate()
	recorder.free()
	return assert_has(played, SfxBank.MOVE, "a completed move should have played the move sound")


## main.gd is the only place that hands SoundHooks something to play through,
## and nothing else covers that one line. Without it every layer below is
## correct and the game is still silent - the same bug, one level up - so this
## instantiates the real main scene and checks the chain came up wired.
func test_the_main_scene_wires_up_the_sound_chain() -> bool:
	var previous: Sfx = SoundHooks.attached()
	SoundHooks.attach(null)

	var main: Node = load("res://game/Main.tscn").instantiate()
	_tree().root.add_child(main)
	# _ready() does not run synchronously on add_child() here - the runner adds
	# nodes before the tree starts processing - so let a frame happen first.
	# That makes this a coroutine; see tests/run_tests.gd.
	await _tree().create_timer(RELEASE_TICK_SECONDS).timeout

	# Read everything out before the teardown below: freeing main frees the Sfx
	# it owns, and a variable still pointing at a freed node compares equal to
	# null, which would make these assertions lie.
	var sfx: Sfx = SoundHooks.attached()
	var was_attached: bool = sfx != null
	var in_tree: bool = was_attached and sfx.is_inside_tree()
	var voices: int = sfx._voices.size() if was_attached else -1

	_tree().root.remove_child(main)
	main.free()
	SoundHooks.attach(previous)

	if not assert_true(was_attached, "main.gd should attach an Sfx node when it becomes ready"):
		return false
	if not assert_true(in_tree, "the attached node has to be in the tree, or its players can't play"):
		return false
	return assert_eq(voices, Sfx.VOICE_COUNT, "the attached node should have built its voice pool")


## Every hook has to stay a harmless no-op with nothing attached. That is the
## normal state outside the running game - the test runner and
## tools/solve_level.gd never call attach() - so they must not error or crash.
func test_hooks_are_silent_no_ops_with_nothing_attached() -> bool:
	var failure: String = ""
	_with_sfx_attached(null, func() -> void:
		if SoundHooks.attached() != null:
			failure = "attached() should be null after attaching nothing"
			return
		SoundHooks.on_move()
		SoundHooks.on_capture()
		SoundHooks.on_promotion()
		SoundHooks.on_card_played("promote")
		SoundHooks.on_win()
		SoundHooks.on_loss())
	return assert_eq(failure, "", "hooks misbehaved with nothing attached")


## A fresh Sfx node attached to the tree, with playback forced on. _ready()
## disables itself under the headless runner's dummy audio driver, which is
## the right call in the real game but would make these tests assert nothing.
## Caller frees it via _release_sfx().
func _make_sfx() -> Sfx:
	var sfx: Sfx = Sfx.new()
	_tree().root.add_child(sfx)
	await _ready_tick()
	sfx.enabled = true
	return sfx


## Wait for a node just added to the tree to have run _ready().
##
## add_child() only calls _ready() straight away once the tree has started
## processing frames. Tests begin inside SceneTree._initialize(), before any
## frame has happened, so there a freshly added node's _ready() is deferred -
## and this is true of a plain Node.new() just as much as of an instantiated
## PackedScene. Awaiting a frame is what makes the difference, so any test
## that adds a node and then reads state _ready() sets up has to do it.
##
## It is easy to get away with skipping this: any earlier test that awaits
## anything pumps the tree and makes every test after it look fine. That is
## exactly why each test here waits for itself rather than relying on the one
## before it - running this file alone, or reordering it, must not change what
## these tests mean.
func _ready_tick() -> void:
	await _tree().process_frame


## Stop every voice, let the audio server tick once, then free.
##
## The tick is the part that matters: AudioStreamPlayer.stop() hands the
## playback back to the AudioServer, but the server only lets go of it on its
## next mix. Free the node before that happens and the playback (plus the
## stream behind it) survives to engine cleanup, where Godot reports it as a
## leaked instance. Awaiting a timer here is the same trick tests/
## test_board_view.gd uses to get real frames out of the headless runner, and
## it is why the tests calling this are coroutines - see tests/run_tests.gd.
func _release_sfx(sfx: Sfx) -> void:
	for voice in sfx._voices:
		voice.stop()
	await _tree().create_timer(RELEASE_TICK_SECONDS).timeout
	_tree().root.remove_child(sfx)
	sfx.free()


## Sfx must not start playbacks when there is nothing to play into.
## This is what keeps the suite (and tools/solve_level.gd) from spending time
## mixing audio nobody can hear.
func test_playback_is_disabled_without_an_audio_device() -> bool:
	if not assert_eq(AudioServer.get_driver_name(), "Dummy", "headless runs are expected to use the dummy audio driver"):
		return false

	var sfx: Sfx = Sfx.new()
	_tree().root.add_child(sfx)
	await _ready_tick()
	var was_enabled: bool = sfx.enabled
	sfx.play(SfxBank.MOVE)
	var any_playing: bool = false
	for voice in sfx._voices:
		any_playing = any_playing or voice.playing
	await _release_sfx(sfx)

	if not assert_false(was_enabled, "should disable itself under the dummy driver"):
		return false
	return assert_false(any_playing, "play() should start no voice while disabled")


## The path the whole change exists for: a hook's sound name reaches a real
## player, with the matching stream on it, and that player is sounding.
func test_play_puts_the_named_stream_on_a_sounding_voice() -> bool:
	var sfx: Sfx = await _make_sfx()
	sfx.play(SfxBank.CAPTURE)

	var sounding: Array = []
	for voice in sfx._voices:
		if voice.playing:
			sounding.append(voice)
	var played_stream: AudioStream = sounding[0].stream if sounding.size() == 1 else null
	var expected_stream: AudioStream = sfx._streams[SfxBank.CAPTURE]
	await _release_sfx(sfx)

	if not assert_eq(sounding.size(), 1, "exactly one voice should be sounding after one play()"):
		return false
	return assert_eq(played_stream, expected_stream, "the voice should carry the stream that was asked for")


## The pool exists so that a move and the capture it caused don't cut each
## other off. Claiming voices while the earlier ones are still sounding must
## hand back distinct players, up to the pool size.
func test_voice_pool_hands_out_distinct_players() -> bool:
	var sfx: Sfx = await _make_sfx()
	# Against the pool that was actually built, not against the constant:
	# VOICE_COUNT reads 6 whether or not _ready() has run, so trusting it would
	# let this test pass over an empty pool without claiming anything.
	var voice_count: int = sfx._voices.size()

	var ok: bool = true
	var claimed: Array = []
	for i in range(voice_count):
		var voice: AudioStreamPlayer = sfx._claim_voice()
		if not assert_not_has(claimed, voice, "voice %d had already been handed out" % i):
			ok = false
			break
		claimed.append(voice)
		# _claim_voice() only reuses a player that isn't playing, so hold each one
		# the way play() does before asking for the next.
		voice.stream = sfx._streams[SfxBank.WIN]
		voice.play()

	await _release_sfx(sfx)

	if not ok:
		return false
	if not assert_eq(voice_count, Sfx.VOICE_COUNT, "the pool should have been built by _ready()"):
		return false
	return assert_eq(claimed.size(), voice_count, "should have claimed every voice")
