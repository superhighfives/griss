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


func test_powerup_pickup_adds_card_to_hand() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	state.powerups[Vector2i(1, 1)] = "promote"
	Rules.apply_move(state, pawn.id, Vector2i(1, 1))
	if not assert_eq(pawn.kind, PieceKind.Kind.PAWN, "picking up the tile does not promote by itself"):
		return false
	if not assert_has(state.player_hand, "promote", "tile grants a card"):
		return false
	return assert_not_has(state.powerups, Vector2i(1, 1), "powerup tile consumed")


func test_play_card_promote_advances_kind_and_consumes_card() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	state.player_hand = ["promote"]
	var applied: bool = Rules.play_card(state, Rules.CARD_PROMOTE, pawn.id)
	if not assert_true(applied, "play_card should succeed"):
		return false
	if not assert_eq(pawn.kind, PieceKind.Kind.KNIGHT, "pawn promotes to knight"):
		return false
	return assert_not_has(state.player_hand, "promote", "card consumed")


func test_play_card_fails_without_the_card_in_hand() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	return assert_false(Rules.play_card(state, Rules.CARD_PROMOTE, pawn.id), "cannot play a card not in hand")


func test_play_card_fails_after_a_card_already_played_this_turn() -> bool:
	var state: BoardState = _fresh_state()
	var pawn: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	state.player_hand = ["promote", "promote"]
	Rules.play_card(state, Rules.CARD_PROMOTE, pawn.id)
	return assert_false(Rules.play_card(state, Rules.CARD_PROMOTE, pawn.id), "only one card per turn, even with a spare copy in hand")


func test_play_card_promote_requires_a_player_piece_target() -> bool:
	var state: BoardState = _fresh_state()
	var enemy: Piece = state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(2, 2))
	state.player_hand = ["promote"]
	var applied: bool = Rules.play_card(state, Rules.CARD_PROMOTE, enemy.id)
	if not assert_false(applied, "cannot target an enemy piece"):
		return false
	return assert_has(state.player_hand, "promote", "failed play does not consume the card")


func test_play_card_push_back_moves_enemy_away_from_nearest_player() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var enemy: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 3))
	state.player_hand = ["push_back"]
	var applied: bool = Rules.play_card(state, Rules.CARD_PUSH_BACK)
	if not assert_true(applied, "play_card should succeed"):
		return false
	return assert_eq(enemy.pos, Vector2i(1, 4), "enemy pushed one square further from the player")


func test_play_card_push_back_skips_enemy_blocked_by_wall() -> bool:
	var state: BoardState = _fresh_state()
	state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 0))
	var enemy: Piece = state.add_piece(PieceKind.Kind.ROOK, 1, Vector2i(1, 3))
	state.walls[Vector2i(1, 4)] = true
	state.player_hand = ["push_back"]
	Rules.play_card(state, Rules.CARD_PUSH_BACK)
	return assert_eq(enemy.pos, Vector2i(1, 3), "enemy stays put when the push-back square is a wall")


func test_promotion_track_full_sequence() -> bool:
	var sequence: Array[PieceKind.Kind] = [
		PieceKind.Kind.PAWN, PieceKind.Kind.KNIGHT, PieceKind.Kind.BISHOP,
		PieceKind.Kind.ROOK, PieceKind.Kind.QUEEN,
	]
	for i in range(sequence.size() - 1):
		if not assert_eq(PieceKind.next_in_promotion_track(sequence[i]), sequence[i + 1], "step %d" % i):
			return false
	return true


func test_play_card_promote_queen_is_terminal() -> bool:
	var state: BoardState = _fresh_state()
	var queen: Piece = state.add_piece(PieceKind.Kind.QUEEN, 0, Vector2i(1, 0))
	state.player_hand = ["promote"]
	var applied: bool = Rules.play_card(state, Rules.CARD_PROMOTE, queen.id)
	if not assert_true(applied, "play_card should still succeed on a terminal target"):
		return false
	if not assert_eq(queen.kind, PieceKind.Kind.QUEEN, "queen stays queen"):
		return false
	return assert_not_has(state.player_hand, "promote", "card still consumed on a terminal promotion")


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


## A knight directly ahead of a pawn blocks its only forward move without
## threatening it (that exact relative position is never a legal knight
## move), so this isn't a real dead end - the knight itself has other
## legal moves and, having no "stay put" option, must take one on its own
## next turn. advance_enemies_and_resolve_stalemate() should let it,
## rather than the caller declaring an instant loss the moment the player
## has no move right this second.
func test_advance_enemies_and_resolve_stalemate_lets_blocking_knight_move_off() -> bool:
	var state: BoardState = _fresh_state()
	var player: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	var enemy: Piece = state.add_piece(PieceKind.Kind.KNIGHT, 1, Vector2i(1, 6))
	Rules.advance_enemies_and_resolve_stalemate(state)
	if not assert_not_null(state.get_piece(player.id), "player was never in capturing range, should survive"):
		return false
	if not assert_true(enemy.pos != Vector2i(1, 6), "the blocking knight had to move off on its own next turn"):
		return false
	return assert_false(MoveGen.legal_moves(state, player.id).is_empty(), "player regained a legal move once unblocked")


## A genuine deadlock - the enemy has no legal moves either - is not the
## same situation and must still end the game: nothing will ever change
## no matter how many more enemy turns are granted.
func test_advance_enemies_and_resolve_stalemate_stays_stuck_if_enemy_also_cannot_move() -> bool:
	var state: BoardState = _fresh_state()
	var player: Piece = state.add_piece(PieceKind.Kind.PAWN, 0, Vector2i(1, 5))
	var enemy: Piece = state.add_piece(PieceKind.Kind.PAWN, 1, Vector2i(1, 6))
	Rules.advance_enemies_and_resolve_stalemate(state)
	if not assert_eq(enemy.pos, Vector2i(1, 6), "an enemy with no legal moves of its own never moves"):
		return false
	return assert_eq(Rules.check_outcome(state), Rules.Outcome.LOSS_NO_MOVES, "a true deadlock is still a loss")
