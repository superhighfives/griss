extends TestCase

## Regression tests for tween ownership in game/board_view.gd.
##
## The bug these cover: _pulse_highlight() built its looping tween with
## self.create_tween(), which binds the tween to BoardView rather than to the
## highlight ColorRect it animates. clear_highlights() queue_free()s the
## highlights but BoardView survives every move, so each selection left behind
## an infinite tween stepping a freed target. A PropertyTweener whose target is
## gone returns without consuming any delta, so Tween::step() loops forever.
## Debug builds detect that and bail out ("Infinite loop detected"), which is
## why it survived editor testing; export templates compile the check out
## (#ifdef DEBUG_ENABLED), so release iOS builds hung the main thread on the
## first frame after a move and the watchdog killed the app.
##
## Both tests assert ownership through its observable consequence: a tween
## bound to a node is paused while that node is outside the tree. Detach only
## the animated node, leave BoardView in the tree, and let real frames pass -
## a correctly bound tween freezes, a BoardView-bound one keeps animating.
## Counting SceneTree.get_processed_tweens() can't be used here: the debug
## build's own infinite-loop guard reaps the orphans, hiding the leak.
##
## These are coroutines, since a bound tween only steps while its node is
## inside the tree and frames are being processed - neither is true during
## SceneTree._initialize(). See tests/run_tests.gd.

## Comfortably longer than MOVE_TWEEN_DURATION and a visible slice of the
## highlight pulse, so an unfrozen tween is guaranteed to have moved.
const SETTLE_SECONDS: float = 0.25


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## A BoardView attached to the tree (create_tween() requires that), wired to
## `level` exactly as main.gd wires it. Caller is responsible for _teardown().
static func _make_board_view(level: Level) -> BoardView:
	var controller: GameController = GameController.new()
	controller.load_level(level)
	var board_view: BoardView = BoardView.new()
	_tree().root.add_child(board_view)
	board_view.setup(controller)
	controller.state_updated.connect(board_view.refresh)
	return board_view


static func _teardown(board_view: BoardView, detached: Node) -> void:
	if detached != null:
		detached.free()
	_tree().root.remove_child(board_view)
	board_view.free()


static func _capture_level() -> Level:
	var level: Level = Level.new()
	level.level_name = "Capture"
	level.width = 4
	level.height = 4
	level.move_budget = 10
	level.player_kind = PieceKind.Kind.ROOK
	level.player_pos = Vector2i(0, 0)
	level.walls = []
	level.powerups = []
	level.enemies = []
	return level


func test_highlight_pulse_tween_is_bound_to_its_highlight() -> bool:
	var level: Level = LevelLoader.load_from_file("res://levels/01_first_steps.json")
	var board_view: BoardView = _make_board_view(level)
	await _tree().process_frame

	var cells: Array[Vector2i] = [Vector2i(1, 1)]
	board_view.show_highlights(cells)
	await _tree().process_frame

	var highlight: ColorRect = board_view._highlight_nodes[0]
	board_view.remove_child(highlight)
	var alpha_at_detach: float = highlight.color.a

	await _tree().create_timer(SETTLE_SECONDS).timeout
	var alpha_after: float = highlight.color.a
	_teardown(board_view, highlight)

	return assert_eq(alpha_after, alpha_at_detach,
		"the pulse tween kept animating a highlight that had left the tree, so it is bound to BoardView, not to the highlight - it will outlive clear_highlights() and spin forever on a freed target")


func test_piece_move_tween_is_bound_to_its_piece() -> bool:
	var board_view: BoardView = _make_board_view(_capture_level())
	await _tree().process_frame

	var controller: GameController = board_view.controller
	var player: Piece = controller.state.get_player_piece()
	var body: ColorRect = board_view._piece_nodes[player.id]

	# try_move() refreshes the view, which starts the position tween.
	var moved: bool = controller.try_move(player.id, Vector2i(0, 2))
	board_view.remove_child(body)
	var position_at_detach: Vector2 = body.position

	await _tree().create_timer(SETTLE_SECONDS).timeout
	var position_after: Vector2 = body.position
	_teardown(board_view, body)

	if not assert_true(moved, "the rook should be able to move straight ahead"):
		return false
	return assert_eq(position_after, position_at_detach,
		"the move tween kept animating a piece that had left the tree, so it is bound to BoardView, not to the piece it animates")
