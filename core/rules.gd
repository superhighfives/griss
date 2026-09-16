class_name Rules
extends RefCounted

enum Outcome { ONGOING, WIN, LOSS_ELIMINATED, LOSS_NO_MOVES }

const ENEMY_TURN_MODE_ONE: String = "one"
const ENEMY_TURN_MODE_ALL: String = "all"


## Applies a move for the piece to `dest` in place, mutating `state`.
## Caller is responsible for snapshotting state beforehand if undo is needed.
## Returns true if the move was legal and applied. Shared by both player
## moves (GameController) and enemy moves (advance_enemies below) - move
## budget and powerup consumption are player-only (team 0), everything
## else (capture, has_moved) applies to any piece.
static func apply_move(state: BoardState, piece_id: int, dest: Vector2i) -> bool:
	var piece: Piece = state.get_piece(piece_id)
	if piece == null:
		return false
	var legal: Array[Vector2i] = MoveGen.legal_moves(state, piece_id)
	if not legal.has(dest):
		return false

	var occupant: Piece = state.piece_at(dest)
	if occupant != null and occupant.team != piece.team:
		state.remove_piece(occupant.id)

	piece.pos = dest
	piece.has_moved = true

	if piece.team == 0:
		state.moves_used += 1
		if state.powerups.has(dest):
			var powerup_type: String = state.powerups[dest]
			if powerup_type == "promote":
				piece.kind = PieceKind.next_in_promotion_track(piece.kind)
			state.powerups.erase(dest)

	return true


## Moves the enemy team according to `mode`:
## - "one" (default): the single best (enemy, destination) pair across
##   every enemy acts - any capture anywhere beats any non-capture move;
##   among equally-capturing or equally-non-capturing choices, the first
##   found in board order wins (deterministic, not meaningfully "better").
## - "all": every enemy acts once, in board order, each independently
##   preferring a capture over closing distance. Later enemies see the
##   board after earlier ones have already moved, including captures.
static func advance_enemies(state: BoardState, mode: String = ENEMY_TURN_MODE_ONE) -> void:
	var enemy_ids: Array[int] = []
	for piece in state.pieces:
		if piece.team == 1:
			enemy_ids.append(piece.id)

	if mode == ENEMY_TURN_MODE_ALL:
		for enemy_id in enemy_ids:
			var enemy: Piece = state.get_piece(enemy_id)
			if enemy == null:
				continue
			var choice: Dictionary = _best_move_for(state, enemy)
			if not choice.is_empty():
				apply_move(state, enemy_id, choice["dest"])
		return

	var best_enemy_id: int = -1
	var best_choice: Dictionary = {}
	for enemy_id in enemy_ids:
		var enemy: Piece = state.get_piece(enemy_id)
		if enemy == null:
			continue
		var choice: Dictionary = _best_move_for(state, enemy)
		if choice.is_empty():
			continue
		if best_choice.is_empty() \
			or (choice["is_capture"] and not best_choice["is_capture"]) \
			or (choice["is_capture"] == best_choice["is_capture"] and choice["distance"] < best_choice["distance"]):
			best_enemy_id = enemy_id
			best_choice = choice

	if best_enemy_id != -1:
		apply_move(state, best_enemy_id, best_choice["dest"])


## Simple heuristic for one enemy: capture a player piece if any legal
## move lands on one, otherwise the move that most reduces distance to
## the nearest player piece. Returns {} if the enemy has no legal moves.
static func _best_move_for(state: BoardState, enemy: Piece) -> Dictionary:
	var legal: Array[Vector2i] = MoveGen.legal_moves(state, enemy.id)
	if legal.is_empty():
		return {}

	for dest in legal:
		if state.piece_at(dest) != null:
			return {"dest": dest, "is_capture": true, "distance": 0}

	var best_dest: Vector2i = legal[0]
	var best_distance: int = _distance_to_nearest_player(state, best_dest)
	for dest in legal:
		var distance: int = _distance_to_nearest_player(state, dest)
		if distance < best_distance:
			best_dest = dest
			best_distance = distance
	return {"dest": best_dest, "is_capture": false, "distance": best_distance}


static func _distance_to_nearest_player(state: BoardState, from: Vector2i) -> int:
	var best: int = -1
	for player in state.get_player_pieces():
		var distance: int = abs(player.pos.x - from.x) + abs(player.pos.y - from.y)
		if best == -1 or distance < best:
			best = distance
	return best


## A player piece on the goal row wins immediately, even with other
## player pieces still on the board - the objective is getting ONE piece
## through, not all of them. Losing is: every player piece captured (none
## reached the goal), move budget exhausted, or every remaining player
## piece has zero legal moves. Moving onto a square an enemy threatens is
## no longer instant loss on its own now that enemies actually move and
## capture (see plans/done/m5-sacrifice.md) - MoveGen.threatened_squares()
## is still used for BoardView's warning overlay, just not as a rule here.
static func check_outcome(state: BoardState) -> Outcome:
	var players: Array[Piece] = state.get_player_pieces()

	for player in players:
		if player.pos.y == state.goal_row:
			return Outcome.WIN

	if players.is_empty():
		return Outcome.LOSS_ELIMINATED

	if state.moves_used >= state.move_budget:
		return Outcome.LOSS_NO_MOVES

	for player in players:
		if not MoveGen.legal_moves(state, player.id).is_empty():
			return Outcome.ONGOING

	return Outcome.LOSS_NO_MOVES
