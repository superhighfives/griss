class_name Level
extends RefCounted

var level_name: String
var width: int
var height: int
var move_budget: int
var player_kind: PieceKind.Kind
var player_pos: Vector2i
var walls: Array[Vector2i]
var powerups: Array[Dictionary]  # { "pos": Vector2i, "type": String }
var enemies: Array[Dictionary]   # { "kind": PieceKind.Kind, "pos": Vector2i }


func to_board_state() -> BoardState:
	var state: BoardState = BoardState.new(width, height)
	state.move_budget = move_budget
	for wall in walls:
		state.walls[wall] = true
	for powerup in powerups:
		state.powerups[powerup["pos"]] = powerup["type"]
	state.add_piece(player_kind, 0, player_pos)
	for enemy in enemies:
		state.add_piece(enemy["kind"], 1, enemy["pos"])
	return state
