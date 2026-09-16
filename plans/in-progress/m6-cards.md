---
title: M6 — Cards
status: In Progress
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

- [ ] `BoardState`: `player_hand`, `card_played_this_turn`.
- [ ] `Rules.apply_move()`: powerup pickup adds to hand, no longer
      applies an effect directly.
- [ ] `Rules.play_card()`: promote and push_back.
- [ ] `LevelLoader`: validate powerup `type` against the known set.
- [ ] `GameController.try_play_card()`, per-turn reset after the enemy
      turn.
- [ ] `SoundHooks.on_card_played()`.
- [ ] `Hud`: hand display, card buttons.
- [ ] `main.gd`: pending-card-target click handling.
- [ ] New level demonstrating a card actually mattering.
- [ ] `tools/solve_level.gd`: extend for card plays, or scope-limit and
      say so.
- [ ] New core tests per the list above.
- [ ] Full headless suite green.
- [ ] Manual playthrough exercising both cards through the real HUD.

## Open questions

- Exact HUD layout for card buttons — resolve during implementation, not
  upfront; there's limited screen space already in use by
  Restart/Undo/Levels.
- Whether a level should ever grant more than one card at a time, or
  more than one of the same type — no reason it can't with this design,
  just not needed for the first demonstration level.
