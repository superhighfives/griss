---
title: Hitting a wall isn't a loss while a card can change your form
status: Complete
created: 2026-09-17
updated: 2026-09-17
---

# Hitting a wall isn't a loss while a card can change your form

## Goal

A piece with nothing to click shouldn't end the game while the player is
holding a card that would give it somewhere to go. Being blocked with a
Promote card in hand is the moment the card exists for — change form,
move on — not a defeat.

## Context

Reported against `04_point_of_no_return.json`, with a screenshot: the
pawn had picked up the Promote card, stepped forward to `(1, 2)`, and sat
directly under the wall at `(1, 3)` — `LOSS - out of moves` at 2 moves of
a 10-move budget, Promote button still sitting in the HUD, unusable.

The level was built for M3, when a powerup tile promoted on pickup: the
pawn became a knight the moment it stepped on `(1, 1)` and the wall was
never a problem. M6 turned that tile into a *card* the player chooses
when to play, which introduced exactly one new position the old rules
had no answer for — blocked, but holding the thing that unblocks you —
and `Rules.check_outcome()` read it as a dead end. Worse, the loss was
self-sealing: `GameController.try_play_card()` refuses to play anything
once `outcome != ONGOING`, so the card that would have fixed it was dead
the instant it was needed. Reproduced headlessly before changing
anything:

```
after pickup: hand=["promote"] outcome=0
after step into the wall: pos=(1, 2) outcome=3   # LOSS_NO_MOVES
legal moves now: []
can play promote: false
```

Note what this is *not*: the fix in
[`stalemate-is-not-instant-loss.md`](stalemate-is-not-instant-loss.md),
which was about a *blocking enemy* being given its own next turn. A wall
never moves. What resolves this block isn't another turn for anyone —
it's the player's own hand.

## Overview

"The player has no legal moves" stops being the loss condition on its
own. The condition is now "the player has no action left at all": no
piece with a legal move, *and* no card in hand that would give one back.
`Rules.player_has_action()` answers that, and `check_outcome()` asks it
instead of scanning for legal moves directly.

Whether a card would help is answered by playing it — each `(card,
target)` pair in hand, on a throwaway `duplicate_state()`, asking whether
any player piece can move afterwards — rather than by reasoning about
what each card does. Promote frees a pawn walled in ahead by turning it
into a knight; Push Back frees one blocked by an enemy by shoving the
enemy off; a card added later gets counted for free, and the answer can't
drift from what `play_card()` really does.

## Architecture

- **`Rules.player_has_action(state)`** — `_any_player_piece_can_move()`
  or `_any_card_unblocks_player()`. Public because two callers need it:
  `check_outcome()` and the stalemate loop.
- **`Rules._any_card_unblocks_player(state)`** — the simulation above.
  Returns false immediately when the hand is empty (the common case, so
  `check_outcome()` stays cheap for the solver's BFS) or when
  `card_played_this_turn` is already set: the turn's one card play is
  spent, only a move ends the turn and refreshes it, so a player who is
  still stuck at that point has genuinely run out. Spending the card on
  something useless is a real loss, immediately.
- **`Rules.card_target_ids(state, card_type)`** — every player piece for
  a targeted card, `[-1]` for an untargeted one. Extracted from
  `tools/solve_level.gd`'s private `_card_targets()`, which enumerated
  the identical branches; the solver now calls the shared one.
- **`Rules.advance_enemies_and_resolve_stalemate()`** loops on
  `player_has_action()` rather than `_any_player_piece_can_move()`. Those
  extra enemy turns are granted on the premise that the player can only
  pass — a player holding a card that frees them isn't passing, and
  handing the enemy team free turns to reposition while they still have
  something to play is the same unfairness from the other direction.
- **`GameController.try_move()`** clears `card_played_this_turn` before
  the enemy response instead of after it. The move already ended the
  turn; leaving the flag set through the outcome check and the stalemate
  loop had both of them judge the player against a turn that was over,
  and `player_has_action()` reads that flag. `tools/solve_level.gd`'s BFS
  transition moved in the same way, to keep mirroring `try_move()`.
- **`GameController.try_play_card()`** finishes through `_finish_turn()`
  instead of emitting `state_updated` alone. A card play can now change
  the outcome on its own — it's the thing that spends the reprieve — and
  without recomputing, a player who played a card that didn't help sat in
  a dead position with no loss ever reported.

**HUD**: a blocked-but-playable position has no highlighted square to
click, which is precisely what a loss looks like. The status line now
reads `Blocked - play a card` in that position, from
`Rules.player_must_play_card()` (no legal move, and a card would give
one). It hangs off `outcome_updated` as the other statuses always have -
every state change that reaches the HUD, a card play now included, goes
through `_finish_turn()`. The status label also moved from `(150, 8)` to
`(150, 32)`: it now says something during ordinary play, not just at the
end of one, and on the top row a level name of any length ran straight
into it — visible in the original bug report's screenshot as
`Point of No ReturnLOSS - out of moves`.

**Tests**: 80 passing, up from 72. Six in `test_rules.gd` cover the rule
itself — blocked with a freeing card is ONGOING; blocked with a card that
changes nothing (Push Back, no enemies) is still `LOSS_NO_MOVES`; so is
blocked with this turn's card play already spent; the stalemate loop
stops while a card can free the player (a distant rook gets its one
ordinary turn, not a free walk into capturing range) and still runs when
no card can; and `player_must_play_card()` fires only when a card is the
only way to move. Two in `test_game_controller.gd` play the reported bug
end to end on a copy of the level — step into the wall, and the game is
ongoing with the Promote card still playable — and then the other half of
it: spend the card on Push Back with nothing to push and the loss lands
immediately.

All eight levels re-verified with `tools/solve_level.gd`; both
solver-proved properties still hold (`06_the_sacrifice.json` requires a
sacrifice, `07_the_shove.json` requires playing Push Back).

## Deviations

Two things grew out of the fix rather than being in the original report,
both because the fix itself created them: `try_play_card()` recomputing
the outcome (a card play could now *cause* a loss, and nothing was
recomputing), and the HUD prompt (the new non-losing position is
indistinguishable from a lost one on a board with no highlights).
