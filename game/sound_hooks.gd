class_name SoundHooks
extends RefCounted

## Static front door for game audio. Call sites live at every natural
## trigger point in GameController; this class decides what (if anything)
## actually makes noise, so game logic never holds an audio reference.
##
## M4 shipped these as no-op `pass` stubs by design (docs/PLAN.md: "sound
## hooks left unimplemented"), which is why the game was silent on every
## platform, not just iOS. They now forward to an Sfx node - but only once
## something has handed them one.
##
## Nothing attached means silence, not an error, and that is the normal state
## for everything that isn't the running game: the headless test runner and
## tools/solve_level.gd both drive GameController without ever calling
## attach(), and they should stay exactly as silent as these hooks used to be.

static var _sfx: Sfx = null


## Hand the hooks the node that actually makes noise. Called once, from
## main.gd. Passing null detaches, which is what tests use to assert the
## unattached behaviour.
static func attach(sfx: Sfx) -> void:
	_sfx = sfx


## The attached Sfx node, or null if there isn't a live one. Exposed so tests
## can save and restore whatever was attached before them.
##
## is_instance_valid() rather than a plain null check: this is a static
## reference to a Node, so it outlives the node itself on shutdown, and a
## freed Sfx would otherwise be called into.
static func attached() -> Sfx:
	return _sfx if is_instance_valid(_sfx) else null


static func on_move() -> void:
	_play(SfxBank.MOVE)


static func on_capture() -> void:
	_play(SfxBank.CAPTURE)


static func on_promotion() -> void:
	_play(SfxBank.PROMOTION)


## Every card currently shares one sound. The type is still threaded through
## so giving Push Back its own cue later is a change in this function alone.
static func on_card_played(_card_type: String) -> void:
	_play(SfxBank.CARD)


static func on_win() -> void:
	_play(SfxBank.WIN)


static func on_loss() -> void:
	_play(SfxBank.LOSS)


static func _play(sound_name: String) -> void:
	var sfx: Sfx = attached()
	if sfx == null:
		return
	sfx.play(sound_name)
