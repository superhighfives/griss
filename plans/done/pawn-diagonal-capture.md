---
title: Add pawn diagonal capture
status: Complete
created: 2026-09-16
updated: 2026-09-16
---

# Add pawn diagonal capture

## Goal

Pawns should be able to capture, matching real chess: they move straight
ahead but capture diagonally. Reported directly against
`06_the_sacrifice.json` — the player expected to be able to kill the
knight by getting diagonally adjacent to it, and couldn't.

## Context

This was a deliberate MVP simplification from the very first milestone
(`docs/PLAN.md` §5: "Pawn: one step forward (+y). No diagonal capture in
MVP — keep it dead simple."). Never revisited until now.

## Overview

`MoveGen._pawn_moves()` now offers a capture-only move onto either
forward-diagonal square if an enemy occupies it — a pawn still can't move
diagonally onto an empty square, and still can't capture the piece
directly ahead of it (real chess pawns can't do either). This is a pure
`core/` rules change with no `game/` code touched: `BoardView`,
`InputController`, and `GameController` already treat "a legal move" as
"a legal move" regardless of shape, so diagonal captures render, animate,
and count against the move budget exactly like every other move already
did.

The interesting part of this change wasn't the rule itself — it's that
adding it broke the sacrifice guarantee in `06_the_sacrifice.json`,
because a chasing enemy approaching a pawn will often end up exactly one
diagonal square away, which a pawn can now punish. That took three
redesigns to fix properly (see below), verified with the same
`tools/solve_level.gd` proof each time rather than assumed fixed.

## Architecture

**`core/move_gen.gd`**: the old `_pawn_moves()` used an early `return`
when the square directly ahead was blocked — reasonable when the only
other case being handled was "no moves at all," but wrong once diagonal
capture existed, since a pawn blocked straight ahead can still capture to
either side in real chess. Restructured so the forward-move check (and
the two-square-first-move check nested inside it) no longer prevents the
diagonal-capture check below it from running.

Four new tests in `tests/test_move_gen.gd`: a normal diagonal capture on
both sides simultaneously, confirming no diagonal move exists onto an
empty square, confirming a friendly piece diagonally ahead can't be
"captured," and confirming a diagonal capture is still available when the
pawn is blocked straight ahead by a *different* piece — the specific case
the restructured early-return logic exists to handle correctly.

**`06_the_sacrifice.json` had to be redesigned, not just re-verified.**
Running `tools/solve_level.gd --require-all-survive` against the
shipped M5 version immediately found a solution — both pawns survived,
because one of them simply killed the pursuing knight diagonally once it
closed in. Three attempts to restore the guarantee, each checked with the
solver rather than assumed:

1. A second knight, on the theory that killing one still leaves a
   threat. Didn't help — `--require-all-survive` still found a solution;
   nothing stops a pawn from picking off knights one at a time as they
   individually close to melee range.
2. A bishop instead of a knight. Worse: the *unconstrained* search found
   a 10-move win where the second pawn never even had to move, because
   the bishop got diagonally sniped just as easily as the knights had.
3. A bare rook. Overcorrected — a rook aligns with a column and snipes
   down it from any range, and turned out to be strong enough that even
   the unconstrained search found no win at all, regardless of budget.

The insight that actually worked: a rook approaching to minimize distance
naturally ends up *orthogonally* adjacent (same row or column) to a
stationary target, never diagonally — diagonal adjacency would mean an
unnecessarily inefficient approach the distance-minimizing heuristic
wouldn't choose. So a rook is structurally close to immune to this
pawn's counter-capture, without needing to be tuned into that immunity by
distance alone. Fixed the "rook is simply too strong" problem the same
way `04_point_of_no_return.json` and `05_the_gauntlet.json` already
solved a different problem: a wall. Column `x=2` is walled solid for the
entire board height, splitting it into two halves neither pawn ever needs
to cross (each only needs its own column) but the rook can never cross
either — confining it to one pawn's half permanently. `--require-all-survive`
now correctly finds no solution; the unconstrained search finds a
10-move win using only the untouched pawn, which is the sacrifice the
level is named for.

All other levels re-verified unaffected by the rule change:
`01_first_steps` through `05_the_gauntlet` and `edge_case_boxed_in` all
produced identical solutions (or identical unsolvability, for the
boxed-in case) to before, and `04`/`05`'s promotion-required proofs
(`--forbid-promotion`) still hold.

63/63 tests green (59 before, +4 for diagonal capture).

## Deviations

None from the request itself — the pawn rule is exactly what was asked
for. The level redesign was unplanned work the rule change made
necessary, not scope creep; documented in detail above since the dead
ends (two knights, a bishop) are as informative as the fix that worked.
