---
title: Add a macOS build to TestFlight
status: Backlog
created: 2026-09-15
updated: 2026-09-15
---

# Add a macOS build to TestFlight

## Goal

Distribute a native macOS build of Griss via TestFlight, alongside the
existing iOS one, so it can be tested without running `godot --path .`
from source.

## Context

Raised while discussing local testing — since `godot --path .` already
runs the game natively on macOS for development, this isn't solving an
immediate problem. It's a nice-to-have for sharing a build with someone
who doesn't have this repo checked out, not a blocker for anything else.
Explicitly parked, not prioritized.

TestFlight does support native Mac apps (not just Mac Catalyst) — this
would be a real, working option if picked up.

## Approach (rough, unrefined — this is a backlog idea, not a spec)

- Godot has a separate "macOS" export platform/preset, distinct from the
  existing iOS one in `export_presets.cfg` — would need its own preset,
  not a variant of the current one.
- Mac App Store distribution (required for TestFlight) needs the App
  Sandbox entitlement, unlike direct Developer ID distribution outside
  the App Store. Griss doesn't do anything sandbox-unfriendly today (no
  filesystem access beyond `user://`, no network), so this is likely
  low-risk, but untested.
- Signing: extend the existing `fastlane match` setup
  (`griss-certificates`) with a macOS App Store distribution
  certificate/profile, alongside the existing iOS one.
- App Store Connect: either add "Mac" as an additional platform on the
  existing Griss app record (if bundle ID reuse is viable), or a new app
  record — needs checking which applies once this is picked up.
- CI: a new job (or a parameterized version of the existing one) in
  `.github/workflows/testflight.yml` for the macOS export + build + sign
  + upload.

## Open questions

- Same bundle ID / app record as iOS, or separate? Depends on how App
  Store Connect's "additional platform on one app" flow actually works in
  practice — check when this is picked up, don't assume.
- Whether the macOS-native `godot --path .` build differs meaningfully
  from what Mac App Store distribution needs (signing/sandboxing aside) —
  probably not, but unverified.
