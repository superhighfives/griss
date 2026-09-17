extends SceneTree

# Usage: godot --headless --script res://solve_level.gd -- <level_path> [--forbid-promotion] [--require-all-survive] [--forbid-cards]
# BFS over full board states (every piece's id/pos/kind, moves_used,
# remaining powerups, hand, and card_played_this_turn) using the real core
# rules engine. Each transition is one turn: optionally play a card
# (Rules.play_card(), for every card type in hand and every target
# Rules.card_target_ids() offers), then a player piece's move, then the
# level's configured enemy response (Rules.advance_enemies()) - matching
# what GameController.try_play_card() + try_move() actually do - so the
# search reflects real play, not just the player's own moves in
# isolation. Prints a winning move sequence if one exists within the
# level's move budget, or says no solution was found. A step in the
# printed path is either {piece_id, dest} (a move) or {card, target} (a
# card play, target -1 for untargeted cards).
#
# --forbid-promotion prunes any branch where a player piece's kind has
# changed from what it started as - used to prove a level requires
# promotion, rather than asserting it from the level's geometry.
#
# --require-all-survive prunes any branch where the player piece count has
# dropped below its starting count - used to prove a level requires a
# sacrifice (no solution exists with every player piece intact), the same
# way --forbid-promotion proves a promotion requirement.
#
# --forbid-cards never branches into playing a card - used to prove a
# level actually requires using a card (no solution exists via moves
# alone), the same way --forbid-promotion proves a promotion requirement.

func _init():
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("usage: solve_level.gd <level_path> [--forbid-promotion] [--require-all-survive] [--forbid-cards]")
		quit(1)
		return
	var level_path: String = args[0]
	var forbid_promotion: bool = args.has("--forbid-promotion")
	var require_all_survive: bool = args.has("--require-all-survive")
	var forbid_cards: bool = args.has("--forbid-cards")

	var level: Level = LevelLoader.load_from_file(level_path)
	if level == null:
		print("LOAD FAILED: ", LevelLoader.last_error)
		quit(1)
		return

	var start_state: BoardState = level.to_board_state()
	var start_kinds: Dictionary = {}
	for player in start_state.get_player_pieces():
		start_kinds[player.id] = player.kind
	var start_player_count: int = start_state.get_player_pieces().size()

	# Each queue entry: {state, path (array of {piece_id, dest})}
	var queue: Array = [{"state": start_state, "path": []}]
	var seen: Dictionary = {}
	var solution: Array = []
	var found: bool = false
	var states_explored: int = 0

	while not queue.is_empty() and not found:
		var entry: Dictionary = queue.pop_front()
		var state: BoardState = entry["state"]
		var path: Array = entry["path"]
		states_explored += 1

		var outcome: Rules.Outcome = Rules.check_outcome(state)
		if outcome == Rules.Outcome.WIN:
			solution = path
			found = true
			break
		if outcome != Rules.Outcome.ONGOING:
			continue
		if state.moves_used >= state.move_budget:
			continue

		var key: String = _state_key(state)
		if seen.has(key):
			continue
		seen[key] = true

		# Every turn starts from `state` either as-is (no card played) or
		# after playing one card from the hand on one legal target - a
		# card play doesn't end the turn, so each is just a different
		# jumping-off point for the move enumeration below. turn_start
		# entries are {state, card_step}, card_step null for "no card".
		var turn_starts: Array = [{"state": state, "card_step": null}]
		if not forbid_cards and not state.card_played_this_turn:
			for card_type in _unique_card_types(state.player_hand):
				for target_id in Rules.card_target_ids(state, card_type):
					var card_state: BoardState = state.duplicate_state()
					if Rules.play_card(card_state, card_type, target_id):
						turn_starts.append({
							"state": card_state,
							"card_step": {"card": card_type, "target": target_id},
						})

		for turn_start: Dictionary in turn_starts:
			var pre_move_state: BoardState = turn_start["state"]
			var card_step: Variant = turn_start["card_step"]

			for player in pre_move_state.get_player_pieces():
				for dest: Vector2i in MoveGen.legal_moves(pre_move_state, player.id):
					var next_state: BoardState = pre_move_state.duplicate_state()
					var applied: bool = Rules.apply_move(next_state, player.id, dest)
					if not applied:
						continue
					if forbid_promotion:
						var moved_player: Piece = next_state.get_piece(player.id)
						if moved_player != null and moved_player.kind != start_kinds.get(player.id):
							continue
					# The move ends the turn - a fresh card play is available
					# next turn, mirroring GameController.try_move(), and
					# cleared before the enemy response for the same reason
					# it is there.
					next_state.card_played_this_turn = false
					# Mirrors GameController.try_move(): the enemy team only
					# responds if the player's move didn't already end the game,
					# and a capture-free block doesn't end it either as long as
					# some enemy still has a move to make.
					if Rules.check_outcome(next_state) == Rules.Outcome.ONGOING:
						Rules.advance_enemies_and_resolve_stalemate(next_state, level.enemy_turn_mode)
					if require_all_survive and next_state.get_player_pieces().size() < start_player_count:
						continue
					var next_path: Array = path.duplicate()
					if card_step != null:
						next_path.append(card_step)
					next_path.append({"piece_id": player.id, "dest": dest})
					queue.append({"state": next_state, "path": next_path})

	print("states explored: ", states_explored)
	if found:
		print("SOLUTION (", solution.size(), " steps): ", solution)
	else:
		print("NO SOLUTION FOUND (forbid_promotion=", forbid_promotion, ", require_all_survive=", require_all_survive, ", forbid_cards=", forbid_cards, ")")
	quit()


## Every piece's id/pos/kind (sorted for a stable ordering across states
## built independently), plus moves_used, remaining powerup tiles, the
## player's hand, and whether a card's already been played this turn.
## Enemies are part of the key too, not just player pieces - unlike M2/M3,
## enemy positions now vary run to run (Rules.advance_enemies() moves
## them), so they're real state, not a constant the search can ignore.
static func _state_key(state: BoardState) -> String:
	var parts: Array = []
	for piece in state.pieces:
		parts.append(str(piece.id) + "@" + str(piece.pos) + "#" + str(piece.kind))
	parts.sort()
	var hand: Array = state.player_hand.duplicate()
	hand.sort()
	return ",".join(parts) + "|" + str(state.moves_used) + "|" + str(state.powerups.keys()) \
		+ "|" + ",".join(hand) + "|" + str(state.card_played_this_turn)


static func _unique_card_types(hand: Array) -> Array:
	var seen: Dictionary = {}
	for card_type in hand:
		seen[card_type] = true
	return seen.keys()
