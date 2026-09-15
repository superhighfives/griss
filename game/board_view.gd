class_name BoardView
extends Node2D

const CELL_SIZE: int = 60
const BOARD_OFFSET: Vector2 = Vector2(120, 60)
const CELL_MARGIN: float = 2.0
const PIECE_MARGIN: float = 8.0

const COLOR_CELL: Color = Color(0.22, 0.22, 0.26)
const COLOR_WALL: Color = Color(0.08, 0.08, 0.09)
const COLOR_GOAL: Color = Color(0.16, 0.34, 0.2)
const COLOR_PLAYER: Color = Color(0.2, 0.45, 0.9)
const COLOR_ENEMY: Color = Color(0.8, 0.2, 0.2)
const COLOR_HIGHLIGHT: Color = Color(1.0, 0.95, 0.3, 0.4)
const COLOR_THREAT: Color = Color(0.9, 0.15, 0.15, 0.35)

var controller: GameController
var _cell_nodes: Dictionary = {}
var _piece_nodes: Dictionary = {}
var _highlight_nodes: Array[ColorRect] = []
var _threat_nodes: Array[ColorRect] = []


func setup(p_controller: GameController) -> void:
	controller = p_controller
	_build_cells()
	_rebuild_threats()
	_rebuild_pieces()


func grid_to_screen(pos: Vector2i) -> Vector2:
	var height: int = controller.state.height
	return BOARD_OFFSET + Vector2(pos.x * CELL_SIZE, (height - 1 - pos.y) * CELL_SIZE)


func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - BOARD_OFFSET
	var grid_x: int = int(floor(local_pos.x / CELL_SIZE))
	var grid_y: int = controller.state.height - 1 - int(floor(local_pos.y / CELL_SIZE))
	return Vector2i(grid_x, grid_y)


func refresh() -> void:
	_rebuild_threats()
	_rebuild_pieces()
	clear_highlights()


func show_highlights(cells: Array[Vector2i]) -> void:
	clear_highlights()
	for pos in cells:
		var highlight: ColorRect = ColorRect.new()
		highlight.size = Vector2(CELL_SIZE - CELL_MARGIN, CELL_SIZE - CELL_MARGIN)
		highlight.position = grid_to_screen(pos)
		highlight.color = COLOR_HIGHLIGHT
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(highlight)
		_highlight_nodes.append(highlight)


func clear_highlights() -> void:
	for highlight in _highlight_nodes:
		highlight.queue_free()
	_highlight_nodes = []


## Squares any enemy could currently move/capture into - rebuilt on every
## refresh() (not tied to selection like show_highlights) so danger stays
## visible whether or not a piece is selected. Rebuilt before pieces each
## time so the tint sits under them, not over.
func _rebuild_threats() -> void:
	for threat in _threat_nodes:
		threat.queue_free()
	_threat_nodes = []
	var threatened: Dictionary = MoveGen.threatened_squares(controller.state, 1)
	for pos: Vector2i in threatened.keys():
		var threat: ColorRect = ColorRect.new()
		threat.size = Vector2(CELL_SIZE - CELL_MARGIN, CELL_SIZE - CELL_MARGIN)
		threat.position = grid_to_screen(pos)
		threat.color = COLOR_THREAT
		threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(threat)
		_threat_nodes.append(threat)


func _build_cells() -> void:
	for y in range(controller.state.height):
		for x in range(controller.state.width):
			var pos: Vector2i = Vector2i(x, y)
			var rect: ColorRect = ColorRect.new()
			rect.size = Vector2(CELL_SIZE - CELL_MARGIN, CELL_SIZE - CELL_MARGIN)
			rect.position = grid_to_screen(pos)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if controller.state.is_wall(pos):
				rect.color = COLOR_WALL
			elif pos.y == controller.state.goal_row:
				rect.color = COLOR_GOAL
			else:
				rect.color = COLOR_CELL
			add_child(rect)
			_cell_nodes[pos] = rect


func _rebuild_pieces() -> void:
	for node in _piece_nodes.values():
		node.queue_free()
	_piece_nodes = {}
	for piece in controller.state.pieces:
		_create_piece_node(piece)


func _create_piece_node(piece: Piece) -> void:
	var body: ColorRect = ColorRect.new()
	body.size = Vector2(CELL_SIZE - PIECE_MARGIN, CELL_SIZE - PIECE_MARGIN)
	body.position = grid_to_screen(piece.pos) + Vector2(PIECE_MARGIN, PIECE_MARGIN) / 2.0
	body.color = COLOR_PLAYER if piece.team == 0 else COLOR_ENEMY
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label: Label = Label.new()
	label.text = PieceKind.kind_to_letter(piece.kind) if piece.team == 0 else "E"
	label.size = body.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(label)

	add_child(body)
	_piece_nodes[piece.id] = body
