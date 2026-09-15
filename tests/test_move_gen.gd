extends TestCase


func _empty_board() -> BoardState:
	return BoardState.new(4, 12)


func test_pawn_moves_one_step_forward() -> bool:
	var state: BoardState = _empty_board()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	pawn.has_moved = true
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [Vector2i(1, 6)], "pawn forward move")


func test_pawn_blocked_by_edge() -> bool:
	var state: BoardState = _empty_board()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 11))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [], "pawn at top edge has no forward move")


func test_pawn_blocked_by_piece() -> bool:
	var state: BoardState = _empty_board()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 6))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [], "pawn cannot capture forward")


func test_pawn_first_move_can_advance_two_squares() -> bool:
	var state: BoardState = _empty_board()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [Vector2i(1, 1), Vector2i(1, 2)], "pawn first move: one or two squares")


func test_pawn_cannot_double_move_after_moving() -> bool:
	var state: BoardState = _empty_board()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	Rules.apply_move(state, pawn.id, Vector2i(1, 1))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [Vector2i(1, 2)], "pawn only one square after its first move")


func test_pawn_double_move_blocked_by_wall_on_second_square() -> bool:
	var state: BoardState = _empty_board()
	state.walls[Vector2i(1, 2)] = true
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [Vector2i(1, 1)], "pawn cannot leap a wall on the second square")


func test_pawn_double_move_blocked_by_piece_on_second_square() -> bool:
	var state: BoardState = _empty_board()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 2))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, pawn.id)
	return assert_array_eq_unordered(moves, [Vector2i(1, 1)], "pawn cannot leap a piece on the second square")


func test_knight_moves_on_4_wide_board() -> bool:
	var state: BoardState = _empty_board()
	var knight: Piece = state.add_piece(PieceKind.Kind.KNIGHT, 0, Vector2i(1, 5))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, knight.id)
	var expected: Array[Vector2i] = [
		Vector2i(2, 7), Vector2i(0, 7), Vector2i(2, 3), Vector2i(0, 3),
		Vector2i(3, 6), Vector2i(3, 4),
	]
	return assert_array_eq_unordered(moves, expected, "knight offsets clipped to 4-wide board")


func test_knight_corner_clipping() -> bool:
	var state: BoardState = _empty_board()
	var knight: Piece = state.add_piece(PieceKind.Kind.KNIGHT, 0, Vector2i(0, 0))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, knight.id)
	var expected: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1)]
	return assert_array_eq_unordered(moves, expected, "knight in corner")


func test_bishop_diagonal_rays() -> bool:
	var state: BoardState = _empty_board()
	var bishop: Piece = state.add_piece(PieceKind.Kind.BISHOP, 0, Vector2i(1, 5))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, bishop.id)
	var expected: Array[Vector2i] = [
		Vector2i(2, 6), Vector2i(3, 7),
		Vector2i(0, 6),
		Vector2i(2, 4), Vector2i(3, 3),
		Vector2i(0, 4),
	]
	return assert_array_eq_unordered(moves, expected, "bishop diagonal rays on empty board")


func test_rook_orthogonal_rays() -> bool:
	var state: BoardState = _empty_board()
	var rook: Piece = state.add_piece(PieceKind.Kind.ROOK, 0, Vector2i(1, 5))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, rook.id)
	if moves.size() != (3 + 11):
		last_error = "expected 14 rook moves on empty 4x12 board, got %d" % moves.size()
		return false
	return assert_has(moves, Vector2i(0, 5)) and assert_has(moves, Vector2i(3, 5)) and assert_has(moves, Vector2i(1, 11)) and assert_has(moves, Vector2i(1, 0))


func test_rook_blocked_by_wall() -> bool:
	var state: BoardState = _empty_board()
	var rook: Piece = state.add_piece(PieceKind.Kind.ROOK, 0, Vector2i(1, 5))
	state.walls[Vector2i(1, 7)] = true
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, rook.id)
	if not assert_not_has(moves, Vector2i(1, 7), "wall itself is not a legal destination"):
		return false
	if not assert_not_has(moves, Vector2i(1, 8), "cannot slide past a wall"):
		return false
	return assert_has(moves, Vector2i(1, 6), "can still reach the square before the wall")


func test_rook_blocked_by_friendly_piece() -> bool:
	var state: BoardState = _empty_board()
	var rook: Piece = state.add_piece(PieceKind.Kind.ROOK, 0, Vector2i(1, 5))
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 7))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, rook.id)
	if not assert_not_has(moves, Vector2i(1, 7), "cannot land on a friendly piece"):
		return false
	return assert_not_has(moves, Vector2i(1, 8), "cannot slide past a friendly piece")


func test_rook_captures_first_enemy_in_ray() -> bool:
	var state: BoardState = _empty_board()
	var rook: Piece = state.add_piece(PieceKind.Kind.ROOK, 0, Vector2i(1, 5))
	state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 7))
	state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 9))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, rook.id)
	if not assert_has(moves, Vector2i(1, 7), "can capture the first enemy in the ray"):
		return false
	return assert_not_has(moves, Vector2i(1, 9), "cannot capture past the first enemy")


func test_queen_combines_rook_and_bishop() -> bool:
	var state: BoardState = _empty_board()
	var queen: Piece = state.add_piece(PieceKind.Kind.QUEEN, 0, Vector2i(1, 5))
	var moves: Array[Vector2i] = MoveGen.legal_moves(state, queen.id)
	return assert_has(moves, Vector2i(0, 5)) and assert_has(moves, Vector2i(2, 6))


func test_threatened_squares_from_enemy_rook() -> bool:
	var state: BoardState = _empty_board()
	state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 5))
	var threatened: Dictionary = MoveGen.threatened_squares(state, 1)
	return assert_has(threatened, Vector2i(1, 6)) and assert_has(threatened, Vector2i(0, 5))
