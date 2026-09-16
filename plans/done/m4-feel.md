---
title: M4 — Feel
status: Complete
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

M0–M3 were done before this started (`plans/done/`). This was the last
milestone in the original `docs/PLAN.md` brief.

## Overview

Centralized every presentation constant into a new `Tuning` script,
animated piece movement instead of snapping, gave legal-move highlights a
subtle pulse, and left clearly-marked (but genuinely unimplemented, per
scope) sound hook call sites at every natural trigger point.

## Architecture

**`game/tuning.gd`**: `class_name Tuning extends RefCounted` holding every
constant `BoardView` used to declare locally (cell size, board offset,
margins, all colors) plus new animation timing constants. Referenced as
`Tuning.CONST_NAME` — no autoload needed, matching the existing
static-class-with-consts pattern `PieceKind` already used.

**Move tweens**: `BoardView._rebuild_pieces()` used to unconditionally
free and recreate every piece node on every `refresh()`, which discarded
position state every call — there was never an "old position" available
to animate from. Rewrote it to diff against `_piece_nodes` by piece id:
pieces still present get `_update_piece_node()` (animates `position` via
`create_tween().tween_property()` over `Tuning.MOVE_TWEEN_DURATION` if it
changed, updates the label if `kind` changed from a promotion), and only
pieces that actually left the board (captures) get freed. Verified with a
headless script that processed real frames via `create_timer().timeout`
(not just checking end-state): `body.position` is confirmed still at the
start position immediately after `try_move()`, then confirmed exactly at
the target position after waiting past the tween duration — proof it's
genuinely animating, not just computing the right final value.

**Highlight pulse**: `show_highlights()` starts a looping
`Tween` per highlight cell, oscillating `color:a` between
`Tuning.HIGHLIGHT_PULSE_MIN_ALPHA` and `MAX_ALPHA`. The tween is owned by
the highlight node itself, so `clear_highlights()`'s existing
`queue_free()` is sufficient teardown — no separate cleanup needed.

**Sound hooks** (`game/sound_hooks.gd`): a `SoundHooks` static-method
class, every method a no-op `pass`, called from `GameController` at the
points the plan named — `on_move`/`on_capture`/`on_promotion` in
`try_move()` (capture and promotion detected by comparing piece
count/kind before and after `Rules.apply_move()`), `on_win`/`on_loss`
from a new `_finish_turn()` helper shared by `load_level()`, `try_move()`,
`undo()`, and `restart()` — which also fixed a small gap: a level that's
already lost on load (like `edge_case_boxed_in.json`) now fires
`on_loss()` too, not just outcomes reached via an actual move. This
refactor preserves the exact signal emission order every call site had
before (`state_updated` then `outcome_updated`) rather than changing
behavior while consolidating it.

Full headless suite green (44/44 — briefly 42/44 mid-implementation, not
from a logic bug but a stale global-class cache: Godot didn't know about
the new `SoundHooks` `class_name` until a `godot --headless --editor
--quit-after 1` rescan, since the file was created directly rather than
through the editor). Manually verified the level-select screen still
renders correctly (no regression from the `Tuning` reference swap) with a
fresh screenshot; the actual new behavior (tweening, not the unchanged
rendering) was verified via the frame-processing script above rather than
by eye, since a ~120ms tween isn't reliably eyeball-verifiable through
this environment's screenshot tooling anyway.
