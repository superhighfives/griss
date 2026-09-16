# Griss

[![TestFlight](https://github.com/superhighfives/griss/actions/workflows/testflight.yml/badge.svg)](https://github.com/superhighfives/griss/actions/workflows/testflight.yml)

A turn-based puzzle game built in Godot: chess pieces traverse a narrow
vertical lane to reach the far end, upgrading their movement along the way.
Every push to `main` automatically builds, signs, and uploads a new iOS build
to TestFlight.

## Requirements

- **Godot 4.7.2** (`brew install --cask godot` on macOS). The CI pipeline
  pins this exact version — keep your local install in sync with
  `GODOT_VERSION` in [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml).
- To build/sign the iOS app locally: Xcode, and a Ruby ≥ 3.0 for Fastlane
  (`bundle install` picks up the pinned version from `Gemfile.lock`).

## Running the game

Open the project in the Godot editor (`godot --path .`), or run it directly:

```sh
godot --path .
```

There's no menu system yet — it loads straight into
`levels/01_first_steps.json`. Click the player piece to select it, click a
highlighted cell to move.

## Running the tests

```sh
godot --headless --path . --script res://tests/run_tests.gd
```

Headless, no editor, no addons — `tests/run_tests.gd` is a `SceneTree`
script that runs every `test_*()` function it finds and exits non-zero on
failure. Should print `Passed: 46, Failed: 0`. Run this after any change to
`core/` or `game/`.

**Faster iteration for UI/input changes:** run the game locally
(`godot --path .`) and interact with it directly rather than round-tripping
through a TestFlight build — a local check takes seconds, a real device
build takes several minutes. Two real bugs (pawn selection not registering,
background not filling the screen on non-4:5 devices) were both found and
fixed this way, verified with real evidence (debug prints on the input
pipeline, before/after screenshots at a simulated device resolution) rather
than guessed at.

## Architecture

The codebase is split into two layers with a hard boundary between them:

- **`core/`** — the rules engine. Pure GDScript (`RefCounted`/plain
  classes only): no `Node`, no `Input`, no scene tree, no signals. Given a
  board state and a move, it deterministically returns a result. This is
  what's unit-tested.
- **`game/`** — everything else: rendering, input, HUD. Reads state from
  `core/` and draws it; never implements a rule itself.

```
res://
  core/
    board_state.gd      # grid dims, cells, pieces, turn count
    piece.gd             # id, kind, team, position
    piece_kind.gd         # enum + movement vector tables
    move_gen.gd           # legal_moves(state, piece_id)
    rules.gd              # apply_move(), check_outcome()
    level.gd              # parsed level definition
    level_loader.gd        # JSON -> Level -> BoardState
  game/
    Main.tscn            # the only hand-authored scene
    main.gd               # entry point, owns GameController
    game_controller.gd    # holds BoardState, undo stack, input -> core calls
    board_view.gd         # builds/updates cell + piece visuals from state
    input_controller.gd   # click routing -> Vector2i cell
    hud.gd                 # moves remaining, restart/undo
  levels/
    01_first_steps.json
  tests/
    run_tests.gd          # headless runner
    test_*.gd
```

The entire board — cells, pieces, highlights — is built at runtime from
script (`board_view.gd`), never wired up in the Godot editor. `Main.tscn`
is the one exception: a `Node2D` root plus an empty `BoardRoot` and a
`CanvasLayer` named `UI`. This is deliberate (see
[`docs/PLAN.md`](docs/PLAN.md)) — it keeps the scene tree reviewable as
plain text.

### Levels

Levels are hand-written JSON (`levels/*.json`), validated and loaded by
`LevelLoader`:

```json
{
  "name": "First Steps",
  "width": 4,
  "height": 12,
  "move_budget": 20,
  "player": { "kind": "PAWN", "pos": [1, 0] },
  "walls": [[0, 4], [3, 4]],
  "powerups": [{ "pos": [2, 3], "type": "promote" }],
  "enemies": [{ "kind": "ROOK", "pos": [3, 9] }]
}
```

`(0, 0)` is the bottom-left; the goal is the top row. `LevelLoader` rejects
out-of-bounds coordinates, overlapping entities, and unknown `kind` strings
with the offending field name.

## Development notes

- **No `timeout` command on macOS.** Use a backgrounded process + `kill`,
  or install `coreutils` for `gtimeout`, when you need a bounded Godot run.
- **Synthetic mouse clicks (`cliclick`) work fine**, but some environments
  are prone to window-focus/Space flakiness — a click can silently land on
  the wrong window if focus wasn't freshly confirmed. Verify with a
  temporary debug `print()` in the relevant `_input`/`_unhandled_input`
  handler rather than trusting a screenshot if clicks seem to do nothing.
  For pure game-logic checks with no rendering involved, drive
  `GameController` headlessly instead: load a level, fetch the player
  piece, call `get_legal_moves`/`try_move` in a loop, assert on
  `controller.outcome`.
- **This is an early-stage prototype, not a team project with a review
  process to protect** — pushes go straight to `main`, no PR required.
  [`superhighfives/control-room`](https://github.com/superhighfives/control-room)
  is still installed and reviews any PR that does get opened
  (`.github/workflows/claude-code-review.yml`), but it isn't a gate.

## iOS build & TestFlight

Every push to `main` (docs-only changes excluded) runs
[`.github/workflows/testflight.yml`](.github/workflows/testflight.yml):
Godot exports an Xcode project, Fastlane (`fastlane/Fastfile`) signs it
with a `match`-managed App Store distribution certificate and uploads it to
TestFlight. A new build typically appears in App Store Connect within
3–4 minutes of the push.

This already works end-to-end for `superhighfives/griss` — the one-time
Apple Developer / App Store Connect setup (Team ID, app record, API key,
certificate storage) is done. If you're standing this up for a fork or a
new app, follow [`docs/TESTFLIGHT_SETUP.md`](docs/TESTFLIGHT_SETUP.md) from
scratch.

To trigger a build manually without a code change, use the workflow's
`workflow_dispatch` trigger (Actions tab → TestFlight → Run workflow), or:

```sh
gh workflow run testflight.yml
```

## Further reading

- [`docs/PLAN.md`](docs/PLAN.md) — the original design brief: architecture
  constraints, full game rules, level format, and the milestone roadmap
  (M0–M4).
- [`plans/`](plans/README.md) — where the project currently stands and
  what's next: one milestone/feature spec per file, moving through a
  backlog → ready → in-progress → done lifecycle.
- [`docs/TESTFLIGHT_SETUP.md`](docs/TESTFLIGHT_SETUP.md) — the one-time
  manual runbook for standing up the TestFlight pipeline from scratch.
