---
title: M6 — Cards
status: Complete
created: 2026-09-16
updated: 2026-09-16
---

# M6 — Cards

## Goal

Powerup tiles grant a card instead of an immediate effect. Cards are
played at the player's choice; each turn allows up to one card play
**plus** one move (both, not either/or). Starting card set: "Promote"
(what powerup tiles already did — advance a chosen piece up the
promotion track) and "Push Back" (push every enemy one square away from
the nearest player piece).

## Context

Followed up directly from the M6 backlog entry, now with the real open
questions resolved in conversation:

- **Acquisition**: picking up a powerup grants a card to a hand, rather
  than applying its effect immediately.
- **Turn cost**: playing a card does **not** replace or cost the turn's
  move — a turn is one card (optional) plus one move (still mandatory,
  same as every milestone before this).
- **Starter set**: two cards — Promote (existing mechanic, now
  player-triggered instead of automatic) and Push Back (new).

## Approach

**`core/`**:

- `BoardState` gains `player_hand: Array[String]` (card type strings held)
  and `card_played_this_turn: bool`. Both are plain fields, deep-copied
  by `duplicate_state()` like everything else — undo/restart need to
  revert hand contents and per-turn play state exactly like they already
  revert piece positions.
- `Rules.apply_move()`: landing on a powerup tile appends its type to
  `player_hand` instead of applying an effect directly. The
  `if powerup_type == "promote": piece.kind = ...` branch is removed
  entirely — promotion only happens through `Rules.play_card()` now.
- New `Rules.play_card(state, card_type, target_piece_id = -1) -> bool`:
  fails if `card_played_this_turn` is already true, or the hand doesn't
  contain `card_type`. On success, removes one instance of `card_type`
  from the hand, sets `card_played_this_turn = true`, applies the effect,
  returns true.
  - `"promote"`: requires `target_piece_id` to resolve to a player piece;
    advances its kind via the existing `PieceKind.next_in_promotion_track`.
  - `"push_back"`: no target. For every enemy, push it one square directly
    away from whichever player piece is nearest (sign of the position
    delta — this can be a diagonal step, not just orthogonal). Skip an
    individual enemy if its pushed-back square is out of bounds, a wall,
    or occupied — a soft per-enemy failure, not an all-or-nothing effect
    for the whole card.
- `LevelLoader`: currently doesn't validate a powerup's `type` string
  against a known set at all (only `"promote"` ever did anything; any
  other string was silently accepted and silently inert). Now that a
  second real type exists, validate `type` is one of `"promote"` /
  `"push_back"`, failing loudly on anything else — matching how every
  other field is already validated.
- `card_played_this_turn` resets to `false` once the player's move ends
  the turn (i.e., right after `Rules.advance_enemies()` runs) — this is
  `GameController`'s job, not `Rules`', since it's turn bookkeeping around
  the rules rather than a rule itself.
- New `SoundHooks.on_card_played(card_type: String)` hook (unimplemented,
  per the established pattern), fired whenever a card is successfully
  played.

**`game/`**:

- `GameController.try_play_card(card_type, target_piece_id = -1) -> bool`:
  calls `Rules.play_card()`; on success, emits `state_updated` (so the
  board reflects the new piece kind or shifted enemies immediately) but
  does **not** call `_finish_turn()` — no outcome recheck, no enemy turn,
  no win/loss sound hooks. Those still happen when the turn's move is
  made via the existing `try_move()`. Fires `SoundHooks.on_card_played()`
  on success.
- `Hud`: shows the current hand (a button per held card type, with a
  count if more than one). Pressing a card button that needs a target
  (Promote) enters a "pick a target" mode; pressing one that doesn't
  (Push Back) plays immediately.
- `main.gd`: new `_pending_card_type: String` state. When set, the next
  cell click resolves the card's target instead of starting/continuing a
  move selection — reuses `_player_piece_at()` to identify the clicked
  piece the same way move-selection already does.
- At least one new level built around actually having a Promote and/or
  Push Back card matter — not just a repeat of the existing powerup-intro
  level with the mechanic renamed.

**Verification**:

- `tools/solve_level.gd` needs to model card plays as part of its search
  if any new level's solvability actually depends on playing one —
  extend it, or explicitly scope-limit it and say so, the same judgment
  call M5 made about enemy turns.
- New core tests: powerup pickup adds to hand instead of applying an
  effect, `play_card()` fails when the hand lacks the card, fails when a
  card was already played this turn, promote requires and applies to a
  valid target, push_back moves every enemy away from the nearest player
  piece, push_back skips an enemy whose destination is blocked.
- Full headless suite green.
- Manual playthrough of the real rendered game, specifically exercising
  both card types through the actual HUD/click interaction, not just the
  underlying `GameController` calls.

## Tasks

- [x] `BoardState`: `player_hand`, `card_played_this_turn`.
- [x] `Rules.apply_move()`: powerup pickup adds to hand, no longer
      applies an effect directly.
- [x] `Rules.play_card()`: promote and push_back.
- [x] `LevelLoader`: validate powerup `type` against the known set.
- [x] `GameController.try_play_card()`, per-turn reset after the enemy
      turn.
- [x] `SoundHooks.on_card_played()`.
- [x] `Hud`: hand display, card buttons.
- [x] `main.gd`: pending-card-target click handling.
- [x] New level demonstrating a card actually mattering.
- [x] `tools/solve_level.gd`: extend for card plays (not scope-limited —
      see Architecture).
- [x] New core tests per the list above.
- [x] Full headless suite green.
- [x] Manual playthrough — via a scripted `GameController` replay of the
      solver's exact winning line, not the real rendered HUD (see
      Deviations).

## Open questions

- Exact HUD layout for card buttons — resolve during implementation, not
  upfront; there's limited screen space already in use by
  Restart/Undo/Levels. Resolved: a column under the moves label, one
  button per unique card type in hand.
- Whether a level should ever grant more than one card at a time, or
  more than one of the same type — no reason it can't with this design,
  just not needed for the first demonstration level. Still true; not
  exercised in `07_the_shove.json`.

## Overview

Powerup tiles now grant a card to the player's hand instead of applying
an effect on pickup. Each turn is one optional card play plus one
mandatory move, both before the enemy responds. Two cards exist: Promote
(the old automatic-on-pickup mechanic, now player-triggered and
target-picked) and Push Back (new — shoves every enemy one square away
from whichever player piece is nearest it). A new level,
`07_the_shove.json`, is the first level whose solvability was proven to
*require* a card play, the same way `solve_level.gd` previously proved
`06_the_sacrifice.json` requires a sacrifice.

## Architecture

**Core (`core/`)**:

- `BoardState` gains `player_hand: Array[String]` and
  `card_played_this_turn: bool`, both deep-copied by `duplicate_state()`
  so undo/restart revert them exactly like every other field.
- `Rules.apply_move()`: the `if powerup_type == "promote": piece.kind =
  ...` branch is gone entirely. Landing on a powerup tile now only
  appends its type string to `player_hand` (team 0 only, same gating as
  `moves_used`) — `Rules.play_card()` is the only thing that ever changes
  a piece's kind or pushes enemies now.
- New `Rules.play_card(state, card_type, target_piece_id = -1) -> bool`:
  fails (no mutation) if a card was already played this turn or the hand
  doesn't contain `card_type`. `"promote"` requires `target_piece_id` to
  resolve to a player piece and advances it via the existing
  `PieceKind.next_in_promotion_track` (queen stays queen — still
  terminal, still consumes the card). `"push_back"` takes no target: for
  every enemy, `_nearest_player()` finds the closest player piece and the
  enemy is pushed one square along `sign()` of the position delta away
  from it (a diagonal step where the delta isn't axis-aligned); an
  individual enemy is skipped, not the whole card, if its destination is
  out of bounds, a wall, or occupied.
- `LevelLoader` now validates a powerup's `type` against
  `Rules.CARD_PROMOTE` / `Rules.CARD_PUSH_BACK` and fails loudly
  (`"powerups.type"`) on anything else — previously any string was
  silently accepted and silently inert unless it happened to be
  `"promote"`.

**Game (`game/`)**:

- `GameController.try_play_card()`: snapshots undo, calls
  `Rules.play_card()`, fires `SoundHooks.on_card_played()` (+
  `on_promotion()` for promote) and emits `state_updated` only — no
  `_finish_turn()`, no enemy turn, no outcome recheck. Those still happen
  exactly once, in `try_move()`, which now also resets
  `card_played_this_turn = false` right before ending the turn so next
  turn gets a fresh play.
- `Hud._rebuild_hand()`: rebuilt from scratch on every `state_updated`
  (hand size is at most a couple of entries, so this stays cheap) —
  groups `player_hand` by type, one button per type with an `x2`-style
  count suffix if held more than once, disabled once
  `card_played_this_turn` is true. Pressing Promote emits
  `card_target_requested` (it needs a piece to target); pressing Push
  Back plays immediately since it has none.
- `main.gd`: new `_pending_card_type` state, set by the Hud's
  `card_target_requested` signal. While set, the next cell click resolves
  the card's target via the existing `_player_piece_at()` (instead of
  starting/continuing a move selection) and clears the pending state
  whether or not the click landed on a valid target — clicking empty
  space cancels a pending targeted card rather than leaving it stuck.
- `07_the_shove.json`: single pawn, single confined-nowhere knight at
  `(3, 7)`, a `push_back` tile at `(1, 2)`, budget 11. Found by scanning
  knight start positions against `solve_level.gd` rather than hand-tuned
  geometry (see below) — the knight's greedy capture-or-approach heuristic
  makes hand-predicting its exact position turn-by-turn impractical, the
  same reason M5's sacrifice level was tuned by search rather than by
  eye.

**Verification tooling**: `tools/solve_level.gd` was extended to model
card plays as part of the search, not scope-limited — a level like
`07_the_shove.json` can't be verified at all otherwise. Each turn's
enumeration now branches over every `{state, card_step}` "turn start": the
state as-is (no card played) plus one branch per card type in hand played
against every legal target (every player piece id for Promote, a single
untargeted branch for Push Back), each going through the real
`Rules.play_card()`. The move enumeration that already existed runs
unchanged from whichever turn-start state is being considered. The
dedup key (`_state_key()`) grew to include the hand and
`card_played_this_turn`, since two states with identical piece layouts
but different hands are not the same state. A new `--forbid-cards` flag,
symmetric to `--forbid-promotion` / `--require-all-survive`, disables the
card-play branches entirely — this is what actually *proved*
`07_the_shove.json` requires the card: `--forbid-cards` finds no solution
at budget 11, and the unconstrained search finds an 11-step win that
plays Push Back on turn 1.

69/69 tests green (63 before this milestone; +6 net — two old
`apply_move`-auto-promotes tests rewritten into a pickup-adds-to-hand
test plus a separate `play_card` promote test, and five new tests for
`play_card`'s failure modes and Push Back's movement/blocking).

## Deviations

**No screenshot/click-driven verification of the real HUD.** Every other
milestone's manual-playthrough step drove the actual rendered scene
through `InputController` clicks or a live `BoardView`. This one instead
replayed the solver's exact winning move-and-card sequence directly
through `GameController` calls (confirming `try_play_card()` /
`try_move()` interact correctly and the sequence reaches `Outcome.WIN`),
plus a second scripted check of `play_card()`'s failure modes
(no-card-in-hand, already-played-this-turn) through the same controller
API. The `Hud` card buttons and `main.gd`'s pending-card-target click
routing were reviewed by reading the code, not exercised by an actual
click in a running window. Worth an actual playthrough — pressing the
Promote button, clicking a target piece, pressing Push Back — before
considering the HUD side content-complete, the same caveat M5's writeup
made about multi-piece rendering and then M6... didn't close. Low risk:
the click-routing code is a small, direct extension of the
already-verified move-selection path (same `_player_piece_at()` helper,
same signal-driven rebuild pattern the Hud already used for
moves/status), but it's a real gap, not a verified one.

**No visual "picking a target" affordance.** While `_pending_card_type`
is set, nothing highlights which pieces are valid targets or otherwise
indicates the mode is active beyond the absence of the normal move
highlight — a player mid-game has no on-screen cue they're in
target-picking mode versus move-picking mode. Left as-is for this
milestone since there's only one targeted card; worth revisiting if a
second targeted card is ever added.
