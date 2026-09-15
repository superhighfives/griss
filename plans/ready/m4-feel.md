---
title: M4 — Feel
status: Ready
created: 2026-09-15
updated: 2026-09-15
---

# M4 — Feel

## Goal

Per [`docs/PLAN.md`](../../docs/PLAN.md) section 8: move tweens (~120ms), a
subtle highlight animation, sound hooks left unimplemented, and a `Tuning`
script holding cell size, colors, and animation durations as constants in
one place. This is the last milestone in the original plan — polish, not
new mechanics.

## Context

M0–M3 are done (`plans/done/`). Every constant this milestone needs to
centralize currently lives as `const` declarations at the top of
`game/board_view.gd`:

```
CELL_SIZE, BOARD_OFFSET, CELL_MARGIN, PIECE_MARGIN, POWERUP_MARKER_SIZE,
COLOR_CELL, COLOR_WALL, COLOR_GOAL, COLOR_PLAYER, COLOR_ENEMY,
COLOR_HIGHLIGHT, COLOR_THREAT, COLOR_POWERUP
```

Movement and highlight changes today are instant — `BoardView._rebuild_pieces()`
frees and recreates every piece node on each `refresh()`, and
`show_highlights()`/`_rebuild_threats()`/`_rebuild_powerups()` do the same
for their own overlays. There's no animation layer at all yet.

`docs/PLAN.md` §2's architecture constraint still applies: no new scenes,
build everything in code.

## Approach

- **`Tuning`**: a single new script (`game/tuning.gd` or `core/tuning.gd`
  — `game/` fits better since these are all presentation constants, not
  rules) holding every constant listed above, referenced from
  `BoardView` instead of its own local consts. Per `docs/PLAN.md` §9,
  this is the one exception to "no Autoload/singletons" if it ends up
  needing to be one — but a plain `class_name Tuning extends RefCounted`
  with `const` fields, referenced as `Tuning.CELL_SIZE` etc., needs no
  autoload at all and fits the existing static-class-with-consts pattern
  `PieceKind` already uses. Prefer that over an autoload unless a real
  need for instance state shows up.
- **Move tweens**: when a piece's `pos` changes (a real move, not the
  free/recreate that already happens on `refresh()`), animate its node
  from the old screen position to the new one over ~120ms instead of
  snapping. This likely means `_rebuild_pieces()` needs to stop
  unconditionally freeing and recreating every piece — diff against the
  previous frame's piece nodes by `piece.id`, move existing ones (via
  `Tween`), and only create/free nodes for pieces that actually
  appeared/disappeared (captures, promotions changing the letter).
- **Highlight animation**: a subtle effect on `show_highlights()`'s
  cells — a gentle pulse/fade via `Tween` is likely enough. Keep it
  subtle per the plan wording; this is polish, not a new mechanic.
- **Sound hooks**: per the plan, these stay **unimplemented** — the task
  is leaving clearly-marked call sites (e.g. a no-op `Tuning.play_sound()`
  or just a comment) at the natural trigger points (move, capture, win,
  loss, promotion), not adding actual audio.

## Tasks

- [ ] Create `Tuning` with every constant currently in `BoardView`;
      update `BoardView` to reference it instead of local consts.
- [ ] Animate piece movement (~120ms tween) instead of the current
      instant free/recreate-in-place.
- [ ] Add a subtle highlight animation to `show_highlights()`.
- [ ] Leave clearly-marked, unimplemented sound hook points at
      move/capture/win/loss/promotion.
- [ ] Full headless suite green — this milestone shouldn't touch `core/`
      at all, so this is mostly a regression check.
- [ ] Manual playthrough of the real rendered game (per the now-standing
      convention from M2/M3) — this milestone is *entirely* about how it
      feels to play, so a headless check alone would miss the point
      more than usual here.

## Open questions

- Exact tween easing/timing beyond "~120ms" — resolve by feel during
  implementation, not upfront.
