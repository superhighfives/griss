# Handover

Picking this up cold? Start with [`README.md`](README.md), then
[`docs/PLAN.md`](docs/PLAN.md) for the original design brief.

## Where things stand

This project uses the [`plans`](plans/README.md) skill for status and
roadmap tracking — that's the source of truth now, not this file:

- [`plans/done/`](plans/done/) — completed work, including the full story
  of M0/M1 and the iOS TestFlight pipeline
  ([`m0-m1-and-testflight-pipeline.md`](plans/done/m0-m1-and-testflight-pipeline.md)).
- [`plans/ready/`](plans/ready/) — specced and pickable. M2 — Pressure is
  here ([`m2-pressure.md`](plans/ready/m2-pressure.md)) and is the
  immediate next thing to do.
- [`plans/in-progress/`](plans/in-progress/) / [`plans/backlog/`](plans/backlog/)
  — check these too; empty at time of writing.

Run the test suite from repo root — should print `Passed: 44, Failed: 0` —
after every change, and again before ending any milestone:

```
godot --headless --path . --script res://tests/run_tests.gd
```

**For UI/input/rendering changes, test locally first** (`godot --path .`)
rather than round-tripping through a TestFlight build — a local check takes
seconds, a real device build takes minutes.

## Environment notes for whoever runs this next

- `godot` is installed via Homebrew (`brew install --cask godot`, v4.7.2),
  matching what CI uses.
- **No `timeout` command on this macOS box.** Use `run_in_background` +
  kill, or install `coreutils` for `gtimeout`, when you need a bounded
  Godot run.
- **Synthetic mouse clicks (`cliclick`) do work here**, but this
  environment is prone to window-focus and macOS-Space flakiness — a
  click can silently land on a different window than intended if focus
  wasn't freshly confirmed. Before trusting a click's result: confirm
  exactly one `godot --path .` process is running
  (`ps aux | grep godot`), explicitly `osascript -e 'tell application
  "Godot" to activate'`, and prefer verifying behavior via a temporary
  debug `print()` in the relevant `_input`/`_unhandled_input` handler over
  trusting a screenshot — screenshot-based verification proved unreliable
  multiple times in this environment (window position queries returning
  stale/incorrect values), while log output did not. For pure game-logic
  verification (no rendering/input involved), driving `GameController`
  headlessly is still simplest: load a level, fetch the player piece, call
  `get_legal_moves`/`try_move` in a loop, assert on `controller.outcome`.
- `gh` is authenticated as `superhighfives` with `repo`/`workflow` scopes.

## Repo / CI conventions

- **This is an early-stage prototype — pushes go straight to `main`, no PR
  required.** Branch protection technically still requires a PR
  (`enforce_admins: false`, so the repo owner can bypass it), but the
  working convention here is direct pushes with a clear commit message.
- `superhighfives/control-room` reviews any PR that does get opened
  (`.github/workflows/claude-code-review.yml`) but isn't a required gate
  given the above.
