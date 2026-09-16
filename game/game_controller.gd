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


func try_move(piece_id: int, dest: Vector2i) -> bool:
	if outcome != Rules.Outcome.ONGOING:
		return false
	undo_stack.append(state.duplicate_state())
	var piece_before: Piece = state.get_piece(piece_id)
	var kind_before: PieceKind.Kind = piece_before.kind
	var piece_count_before: int = state.pieces.size()

	var applied: bool = Rules.apply_move(state, piece_id, dest)
	if not applied:
		undo_stack.pop_back()
		return false

	SoundHooks.on_move()
	if state.pieces.size() < piece_count_before:
		SoundHooks.on_capture()
	if state.get_piece(piece_id).kind != kind_before:
		SoundHooks.on_promotion()

	# Only let the enemy team act if the player's own move didn't already
	# end the game (e.g. reaching the goal row) - checked directly rather
	# than through _finish_turn(), which is called once at the end so
	# outcome is computed and both signals emitted exactly once per
	# try_move(), reflecting the enemy turn's effect too.
	if Rules.check_outcome(state) == Rules.Outcome.ONGOING:
		var count_before_enemy_turn: int = state.pieces.size()
		Rules.advance_enemies(state, enemy_turn_mode)
		if state.pieces.size() < count_before_enemy_turn:
			SoundHooks.on_capture()

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
