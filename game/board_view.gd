class_name BoardView
extends Node2D

var controller: GameController
var _cell_nodes: Dictionary = {}
var _piece_nodes: Dictionary = {}
var _highlight_nodes: Array[ColorRect] = []
var _threat_nodes: Array[ColorRect] = []
var _powerup_nodes: Array[ColorRect] = []


func setup(p_controller: GameController) -> void:
	controller = p_controller
	_build_cells()
	_rebuild_threats()
	_rebuild_powerups()
	_rebuild_pieces()


func grid_to_screen(pos: Vector2i) -> Vector2:
	var height: int = controller.state.height
	return Tuning.BOARD_OFFSET + Vector2(pos.x * Tuning.CELL_SIZE, (height - 1 - pos.y) * Tuning.CELL_SIZE)


func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - Tuning.BOARD_OFFSET
	var grid_x: int = int(floor(local_pos.x / Tuning.CELL_SIZE))
	var grid_y: int = controller.state.height - 1 - int(floor(local_pos.y / Tuning.CELL_SIZE))
	return Vector2i(grid_x, grid_y)


func refresh() -> void:
	_rebuild_threats()
	_rebuild_powerups()
	_rebuild_pieces()
	clear_highlights()


func show_highlights(cells: Array[Vector2i]) -> void:
	clear_highlights()
	for pos in cells:
		var highlight: ColorRect = ColorRect.new()
		highlight.size = Vector2(Tuning.CELL_SIZE - Tuning.CELL_MARGIN, Tuning.CELL_SIZE - Tuning.CELL_MARGIN)
		highlight.position = grid_to_screen(pos)
		highlight.color = Tuning.COLOR_HIGHLIGHT
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(highlight)
		_highlight_nodes.append(highlight)
		_pulse_highlight(highlight)


func clear_highlights() -> void:
	for highlight in _highlight_nodes:
		highlight.queue_free()
	_highlight_nodes = []


## Subtle looping alpha pulse so legal-move highlights read as interactive
## rather than static paint.
##
## The tween is created on the highlight, not on self: create_tween() binds
## the tween to the node it's called on, so self.create_tween() would bind
## it to BoardView - which outlives clear_highlights(). The orphaned tween
## then steps a freed target forever, and that is fatal rather than merely
## wasteful: set_loops() makes it infinite, a PropertyTweener whose target
## is gone returns immediately without consuming any delta, so Tween::step()
## loops without end. Debug builds detect this and bail out ("Infinite loop
## detected"), which is why it survived editor testing - but that check is
## compiled out of export templates (#ifdef DEBUG_ENABLED), so on a release
## iOS build the main thread wedges on the first frame after a move and the
## watchdog kills the app. Bound to the highlight, the tween dies with it
## and clear_highlights()'s queue_free() genuinely is enough teardown.
func _pulse_highlight(highlight: ColorRect) -> void:
	var tween: Tween = highlight.create_tween()
	tween.set_loops()
	tween.tween_property(highlight, "color:a", Tuning.HIGHLIGHT_PULSE_MAX_ALPHA, Tuning.HIGHLIGHT_PULSE_HALF_DURATION)
	tween.tween_property(highlight, "color:a", Tuning.HIGHLIGHT_PULSE_MIN_ALPHA, Tuning.HIGHLIGHT_PULSE_HALF_DURATION)


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
		threat.size = Vector2(Tuning.CELL_SIZE - Tuning.CELL_MARGIN, Tuning.CELL_SIZE - Tuning.CELL_MARGIN)
		threat.position = grid_to_screen(pos)
		threat.color = Tuning.COLOR_THREAT
		threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(threat)
		_threat_nodes.append(threat)


## A small centered marker per powerup tile, distinct from the threat
## overlay's full-cell tint so the two read differently at a glance.
## Rebuilt on every refresh() - the tile disappears the moment
## Rules.apply_move() consumes it, and this is how that becomes visible.
func _rebuild_powerups() -> void:
	for marker in _powerup_nodes:
		marker.queue_free()
	_powerup_nodes = []
	for pos: Vector2i in controller.state.powerups.keys():
		var marker: ColorRect = ColorRect.new()
		marker.size = Vector2(Tuning.POWERUP_MARKER_SIZE, Tuning.POWERUP_MARKER_SIZE)
		marker.position = grid_to_screen(pos) + (Vector2(Tuning.CELL_SIZE, Tuning.CELL_SIZE) - marker.size) / 2.0
		marker.color = Tuning.COLOR_POWERUP
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		_powerup_nodes.append(marker)


func _build_cells() -> void:
	for y in range(controller.state.height):
		for x in range(controller.state.width):
			var pos: Vector2i = Vector2i(x, y)
			var rect: ColorRect = ColorRect.new()
			rect.size = Vector2(Tuning.CELL_SIZE - Tuning.CELL_MARGIN, Tuning.CELL_SIZE - Tuning.CELL_MARGIN)
			rect.position = grid_to_screen(pos)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if controller.state.is_wall(pos):
				rect.color = Tuning.COLOR_WALL
			elif pos.y == controller.state.goal_row:
				rect.color = Tuning.COLOR_GOAL
			else:
				rect.color = Tuning.COLOR_CELL
			add_child(rect)
			_cell_nodes[pos] = rect


## Diffs against the previous frame's piece nodes by id, rather than
## unconditionally freeing and recreating everything: a piece that's still
## on the board gets its position animated (see _update_piece_node), and
## only pieces that actually left the board (captures) get freed. This is
## what makes move tweens visible at all - the old free/recreate approach
## discarded position state every call, so there was never an "old
## position" to animate from.
func _rebuild_pieces() -> void:
	var seen_ids: Dictionary = {}
	for piece in controller.state.pieces:
		seen_ids[piece.id] = true
		if _piece_nodes.has(piece.id):
			_update_piece_node(piece)
		else:
			_create_piece_node(piece)
	for id in _piece_nodes.keys().duplicate():
		if not seen_ids.has(id):
			_piece_nodes[id].queue_free()
			_piece_nodes.erase(id)


func _create_piece_node(piece: Piece) -> void:
	var body: ColorRect = ColorRect.new()
	body.size = Vector2(Tuning.CELL_SIZE - Tuning.PIECE_MARGIN, Tuning.CELL_SIZE - Tuning.PIECE_MARGIN)
	body.position = grid_to_screen(piece.pos) + Vector2(Tuning.PIECE_MARGIN, Tuning.PIECE_MARGIN) / 2.0
	body.color = Tuning.COLOR_PLAYER if piece.team == 0 else Tuning.COLOR_ENEMY
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


func _update_piece_node(piece: Piece) -> void:
	var body: ColorRect = _piece_nodes[piece.id]
	var target_pos: Vector2 = grid_to_screen(piece.pos) + Vector2(Tuning.PIECE_MARGIN, Tuning.PIECE_MARGIN) / 2.0
	if body.position != target_pos:
		# Bound to the piece it animates, for the same reason as
		# _pulse_highlight: a piece captured mid-tween is queue_free()d by
		# _rebuild_pieces(), and the tween should go with it. This one can't
		# hang the way the pulse could (it doesn't loop, so a dead target
		# just ends it), but the binding rule is worth applying uniformly.
		var tween: Tween = body.create_tween()
		tween.tween_property(body, "position", target_pos, Tuning.MOVE_TWEEN_DURATION)

	var label: Label = body.get_child(0)
	label.text = PieceKind.kind_to_letter(piece.kind) if piece.team == 0 else "E"
