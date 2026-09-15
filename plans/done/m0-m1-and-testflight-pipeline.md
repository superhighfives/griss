---
title: M0/M1 core game and iOS TestFlight pipeline
status: Complete
created: 2026-09-11
updated: 2026-09-15
---

# M0/M1 core game and iOS TestFlight pipeline

## Goal

Build the M0 (scaffold) and M1 (playable traversal) milestones per
[`docs/PLAN.md`](../../docs/PLAN.md), then get the result onto a real
iPhone via TestFlight, automatically, on every push to `main`.

## Context

This predates the `plans/` workflow — `docs/PLAN.md` served as the spec,
and [`HANDOVER.md`](../../HANDOVER.md) tracked status until now. Recorded
here retroactively so the historical record lives in the same place
future work does.

## Overview

Shipped a playable puzzle game (pawn traverses a walled vertical lane,
click to select and move, win on reaching the goal row) with a pure,
headlessly-tested rules engine (`core/`) driving a runtime-built
presentation layer (`game/`) — no editor-wired scenes beyond the three
required nodes. Then built the infrastructure to get it in front of an
actual tester: every push to `main` now exports, signs, and uploads a new
TestFlight build in 2–4 minutes, with no manual steps.

Along the way, testing the very first real builds on an actual device
surfaced several bugs that no amount of headless testing or desktop
`godot --path .` runs had caught, all found and fixed with real evidence
rather than guessed at.

## Architecture

**Core game (M0/M1).** `core/` (`BoardState`, `Piece`, `MoveGen`, `Rules`,
`LevelLoader`) has zero Godot scene dependencies — `RefCounted`/plain
classes only, fully covered by `tests/` (44 tests,
`godot --headless --path . --script res://tests/run_tests.gd`). `game/`
(`Main.tscn` + `main.gd`, `board_view.gd`, `input_controller.gd`,
`hud.gd`) builds the entire board from script at runtime and never
implements a rule itself.

**iOS TestFlight pipeline** (`.github/workflows/testflight.yml`,
`fastlane/Fastfile`, `export_presets.cfg`). Godot exports an Xcode
project → Fastlane signs it with a `match`-managed App Store distribution
certificate → uploads to TestFlight. One-time Apple-side setup is
[`docs/TESTFLIGHT_SETUP.md`](../../docs/TESTFLIGHT_SETUP.md).

The pipeline's biggest deviation from "just works": early runs
consistently hung for the full 20-minute job timeout somewhere in the
Xcode archive step, at an inconsistent point each run. Memory exhaustion,
Spotlight indexing contention, and CPU starvation on the runner's 3 vCPUs
were each suspected and ruled out in turn with real process-state/CPU
sampling data — none of them were it. The actual cause, found only after
disabling `xcpretty` formatting to see xcodebuild's real raw output:
`codesign` itself, invoked from inside `swift-stdlib-tool` while signing
the Swift runtime dylibs, hanging forever on a keychain ACL prompt a
headless session can never answer — `fastlane match`'s certificate import
grants the `apple-tool:`/`apple:` keychain partition IDs but not
`codesign:`. Fixed with fastlane's `setup_ci` (a dedicated, correctly
provisioned CI keychain). See `HANDOVER.md`'s pipeline section for the
full detail if this class of failure ever recurs.

**On-device fixes**, found only once a real person tried the first real
builds on a real phone:
- Pawn selection did nothing — `board_view.gd`'s cells/pieces are
  `ColorRect`s, and `Control`'s default `mouse_filter=STOP` was silently
  absorbing every click before it reached `InputController`. Likely never
  worked via real input, only ever exercised via the headless test
  harness calling `GameController` directly.
- Device orientation defaulted to landscape despite a portrait-shaped
  viewport (`display/window/handheld/orientation` needed an int enum
  value, not the string it was set to).
- Background didn't fill the screen on non-4:5 aspect devices
  (`window/stretch/aspect="expand"`), then the board sat under the
  notch/Dynamic Island once it did (fixed by centering within
  `DisplayServer.get_display_safe_area()` in `main.gd`).
- `MinimumOSVersion` and export-compliance (`ITSAppUsesNonExemptEncryption`)
  App Store Connect warnings, both one-line fixes once identified.
- The pawn's move rules were tightened toward real chess (two-square
  first move) after initial device playtesting, beyond the MVP's
  original "one step forward, keep it dead simple" scope.
- The app itself was still internally named "Chess Lane" in
  `project.godot`'s `config/name` (→ `INFOPLIST_KEY_CFBundleDisplayName`)
  well after the project and repo had become Griss.

No deviation from the *architecture* — the core/game separation and
runtime-built scene held up through all of the above; every fix lived
entirely in `game/`, `project.godot`, or the CI/signing layer.
