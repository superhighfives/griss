class_name LevelLoader
extends RefCounted

## Set by load_from_json()/load_from_string() when they return null, naming
## the offending field.
static var last_error: String = ""


static func load_from_string(json_text: String) -> Level:
	last_error = ""
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		last_error = "root"
		return null
	return _load_from_dict(parsed)


static func load_from_file(path: String) -> Level:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "file"
		return null
	var text: String = FileAccess.get_file_as_string(path)
	return load_from_string(text)


static func _fail(field: String) -> Level:
	last_error = field
	return null


static func _load_from_dict(data: Dictionary) -> Level:
	if not data.has("width") or typeof(data["width"]) != TYPE_FLOAT and typeof(data["width"]) != TYPE_INT:
		return _fail("width")
	if not data.has("height") or typeof(data["height"]) != TYPE_FLOAT and typeof(data["height"]) != TYPE_INT:
		return _fail("height")
	if not data.has("move_budget") or typeof(data["move_budget"]) != TYPE_FLOAT and typeof(data["move_budget"]) != TYPE_INT:
		return _fail("move_budget")
	if not data.has("players") or typeof(data["players"]) != TYPE_ARRAY or data["players"].is_empty():
		return _fail("players")

	var level: Level = Level.new()
	level.level_name = String(data.get("name", ""))
	level.width = int(data["width"])
	level.height = int(data["height"])
	level.move_budget = int(data["move_budget"])

	if level.width <= 0 or level.height <= 0:
		return _fail("width/height")

	var occupied: Dictionary = {}

	level.players = []
	for player_entry in data["players"]:
		if typeof(player_entry) != TYPE_DICTIONARY or not player_entry.has("kind") or not player_entry.has("pos"):
			return _fail("players")
		var player_kind: PieceKind.Kind = PieceKind.kind_from_string(String(player_entry["kind"]))
		if player_kind == -1:
			return _fail("players.kind")
		var player_pos: Vector2i = _parse_pos(player_entry["pos"])
		if not _in_bounds(player_pos, level.width, level.height):
			return _fail("players.pos")
		if occupied.has(player_pos):
			return _fail("players.pos")
		occupied[player_pos] = true
		level.players.append({"kind": player_kind, "pos": player_pos})

	level.walls = []
	for wall_entry in data.get("walls", []):
		var wall_pos: Vector2i = _parse_pos(wall_entry)
		if not _in_bounds(wall_pos, level.width, level.height):
			return _fail("walls")
		if occupied.has(wall_pos):
			return _fail("walls")
		occupied[wall_pos] = true
		level.walls.append(wall_pos)

	level.powerups = []
	for powerup_entry in data.get("powerups", []):
		if typeof(powerup_entry) != TYPE_DICTIONARY or not powerup_entry.has("pos") or not powerup_entry.has("type"):
			return _fail("powerups")
		var powerup_pos: Vector2i = _parse_pos(powerup_entry["pos"])
		if not _in_bounds(powerup_pos, level.width, level.height):
			return _fail("powerups")
		if occupied.has(powerup_pos):
			return _fail("powerups")
		occupied[powerup_pos] = true
		var powerup_type: String = String(powerup_entry["type"])
		if powerup_type != Rules.CARD_PROMOTE and powerup_type != Rules.CARD_PUSH_BACK:
			return _fail("powerups.type")
		level.powerups.append({"pos": powerup_pos, "type": powerup_type})

	level.enemies = []
	for enemy_entry in data.get("enemies", []):
		if typeof(enemy_entry) != TYPE_DICTIONARY or not enemy_entry.has("kind") or not enemy_entry.has("pos"):
			return _fail("enemies")
		var enemy_kind: PieceKind.Kind = PieceKind.kind_from_string(String(enemy_entry["kind"]))
		if enemy_kind == -1:
			return _fail("enemies.kind")
		var enemy_pos: Vector2i = _parse_pos(enemy_entry["pos"])
		if not _in_bounds(enemy_pos, level.width, level.height):
			return _fail("enemies.pos")
		if occupied.has(enemy_pos):
			return _fail("enemies.pos")
		occupied[enemy_pos] = true
		level.enemies.append({"kind": enemy_kind, "pos": enemy_pos})

	var mode: String = String(data.get("enemy_turn_mode", Rules.ENEMY_TURN_MODE_ONE))
	if mode != Rules.ENEMY_TURN_MODE_ONE and mode != Rules.ENEMY_TURN_MODE_ALL:
		return _fail("enemy_turn_mode")
	level.enemy_turn_mode = mode

	return level


static func _parse_pos(value: Variant) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(value[0]), int(value[1]))


static func _in_bounds(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height
