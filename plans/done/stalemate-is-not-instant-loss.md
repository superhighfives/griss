---
title: A capture-free block shouldn't be an instant loss
status: Complete
created: 2026-09-16
updated: 2026-09-16
---

# A capture-free block shouldn't be an instant loss

## Goal

A piece merely standing in the player's way — not threatening to capture
them, just physically blocking their only forward move — shouldn't end
the game outright if that piece will be forced to move off on its own
very next turn.

## Context

Reported directly against `07_the_shove.json`: a knight ended up parked
one square directly ahead of the player's pawn. That relative position
(directly ahead, one square) is never a legal knight move, so the knight
posed no capture threat at all — yet the game declared an immediate
`LOSS_NO_MOVES` the moment the pawn had no legal move, without giving the
knight a chance to move off first. The player's framing was useful:
this isn't "checkmate" (no threat is involved at all), and it isn't even
really analogous to chess stalemate either, since in chess stalemate is a
**draw** for whoever can't move, not a loss — Griss already treats *any*
zero-legal-moves state as a loss (`Rules.check_outcome`'s
`LOSS_NO_MOVES`, predating this fix and unchanged by it). The actual bug
was narrower and mechanical: enemies never have a "stay put" option
(`advance_enemies()` always takes the single legal move that most helps
an enemy, if it has any), so a blocking piece with other legal moves
available to it was always going to move off on its own very next turn —
the game just never gave it that turn before declaring defeat.

## Overview

`GameController.try_move()` and `tools/solve_level.gd` both used to call
`Rules.advance_enemies()` exactly once per player turn, then immediately
check the outcome. Now they call a new `Rules.advance_enemies_and_-
resolve_stalemate()`, which keeps granting the enemy team further turns —
as if the player passed — for as long as the player still has no legal
move and at least one enemy still does. A non-threatening block resolves
itself within the same turn instead of ending the game. A genuine
deadlock (no enemy can move either) is unaffected and still ends the game
immediately, exactly as before.

## Architecture

- New `Rules.advance_enemies_and_resolve_stalemate(state, mode)`: calls
  `advance_enemies()` once unconditionally (unchanged first-turn
  behavior), then loops calling it again while the player has zero legal
  moves *and* some enemy still has one, using two small new helpers
  (`_any_player_piece_can_move()`, `_any_enemy_can_move()`) rather than
  `check_outcome()` directly — `check_outcome()` conflates "no legal
  moves" with "budget exhausted" into the same `LOSS_NO_MOVES` value, and
  only the former should keep looping. Capped at
  `_MAX_STALEMATE_ENEMY_TURNS` (64) as a safety net against a
  pathological oscillation that never frees the player; none of the
  current levels come close to needing it.
- `GameController.try_move()` and `tools/solve_level.gd`'s BFS transition
  both call the new function instead of `advance_enemies()` directly —
  the same pattern the project already follows for keeping the solver's
  turn resolution mirroring the real game exactly (see
  `plans/done/m5-sacrifice.md`).
- `Rules.check_outcome()` itself is unchanged — it's still a pure
  per-state predicate. Only *when* it gets called changed: by the time
  it's asked "does the player have a move," the enemy team has already
  been given every turn it's owed.
- An enemy can still capture the player during one of these extra
  "passed" turns if a capture becomes available partway through — this
  is intentional, not a gap: it's what would happen if the enemy could
  genuinely act freely while the player is stuck, and a capture is a real
  possible outcome of "the block resolves itself," not just an escape.

**Tests**: two new `Rules` tests isolate the mechanism directly — a
knight parked one square directly ahead of a pawn (no capture available,
some other legal move) gets to move off and the pawn regains a legal
move; an enemy pawn in the same blocking position but with zero legal
moves of its own never moves, and the outcome stays `LOSS_NO_MOVES`. A
third, `GameController`-level test reproduces the actual reported bug
end to end: a level tuned so a knight's own capture-or-approach heuristic
lands it exactly one square ahead of the player's pawn after the pawn's
first move, confirming `try_move()` itself no longer ends the game there.
72/72 tests green (69 before this fix).

All seven real levels re-verified against `tools/solve_level.gd` after
the change — same solutions found for all of them, and both
solver-proved properties (`06_the_sacrifice.json` requires a sacrifice,
`07_the_shove.json` requires playing Push Back) still hold.

## Deviations

None — this was a small, targeted fix to a specific reported bug rather
than a milestone with open design questions.
