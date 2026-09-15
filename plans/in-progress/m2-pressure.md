---
title: M2 — Pressure
status: Ready
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

M0 (scaffold) and M1 (playable traversal) are done and live on `main`. The
rules engine already supports most of what M2 needs — this milestone is
mostly wiring up the game layer, not new core logic:

- `BoardState`/`Level`/`LevelLoader` already parse `team: 1` (enemy)
  pieces and a level's `enemies` array.
- `MoveGen.threatened_squares(state, team)` already computes every square
  a given team could move to — call it with `team: 1` to get the danger
  overlay.
- `Rules.check_outcome()` already has the `LOSS_THREATENED` branch,
  unit-tested.
- `GameController` already exposes `restart`/`undo`, backed by
  `BoardState.duplicate_state()`.

What's missing is entirely in `game/`: rendering the threat overlay,
surfacing loss states in the HUD, and content (a level with enemies) to
demonstrate it.

## Approach

- **`BoardView`**: add a threat-square overlay. Render
  `MoveGen.threatened_squares(state, 1)` similarly to the existing
  move-highlight rendering (`show_highlights`), but a visually distinct
  color/style so it doesn't get confused with legal-move highlights.
  Capture needs no new core work — `Rules.apply_move` already removes an
  occupied enemy on capture.
- **`Hud`**: already shows `moves_used`/`move_budget`
  (`_on_state_updated`); verify it reads clearly as the budget runs low
  (a color change past some threshold, e.g. under 3 moves remaining, is
  enough — no new mechanic needed). Already shows outcome text for all
  three `Outcome` branches (`_on_outcome_updated`) — confirm the copy
  reads sensibly for a threatened-loss vs. out-of-moves loss once real
  enemies exist.
- **Restart/undo**: already implemented in `GameController` — verify
  they're reachable from a loss state (not just mid-game) and correct
  once enemies are on the board (undo should restore threatened squares
  too, since they're derived from `state` each frame, not cached).
- **Content**: add at least one new level JSON under `levels/` with
  enemies, so all three loss paths are actually reachable:
  1. `LOSS_THREATENED` — walk onto a square an enemy threatens.
  2. `LOSS_NO_MOVES` (budget exhausted) — run out of moves before the
     goal row.
  3. `LOSS_NO_MOVES` (no legal moves) — check whether this is
     realistically constructible on a 4-wide board, or whether it needs a
     dedicated level shape (e.g. boxed in by walls and an enemy). If it
     turns out contrived or unreachable in practice, flag it rather than
     forcing a level to fit — see `docs/PLAN.md` §9's "if a rule makes a
     level unsolvable, stop and flag it" guidance.

## Tasks

- [ ] `BoardView`: render threat squares for `team: 1`, distinct from
      move highlights.
- [ ] Verify capture correctly removes the enemy's rendered piece (via the
      existing `state_updated` → `refresh` signal chain).
- [ ] `Hud`: confirm/adjust outcome copy for `LOSS_THREATENED` vs.
      `LOSS_NO_MOVES` now that enemies make both reachable.
- [ ] Verify restart/undo work correctly from a loss state, and that undo
      correctly recomputes threat squares (not stale).
- [ ] Add a new level under `levels/` with at least one enemy, reachable
      goal, and a real threatened-square trap.
- [ ] Confirm (or add a level for) the "no legal moves" loss path; flag in
      this plan if it turns out not cleanly constructible.
- [ ] Extend `tests/test_move_gen.gd`/`tests/test_rules.gd` for any new
      edge case that surfaces — check existing threat-square coverage per
      piece kind first, it's already fairly thorough.
- [ ] Full headless suite green: `godot --headless --path . --script res://tests/run_tests.gd`.
- [ ] Manually verify in a real run (`godot --path .`) — headless tests
      cover the rules, not the rendering/click-through experience.

## Open questions

- Is "stuck with no legal moves" actually a distinct third loss condition
  on a 4-wide board, or does it collapse into one of the other two in
  practice? Resolve during implementation (see Approach above); don't
  block starting on this.
