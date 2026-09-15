extends Node2D

const LEVEL_PATH: String = "res://levels/01_first_steps.json"
const DESIGN_SIZE: Vector2 = Vector2(480, 800)

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

	_center_in_safe_area()


# window/stretch/aspect is "expand", which fills the whole screen (no
# letterbox bars) but reveals more canvas than the 480x800 design size on
# any device whose aspect ratio doesn't exactly match, anchored at the
# top-left by default. On an iPhone with a notch/Dynamic Island, that
# leaves the design canvas's origin - where the HUD and top board row both
# sit - directly under the safe-area cutout, clipped. Centering everything
# in the safe area (not just the full screen) fixes both: the content
# moves clear of the notch, and any extra revealed space is split evenly
# top/bottom instead of dumped entirely below.
func _center_in_safe_area() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return

	# get_display_safe_area() is reported in absolute screen coordinates,
	# not window-relative - only meaningful to compare against window_size
	# when the window genuinely occupies the whole screen (always true on
	# iOS; only sometimes true testing windowed on desktop, where comparing
	# the two would produce a nonsense ratio). Fall back to plain centering
	# with zero insets otherwise.
	var top_inset: float = 0.0
	var bottom_inset: float = 0.0
	if window_size == DisplayServer.screen_get_size():
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		top_inset = (float(safe_area.position.y) / window_size.y) * viewport_size.y
		bottom_inset = (float(window_size.y - (safe_area.position.y + safe_area.size.y)) / window_size.y) * viewport_size.y

	var usable_height: float = viewport_size.y - top_inset - bottom_inset
	var offset_y: float = top_inset + (usable_height - DESIGN_SIZE.y) / 2.0

	$BoardRoot.position.y = offset_y
	$UI.offset.y = offset_y


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
