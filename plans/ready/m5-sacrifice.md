---
title: M5 — Sacrifice
status: Ready
created: 2026-09-16
updated: 2026-09-16
---

# M5 — Sacrifice

## Goal

Enemies actually move and capture instead of sitting still, and the
player can field more than one piece — with the goal being to get **one**
of them to the end, so deliberately losing a piece to protect or enable
another becomes real strategy. Turn order defaults to real-chess-style
alternation (one enemy acts per player move), with "every enemy acts per
turn" available as a togglable experiment per your answer.

## Context

This came out of a design conversation, not `docs/PLAN.md` (which
`M0`–`M4` already fully covered) — enemy movement was explicitly out of
scope for the original MVP (`docs/PLAN.md` §10: "Enemy movement phases...
should be easy to add if the architecture constraints above are
respected"). `Rules.advance_enemies(state)` has been sitting as a
documented no-op stub since M0 for exactly this.

Multiple player pieces and enemy movement are bundled into one milestone
because they're the same design question: "one enemy moves per turn, like
real chess" only becomes an interesting choice once the player also has
more than one piece to choose from each turn — with a single player piece
there's no real alternation to speak of, just "you move, then the one
enemy responds."

**The core data model barely changes.** `BoardState.pieces` is already
just `Array[Piece]` with a `team` field — nothing stops multiple `team: 0`
pieces today except `get_player_piece()` only ever returning the first
match, and every call site assuming there's exactly one. The `game/`
layer's click-to-select logic has the same assumption.

## Decisions from our conversation

- **Turn order**: one enemy moves per player turn by default (matches
  chess alternation). "Every enemy moves per turn" is a togglable mode
  to experiment with, not a replacement.
- **Enemy AI**: simple heuristic — capture a player piece if any enemy
  has a legal capturing move this turn; otherwise, move whichever
  enemy/move combination reduces distance to the nearest player piece the
  most. No lookahead/minimax.
- **Multiple player pieces**: yes. Win condition becomes "any player
  piece reaches the goal row," not "the player piece."

## Proposed design changes — please review before this moves to in-progress

These follow from the above but aren't things you explicitly signed off
on yet, and they change existing tested behavior:

1. **`LOSS_THREATENED` goes away as an instant-loss rule.** Right now,
   moving onto a square an enemy *could* reach is immediate death. That
   made sense when enemies never actually moved — it was the only way a
   static enemy could ever pose a threat. Once enemies really move and
   capture, "you might get captured next turn" should be a real risk you
   can choose to take (exactly what makes sacrifice a choice), not an
   automatic loss. The threat overlay (`BoardView`'s red tint) stays as
   visual information — it just stops being a trap that ends the game by
   itself. Loss instead becomes:
   - Every one of your remaining pieces has been captured, and none
     reached the goal (new terminal condition).
   - Move budget exhausted (unchanged).
   - Every remaining player piece has zero legal moves (unchanged in
     spirit, extended from "the" piece to "every" piece).

   **Impact**: `02_under_threat.json`, `04_point_of_no_return.json`, and
   `05_the_gauntlet.json` were all designed around instant-threat-loss.
   They'll still work as levels, but their actual difficulty/feel will
   change — a "wrong" move becomes "this piece might die" rather than
   "you lose right now." Worth replaying and possibly retuning once this
   lands, not necessarily before.

2. **Level schema**: `"player": {kind, pos}` (singular) becomes
   `"players": [{kind, pos}, ...]` (array). This is a breaking format
   change — recommending a clean migration (update all 6 existing level
   files) over maintaining both schemas indefinitely, since this project
   has few levels and no external consumers of the format yet. Also
   adding an optional `"enemy_turn_mode": "one" | "all"` field, defaulting
   to `"one"` when absent so existing levels don't need it.

If either of these isn't what you had in mind, easier to redirect now
than after implementation.

## Approach

**`core/`**:

- `BoardState.get_player_piece()` → `get_player_pieces() -> Array[Piece]`.
  Update every call site (there are only a handful: `Rules`,
  `GameController`, `main.gd`).
- `Rules.check_outcome()`: WIN if any player piece's `pos.y == goal_row`;
  new loss branch if `get_player_pieces()` is empty and no win happened;
  `LOSS_NO_MOVES` (budget) unchanged; `LOSS_NO_MOVES` (stuck) becomes "every
  remaining player piece has zero legal moves," not just one. Drop the
  `LOSS_THREATENED` branch per the proposal above (`MoveGen.threatened_squares`
  stays — `BoardView` still uses it for the overlay).
- New `Rules.Outcome` value for "all your pieces are gone" — naming TBD
  (`LOSS_ELIMINATED`? `LOSS_NO_PIECES`?) — pick something the `Hud` can
  turn into a clear message.
- `Rules.advance_enemies(state, mode: String)` (replacing the no-op
  stub): implements the heuristic above. For `"one"`, evaluate every
  enemy's legal moves, act on the single best (enemy, move) pair. For
  `"all"`, run the same per-enemy heuristic for every enemy in sequence
  (later enemies see the board state after earlier ones have already
  acted, including any captures).
- `Level`/`LevelLoader`: `players: Array[Dictionary]` replacing the
  singular `player`; new `enemy_turn_mode: String` field
  (`"one"`/`"all"`, default `"one"`), validated the same way other
  optional fields are.

**`game/`**:

- `GameController.try_move()`: after the player's move resolves and
  outcome is checked, if still `ONGOING`, call `Rules.advance_enemies()`
  per the level's configured mode, then check outcome again (an enemy's
  capture could now end the game) before emitting signals. Sound hooks
  (`on_capture`, `on_loss`, etc.) should fire correctly either way since
  they're keyed off state diffs, not off whose turn it was — verify this
  rather than assume it.
- `InputController`/`main.gd._on_cell_clicked`: selecting a piece needs
  to check *any* player piece at the clicked position, not `player.pos ==
  pos` against a single implied piece. Track the selected piece by id as
  today, just sourced from `get_player_pieces()`.
- Enemy movement should animate for free through `BoardView`'s existing
  tween-by-id diffing (`_update_piece_node`) — enemies are just more
  `Piece` entries in `state.pieces`, and that code doesn't care which
  team a piece belongs to. Verify this rather than assume it, the same
  way M3's promotion-highlights question was verified rather than
  guessed at.
- Migrate all 6 existing level JSON files to the new `players` array
  schema.
- At least one new level built around sacrifice — a layout where getting
  every piece through isn't possible, but getting one through is, so the
  mechanic this milestone exists for is actually demonstrable.

**Verification** (same discipline as M2/M3 — `tools/solve_level.gd` will
need updating for multi-piece state, since a "solved" state is now "any
player piece on the goal row" rather than a single tracked piece):

- Extend the BFS solver for multiple player pieces and the new outcome
  space, or accept it only searches with one designated piece to move
  each turn (decide based on how painful the state space gets — flag
  honestly in the done writeup either way, don't quietly under-scope it).
- New core tests for: multi-piece win (any piece on goal), the new
  all-pieces-eliminated loss, "every remaining piece stuck" loss,
  `advance_enemies()` capturing when available, `advance_enemies()`
  closing distance when no capture is available, and `"all"` mode moving
  every enemy in one call.

## Tasks

- [ ] `BoardState.get_player_pieces()`, update all call sites.
- [ ] `Rules.check_outcome()`: multi-piece win/loss, drop
      `LOSS_THREATENED`, new all-eliminated outcome.
- [ ] `Rules.advance_enemies(state, mode)`: capture-if-available, else
      close distance; `"one"` vs `"all"` modes.
- [ ] `Level`/`LevelLoader`: `players` array, `enemy_turn_mode` field.
- [ ] Migrate all 6 existing levels to the new schema.
- [ ] `GameController.try_move()`: invoke enemy turn, re-check outcome.
- [ ] `main.gd`/`InputController`: multi-piece selection.
- [ ] Verify (don't assume) enemy moves animate correctly through
      existing `BoardView` code.
- [ ] Verify (don't assume) sound hooks fire correctly regardless of
      whose turn triggered them.
- [ ] Update `tools/solve_level.gd` for multi-piece state, or explicitly
      scope-limit it and say so.
- [ ] New level demonstrating sacrifice (not all pieces can survive, one
      reaching the goal is still a win).
- [ ] New core tests per the list above.
- [ ] Full headless suite green.
- [ ] Manual playthrough of the real rendered game, including watching
      an enemy actually move and capture.

## Open questions

- Exact name for the new "all pieces eliminated" outcome — pick something
  reasonable during implementation.
- Tie-breaking when multiple enemies have an equally-good capture or
  equally-close approach move — pick something deterministic and simple
  (e.g. board order), don't overthink it.
- Whether `tools/solve_level.gd` is worth fully generalizing to
  multi-piece turn-by-turn search (state space grows a lot with enemy
  moves interleaved) or should stay single-piece-focused with an honest
  caveat — decide once the shape of `advance_enemies()` is real, not
  upfront.
