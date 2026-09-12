extends Node2D

const LEVEL_PATH: String = "res://levels/01_first_steps.json"

var controller: GameController
var board_view: BoardView
var input_controller: InputController
var hud: Hud
var selected_piece_id: int = -1


func _ready() -> void:
	var level: Level = LevelLoader.load_from_file(LEVEL_PATH)
	if level == null:
		push_error("Failed to load level %s: bad field '%s'" % [LEVEL_PATH, LevelLoader.last_error])
		return

	controller = GameController.new()
	controller.load_level(level)

	board_view = BoardView.new()
	$BoardRoot.add_child(board_view)
	board_view.setup(controller)

	input_controller = InputController.new()
	input_controller.setup(board_view)
	add_child(input_controller)
	input_controller.cell_clicked.connect(_on_cell_clicked)

	hud = Hud.new()
	$UI.add_child(hud)
	hud.setup(controller, level.level_name)

	controller.state_updated.connect(board_view.refresh)
	controller.outcome_updated.connect(_on_outcome_updated)


func _on_cell_clicked(pos: Vector2i) -> void:
	if controller.outcome != Rules.Outcome.ONGOING:
		return
	var player: Piece = controller.state.get_player_piece()
	if player == null:
		return

	if selected_piece_id == -1:
		if player.pos == pos:
			selected_piece_id = player.id
			board_view.show_highlights(controller.get_legal_moves(player.id))
		return

	var legal: Array[Vector2i] = controller.get_legal_moves(selected_piece_id)
	if legal.has(pos):
		controller.try_move(selected_piece_id, pos)
		selected_piece_id = -1
	elif player.pos == pos:
		board_view.show_highlights(controller.get_legal_moves(player.id))
	else:
		selected_piece_id = -1
		board_view.clear_highlights()


func _on_outcome_updated(outcome: Rules.Outcome) -> void:
	if outcome != Rules.Outcome.ONGOING:
		selected_piece_id = -1
		board_view.clear_highlights()
