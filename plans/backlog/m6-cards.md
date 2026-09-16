---
title: M6 — Cards
status: Backlog
created: 2026-09-16
updated: 2026-09-16
---

# M6 — Cards

## Goal

Layer a card-based powerup system on top of the core movement game —
collectible/playable cards that grant one-off tactical effects (e.g.
"push all enemies back a square"), distinct from the existing promotion
powerup tiles.

## Context

Raised as a "longer term" idea alongside M5's design conversation, at the
"here's the shape of it" stage, not scoped in detail yet — deliberately
kept in `backlog/`, not `ready/`, since there isn't yet a concrete enough
spec for someone to pick up and build directly (per `plans/README.md`:
"backlog entries are ideas, not specs").

Likely depends on M5 landing first: several plausible card effects (push
enemies back, swap with an enemy) are far more meaningful once enemies
actually move and pursue the player each turn, rather than sitting still.
Multiple player pieces (also M5) probably interact with card targeting
too — does a card affect one piece, all of them, or let you choose?

## Rough shape (not a spec yet)

- **A card grants a special, situational effect** beyond what a piece's
  normal move already does — the one example so far is "push all enemies
  back a square." Needs a small starter library of effects, not just one.
- **Existing powerup tiles already grant promotion** (M3). Cards are a
  separate system, not a replacement — though how a player *acquires*
  cards (new tile type? drawn at level start? something else?) isn't
  decided.
- Playing a card presumably competes with the existing turn structure
  M5 introduces (one player move, then the enemy turn) — does playing a
  card cost your move for the turn, or is it a separate free action? This
  is probably the single biggest open question, since it changes the
  game's pacing more than any individual card effect would.

## Open questions (deliberately unresolved — this is why it's backlog, not ready)

- How are cards acquired — per-level, persistent across the level list,
  drawn randomly, chosen?
- Hand size / how many cards can be held or carried between levels?
- Does playing a card cost a turn?
- What's the actual starter set of card effects, beyond the one example?
- Where does this live architecturally — a new `core/card.gd` /
  `core/card_effect.gd` alongside the existing pure-rules classes (kept
  to the same "zero Godot dependencies" constraint as the rest of
  `core/`), with `game/` handling the hand UI and play interaction?

## Next step

Once M5 has landed and the turn structure it introduces is real (not
just planned), revisit this with a proper `Approach`/`Tasks` section and
promote it to `ready/` — trying to fully spec the card system now, before
knowing how M5's turn order actually feels to play, risks designing
around assumptions that don't hold up.
