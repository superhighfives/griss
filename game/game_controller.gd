class_name GameController
extends RefCounted

signal state_updated
signal outcome_updated(outcome: Rules.Outcome)

var state: BoardState
var initial_state: BoardState
var undo_stack: Array[BoardState] = []
var outcome: Rules.Outcome = Rules.Outcome.ONGOING
var enemy_turn_mode: String = Rules.ENEMY_TURN_MODE_ONE


func load_level(level: Level) -> void:
	state = level.to_board_state()
	initial_state = state.duplicate_state()
	enemy_turn_mode = level.enemy_turn_mode
	undo_stack = []
	_finish_turn()


func get_legal_moves(piece_id: int) -> Array[Vector2i]:
	if outcome != Rules.Outcome.ONGOING:
		return []
	return MoveGen.legal_moves(state, piece_id)


## Plays a card from the current hand. Does not end the turn or let the
## enemy team act - a turn is one card (optional) plus one move, and the
## move (try_move()) is what ends it. Snapshots for undo just like
## try_move() does, so undoing a move also undoes a card played earlier
## in the same turn if the player chains Undo.
func try_play_card(card_type: String, target_piece_id: int = -1) -> bool:
	if outcome != Rules.Outcome.ONGOING:
		return false
	undo_stack.append(state.duplicate_state())
	var applied: bool = Rules.play_card(state, card_type, target_piece_id)
	if not applied:
		undo_stack.pop_back()
		return false
	SoundHooks.on_card_played(card_type)
	if card_type == Rules.CARD_PROMOTE:
		SoundHooks.on_promotion()
	state_updated.emit()
	return true


func try_move(piece_id: int, dest: Vector2i) -> bool:
	if outcome != Rules.Outcome.ONGOING:
		return false
	undo_stack.append(state.duplicate_state())
	var piece_count_before: int = state.pieces.size()

	var applied: bool = Rules.apply_move(state, piece_id, dest)
	if not applied:
		undo_stack.pop_back()
		return false

	SoundHooks.on_move()
	if state.pieces.size() < piece_count_before:
		SoundHooks.on_capture()

	# Only let the enemy team act if the player's own move didn't already
	# end the game (e.g. reaching the goal row) - checked directly rather
	# than through _finish_turn(), which is called once at the end so
	# outcome is computed and both signals emitted exactly once per
	# try_move(), reflecting the enemy turn's effect too.
	if Rules.check_outcome(state) == Rules.Outcome.ONGOING:
		var count_before_enemy_turn: int = state.pieces.size()
		Rules.advance_enemies_and_resolve_stalemate(state, enemy_turn_mode)
		if state.pieces.size() < count_before_enemy_turn:
			SoundHooks.on_capture()

	# The move ends the turn - a fresh card play is available next turn.
	state.card_played_this_turn = false

	_finish_turn()
	return true


func undo() -> void:
	if undo_stack.is_empty():
		return
	state = undo_stack.pop_back()
	_finish_turn()


func restart() -> void:
	state = initial_state.duplicate_state()
	undo_stack = []
	_finish_turn()


## Shared tail of every state transition: recompute the outcome, emit both
## signals (state_updated before outcome_updated, same order every path
## used before this was factored out), and fire the win/loss sound hook.
## A level can report a terminal outcome immediately on load (see
## tests/test_game_controller.gd) - going through this same path from
## load_level() means that case fires SoundHooks.on_loss() too, not just
## the ones reached via an actual move.
func _finish_turn() -> void:
	outcome = Rules.check_outcome(state)
	state_updated.emit()
	outcome_updated.emit(outcome)
	if outcome == Rules.Outcome.WIN:
		SoundHooks.on_win()
	elif outcome != Rules.Outcome.ONGOING:
		SoundHooks.on_loss()
