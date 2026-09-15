# Handover

Picking this up cold? Read this, then [`docs/PLAN.md`](docs/PLAN.md) (the
original brief — architecture constraints, file layout, milestones M0–M4).
Everything below assumes you've read the plan.

## Where things stand

- **M0 and M1 are done and merged to `main`** (was PR #1). Core rules engine
  (`core/`), a runtime-built game layer (`game/`), the headless test suite
  (`tests/`, 40 passing), and `levels/01_first_steps.json` all live on `main`.
- **An iOS TestFlight CI pipeline has been added** since M0/M1 landed — see
  "iOS TestFlight pipeline" below before touching anything under
  `fastlane/`, `.github/workflows/testflight.yml`, or `export_presets.cfg`.
  It is not yet reliably green; see "Immediate next step".
- `godot` is installed via Homebrew (`brew install --cask godot`, v4.7.2) on
  this machine, matching what CI uses.

Run the test suite from repo root:

```
godot --headless --path . --script res://tests/run_tests.gd
```

Should print `Passed: 40, Failed: 0`. Run this after every change, and again
before ending any milestone.

## Immediate next step: get TestFlight CI reliably green

The pipeline's Godot export, code signing, and Xcode archive/link steps have
all been individually verified working (both locally and in real CI runs),
but the `macos-latest` GitHub-hosted runner is resource-constrained — only
**3 CPUs / 7.5GB RAM** (confirmed via `sysctl` in a CI run) — and linking
Godot's large statically-linked engine binary at full parallelism has caused
several runs to stall for 20-45 minutes at inconsistent steps (dSYM
generation, right after linking, App Intents metadata extraction — all
fast on a normal machine), which reads exactly like memory-pressure swap
thrashing, not a deterministic bug.

The latest fix (`-jobs 2` in `fastlane/Fastfile`'s `build_app` call, capping
`xcodebuild` parallelism) is in PR #10, not yet confirmed to fully resolve
it — check whether that run (or the next one) actually completes rather than
timing out. If it still hangs, the next things to try, in order: drop to
`-jobs 1`, or accept that the free-tier runner is simply too small and move
to a larger paid runner tier (`macos-latest-xlarge` or similar).

**Known wrinkle, general and ongoing (not specific to any one PR):** the
control-room review workflow has a safety guard that skips review entirely —
posting "this PR has not been reviewed" instead of a real verdict — on any
PR that touches a path under `.github/workflows/`. Several PRs this session
(adding `workflow_dispatch`, switching to `macos-latest`, the disk/memory
diagnostics) could never get a real review for exactly this reason and were
merged with `gh pr merge --admin` (repo owner bypassing the "1 approval"
branch rule deliberately). PRs that *don't* touch `.github/workflows/` (e.g.
`fastlane/Fastfile` changes) get a real review and, since the control-room
GitHub App now has `Contents: Read-and-write`, a genuine 🟢 approval from it
can satisfy the branch rule on its own — see "iOS TestFlight pipeline" and
`superhighfives/control-room`'s README ("Making blocking actually block")
for why that permission is needed.

## iOS TestFlight pipeline

Every push to `main` (excluding docs-only changes) exports the game with
Godot, builds and signs it via Xcode, and uploads to TestFlight via
Fastlane — see `.github/workflows/testflight.yml`. Manual re-run available
via `workflow_dispatch`.

- **One-time setup runbook**: [`docs/TESTFLIGHT_SETUP.md`](docs/TESTFLIGHT_SETUP.md)
  — Apple Developer Team ID, App Store Connect app record + API key, the
  Fastlane `match` certificates repo (`superhighfives/griss-certificates`,
  private), and the 7 GitHub secrets the workflow needs. All of this is
  already done for this project; the doc exists for reference/rotation, not
  as a blocker.
- **Signing**: `fastlane match` manages the distribution certificate and
  provisioning profile, encrypted in `griss-certificates` under
  `MATCH_PASSWORD`. The certificate's `.p12` **must have an empty internal
  password** — `fastlane`'s keychain importer hardcodes that assumption with
  no override, so a `.p12` exported from Keychain Access with a real
  password (the natural thing to do) will import fine on a machine that
  already trusts the identity but fail with "MAC verification failed" on a
  fresh CI keychain. If you ever need to re-bootstrap the certs repo,
  re-encode the `.p12` via a `security export … -P ""` round-trip (not
  OpenSSL — OpenSSL 3.x's empty-password PKCS12 encoding isn't compatible
  with macOS's importer, confirmed empirically) before importing it.
- **Godot version gotchas**: several `export_presets.cfg` option keys from
  older Godot docs/tutorials have been renamed as of 4.7 —
  `application/identifier` → `application/bundle_identifier`,
  `"iPhone Distribution"`/`"iPhone Developer"` code-sign identity strings →
  `"Apple Distribution"`/`"Apple Development"`, `.ipa` is no longer a valid
  `export_path` extension (use `.zip` or `.xcodeproj`). Worth knowing if any
  of this needs touching again after a future Godot upgrade.
- **A missing app icon silently blocks export with no error message** — a
  genuine Godot bug (`should_import_etc2_astc()` fails validation without
  ever appending an error string, so you just see an empty "configuration
  errors:" block). Fixed by adding `icon.png` (currently a placeholder) and
  `rendering/textures/vram_compression/import_etc2_astc=true` in
  `project.godot`. Replace `icon.png` with real branding before an actual
  App Store submission — it's a placeholder, fine for internal TestFlight
  testing only.
- **Fastlane secrets are explicit, never `secrets: inherit`** in
  `.github/workflows/claude-code-review.yml` — this repo also holds Apple
  signing secrets (`MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`,
  `APP_STORE_CONNECT_API_KEY_CONTENT`) that the review job has no reason to
  ever see. See `superhighfives/control-room`'s README for the full
  reasoning (the review job runs an AI agent with broad Bash access over PR
  content — exactly what prompt injection targets).

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
  `.github/workflows/claude-code-review.yml` on `main`, pinned to a specific
  commit SHA (not `@main` — it now carries the more sensitive
  `APP_PRIVATE_KEY` secret below, worth reviewing deliberately rather than
  trusting whatever `control-room`'s `main` currently contains), with
  `runtime: none` (no node/bun toolchain — this is a GDScript project).
  Two secrets: `CLAUDE_CODE_OAUTH_TOKEN` (confirmed working — real reviews
  have posted) and `APP_PRIVATE_KEY` (the `control-room-review` GitHub
  App's key, needed for the review's 🟢 verdict to actually land as an
  `APPROVE` state instead of silently downgrading to a comment — see
  `superhighfives/control-room`'s README for why).
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
