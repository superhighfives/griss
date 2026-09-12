# Handover

Picking this up cold? Read this, then [`docs/PLAN.md`](docs/PLAN.md) (the
original brief — architecture constraints, file layout, milestones M0–M4).
Everything below assumes you've read the plan.

## Where things stand

- **M0 and M1 are done** on the `m0-m1-scaffold` branch, currently open as
  [PR #1](https://github.com/superhighfives/griss/pull/1) against `main`.
  `main` itself is intentionally just a single empty root commit right now —
  see "Why main is empty" below before you touch branch history.
- Core rules engine (`core/`), a runtime-built game layer (`game/`), the
  headless test suite (`tests/`, 37 passing), and `levels/01_first_steps.json`
  all exist only on `m0-m1-scaffold` until that PR merges.
- `godot` is installed via Homebrew (`brew install --cask godot`, v4.7.2) on
  this machine. It was not present before this project started.

Run the test suite from repo root:

```
godot --headless --path . --script res://tests/run_tests.gd
```

Should print `Passed: 37, Failed: 0`. Run this after every change, and again
before ending any milestone.

## Immediate next step: land PR #1

1. Review it, then merge it (branch protection on `main` requires 1 approval
   — see "Repo/CI setup" below).
2. After merging, delete the `m0-m1-scaffold` branch.
3. Pull `main` locally and confirm `godot --headless --path . --script
   res://tests/run_tests.gd` still passes at the merge commit.

**Known wrinkle:** the control-room review workflow (see below) has a safety
guard that skips review entirely — posting "this PR has not been reviewed"
instead of a real verdict — on any PR that touches a path under
`.github/workflows/`, unless that file is byte-identical to `main`'s copy.
PR #1 currently trips this because an earlier commit on the branch deleted
`.github/workflows/claude-code-review.yml` (it had been added to the branch,
then also pushed directly to `main` separately, then removed from the branch
to avoid duplicating it — net result: the branch's diff still touches that
path even though the deletion nets out to "no change"). The PR's last *real*
review (before the deletion commit) was 🟡 *Approved with comments*, nothing
blocking. If you want a fresh, non-skipped review before merging, you likely
need a commit on the branch that touches no path under `.github/workflows/`
relative to `main` — check `git diff origin/main...m0-m1-scaffold --
.github/workflows/` is empty before pushing.

## Then: M2 — Pressure

Per `docs/PLAN.md` section 8. Scope:

- Static enemies (already representable in `core/` — `BoardState`/`Level`
  support `team: 1` pieces and `LevelLoader` already parses an `enemies`
  array; `MoveGen.threatened_squares()` and `Rules.check_outcome()`'s
  `LOSS_THREATENED` branch already exist and are unit-tested).
- **What's missing is the game layer:** `BoardView` needs a threat-square
  overlay (render `MoveGen.threatened_squares(state, 1)` similarly to the
  existing move-highlight rendering, but a distinct color), capture needs no
  new core work (already handled by `Rules.apply_move`), the move-budget
  needs to actually show in `Hud` as the level runs low (it already shows
  `moves_used`/`move_budget`, so this may just need a "levels can be lost"
  content pass), and undo/restart already exist in `GameController` — verify
  they're reachable and correct once enemies exist.
- Add at least one new level JSON under `levels/` with enemies, so "a level
  can be lost three distinct ways" (threatened, out of moves, or — check
  whether "stuck with no legal moves" counts as a distinct third way, or
  whether that needs a dedicated level shape) is actually demonstrable.
- Extend `tests/test_rules.gd` / `tests/test_move_gen.gd` if any new edge
  cases show up (there's already fairly thorough coverage of threat squares
  per piece kind — check before duplicating).

## Repo / CI setup (already done, for context)

- Public repo: <https://github.com/superhighfives/griss>.
- `superhighfives/control-room` review workflow installed at
  `.github/workflows/claude-code-review.yml` on `main`, with `runtime: none`
  (no node/bun toolchain — this is a GDScript project). Secret
  `CLAUDE_CODE_OAUTH_TOKEN` is configured on the repo and confirmed working
  (a real review has posted successfully on PR #1).
- Branch protection on `main`: requires a PR, 1 approval, dismisses stale
  approvals on new pushes, force-pushes disabled. `enforce_admins` is
  `false`, so the repo owner can still bypass and push directly when needed
  (used once, deliberately, for the workflow file — see below).

### Why `main` is empty

Early in this project all M0/M1 work was pushed **directly** to `main` (no
PR), before branch protection existed. When asked to retroactively put that
work through a PR, the only clean way to do it without an unrelated-history
PR error was: create `m0-m1-scaffold` from that state, then reset `main` to
a fresh empty root commit (temporarily re-enabling force-push, pushing the
empty commit, then re-disabling force-push), then merge `main`'s empty
commit into `m0-m1-scaffold` (`git merge --allow-unrelated-histories`) so
the branch and `main` share history and a normal PR is possible. That's
`PR #1`. **Don't repeat this pattern** — it's a one-time fix for a
one-time mistake. From here on, all work should go: branch → PR → merge.

The workflow file itself (`.github/workflows/claude-code-review.yml`) was
pushed directly to `main` once, deliberately, bypassing the PR-only rule as
the repo admin — GitHub Actions needs a `pull_request`-triggered workflow to
exist on the base branch before it'll run for incoming PRs, so it had to
land on `main` before PR #1 could pick up a working check.

## Environment notes for whoever runs this next

- **No `timeout` command on this macOS box.** Use `run_in_background` +
  kill, or install `coreutils` for `gtimeout`, when you need a bounded
  Godot run.
- **OS-level synthetic mouse clicks are unreliable here.** `cliclick`-driven
  clicks into the running Godot window did not register even with verified
  correct coordinates (confirmed via cursor screenshots landing exactly on
  the target). Don't burn time debugging this again — instead, verify
  interaction logic by driving `GameController` headlessly the same way
  `main.gd`'s click handler does (see the git history around the M1
  verification commit for the pattern: load a level, fetch the player
  piece, call `get_legal_moves`/`try_move` in a loop, assert on
  `controller.outcome`). This exercises the exact same code path as real
  clicks without needing OS input simulation. If you do need a visual
  check, `godot --path .` + `screencapture` works fine for confirming
  rendering; just don't rely on synthetic clicks changing what's on screen.
- `gh` is authenticated as `superhighfives` with `repo`/`workflow` scopes.
