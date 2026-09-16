class_name MoveGen
extends RefCounted

## Legal destination squares for the piece with the given id.
## Sliding pieces stop before a wall or a piece; they may capture the first
## enemy piece encountered in a ray, but never pass through anything.
static func legal_moves(state: BoardState, piece_id: int) -> Array[Vector2i]:
	var piece: Piece = state.get_piece(piece_id)
	if piece == null:
		return []
	return _moves_for(state, piece)


## All squares any piece on `team` could legally move to right now.
## Used to compute threat squares (call with the opposing team).
static func threatened_squares(state: BoardState, team: int) -> Dictionary:
	var threatened: Dictionary = {}
	for piece in state.pieces:
		if piece.team != team:
			continue
		for move in _moves_for(state, piece):
			threatened[move] = true
	return threatened


static func _moves_for(state: BoardState, piece: Piece) -> Array[Vector2i]:
	match piece.kind:
		PieceKind.Kind.PAWN:
			return _pawn_moves(state, piece)
		PieceKind.Kind.KNIGHT:
			return _offset_moves(state, piece, PieceKind.KNIGHT_OFFSETS)
		PieceKind.Kind.BISHOP:
			return _sliding_moves(state, piece, PieceKind.DIAGONAL_DIRS)
		PieceKind.Kind.ROOK:
			return _sliding_moves(state, piece, PieceKind.ORTHOGONAL_DIRS)
		PieceKind.Kind.QUEEN:
			return _sliding_moves(state, piece, PieceKind.DIAGONAL_DIRS + PieceKind.ORTHOGONAL_DIRS)
		_:
			return []


static func _forward_dir(team: int) -> int:
	# Player (team 0) advances toward +y (the goal row); enemies face the opposite way.
	return 1 if team == 0 else -1


static func _pawn_moves(state: BoardState, piece: Piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var dir: int = _forward_dir(piece.team)

	var one_step: Vector2i = piece.pos + Vector2i(0, dir)
	if state.is_in_bounds(one_step) and not state.is_wall(one_step) and state.piece_at(one_step) == null:
		moves.append(one_step)

		# Two-square advance, chess rules: only before the pawn's first
		# move, and only if both squares ahead are clear - it can't jump
		# over an occupant. Nested under the one-step check (rather than
		# an early return like before diagonal capture existed) because a
		# pawn blocked straight ahead should still be able to capture
		# diagonally - only the forward advance is blocked, not the whole
		# turn.
		if not piece.has_moved:
			var two_step: Vector2i = piece.pos + Vector2i(0, dir * 2)
			if state.is_in_bounds(two_step) and not state.is_wall(two_step) and state.piece_at(two_step) == null:
				moves.append(two_step)

	# Diagonal capture, chess rules: only onto a square actually occupied
	# by an enemy - pawns can never move diagonally to an empty square.
	for dx in [-1, 1]:
		var diagonal: Vector2i = piece.pos + Vector2i(dx, dir)
		if not state.is_in_bounds(diagonal) or state.is_wall(diagonal):
			continue
		var occupant: Piece = state.piece_at(diagonal)
		if occupant != null and occupant.team != piece.team:
			moves.append(diagonal)

	return moves


static func _offset_moves(state: BoardState, piece: Piece, offsets: Array[Vector2i]) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for offset in offsets:
		var dest: Vector2i = piece.pos + offset
		if not state.is_in_bounds(dest) or state.is_wall(dest):
			continue
		var occupant: Piece = state.piece_at(dest)
		if occupant != null and occupant.team == piece.team:
			continue
		moves.append(dest)
	return moves


static func _sliding_moves(state: BoardState, piece: Piece, dirs: Array[Vector2i]) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for dir in dirs:
		var dest: Vector2i = piece.pos + dir
		while state.is_in_bounds(dest) and not state.is_wall(dest):
			var occupant: Piece = state.piece_at(dest)
			if occupant != null:
				if occupant.team != piece.team:
					moves.append(dest)
				break
			moves.append(dest)
			dest += dir
	return moves
