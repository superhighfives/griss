---
title: M5 — Sacrifice
status: Complete
created: 2026-09-16
updated: 2026-09-16
---

# M5 — Sacrifice

## Goal

Enemies actually move and capture instead of sitting still, and the
player can field more than one piece — with the goal being to get **one**
of them to the end, so deliberately losing a piece to protect or enable
another becomes real strategy.

## Context

Enemy movement was explicitly deferred from the original MVP
(`docs/PLAN.md` §10) — `Rules.advance_enemies(state)` had been a
documented no-op stub since M0. Bundled with multi-piece player support
because they're the same design question: one-enemy-per-turn alternation
only becomes interesting once the player has more than one piece to
choose from each turn too.

Two design changes were proposed and confirmed before implementation
started: dropping `LOSS_THREATENED` as an instant-loss rule now that
enemies can actually capture, and migrating the level schema from a
singular `player` to a `players` array.

## Overview

Enemies now move every turn using a simple capture-or-approach heuristic,
in either of two configurable modes (one enemy acts per turn, or all of
them do). The player can field multiple pieces; winning means getting any
one of them to the goal row, which makes sacrificing a piece a genuine
tactic rather than something the rules would even allow. A new level,
`06_the_sacrifice.json`, is the first level in this project whose
difficulty was tuned by binary-searching a move budget against a
solver-proved property, not by feel.

## Architecture

**Core (`core/`)**:

- `BoardState.get_player_piece()` → `get_player_pieces() -> Array[Piece]`,
  removed rather than kept alongside the plural version — every call site
  (`Rules`, `GameController`, `main.gd`, `tools/solve_level.gd`, tests)
  had to consciously handle "more than one," rather than silently keep
  using a "just grab the first" convenience method that could hide a bug
  once levels with multiple players existed.
- `Rules.apply_move()` had a real latent bug, exposed only now that
  enemies move: `state.moves_used += 1` ran unconditionally, so an enemy
  move would have counted against the *player's* move budget. Gated it
  (and powerup consumption, which was already correctly gated) to
  `piece.team == 0`. `apply_move()` is now the single, genuinely
  team-agnostic function both `GameController` (player moves) and
  `Rules.advance_enemies()` (enemy moves) call.
- `Rules.Outcome.LOSS_THREATENED` → `LOSS_ELIMINATED`. `check_outcome()`:
  any player piece on the goal row wins immediately, even with others
  still on the board; zero remaining player pieces is `LOSS_ELIMINATED`;
  budget exhaustion is unchanged; "every remaining player piece has zero
  legal moves" replaces the old single-piece stuck check.
  `MoveGen.threatened_squares()` is untouched and still drives
  `BoardView`'s warning overlay — it's just no longer consulted by the
  rules at all.
- `Rules.advance_enemies(state, mode)`: `"one"` (default) finds the
  single best `(enemy, move)` pair across every enemy — any capture
  anywhere beats any non-capture move, evaluated via a shared
  `_best_move_for()` helper also used by `"all"` mode, which just runs
  that same per-enemy heuristic for every enemy in sequence. Heuristic is
  intentionally simple, per the confirmed design: capture if available,
  otherwise minimize Manhattan distance to the nearest player piece.
- `Level`/`LevelLoader`: `players: Array[Dictionary]` replacing the
  singular `player` (loader requires at least one, rejects duplicates on
  the same square exactly like it already did for other entity types);
  new `enemy_turn_mode: String` field, validated against `"one"`/`"all"`,
  defaulting to `"one"`.

**Game (`game/`)**:

- `GameController.try_move()`: after the player's move resolves, checks
  outcome once *before* calling `Rules.advance_enemies()` — if the
  player's own move already ended the game, the enemy team doesn't get a
  turn. `_finish_turn()` (already factored out in M4) is still called
  exactly once per `try_move()`, now reflecting the enemy turn's effect
  too. `SoundHooks.on_capture()` is checked both after the player's move
  and after the enemy's — verified directly (see below), not inferred
  from reading the code, that a capture from either side fires it.
- `main.gd._on_cell_clicked()`: selects whichever player piece was
  clicked (`_player_piece_at()`), rather than assuming there's exactly
  one. Same click-to-select, click-to-move interaction, just sourced from
  `get_player_pieces()` instead of a single implied piece.
- `Hud`: `LOSS_ELIMINATED` gets its own message ("all pieces lost")
  instead of the removed threatened-loss text.
- All 6 existing levels migrated to the `players` array. No other
  content changes to them — `02_under_threat`, `04_point_of_no_return`,
  and `05_the_gauntlet` will play differently now that their enemies
  actually move (flagged as a known effect in the original plan, not a
  regression).

**Verification tooling**: `tools/solve_level.gd` was substantially
rewritten, not just touched up for the renamed API. Two changes were
necessary, not optional:

1. The BFS now interleaves a real enemy turn after every player move
   (mirroring `GameController.try_move()` exactly, including the
   "only if still ongoing" check), instead of searching player moves in
   isolation. Enemies are deterministic given a state, so this doesn't
   change the search's asymptotic shape, but it does mean the *dedup key*
   had to grow from "player position/kind" to every piece's id/pos/kind —
   enemy positions are no longer a constant the search can ignore.
2. A new `--require-all-survive` flag, symmetric to the existing
   `--forbid-promotion`: prunes any branch where the player piece count
   has dropped. This is what actually *proved* `06_the_sacrifice.json`
   requires a sacrifice, rather than asserting it from the layout — the
   same rigor `--forbid-promotion` brought to M3's promotion-required
   level.

**`06_the_sacrifice.json`**: two pawns starting in different columns (a
pawn can't move sideways, so two independent columns are what make a
real choice possible) against one knight, on an 18-move budget. Tuned by
binary search: budget 20 let both pawns survive (not a sacrifice level at
all), budget ≤16 made the level unsolvable outright, and 18 is the exact
point where `solve_level.gd` finds a win but `--require-all-survive`
proves none exists without losing a piece.

**Two things verified directly, not assumed**, per the plan's own
instruction (both M2 and M3 had prior instances of "verify, don't
assume" catching real gaps):

- Enemy movement animates through `BoardView`'s existing tween-by-id
  diffing with zero code changes — confirmed by driving a real move
  through a live `BoardView` and watching an enemy's rendered position
  actually change after the frame settles, the same technique used to
  verify M4's move tweens originally.
- Sound hooks fire correctly regardless of which side's turn triggered
  the underlying event — confirmed by temporarily instrumenting
  `SoundHooks` with prints and constructing a scenario where the
  *player's* move captures nothing, but the *enemy's* immediate response
  does (and, being the last player piece, ends the game): `on_capture()`
  and `on_loss()` both fired from the enemy-turn branch, not the
  player-move branch. Instrumentation was reverted after confirming this.

59/59 tests green (44 before this milestone; +15 for multi-piece
outcomes, the removed-threat-is-not-a-loss behavior change,
`advance_enemies()` in both modes, the `moves_used` budget fix, and the
new level schema).

## Deviations

**Multi-piece rendering wasn't independently screenshotted.** The
level-select screen (now listing "6. The Sacrifice") was visually
confirmed, but I didn't click into the sacrifice level itself and
screenshot two rendered player pieces side by side — I judged this
low-risk rather than verified, since `_create_piece_node()` has never
special-cased team or piece count; it's the same code path that's
rendered multiple enemy pieces since M2 without incident. Worth an actual
playthrough of `06_the_sacrifice.json` before considering it
content-complete, the same caveat M2's writeup made and M3 then closed.
