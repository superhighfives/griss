extends TestCase


const VALID_JSON: String = """
{
  "name": "First Steps",
  "width": 4,
  "height": 12,
  "move_budget": 20,
  "player": { "kind": "PAWN", "pos": [1, 0] },
  "walls": [[0, 4], [1, 4], [3, 7]],
  "powerups": [{ "pos": [2, 3], "type": "promote" }],
  "enemies": [{ "kind": "ROOK", "pos": [3, 9] }]
}
"""


func test_valid_level_round_trips_into_expected_state() -> bool:
	var level: Level = LevelLoader.load_from_string(VALID_JSON)
	if not assert_not_null(level, "valid level should parse"):
		return false
	if not assert_eq(level.level_name, "First Steps"):
		return false
	if not assert_eq(level.width, 4) or not assert_eq(level.height, 12):
		return false
	if not assert_eq(level.move_budget, 20):
		return false
	if not assert_eq(level.player_kind, PieceKind.Kind.PAWN):
		return false
	if not assert_eq(level.player_pos, Vector2i(1, 0)):
		return false

	var state: BoardState = level.to_board_state()
	if not assert_eq(state.width, 4) or not assert_eq(state.height, 12):
		return false
	if not assert_true(state.is_wall(Vector2i(0, 4)), "wall present"):
		return false
	if not assert_true(state.is_wall(Vector2i(3, 7)), "wall present"):
		return false
	if not assert_eq(state.powerups.get(Vector2i(2, 3)), "promote", "powerup present"):
		return false
	var player: Piece = state.get_player_piece()
	if not assert_not_null(player, "player piece created"):
		return false
	if not assert_eq(player.pos, Vector2i(1, 0)):
		return false
	var enemies: Array[Piece] = []
	for piece in state.pieces:
		if piece.team == 1:
			enemies.append(piece)
	if not assert_eq(enemies.size(), 1, "one enemy created"):
		return false
	return assert_eq(enemies[0].kind, PieceKind.Kind.ROOK, "enemy kind preserved")


func test_out_of_bounds_player_pos_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": 10,
	  "player": { "kind": "PAWN", "pos": [9, 0] } }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	if not assert_null(level, "out-of-bounds player pos should fail"):
		return false
	return assert_eq(LevelLoader.last_error, "player.pos")


func test_out_of_bounds_wall_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": 10,
	  "player": { "kind": "PAWN", "pos": [0, 0] },
	  "walls": [[9, 9]] }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	if not assert_null(level, "out-of-bounds wall should fail"):
		return false
	return assert_eq(LevelLoader.last_error, "walls")


func test_overlapping_wall_and_player_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": 10,
	  "player": { "kind": "PAWN", "pos": [0, 0] },
	  "walls": [[0, 0]] }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	return assert_null(level, "player standing on a wall should fail")


func test_overlapping_enemy_and_powerup_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": 10,
	  "player": { "kind": "PAWN", "pos": [0, 0] },
	  "powerups": [{ "pos": [2, 2], "type": "promote" }],
	  "enemies": [{ "kind": "ROOK", "pos": [2, 2] }] }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	return assert_null(level, "overlapping enemy and powerup should fail")


func test_unknown_kind_string_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": 10,
	  "player": { "kind": "WIZARD", "pos": [0, 0] } }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	if not assert_null(level, "unknown player kind should fail"):
		return false
	return assert_eq(LevelLoader.last_error, "player.kind")


func test_unknown_enemy_kind_string_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": 10,
	  "player": { "kind": "PAWN", "pos": [0, 0] },
	  "enemies": [{ "kind": "WIZARD", "pos": [2, 2] }] }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	if not assert_null(level, "unknown enemy kind should fail"):
		return false
	return assert_eq(LevelLoader.last_error, "enemies.kind")


func test_missing_required_field_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12 }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	if not assert_null(level, "missing move_budget should fail"):
		return false
	return assert_eq(LevelLoader.last_error, "move_budget")


func test_malformed_json_rejected() -> bool:
	var level: Level = LevelLoader.load_from_string("{ not valid json")
	return assert_null(level, "malformed json should fail")


func test_non_numeric_move_budget_rejected() -> bool:
	var json_text: String = """
	{ "width": 4, "height": 12, "move_budget": "twenty",
	  "player": { "kind": "PAWN", "pos": [0, 0] } }
	"""
	var level: Level = LevelLoader.load_from_string(json_text)
	if not assert_null(level, "string move_budget should fail"):
		return false
	return assert_eq(LevelLoader.last_error, "move_budget")
