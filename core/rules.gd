class_name Rules
extends RefCounted

enum Outcome { ONGOING, WIN, LOSS_ELIMINATED, LOSS_NO_MOVES }

const ENEMY_TURN_MODE_ONE: String = "one"
const ENEMY_TURN_MODE_ALL: String = "all"

const CARD_PROMOTE: String = "promote"
const CARD_PUSH_BACK: String = "push_back"


## Applies a move for the piece to `dest` in place, mutating `state`.
## Caller is responsible for snapshotting state beforehand if undo is needed.
## Returns true if the move was legal and applied. Shared by both player
## moves (GameController) and enemy moves (advance_enemies below) - move
## budget and powerup pickup are player-only (team 0), everything else
## (capture, has_moved) applies to any piece.
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
			# Grants a card rather than applying an effect immediately -
			# see plans/done/m6-cards.md. play_card() below is the only
			# thing that ever changes a piece's kind or pushes enemies now.
			state.player_hand.append(state.powerups[dest])
			state.powerups.erase(dest)

	return true


## Plays one card from state.player_hand, mutating state in place. Returns
## false (no mutation) if a card was already played this turn or the hand
## doesn't contain card_type - callers don't need to check either
## themselves first. GameController resets card_played_this_turn once the
## player's move ends the turn, mirroring how moves_used only resets on
## restart().
static func play_card(state: BoardState, card_type: String, target_piece_id: int = -1) -> bool:
	if state.card_played_this_turn or not state.player_hand.has(card_type):
		return false

	match card_type:
		CARD_PROMOTE:
			var target: Piece = state.get_piece(target_piece_id)
			if target == null or target.team != 0:
				return false
			target.kind = PieceKind.next_in_promotion_track(target.kind)
		CARD_PUSH_BACK:
			_push_back_enemies(state)
		_:
			return false

	state.player_hand.erase(card_type)
	state.card_played_this_turn = true
	return true


## Pushes every enemy one square directly away from whichever player
## piece is nearest to it - a diagonal step if the nearer player piece
## isn't purely aligned orthogonally. An enemy with no player pieces left
## to push away from, or whose pushed-back square is out of bounds, a
## wall, or occupied, simply doesn't move - a soft per-enemy failure, not
## an all-or-nothing effect for the whole card.
static func _push_back_enemies(state: BoardState) -> void:
	for enemy in state.pieces:
		if enemy.team != 1:
			continue
		var nearest: Piece = _nearest_player(state, enemy.pos)
		if nearest == null:
			continue
		var delta: Vector2i = enemy.pos - nearest.pos
		var away: Vector2i = Vector2i(sign(delta.x), sign(delta.y))
		if away == Vector2i.ZERO:
			continue
		var dest: Vector2i = enemy.pos + away
		if not state.is_in_bounds(dest) or state.is_wall(dest) or state.piece_at(dest) != null:
			continue
		enemy.pos = dest


static func _nearest_player(state: BoardState, from: Vector2i) -> Piece:
	var best: Piece = null
	var best_distance: int = -1
	for player in state.get_player_pieces():
		var distance: int = abs(player.pos.x - from.x) + abs(player.pos.y - from.y)
		if best == null or distance < best_distance:
			best = player
			best_distance = distance
	return best


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


## An enemy has no "stay put" option (advance_enemies() always takes the
## single legal move that most helps it, if it has any), so a piece
## merely standing in the player's way isn't the same as it being stuck
## there - on its next turn it will have to move to one of its own legal
## destinations, which for most piece/geometry combinations means moving
## off the blocking square. Calling advance_enemies() only once and then
## declaring an instant loss the moment the player has no legal move
## denies the enemy that next turn. This wraps advance_enemies() to keep
## giving the enemy team further turns - as if the player passed - for as
## long as the player still can't move and some enemy still can, so a
## capture-free block resolves itself instead of ending the game. Stops
## once the player regains a move, is eliminated, or no enemy has a legal
## move either (a genuine deadlock, still a loss) - or after
## _MAX_STALEMATE_ENEMY_TURNS iterations, a safety net against an
## enemy oscillating in and out of the blocking square forever.
const _MAX_STALEMATE_ENEMY_TURNS: int = 64

static func advance_enemies_and_resolve_stalemate(state: BoardState, mode: String = ENEMY_TURN_MODE_ONE) -> void:
	advance_enemies(state, mode)
	var iterations: int = 0
	while not state.get_player_pieces().is_empty() \
		and not _any_player_piece_can_move(state) \
		and _any_enemy_can_move(state) \
		and iterations < _MAX_STALEMATE_ENEMY_TURNS:
		advance_enemies(state, mode)
		iterations += 1


static func _any_player_piece_can_move(state: BoardState) -> bool:
	for player in state.get_player_pieces():
		if not MoveGen.legal_moves(state, player.id).is_empty():
			return true
	return false


static func _any_enemy_can_move(state: BoardState) -> bool:
	for piece in state.pieces:
		if piece.team == 1 and not MoveGen.legal_moves(state, piece.id).is_empty():
			return true
	return false


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
	var nearest: Piece = _nearest_player(state, from)
	if nearest == null:
		return -1
	return abs(nearest.pos.x - from.x) + abs(nearest.pos.y - from.y)


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
