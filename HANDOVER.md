# Handover

Picking this up cold? Read this, then [`docs/PLAN.md`](docs/PLAN.md) (the
original brief — architecture constraints, file layout, milestones M0–M4).
Everything below assumes you've read the plan.

## Where things stand

- **M0 and M1 are done and merged to `main`.** Core rules engine (`core/`),
  a runtime-built game layer (`game/`), the headless test suite (`tests/`,
  44 passing), and `levels/01_first_steps.json` all live on `main`.
- **The iOS TestFlight CI pipeline is done and reliably green.** Every push
  to `main` builds, signs, and uploads a new build in 2–4 minutes — see
  "iOS TestFlight pipeline" below.
- **This project uses the [`plans`](plans/README.md) skill.** The next
  milestone (M2 — Pressure) is specced at
  [`plans/ready/m2-pressure.md`](plans/ready/m2-pressure.md) — start there
  rather than re-planning from `docs/PLAN.md` §8.
- `godot` is installed via Homebrew (`brew install --cask godot`, v4.7.2) on
  this machine, matching what CI uses.

Run the test suite from repo root:

```
godot --headless --path . --script res://tests/run_tests.gd
```

Should print `Passed: 44, Failed: 0`. Run this after every change, and again
before ending any milestone.

**For UI/input/rendering changes, test locally first** (`godot --path .`)
rather than round-tripping through a TestFlight build — a local check takes
seconds, a real device build takes minutes. Two real bugs (pawn selection
silently swallowed by a Control's default input filter, background not
filling the screen on non-4:5 devices) were both found and fixed this way.

## Next: M2 — Pressure

Fully specced at [`plans/ready/m2-pressure.md`](plans/ready/m2-pressure.md).
Move it to `plans/in-progress/` before starting, per the
[`plans`](plans/README.md) workflow.

## iOS TestFlight pipeline

Every push to `main` (excluding docs-only changes) exports the game with
Godot, builds and signs it via Xcode, and uploads to TestFlight via
Fastlane — see `.github/workflows/testflight.yml`. Manual re-run available
via `workflow_dispatch`.

- **One-time setup runbook**: [`docs/TESTFLIGHT_SETUP.md`](docs/TESTFLIGHT_SETUP.md)
  — Apple Developer Team ID, App Store Connect app record + API key, the
  Fastlane `match` certificates repo (`superhighfives/griss-certificates`,
  private), and the GitHub secrets the workflow needs. Already done for
  this project; the doc exists for reference/rotation, not as a blocker.
- **The archive hang that took a while to run down**: early runs
  consistently stalled for the full 20-minute job timeout somewhere inside
  the Xcode archive step, at an inconsistent point each time (dSYM
  generation, right after linking, App Intents metadata extraction). Ruled
  out, in order, with real evidence rather than guesses: memory exhaustion
  (`vm.swapusage` stayed at 0 throughout), Spotlight indexing contention
  (disabling it made no difference), and CPU starvation on the runner's 3
  vCPUs (process-state sampling showed the stuck process at 0% CPU, not
  busy). The actual cause, found by disabling `xcpretty` formatting to get
  xcodebuild's full raw output: `codesign` itself, invoked from inside
  Xcode's `swift-stdlib-tool` step while signing the Swift runtime dylibs,
  hanging forever waiting for a keychain ACL prompt that a headless CI
  session can never answer. `fastlane match`'s certificate import grants
  the `apple-tool:`/`apple:` keychain partition IDs but not `codesign:` — a
  known gap. Fixed by calling `setup_ci` (fastlane's dedicated fix — a
  properly-provisioned, unlocked CI keychain) at the top of the `beta` lane
  in `fastlane/Fastfile`. If a build ever hangs again, `xcodebuild_formatter: ""`
  in `build_app` is the fastest way to see what's actually stuck, rather
  than guessing from `xcpretty`'s step-banner-only console output.
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
- **The app's display name comes from `config/name` in `project.godot`**,
  not from `export_presets.cfg`'s `application/product_name` (which
  appears unused by the current Godot export plugin — the generated
  Xcode project's actual `PRODUCT_NAME` comes from the export path's
  filename instead). Confirmed by re-exporting locally and inspecting the
  generated `project.pbxproj`'s `INFOPLIST_KEY_CFBundleDisplayName`. Keep
  both in sync anyway in case a future Godot version starts using the
  export preset value.
- **The app's minimum iOS version and every device orientation/aspect
  setting are also easy to get wrong silently** — see recent git history
  on `project.godot` and `export_presets.cfg` for the actual fixes
  (portrait orientation is `display/window/handheld/orientation` as an
  **int** enum, not a string; `window/stretch/aspect="expand"` avoids
  letterboxing; centering within `DisplayServer.get_display_safe_area()`
  in `game/main.gd` avoids the board sitting under a notch/Dynamic Island).
- **Fastlane secrets are explicit, never `secrets: inherit`** in
  `.github/workflows/claude-code-review.yml` — this repo also holds Apple
  signing secrets (`MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`,
  `APP_STORE_CONNECT_API_KEY_CONTENT`) that the review job has no reason to
  ever see. See `superhighfives/control-room`'s README for the full
  reasoning (the review job runs an AI agent with broad Bash access over PR
  content — exactly what prompt injection targets).
- **The App Store Connect app record's own registered name** (set manually
  during one-time setup) is separate from `config/name` and isn't touched
  by anything in this repo — check App Store Connect → Griss → App
  Information directly if it ever looks wrong.

## Repo / CI setup

- Public repo: <https://github.com/superhighfives/griss>.
- **This is an early-stage prototype — pushes go straight to `main`, no PR
  required.** Branch protection technically still requires a PR
  (`enforce_admins: false`, so the repo owner can bypass it), but the
  working convention here is direct pushes with a clear commit message,
  not branch → PR → merge.
- `superhighfives/control-room` review workflow is still installed at
  `.github/workflows/claude-code-review.yml` (`runtime: none` — no
  node/bun toolchain, this is a GDScript project) and will review any PR
  that does get opened, but it isn't a required gate given the above.
  Referenced as `@main` deliberately (not SHA-pinned) — same org's own
  actively-iterated tooling. Two secrets: `CLAUDE_CODE_OAUTH_TOKEN` and
  `APP_PRIVATE_KEY` (needed for a 🟢/🟡 verdict to land as a real `APPROVE`
  instead of silently downgrading — see `superhighfives/control-room`'s
  README for why).

## Environment notes for whoever runs this next

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
