extends TestCase


func _fresh_state(width: int = 4, height: int = 12, budget: int = 20) -> BoardState:
	var state: BoardState = BoardState.new(width, height)
	state.move_budget = budget
	return state


func test_apply_move_advances_pawn_and_counts_move() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var applied: bool = Rules.apply_move(state, pawn.id, Vector2i(1, 1))
	if not assert_true(applied, "legal move should apply"):
		return false
	if not assert_eq(pawn.pos, Vector2i(1, 1), "pawn position updated"):
		return false
	return assert_eq(state.moves_used, 1, "moves_used incremented")


func test_apply_move_rejects_illegal_destination() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var applied: bool = Rules.apply_move(state, pawn.id, Vector2i(3, 3))
	if not assert_false(applied, "illegal move should not apply"):
		return false
	return assert_eq(state.moves_used, 0, "moves_used unchanged on rejected move")


func test_apply_move_captures_enemy_in_path() -> bool:
	var state: BoardState = _fresh_state()
	var rook: Piece = state.add_piece(PieceKind.Kind.ROOK, 0, Vector2i(1, 0))
	var enemy: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 3))
	var applied: bool = Rules.apply_move(state, rook.id, Vector2i(1, 3))
	if not assert_true(applied, "capture move should apply"):
		return false
	return assert_null(state.get_piece(enemy.id), "captured enemy removed from state")


func test_apply_move_does_not_count_enemy_moves_against_budget() -> bool:
	var state: BoardState = _fresh_state()
	var enemy: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 5))
	Rules.apply_move(state, enemy.id, Vector2i(1, 8))
	return assert_eq(state.moves_used, 0, "only player (team 0) moves count against move_budget")


func test_promotion_track_advances_and_consumes_tile() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	state.powerups[Vector2i(1, 1)] = "promote"
	Rules.apply_move(state, pawn.id, Vector2i(1, 1))
	if not assert_eq(pawn.kind, PieceKind.Kind.KNIGHT, "pawn promotes to knight"):
		return false
	return assert_not_has(state.powerups, Vector2i(1, 1), "powerup tile consumed")


func test_promotion_track_full_sequence() -> bool:
	var sequence: Array[PieceKind.Kind] = [
		PieceKind.Kind.PAWN, PieceKind.Kind.KNIGHT, PieceKind.Kind.BISHOP,
		PieceKind.Kind.ROOK, PieceKind.Kind.QUEEN,
	]
	for i in range(sequence.size() - 1):
		if not assert_eq(PieceKind.next_in_promotion_track(sequence[i]), sequence[i + 1], "step %d" % i):
			return false
	return true


func test_promotion_queen_is_terminal() -> bool:
	var state: BoardState = _fresh_state()
	var queen: Piece = state.add_piece(PieceKind.Kind.QUEEN, 0, Vector2i(1, 0))
	state.powerups[Vector2i(1, 1)] = "promote"
	Rules.apply_move(state, queen.id, Vector2i(1, 1))
	if not assert_eq(queen.kind, PieceKind.Kind.QUEEN, "queen stays queen"):
		return false
	return assert_not_has(state.powerups, Vector2i(1, 1), "tile still consumed on terminal promotion")


func test_outcome_ongoing() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.ONGOING, "ongoing on a fresh board")


func test_outcome_win_on_goal_row() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, state.goal_row))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.WIN, "win when on goal row")


## Was LOSS_THREATENED before M5 (plans/done/m5-sacrifice.md): standing on
## a square an enemy could reach was instant death, because a static
## enemy had no other way to pose a threat. Enemies now actually move and
## capture (Rules.advance_enemies()), so this is a real risk the player
## can choose to take - not a rule that ends the game by itself.
func test_being_on_a_threatened_square_is_not_instant_loss() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 8))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.ONGOING, "threatened is not, by itself, a loss")


func test_outcome_win_if_any_player_piece_on_goal_row() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(0, 0))
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, state.goal_row))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.WIN, "any player piece reaching the goal row wins")


func test_outcome_loss_eliminated_when_no_player_pieces_remain() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(2, 2))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.LOSS_ELIMINATED, "no player pieces left is a loss")


func test_outcome_ongoing_if_any_player_piece_has_legal_moves() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 6))  # stuck: blocked ahead
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(2, 5))  # free to move
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.ONGOING, "ongoing while at least one player piece can still move")


func test_outcome_loss_no_moves_budget_exhausted() -> bool:
	var state: BoardState = _fresh_state(4, 12, 0)
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.LOSS_NO_MOVES, "loss when budget exhausted")


func test_outcome_loss_no_moves_stuck() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 6))
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.LOSS_NO_MOVES, "loss when no legal moves remain")


func test_threat_squares_computed_per_enemy_kind() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.KNIGHT, 1, Vector2i(1, 5))
	var threatened: Dictionary = MoveGen.threatened_squares(state, 1)
	return assert_has(threatened, Vector2i(2, 7), "knight enemy threatens its offsets")


func test_advance_enemies_captures_if_available() -> bool:
	var state: BoardState = _fresh_state()
	var player: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	var enemy: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 8))
	Rules.advance_enemies(state)
	if not assert_null(state.get_piece(player.id), "player piece captured"):
		return false
	return assert_eq(enemy.pos, Vector2i(1, 5), "enemy moved onto the captured square")


func test_advance_enemies_closes_distance_when_no_capture_available() -> bool:
	var state: BoardState = _fresh_state(6, 6, 20)
	var player: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var enemy: Piece = state.add_piece(PieceKind.Kind.KNIGHT, 1, Vector2i(3, 5))
	var distance_before: int = abs(enemy.pos.x - player.pos.x) + abs(enemy.pos.y - player.pos.y)
	Rules.advance_enemies(state)
	var distance_after: int = abs(enemy.pos.x - player.pos.x) + abs(enemy.pos.y - player.pos.y)
	if not assert_not_null(state.get_piece(player.id), "player was not captured (no capturing move existed)"):
		return false
	return assert_true(distance_after < distance_before, "enemy moved closer to the only player piece")


func test_advance_enemies_all_mode_moves_every_enemy() -> bool:
	var state: BoardState = _fresh_state(6, 6, 20)
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(0, 0))
	var enemy_a: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(5, 5))
	var enemy_b: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(4, 4))
	Rules.advance_enemies(state, Rules.ENEMY_TURN_MODE_ALL)
	if not assert_true(enemy_a.pos != Vector2i(5, 5), "first enemy acted"):
		return false
	return assert_true(enemy_b.pos != Vector2i(4, 4), "second enemy also acted")


func test_advance_enemies_one_mode_moves_exactly_one_enemy() -> bool:
	var state: BoardState = _fresh_state(6, 6, 20)
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(0, 0))
	var enemy_a: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(5, 5))
	var enemy_b: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(4, 4))
	Rules.advance_enemies(state, Rules.ENEMY_TURN_MODE_ONE)
	var a_moved: bool = enemy_a.pos != Vector2i(5, 5)
	var b_moved: bool = enemy_b.pos != Vector2i(4, 4)
	return assert_true(a_moved != b_moved, "exactly one enemy should act in \"one\" mode")
