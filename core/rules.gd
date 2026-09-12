class_name Rules
extends RefCounted

enum Outcome { ONGOING, WIN, LOSS_THREATENED, LOSS_NO_MOVES }


## Applies a move for the player piece to `dest` in place, mutating `state`.
## Caller is responsible for snapshotting state beforehand if undo is needed.
## Returns true if the move was legal and applied.
static func apply_move(state: BoardState, piece_id: int, dest: Vector2i) -> bool:
	var piece: Piece = state.get_piece(piece_id)
	if piece == null:
		return false
	var legal: Array[Vector2i] = MoveGen.legal_moves(state, piece_id)
	if not legal.has(dest):
		return false

	var occupant: Piece = state.piece_at(dest)
	if occupant != null and occupant.team != piece.team:
		state.remove_piece(occupant.id)

	piece.pos = dest
	state.moves_used += 1

	if piece.team == 0 and state.powerups.has(dest):
		var powerup_type: String = state.powerups[dest]
		if powerup_type == "promote":
			piece.kind = PieceKind.next_in_promotion_track(piece.kind)
		state.powerups.erase(dest)

	return true


## No-op in the MVP; enemies never move. Left as the hook for M2's enemy phase.
static func advance_enemies(state: BoardState) -> void:
	pass


static func check_outcome(state: BoardState) -> Outcome:
	var player: Piece = state.get_player_piece()
	if player == null:
		return Outcome.LOSS_NO_MOVES

	if player.pos.y == state.goal_row:
		return Outcome.WIN

	var threatened: Dictionary = MoveGen.threatened_squares(state, 1)
	if threatened.has(player.pos):
		return Outcome.LOSS_THREATENED

	if state.moves_used >= state.move_budget:
		return Outcome.LOSS_NO_MOVES

	if MoveGen.legal_moves(state, player.id).is_empty():
		return Outcome.LOSS_NO_MOVES

	return Outcome.ONGOING
