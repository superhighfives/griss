class_name GameController
extends RefCounted

signal state_updated
signal outcome_updated(outcome: Rules.Outcome)

var state: BoardState
var initial_state: BoardState
var undo_stack: Array[BoardState] = []
var outcome: Rules.Outcome = Rules.Outcome.ONGOING


func load_level(level: Level) -> void:
	state = level.to_board_state()
	initial_state = state.duplicate_state()
	undo_stack = []
	outcome = Rules.check_outcome(state)
	state_updated.emit()
	outcome_updated.emit(outcome)


func get_legal_moves(piece_id: int) -> Array[Vector2i]:
	if outcome != Rules.Outcome.ONGOING:
		return []
	return MoveGen.legal_moves(state, piece_id)


func try_move(piece_id: int, dest: Vector2i) -> bool:
	if outcome != Rules.Outcome.ONGOING:
		return false
	undo_stack.append(state.duplicate_state())
	var applied: bool = Rules.apply_move(state, piece_id, dest)
	if not applied:
		undo_stack.pop_back()
		return false
	outcome = Rules.check_outcome(state)
	state_updated.emit()
	outcome_updated.emit(outcome)
	return true


func undo() -> void:
	if undo_stack.is_empty():
		return
	state = undo_stack.pop_back()
	outcome = Rules.check_outcome(state)
	state_updated.emit()
	outcome_updated.emit(outcome)


func restart() -> void:
	state = initial_state.duplicate_state()
	undo_stack = []
	outcome = Rules.check_outcome(state)
	state_updated.emit()
	outcome_updated.emit(outcome)
