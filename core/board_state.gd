class_name BoardState
extends RefCounted

var width: int
var height: int
var walls: Dictionary       # Vector2i -> true (used as a set)
var powerups: Dictionary    # Vector2i -> String ("promote")
var pieces: Array[Piece]
var goal_row: int
var moves_used: int
var move_budget: int

var _next_piece_id: int = 0


func _init(p_width: int = 4, p_height: int = 12) -> void:
	width = p_width
	height = p_height
	walls = {}
	powerups = {}
	pieces = []
	goal_row = p_height - 1
	moves_used = 0
	move_budget = 0


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func is_wall(pos: Vector2i) -> bool:
	return walls.has(pos)


func piece_at(pos: Vector2i) -> Piece:
	for piece in pieces:
		if piece.pos == pos:
			return piece
	return null


func get_piece(id: int) -> Piece:
	for piece in pieces:
		if piece.id == id:
			return piece
	return null


func get_player_piece() -> Piece:
	for piece in pieces:
		if piece.team == 0:
			return piece
	return null


func add_piece(kind: PieceKind.Kind, team: int, pos: Vector2i) -> Piece:
	var piece: Piece = Piece.new(_next_piece_id, kind, team, pos, 0)
	_next_piece_id += 1
	pieces.append(piece)
	return piece


func remove_piece(id: int) -> void:
	for i in range(pieces.size()):
		if pieces[i].id == id:
			pieces.remove_at(i)
			return


func duplicate_state() -> BoardState:
	var copy: BoardState = BoardState.new(width, height)
	copy.goal_row = goal_row
	copy.moves_used = moves_used
	copy.move_budget = move_budget
	copy._next_piece_id = _next_piece_id
	copy.walls = walls.duplicate(true)
	copy.powerups = powerups.duplicate(true)
	copy.pieces = []
	for piece in pieces:
		copy.pieces.append(piece.duplicate_piece())
	return copy
