extends TestCase

## Regression tests for load_level()/restart() computing outcome from state
## instead of hardcoding ONGOING - a level whose initial state is already
## terminal (here: zero move budget, so moves_used >= move_budget the moment
## it loads) must report that outcome immediately, not ONGOING.


static func _instant_loss_level() -> Level:
	var level: Level = Level.new()
	level.level_name = "Instant Loss"
	level.width = 4
	level.height = 4
	level.move_budget = 0
	level.players = [{"kind": PieceKind.Kind.PAWN, "pos": Vector2i(0, 0)}]
	level.walls = []
	level.powerups = []
	level.enemies = []
	return level


func test_load_level_reports_terminal_outcome_immediately() -> bool:
	var controller: GameController = GameController.new()
	controller.load_level(_instant_loss_level())
	return assert_eq(controller.outcome, Rules.Outcome.LOSS_NO_MOVES,
		"a level that starts already exhausted should not report ONGOING")


func test_restart_reports_terminal_outcome_immediately() -> bool:
	var controller: GameController = GameController.new()
	controller.load_level(_instant_loss_level())
	# Force outcome away from the value under test, so restart() actually has
	# to recompute it rather than coincidentally leaving it correct.
	controller.outcome = Rules.Outcome.ONGOING
	controller.restart()
	return assert_eq(controller.outcome, Rules.Outcome.LOSS_NO_MOVES,
		"restart() should recompute outcome from the reloaded state, not hardcode ONGOING")


## Regression test for a real reported bug: a knight's own capture-or-
## approach heuristic can land it directly ahead of the player's pawn -
## blocking its only forward move without threatening it, since that
## relative position is never a legal knight move. try_move() used to
## declare an instant loss the moment the player had no legal move right
## then, without giving the blocking knight a chance to move off on its
## own very next turn (it has no "stay put" option). This level is tuned
## so the knight's single best move after the pawn's first move is to
## land exactly one square ahead of it.
static func _knight_blocks_but_can_move_off_level() -> Level:
	var level: Level = Level.new()
	level.level_name = "Knight Blocks"
	level.width = 4
	level.height = 12
	level.move_budget = 20
	level.players = [{"kind": PieceKind.Kind.PAWN, "pos": Vector2i(1, 4)}]
	level.walls = []
	level.powerups = []
	level.enemies = [{"kind": PieceKind.Kind.KNIGHT, "pos": Vector2i(2, 8)}]
	return level


func test_try_move_does_not_end_the_game_when_a_blocking_enemy_can_still_move_off() -> bool:
	var controller: GameController = GameController.new()
	controller.load_level(_knight_blocks_but_can_move_off_level())
	var pawn_id: int = controller.state.get_player_pieces()[0].id

	var moved: bool = controller.try_move(pawn_id, Vector2i(1, 5))
	if not assert_true(moved, "the pawn's first move should be legal"):
		return false
	if not assert_eq(controller.outcome, Rules.Outcome.ONGOING,
		"a non-capturing block should resolve itself instead of ending the game"):
		return false
	return assert_false(controller.get_legal_moves(pawn_id).is_empty(),
		"the pawn should have a legal move again once the knight moved off")


## Regression test for the reported bug, as played: 04_point_of_no_return
## has the player pick up a Promote card and then step into the square
## below a wall. try_move() used to end the game right there - no legal
## move, LOSS_NO_MOVES - and try_play_card() then refused the card
## because the game was over, so the level was unwinnable by that route.
## Hitting a wall with a card that changes your form is a turn to think,
## not a defeat.
static func _walled_in_with_a_card_level() -> Level:
	var level: Level = Level.new()
	level.level_name = "Walled In"
	level.width = 4
	level.height = 12
	level.move_budget = 10
	level.players = [{"kind": PieceKind.Kind.PAWN, "pos": Vector2i(1, 0)}]
	level.walls = [Vector2i(1, 3)]
	level.powerups = [{"pos": Vector2i(1, 1), "type": Rules.CARD_PROMOTE}]
	level.enemies = []
	return level


func test_try_move_into_a_wall_is_not_a_loss_while_a_card_can_change_form() -> bool:
	var controller: GameController = GameController.new()
	controller.load_level(_walled_in_with_a_card_level())
	var pawn_id: int = controller.state.get_player_pieces()[0].id
	controller.try_move(pawn_id, Vector2i(1, 1))   # picks up the Promote card
	controller.try_move(pawn_id, Vector2i(1, 2))   # nose against the wall

	if not assert_true(controller.get_legal_moves(pawn_id).is_empty(), "the pawn has no move of its own here"):
		return false
	if not assert_eq(controller.outcome, Rules.Outcome.ONGOING,
		"a wall in front of a piece holding a Promote card is not the end of the game"):
		return false
	if not assert_true(controller.try_play_card(Rules.CARD_PROMOTE, pawn_id),
		"the card the player is holding should still be playable"):
		return false
	return assert_false(controller.get_legal_moves(pawn_id).is_empty(),
		"promoting the blocked pawn to a knight gives it moves around the wall")


## The reprieve lasts exactly one card. Spend it on something that
## doesn't help - Push Back with no enemies to push - and the same
## position is the loss it always was, on the very next state update.
func test_a_spent_card_that_did_not_help_still_ends_the_game() -> bool:
	var controller: GameController = GameController.new()
	controller.load_level(_walled_in_with_a_card_level())
	var pawn_id: int = controller.state.get_player_pieces()[0].id
	controller.state.player_hand.append(Rules.CARD_PUSH_BACK)
	controller.try_move(pawn_id, Vector2i(1, 1))
	controller.try_move(pawn_id, Vector2i(1, 2))

	if not assert_true(controller.try_play_card(Rules.CARD_PUSH_BACK), "Push Back is in hand and playable"):
		return false
	return assert_eq(controller.outcome, Rules.Outcome.LOSS_NO_MOVES,
		"still stuck with this turn's card play spent - that is a real dead end")
