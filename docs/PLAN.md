# Griss — Godot Prototype Plan

A turn-based puzzle game: chess pieces traverse a narrow vertical grid to reach the far end. Pieces upgrade along the way.

This document is the brief for a code agent. Follow the architecture constraints literally — they exist to keep the project agent-drivable (no editor wiring) and testable headlessly.

This is the original design brief and stays as historical reference — active
milestone specs now live in [`../plans/`](../plans/README.md), one file per
milestone: `done/` for M0–M3 (with an honest account of what actually shipped,
deviations included), `ready/` for M4 onward.

---

## 1. Tech and version

- **Godot 4.4+**, GDScript only. No C#, no external addons for the MVP.
- Typed GDScript everywhere (`var x: int`, `func f(a: Vector2i) -> bool`). Use `class_name` for core classes.
- Coordinates are `Vector2i`. Never use floats for grid logic.
- Target: desktop (macOS primary). Web export is a stretch goal, so avoid anything web-hostile (no threads, no filesystem writes outside `user://`).

## 2. Hard architecture constraints

**The rules engine must be pure GDScript with zero Godot scene dependencies.**

- Everything in `res://core/` extends `RefCounted` or is a plain class. No `Node`, no `Input`, no `get_tree()`, no `print` to drive logic, no signals.
- Core functions are deterministic: given a state and a move, they return a result. No hidden mutation of globals.
- All rendering, input, and animation lives in `res://game/`. That layer reads core state and draws it; it never implements a rule.

**Build the board in code, not in the editor.**

- One scene: `res://game/Main.tscn`, containing a `Node2D` root plus an empty `Node2D` named `BoardRoot` and a `CanvasLayer` named `UI`. That's it.
- Every cell, piece, and highlight is instantiated at runtime from script. No TileMap, no prefab scenes to wire up.
- This is deliberate: a code agent can't operate the Godot editor, so the scene tree must be constructible and reviewable as text.

**Placeholder visuals only.**

- Cells: `ColorRect`. Pieces: `ColorRect` with a `Label` child showing a letter (P, N, B, R, Q, and `E` for enemies). Walls: dark `ColorRect`.
- No art assets, no fonts, no shaders in the MVP. Visual polish comes after the rules are fun.

## 3. File layout

```
res://
  core/
    board_state.gd        # class_name BoardState  — grid dims, cells, pieces, turn count
    piece.gd               # class_name Piece       — id, kind, team, position, charges
    piece_kind.gd           # class_name PieceKind   — enum + movement vector tables
    move_gen.gd             # class_name MoveGen     — legal_moves(state, piece_id) -> Array[Vector2i]
    rules.gd                # class_name Rules       — apply_move(), check_outcome()
    level.gd                # class_name Level       — parsed level definition
    level_loader.gd          # class_name LevelLoader — JSON -> Level, Level -> BoardState
  game/
    Main.tscn
    main.gd               # entry point, owns GameController
    game_controller.gd    # holds BoardState, undo stack, translates input -> core calls
    board_view.gd         # builds/updates cell + piece visuals from state
    input_controller.gd   # mouse position -> Vector2i cell, click routing
    hud.gd                # moves remaining, level name, restart/undo buttons
  levels/
    01_first_steps.json
    ...
  tests/
    run_tests.gd          # headless runner, exits non-zero on failure
    test_move_gen.gd
    test_rules.gd
    test_level_loader.gd
```

## 4. Core data model

```gdscript
# PieceKind enum
enum Kind { PAWN, KNIGHT, BISHOP, ROOK, QUEEN }

# Piece
id: int
kind: Kind
team: int          # 0 = player, 1 = enemy
pos: Vector2i
charges: int       # reserved for one-shot abilities; 0 in MVP
```

`BoardState` holds:

- `width: int`, `height: int`
- `walls: Dictionary` keyed by `Vector2i` (use as a set)
- `powerups: Dictionary` — `Vector2i -> String` (`"promote"` in MVP)
- `pieces: Array[Piece]`
- `goal_row: int`
- `moves_used: int`, `move_budget: int`

`BoardState` must implement `duplicate_state() -> BoardState` doing a deep copy of pieces and dictionaries. This gives undo for free: the controller pushes a snapshot before each move.

## 5. Game rules (MVP definition)

**Board.** Default 4 wide × 12 tall. `x` 0–3 left to right, `y` 0 at the bottom (start row) to `height-1` at the top. `goal_row = height - 1`.

**Objective.** Get the player piece onto any cell in `goal_row` within the move budget.

**Movement.** Standard chess vectors, clipped to the board and blocked by walls:

- Pawn: one step forward (+y). No diagonal capture in MVP — keep it dead simple.
- Knight: the eight (±1, ±2) / (±2, ±1) offsets. On a 4-wide board most of these are off-board; that constraint is intended.
- Bishop: diagonal rays. Rook: orthogonal rays. Queen: both.
- Sliding pieces (bishop/rook/queen) stop before a wall or a piece. They may capture the first enemy piece in the ray; they may not pass through anything.
- Pieces may never occupy a wall or a friendly piece's cell.

**Enemies.** Static in the MVP — they never move. They project *threat squares*: every cell an enemy could legally move to (using the same `MoveGen`, with team flipped). Moving the player onto a threatened cell is an immediate loss. Capturing an enemy removes it and its threat.

**Powerups.** A `"promote"` tile advances the player piece one step up the track: `PAWN -> KNIGHT -> BISHOP -> ROOK -> QUEEN`. The tile is consumed on entry. Queen is terminal (tile consumed, no effect).

**Outcomes.** `check_outcome(state) -> Outcome` where Outcome is `ONGOING`, `WIN` (player on goal row), `LOSS_THREATENED` (player on a threatened cell), `LOSS_NO_MOVES` (budget exhausted, or no legal moves exist).

**Turn loop.** One player move per turn, `moves_used += 1`. No enemy phase in the MVP — leave a clearly marked `Rules.advance_enemies(state)` stub that currently does nothing, so M2 behavior can drop in later.

## 6. Level format

JSON so both humans and agents can diff and hand-write levels. `LevelLoader` validates and fails loudly with the offending field name.

```json
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
```

Rules for the loader: reject out-of-bounds coordinates, overlapping entities, an unreachable-by-construction player start, and unknown `kind` strings.

## 7. Testing

Headless, no addons. `tests/run_tests.gd` is a `SceneTree` script that collects test scripts, runs every `func test_*()`, prints failures, and calls `quit(1)` if any failed.

Run it with:

```
godot --headless --path . --script res://tests/run_tests.gd
```

This command must pass at the end of every milestone. Minimum coverage:

- **move_gen**: each piece kind on an empty 4×12 board; edge clipping on all four sides; knight on a 4-wide board; sliding pieces blocked by walls, by friendly pieces, and capturing the first enemy in a ray.
- **rules**: promotion track including the Queen terminal case, powerup consumption, move counter, every `Outcome` branch, threat-square computation for each enemy kind.
- **level_loader**: a valid level round-trips into the expected `BoardState`; each validation error is raised for a malformed fixture.
- **state**: `duplicate_state()` is a genuine deep copy — mutating the copy's pieces must not touch the original.

## 8. Milestones

Commit at each milestone with tests green. Don't start the next one until the previous is playable.

**M0 — Scaffold.** Project skeleton, `Main.tscn` with the three nodes, core classes as stubs with signatures, working headless test runner with one trivial passing test.

**M1 — Playable traversal.** Load `01_first_steps.json`, render the grid and the player piece, click to select, highlight legal moves, click to move, reach the goal row and show a win state. Walls render and block. No enemies, no powerups.
*Done when:* a pawn can walk 12 rows up a walled lane and trigger WIN.

**M2 — Pressure.** Static enemies, threat-square overlay, capture, move budget in the HUD, loss states, restart, and undo backed by the snapshot stack.
*Done when:* a level can be lost three distinct ways and restarted without a scene reload.

**M3 — Powerups and content.** Promotion tiles, the promotion track, upgraded movement reflected in highlights, plus five hand-authored levels of rising difficulty and a minimal level-select list.
*Done when:* level 5 requires at least one promotion to be solvable.

**M4 — Feel.** Move tweens (~120ms), a subtle highlight animation, sound hooks left unimplemented, and a `Tuning` script holding cell size, colors, and animation durations as constants in one place.

## 9. Conventions for the agent

- Snake_case files and functions, PascalCase `class_name`.
- No `Autoload`/singletons except a single `Tuning` constants script if needed. Pass dependencies explicitly.
- Never edit `.tscn` by hand beyond the three nodes described; if something seems to need a new scene, build it in code instead and note why in the commit.
- `project.godot` may be edited directly as text.
- If a rule in section 5 makes a level unsolvable or the code awkward, stop and flag it rather than silently changing the rule.
- Keep each core function under ~40 lines. `MoveGen` should be table-driven off `PieceKind` offsets, not a `match` statement per kind duplicated across files.

## 10. Deliberately out of scope

Enemy movement phases, one-shot ability charges, multiple simultaneous player pieces, procedural level generation, save/load, art, audio, and export configuration. All of these should be easy to add if the architecture constraints above are respected.
