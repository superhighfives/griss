class_name SoundHooks
extends RefCounted

## Unimplemented per M4 scope (docs/PLAN.md): "sound hooks left
## unimplemented". Call sites exist at every natural trigger point so
## wiring in real audio later is a one-line change per hook, not a hunt
## through the codebase for where each event actually happens.

static func on_move() -> void:
	pass


static func on_capture() -> void:
	pass


static func on_promotion() -> void:
	pass


static func on_card_played(card_type: String) -> void:
	pass


static func on_win() -> void:
	pass


static func on_loss() -> void:
	pass
