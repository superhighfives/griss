extends TestCase


func test_trivial_sanity() -> bool:
	return assert_eq(1 + 1, 2, "sanity check")


func test_duplicate_state_is_deep_copy_of_pieces() -> bool:
	var state: BoardState = BoardState.new(4, 12)
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var copy: BoardState = state.duplicate_state()

	var copy_pawn: Piece = copy.get_piece(pawn.id)
	copy_pawn.pos = Vector2i(2, 2)
	copy_pawn.kind = PieceKind.Kind.QUEEN

	if not assert_eq(pawn.pos, Vector2i(1, 0), "original piece position untouched"):
		return false
	return assert_eq(pawn.kind, PieceKind.Kind.PAWN, "original piece kind untouched")


func test_duplicate_state_is_deep_copy_of_walls_and_powerups() -> bool:
	var state: BoardState = BoardState.new(4, 12)
	state.walls[Vector2i(0, 0)] = true
	state.powerups[Vector2i(1, 1)] = "promote"
	var copy: BoardState = state.duplicate_state()

	copy.walls[Vector2i(3, 3)] = true
	copy.powerups.erase(Vector2i(1, 1))

	if not assert_not_has(state.walls, Vector2i(3, 3), "original walls untouched by copy mutation"):
		return false
	return assert_has(state.powerups, Vector2i(1, 1), "original powerups untouched by copy mutation")


func test_duplicate_state_adding_piece_does_not_affect_original() -> bool:
	var state: BoardState = BoardState.new(4, 12)
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var copy: BoardState = state.duplicate_state()

	copy.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(2, 2))

	return assert_eq(state.pieces.size(), 1, "adding to the copy does not grow the original")
