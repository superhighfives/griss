class_name Sfx
extends Node

## Owns the generated sound bank and the AudioStreamPlayers that play it.
##
## Created and added to the tree by main.gd, which hands it to SoundHooks -
## deliberately not an autoload, per docs/PLAN.md section 9 ("No Autoload/
## singletons... Pass dependencies explicitly"). Nothing in the game talks to
## this directly; SoundHooks is the front door, so GameController never has to
## carry an audio dependency just to make a noise.

## Godot's stand-in audio driver, used whenever there is no real output to
## mix into - which is every headless run, so the whole test suite and
## tools/solve_level.gd.
const DUMMY_DRIVER: String = "Dummy"

## Sounds come from game logic, which can produce two in the same frame (a
## move plus the capture it caused, or a card plus the promotion it grants).
## A single player would cut the first one off mid-tail, so voices are
## pooled; six is comfortably more than the game can start at once.
const VOICE_COUNT: int = 6

## False when there is no audio device to play into. Set from the driver in
## _ready(); tests override it to exercise the real playback path.
var enabled: bool = true

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	# An outcome sound can land on the frame the tree gets paused, and no
	# sound here carries game state, so none of them should be held by pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Under the dummy driver every play() would allocate a playback that
	# never gets mixed and never finishes - pointless work in the test suite,
	# and it leaves dangling playbacks that Godot reports as leaked instances
	# when the runner quits. There is nothing to hear, so don't start any.
	enabled = AudioServer.get_driver_name() != DUMMY_DRIVER

	_streams = SfxBank.build_all()
	for i in range(VOICE_COUNT):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = Tuning.SFX_VOLUME_DB
		add_child(player)
		_voices.append(player)


## Play one of SfxBank's sounds by name.
##
## The unknown-name check comes first deliberately: a name the bank has no
## stream for is a programming error (a typo'd constant), and it should still
## be reported on a machine with no audio device, where it would otherwise go
## unnoticed until someone ran the game.
func play(sound_name: String) -> void:
	if not _streams.has(sound_name):
		push_error("Sfx.play(): unknown sound '%s'" % sound_name)
		return
	if not enabled:
		return
	var player: AudioStreamPlayer = _claim_voice()
	player.stream = _streams[sound_name]
	player.play()


## Prefer a voice that isn't currently sounding. If every voice is busy -
## which takes more simultaneous sounds than the game can currently produce -
## steal them in round-robin order, so the oldest is the one interrupted.
func _claim_voice() -> AudioStreamPlayer:
	for player in _voices:
		if not player.playing:
			return player
	var stolen: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen
