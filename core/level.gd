class_name Level
extends RefCounted

var level_name: String
var width: int
var height: int
var move_budget: int
var players: Array[Dictionary]   # { "kind": PieceKind.Kind, "pos": Vector2i }
var walls: Array[Vector2i]
var powerups: Array[Dictionary]  # { "pos": Vector2i, "type": String }
var enemies: Array[Dictionary]   # { "kind": PieceKind.Kind, "pos": Vector2i }
var enemy_turn_mode: String = Rules.ENEMY_TURN_MODE_ONE


func to_board_state() -> BoardState:
	var state: BoardState = BoardState.new(width, height)
	state.move_budget = move_budget
	for wall in walls:
		state.walls[wall] = true
	for powerup in powerups:
		state.powerups[powerup["pos"]] = powerup["type"]
	for player in players:
		state.add_piece(player["kind"], 0, player["pos"])
	for enemy in enemies:
		state.add_piece(enemy["kind"], 1, enemy["pos"])
	return state
