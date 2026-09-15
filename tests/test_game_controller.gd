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
	level.player_kind = PieceKind.Kind.PAWN
	level.player_pos = Vector2i(0, 0)
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
