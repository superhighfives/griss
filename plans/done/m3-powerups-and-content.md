---
title: M3 — Powerups and content
status: Complete
created: 2026-09-15
updated: 2026-09-15
---

# M3 — Powerups and content

## Goal

Promotion tiles, the promotion track, upgraded movement reflected in
highlights, five hand-authored levels of rising difficulty, and a minimal
level-select list, per [`docs/PLAN.md`](../../docs/PLAN.md) section 8.
Done when level 5 requires at least one promotion to be solvable.

## Context

M0–M2 were done before this started. The promotion track and powerup
consumption logic already existed in `core/` from M1, ahead of schedule —
this milestone turned out to be almost entirely `game/`-layer rendering,
a level-select UI, and level design.

## Overview

Powerup tiles now render on the board and disappear on consumption;
promoted movement was verified (not assumed) to update legal-move
highlights immediately, for free, with no code changes needed. Built a
minimal runtime-constructed level-select screen replacing the hardcoded
level path. Added three new levels reaching the required five, the last
of which is proven — not just designed to look like — impossible to
solve without promoting.

## Architecture

**Powerup rendering** (`BoardView._rebuild_powerups()`): a small centered
marker per `state.powerups` entry, rebuilt every `refresh()` the same way
threats and pieces already were — no caching to go stale.

**Promotion verified, not assumed**: a scratch script drove a pawn onto a
promotion tile via `GameController` directly and confirmed
`get_legal_moves()` returned knight-shaped moves immediately after,
matching hand-computed values exactly. `MoveGen.legal_moves()` dispatching
on `piece.kind` and `show_highlights()` rendering whatever that returns
meant this needed zero game-layer changes.

**Level-select UI** (`game/main.gd`): restructured so loading a level is
a reusable `_load_level(path)` that tears down any previous
`board_view`/`input_controller`/`hud` first. `_ready()` now shows a
runtime-built button list (`LEVELS` const array) instead of loading a
level immediately; `Hud` gained a `levels_requested` signal and a
"Levels" button wired to return to that list. Still one `.tscn` — the
list is built the same way the board itself is, per the architecture
constraint in `docs/PLAN.md` §2.

**New verification tool, checked in**: `tools/solve_level.gd` — a BFS
solver over `(pos, kind, moves_used)` states using the real
`MoveGen`/`Rules` engine, with an optional `--forbid-promotion` flag that
prunes any branch where the piece's kind changes. This was worth
committing rather than discarding (unlike M2's scratch script) because it
paid for itself twice during level design: it found a genuinely shorter
solution to `02_under_threat.json` than the hand-planned one, and it
caught an invalid `(+2,+2)` "knight move" in an early draft of a new
level's intended path — not a legal knight delta at all — before that
level was ever trusted. `--forbid-promotion` is what actually *proves*
level 5 requires promotion, rather than asserting it from the level's
geometry.

**Content — five levels**: `01_first_steps` and `02_under_threat`
(unchanged, already existed). `03_powerup_intro` introduces the mechanic
in a position every path lands on, guaranteeing every player sees it once
before it matters. `04_point_of_no_return` and `05_the_gauntlet` both
place the powerup at a position a pawn's two-square first move can jump
*over* without landing on it, with a wall directly beyond that
skippable point — solver-confirmed: `--forbid-promotion` finds no
solution for either, because an unpromoted pawn that skips the tile
walks straight into the wall with no lateral move to escape.
`edge_case_boxed_in.json` (renamed from `03_boxed_in.json`) stays
selectable but outside the numbered five — it's an M2 rules-edge-case
demo, not a difficulty step.

**Deviation from the plan, and why it's fine**: the plan called for level
4 to make promotion "meaningfully help... without being strictly
mandatory," reserving the hard requirement for level 5 alone. It turned
out structurally difficult to honor for *any* pawn-start level with a
real obstacle: a pawn only ever moves in its own column (no lateral
escape), so once a level places anything blocking that column, promoting
into a laterally-mobile piece stops being optional and becomes the only
way to survive. Rather than force an artificially safe, promotion-optional
level 4 that would have undersold the mechanic, both 4 and 5 ended up
solver-confirmed to require promotion — the real difference between them
is 5's added enemy, which the solver confirms genuinely lengthens the
optimal solution (6 moves for level 4, 8 for level 5) rather than being
decorative. The plan's binding requirement — level 5 requires promotion —
holds regardless.

Full headless suite green (44/44, unchanged — no new core logic). Manual
verification happened both deliberately (a fresh launch screenshot of the
level-select list) and, usefully, by accident — a live playthrough during
testing confirmed level selection, actual move-making, and the threat
overlay's rendering all work correctly end to end, closing the gap M2's
writeup had flagged (logic-verified but never visually confirmed).
