---
title: M2 — Pressure
status: Complete
created: 2026-09-15
updated: 2026-09-15
---

# M2 — Pressure

## Goal

Add static enemies, threat-square danger, and loss states to `core/` and
`game/`, per [`docs/PLAN.md`](../../docs/PLAN.md) section 8. Done when a
level can be lost three distinct ways and restarted without a scene
reload.

## Context

M0 (scaffold) and M1 (playable traversal) were done and live on `main`
before this started. The rules engine already supported everything M2
needed — `MoveGen.threatened_squares()`, `Rules.check_outcome()`'s
`LOSS_THREATENED` branch, `GameController.restart`/`undo` — so this was
entirely a `game/`-layer and content milestone, no new core logic.

## Overview

Shipped the threat-square overlay, verified restart/undo/capture all
already worked correctly with enemies on the board (they did, for free —
see Architecture), and added two levels that between them make all three
loss conditions concretely reachable, resolving the plan's open question
about whether "no legal moves" is a real distinct case (it is, and it's
trivial to construct).

## Architecture

**`BoardView`** (`game/board_view.gd`) gained `_rebuild_threats()`,
rendering `MoveGen.threatened_squares(state, 1)` as a red-tinted overlay
distinct from the yellow selection highlight. Rebuilt on every `refresh()`
— not tied to piece selection like `show_highlights()`, so danger stays
visible regardless of selection state — and rebuilt before pieces each
refresh so the tint sits under them, not over.

**No changes needed** to capture, restart, or undo: `Rules.apply_move`
already removed a captured enemy from `state.pieces`, and `refresh()`
(called on every `state_updated` emission, including from `restart()` and
`undo()`) recomputes `_rebuild_threats()` from the live state every time —
there was never anywhere for a stale threat square to hide. Verified this
by tracing the signal chain rather than assuming it; no code changes were
the actual finding here.

**Content**: `levels/02_under_threat.json` and `levels/03_boxed_in.json`.
The under-threat level starts the player as a **knight**, not a pawn —
a pawn can only move straight forward, so it can never dodge a threat
placed in its own column; a real avoid-or-capture puzzle needs a piece
with lateral movement. Verified end to end with a scratch script (not
committed) driving `GameController.try_move()` through hand-planned paths
before trusting the level: a reckless path lands on a threatened square
(`LOSS_THREATENED`), and a 7-move path capturing the bishop en route
reaches the goal row (`WIN`) inside the 10-move budget. Caught a real
arithmetic mistake this way — an initially-planned path used a `(+2,+2)`
delta that isn't a legal knight move at all — before it ever reached a
level file.

`03_boxed_in.json` resolves the open question directly: a pawn walled in
one square ahead of its start has zero legal moves from turn one
(pawns have no lateral escape), which is `LOSS_NO_MOVES` with
`moves_used = 0` — genuinely distinct from budget exhaustion, and
trivially constructible.

**Deviation / honest gap**: verification for this milestone was headless
(the scratch script) plus a successful CI build/deploy, not an
interactive playthrough of the actual rendered scene confirming the red
overlay looks right and the two new levels play as designed on-device.
The rules-level behavior is solid; the *visual* result of `_rebuild_threats()`
hasn't been eyeballed by a human yet. Worth a real playthrough before
calling the levels "content-complete" rather than just "logic-complete."

No new unit tests were added — no new core-layer behavior was introduced
(threat squares and capture logic already existed and were already
tested from M1); existing coverage was reviewed first per the plan's own
guidance and found already thorough.
