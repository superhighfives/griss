extends SceneTree

# Usage: godot --headless --script res://solve_level.gd -- <level_path> [--forbid-promotion]
# BFS over (pos, kind, moves_used) states using the real core rules engine.
# Prints a winning move sequence if one exists within the level's move
# budget, or says no solution was found.

func _init():
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("usage: solve_level.gd <level_path> [--forbid-promotion]")
		quit(1)
		return
	var level_path: String = args[0]
	var forbid_promotion: bool = args.size() > 1 and args[1] == "--forbid-promotion"

	var level: Level = LevelLoader.load_from_file(level_path)
	if level == null:
		print("LOAD FAILED: ", LevelLoader.last_error)
		quit(1)
		return

	var start_state: BoardState = level.to_board_state()
	var start_player: Piece = start_state.get_player_piece()
	var start_kind: PieceKind.Kind = start_player.kind

	# Each queue entry: {state, path (array of Vector2i destinations)}
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

		var player: Piece = state.get_player_piece()
		var key: String = str(player.pos) + "|" + str(player.kind) + "|" + str(state.moves_used) + "|" + str(state.powerups.keys())
		if seen.has(key):
			continue
		seen[key] = true

		for dest: Vector2i in MoveGen.legal_moves(state, player.id):
			var next_state: BoardState = state.duplicate_state()
			var applied: bool = Rules.apply_move(next_state, player.id, dest)
			if not applied:
				continue
			if forbid_promotion:
				var next_player: Piece = next_state.get_player_piece()
				if next_player.kind != start_kind:
					continue
			var next_path: Array = path.duplicate()
			next_path.append(dest)
			queue.append({"state": next_state, "path": next_path})

	print("states explored: ", states_explored)
	if found:
		print("SOLUTION (", solution.size(), " moves): ", solution)
	else:
		print("NO SOLUTION FOUND", " (forbid_promotion=", forbid_promotion, ")")
	quit()
