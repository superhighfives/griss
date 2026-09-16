---
title: Fix the iOS crash on every move
status: Complete
created: 2026-09-16
updated: 2026-09-16
---

# Fix the iOS crash on every move

## Goal

Making a move crashed the app on iOS. Find the cause and fix it.

## Context

Reported against the TestFlight build with a guess that the sound effects
were involved. They aren't: every `SoundHooks` method is still a literal
`pass` (M4 scoped them as unimplemented), so the call sites in
`GameController` can't fail. The real cause is the other half of the same
M4 commit — the highlight pulse tween.

## Overview

`BoardView._pulse_highlight()` created its looping tween with
`create_tween()`, i.e. `self.create_tween()`. `Node.create_tween()` binds
the tween to **the node it is called on**, not to the object passed to
`tween_property()`. So the pulse tween was bound to `BoardView`, which
outlives every move, rather than to the highlight it animates.

`clear_highlights()` `queue_free()`s the highlights, and `refresh()` calls
it on every move. From the next frame on, each orphaned tween was stepping
a freed target. That is fatal rather than merely wasteful:

- `set_loops()` makes the tween loop forever.
- `PropertyTweener::step()` on a freed target returns immediately **without
  consuming any delta**.
- So `Tween::step()`'s `while (running && rem_delta > 0)` never advances
  and never ends.

Godot detects this — but only in debug builds. The check is inside
`#ifdef DEBUG_ENABLED` (`scene/animation/tween.cpp`), where it prints
"Infinite loop detected" and kills the tween. **Export templates compile
that check out.** In the editor the engine silently cleaned up after the
bug; in the release build shipped to TestFlight, the main thread wedged in
an unbounded loop on the first frame after a move and iOS's watchdog killed
the app. That asymmetry is exactly why this shipped.

Measured on a scripted 10-move playthrough of level 1: 11 "Infinite loop
detected" errors before the fix, 0 after.

## Architecture

**`game/board_view.gd`** — two one-line changes, both making a tween belong
to the node it animates:

- `_pulse_highlight()`: `highlight.create_tween()` instead of
  `create_tween()`. The tween now dies with the highlight, so
  `clear_highlights()`'s existing `queue_free()` genuinely is sufficient
  teardown — which is what the M4 comment already claimed, and now is true.
- `_update_piece_node()`: `body.create_tween()` instead of `create_tween()`.
  Same class of bug at the sibling call site. This one could not hang (it
  doesn't loop, so a dead target just ends it), but a piece captured
  mid-tween should take its tween with it, and the rule is worth applying
  uniformly rather than leaving one site to be copied later.

**`tests/test_board_view.gd`** — new, two regression tests, one per call
site. Both assert ownership via its observable consequence: a tween bound
to a node is paused while that node is outside the tree. Each test detaches
only the animated node, leaves `BoardView` in the tree, lets real frames
pass, and asserts the animated property did not move.

Counting `SceneTree.get_processed_tweens()` was tried first and rejected:
it cannot distinguish the two cases, because the debug build's own
infinite-loop guard reaps the orphans within a frame, leaving identical
counts. The property-freeze assertion has no such blind spot — verified by
reverting each binding independently and watching the matching test fail
with the actual before/after values.

**`tests/run_tests.gd`** — a tween bound to a node only steps once that node
is inside the tree and frames are being processed, and neither is true
during `SceneTree._initialize()`, where tests run. The runner now awaits a
test that returns a `GDScriptFunctionState`, so a test can `await` frames.
Detection is by `get_class()` because `GDScriptFunctionState` has no
script-visible type name. Existing synchronous tests are untouched.

46/46 green (44 before, plus the 2 new).

## Deviations

The reported suspicion (sound effects) was wrong, but pointed at the right
commit: the crash and the sound hooks both arrived in M4. `SoundHooks` was
left exactly as it is — still no-ops, still in scope for a later milestone.
