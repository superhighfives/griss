---
title: M3 — Powerups and content
status: In Progress
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

M0–M2 are done (see `plans/done/`). Unusually for this milestone, the core
promotion logic **already exists and is already tested** — it landed
alongside M1's powerup-consumption code, ahead of schedule:

- `PieceKind.PROMOTION_TRACK` + `next_in_promotion_track()` — the
  `PAWN → KNIGHT → BISHOP → ROOK → QUEEN` track, `QUEEN` terminal.
- `Rules.apply_move()` already consumes a `"promote"` powerup tile and
  advances `piece.kind` on entry.
- `tests/test_rules.gd` already covers the full promotion track including
  the queen-terminal case.

So this milestone is almost entirely `game/`-layer work and content, not
new core rules:

1. **Powerup tiles aren't rendered at all.** `BoardView._build_cells()`
   only checks `is_wall`/`goal_row` — a `state.powerups` tile is
   currently invisible on the board.
2. **Upgraded movement in highlights should already work for free** —
   `MoveGen.legal_moves()` dispatches on `piece.kind`, and
   `show_highlights()` just renders whatever that returns. Once a
   promotion changes `piece.kind`, the next highlight computation should
   already reflect the new movement. Verify this rather than assume it.
3. **No level-select UI exists** — `main.gd` hardcodes
   `LEVEL_PATH = "res://levels/01_first_steps.json"`. Per the
   architecture constraint in `docs/PLAN.md` §2 ("One scene:
   `res://game/Main.tscn`... Build the board in code, not in the
   editor"), this has to be runtime-built UI in the existing scene, not a
   second `.tscn`.
4. **Only 3 levels exist**, and two of them (`02_under_threat`,
   `03_boxed_in`) were built as M2 mechanic demonstrations, not a
   difficulty progression — `03_boxed_in` in particular is a one-cell
   instant-loss edge case, not a real "level" a player progresses through.

## Approach

- **Powerup rendering**: in `BoardView._build_cells()`, give a cell with
  a `state.powerups` entry a distinct color (or a small marker on top of
  the base cell color, if the goal-row/powerup combination needs to stay
  distinguishable). Needs to disappear once consumed — `refresh()` already
  runs `_rebuild_pieces()` and threats on every `state_updated`; either
  extend it to rebuild cell coloring too, or rebuild cells entirely on
  refresh (simplest, and cells are cheap - the board is at most a few
  dozen cells).
- **Verify upgraded movement**: after a promotion, select the piece again
  and confirm `get_legal_moves()` reflects the new kind. Do this with a
  script driving `GameController` directly (same pattern as M2's
  verification), not by assumption.
- **Level-select UI**: minimal runtime-built list in `$UI`, shown before
  a level is loaded. Restructure `main.gd` so loading a level is a
  reusable function (tear down the old `board_view`/`input_controller`/
  `hud` cleanly, build the new ones) rather than something only `_ready()`
  does once. Add a way back to the list (a HUD button) so switching
  levels doesn't need an app relaunch.
- **Content — five levels, rising difficulty**:
  1. `01_first_steps.json` — existing, unchanged. Plain traversal.
  2. `02_under_threat.json` — existing, unchanged. Enemy, threat overlay,
     capture-or-dodge.
  3. `03_powerup_intro.json` (new) — introduces the promotion tile in a
     low-stakes layout. Goal reachable either way; this level's job is
     teaching the mechanic, not gating on it.
  4. `04_...json` (new, name TBD once designed) — combines enemies and a
     powerup at moderate difficulty. Promotion should meaningfully help
     (e.g. a safer or shorter route) without being strictly mandatory —
     per the plan, only level 5 must require it.
  5. `05_...json` (new, name TBD) — the capstone. Constructed so that
     *without* promoting, the goal is provably unreachable (a wall/enemy
     configuration only a promoted piece's movement can get past), with a
     powerup positioned on the only viable route. Verify both the
     intended promoted solution *and*, as best as hand-reasoning allows,
     that the movement constraints genuinely rule out an unpromoted
     route — don't just assert it.
  `03_boxed_in.json` is not part of this five — it's an M2 rules-edge-case
  demo (immediate `LOSS_NO_MOVES`), not a difficulty step. Rename it out
  of the numbered sequence (e.g. `edge_case_boxed_in.json`) so it doesn't
  compete with the five for a level-select slot, but keep it selectable.
- **Verification discipline** (carried over from M2, where it caught a
  real arithmetic mistake before it shipped): every new level gets walked
  with a scratch script driving `GameController.try_move()` through a
  hand-planned path before being trusted, not just eyeballed.

## Tasks

- [ ] Render powerup tiles in `BoardView` (visible, disappears on
      consumption).
- [ ] Verify (don't assume) that legal-move highlights reflect a piece's
      new kind immediately after promotion.
- [ ] Rename `03_boxed_in.json` → `edge_case_boxed_in.json`, update any
      reference to it.
- [ ] Design and verify `03_powerup_intro.json`.
- [ ] Design and verify level 4 (enemies + powerup, moderate).
- [ ] Design and verify level 5 (promotion strictly required) — verify
      the intended solution path AND reason through why no unpromoted
      path exists.
- [ ] Build the minimal level-select UI in `main.gd`/`$UI`, replacing the
      hardcoded `LEVEL_PATH`. Include a way back to it from in-game.
- [ ] Extend tests if any new core edge case surfaces (unlikely — check
      existing coverage first, per standing convention).
- [ ] Full headless suite green.
- [ ] Manual playthrough of the real rendered game (not just the
      headless verification scripts) — M2's done-writeup flagged this as
      a gap last time; don't repeat it for M3.

## Open questions

- Exact layout/names for levels 4 and 5 — resolve during implementation,
  not upfront; the difficulty curve matters more than the specific
  geometry.
