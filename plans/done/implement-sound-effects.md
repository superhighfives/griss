---
title: Implement sound effects
status: Complete
created: 2026-09-17
updated: 2026-09-17
---

# Implement sound effects

## Goal
Make the game audible. Reported as "sound effects aren't working, testing on
iOS" — and they weren't working anywhere, because they were never implemented.

## Context
`game/sound_hooks.gd` shipped in M4 as six static methods whose entire body
was `pass`. That was deliberate at the time (`docs/PLAN.md`: "sound hooks left
unimplemented") — the call sites went in so that wiring real audio later would
be a one-line change per hook rather than a hunt for where each event happens.
That later is now.

So the iOS framing was a red herring: the Mac build would have been just as
silent. There is, however, a genuine iOS-only issue stacked behind it, which
this plan also fixes — see **The iOS half** below.

The project has no audio assets, and `docs/PLAN.md` parks art and audio
together as out of scope but "easy to add if the architecture constraints
above are respected".

## Approach
Three pieces, one per layer:

- **`game/sfx_bank.gd`** — synthesises the six sounds in code as
  `AudioStreamWAV`s. No binary assets, no `.import` sidecars; the sounds are
  arithmetic, in the same spirit as `game/tuning.gd` holding the visual
  tunables as numbers. Deterministic (the one noise source is seeded), which
  is what makes the output assertable.
- **`game/sfx.gd`** — an `Sfx` node holding the bank and a pool of six
  `AudioStreamPlayer`s, so a move and the capture it caused don't cut each
  other off. `main.gd` creates it, adds it to the tree, and hands it to
  `SoundHooks` once.
- **`game/sound_hooks.gd`** — unchanged public API, now forwarding to whatever
  has been attached instead of doing nothing. `GameController` is untouched.

The first version of this made `Sfx` an autoload, which `docs/PLAN.md` section
9 rules out ("No `Autoload`/singletons... Pass dependencies explicitly"). The
explicit wiring it was changed to is better anyway: it gives the tests a real
seam (`SoundHooks.attach()`) instead of having to detach and restore an
autoload, and it means nothing outside the running game — the test suite,
`tools/solve_level.gd` — has an audio node at all.

### The iOS half
`audio/general/ios/session_category` defaults to `0` — `Ambient` — which iOS
silences whenever the hardware Ring/Silent switch is set to silent. That is a
reasonable default for background music and the wrong one for gameplay
feedback: it would have produced exactly the reported symptom (silence on an
iPhone) even with everything above working. Set to `3` (`Playback`), which
sounds regardless of the switch.

This is the second bug, and the only genuinely iOS-specific one. It would have
been easy to miss: fix only the hooks, test on a Mac, and it looks solved.

## Tasks
- [x] Synthesise the six sounds (`game/sfx_bank.gd`).
- [x] An `Sfx` node owning the bank and a voice pool (`game/sfx.gd`).
- [x] Wire it up from `main.gd` and point `SoundHooks` at it.
- [x] Set the iOS audio session category to `Playback`.
- [x] Tests (`tests/test_sfx.gd`), including end-to-end wiring coverage.

## Overview
Six procedurally generated sounds — move, capture, promotion, card, win, loss
— now play at the hook points M4 laid down, plus the iOS project setting that
would otherwise have kept an iPhone silent anyway.

Nothing calling into audio changed shape: `GameController` still calls the
same six `SoundHooks` methods with the same arguments. The only signature
change is `on_card_played(card_type)` → `on_card_played(_card_type)`, since
every card currently shares one sound; the parameter stays so that giving
Push Back its own cue later is a change inside that one function.

## Architecture

**Synthesis** (`game/sfx_bank.gd`). Sounds are mixed additively into a
`PackedFloat32Array` and converted to 16-bit mono PCM once at the end, so
overlapping partials sum at full precision and clip (if at all) exactly once.
Every tone gets a few-millisecond attack ramp and every buffer a short release
fade — without them a sine starting or stopping at a non-zero sample has a
step discontinuity there, which is audible as a click layered on top of the
sound that was actually wanted. 22.05 kHz rather than 44.1: the highest
partial used is under 2 kHz. The whole bank is ~109 KB of samples, built in
well under a millisecond at startup.

The sound design is deliberately understated. `move` is the quietest and
shortest thing in the bank because it fires on every single move and anything
with a tail becomes grating within a level; `capture` is the same gesture
lower, louder and with a noise transient, so it reads as the same action with
more weight rather than as an unrelated event; `loss` is `win` inverted, so it
lands as the other outcome of one game and not as an error buzzer.

**Playback** (`game/sfx.gd`). Six pooled voices, claimed by preferring one
that isn't sounding and falling back to round-robin stealing. Game logic can
genuinely produce two sounds in one frame (a move plus its capture, a card
plus the promotion it grants), which a single player would truncate.
`process_mode` is `ALWAYS`: no sound here carries game state, so none of them
should be held by pause.

**The `enabled` flag** is the one piece of this that isn't obvious. Under
Godot's `Dummy` audio driver — any headless run — each `play()` would allocate
a playback that never gets mixed and never finishes. That is pointless work,
and those playbacks are still referenced at engine cleanup, where Godot
reports them as leaked `ObjectDB` instances. So `Sfx` reads
`AudioServer.get_driver_name()` in `_ready()` and stays inert when there is
nothing to play into. Tests that need the real path set `enabled = true`
explicitly.

Note the ordering inside `play()`: the unknown-name check runs *before* the
`enabled` check, deliberately. A name the bank has no stream for is a
programming error, and it should still be reported on a machine with no audio
device rather than waiting until someone runs the game.

**Attachment** (`game/sound_hooks.gd`). The hooks hold a `static var` pointing
at the `Sfx` node, set by `main.gd` through `attach()`. Nothing attached means
silence rather than an error, and that is the normal state for everything that
isn't the running game — the test runner and `tools/solve_level.gd` both drive
`GameController` without ever calling `attach()`, and they stay exactly as
silent as these hooks used to be. `_play()` guards with `is_instance_valid()`
rather than a null check: a static reference to a `Node` outlives the node on
shutdown.

### Tests
`tests/test_sfx.gd` covers the synthesis (every declared sound exists, carries
signal rather than silence, is 16-bit mono at the bank's rate, starts and ends
at silence, and comes out byte-identical across builds), the hook wiring, the
`enabled` guard, and the voice pool.

Three of them are the ones that matter, because each fails on a different
layer of the original bug:

- `test_each_hook_plays_its_own_sound` attaches a recorder and asserts each
  hook plays its own sound, in order.
- `test_a_real_move_reaches_the_sound_chain` drives a real move through
  `GameController` — nothing else covers the `GameController` → `SoundHooks`
  wiring.
- `test_the_main_scene_wires_up_the_sound_chain` instantiates the real
  `Main.tscn` and checks the chain came up connected. `main.gd` is the only
  place that hands `SoundHooks` something to play through, and without this
  every layer below could be correct while the game stayed silent — the same
  bug, one level up.

All three were verified by mutation, along with the rest of the suite. Seven
mutations, seven catches: reverting the hooks to `pass`; deleting
`SoundHooks.on_move()` from `try_move()`; dropping the `attach()` call, the
`add_child()`, or the `_setup_sound()` call from `main.gd`; making the bank
generate silence; and building no voices at all. Each failed the test you
would want it to. The last of those is the one added after review — before
the fix below it would have passed the voice-pool test vacuously.

### Deviations and things found along the way

**Autoloads do exist under the headless runner**, which is worth recording
because it is easy to assume otherwise: a `--script` main loop gets them like
any other. That was found while the autoload version was still in place, when
the "nothing attached" test failed by finding a real `Sfx` node. It stopped
mattering once the autoload went away, but it is the kind of assumption that
would quietly break a future test.

**A freed node compares equal to null.** The main-scene test first read its
assertions *after* tearing the scene down, so the `Sfx` it was holding had
already been freed along with its owner — and a variable pointing at a freed
node compares equal to `null`, so the test failed against correct code while
passing one of the mutations. It now reads every fact it needs into plain
values before the teardown. Worth remembering: `assert_not_null()` on a node
says nothing about whether that node was ever there.

**`_ready()` is not synchronous under the test runner, and the first version
of that finding was wrong in a way worth recording.** It was written as being
about instantiated scenes. It isn't: `add_child()` runs `_ready()` straight
away only once the tree has started processing frames, and tests begin inside
`SceneTree._initialize()`, before any frame has happened. A plain `Node.new()`
is deferred there exactly like a `PackedScene` is.

Three tests here add a node and then read state that `_ready()` sets up, and
all three passed anyway — because an earlier test in the file awaits a timer,
which pumps the tree and makes everything after it work. That is the nasty
shape of this: the suite is green, each test looks self-contained, and the
thing holding it up is an unrelated test's `await`. Delete or reorder that one
test and `test_playback_is_disabled_without_an_audio_device` starts failing,
while `test_voice_pool_hands_out_distinct_players` would have gone on passing
over an empty pool, since `VOICE_COUNT` is a `const` and reads 6 whether or
not `_ready()` built anything.

So each test now waits for itself (`_ready_tick()`), and the pool test sizes
itself off `_voices` and checks that against `VOICE_COUNT` rather than
trusting the constant. Verified by running `tests/test_sfx.gd` both alone and
alone-with-the-awaiting-test-deleted; the second case failed before this and
passes now.

Caught in review by `control-room-review[bot]`, which asked whether a bare
`Sfx.new()` really had its `_ready()` run before the assertions read it. It
did not, and reasoning backwards from "the suite is green" was the wrong way
to answer that — the probe that settles it is three lines.

**Releasing playbacks needs a mix, not just a `stop()`.** The tests that do
force real playback have to stop their voices *and* let a timer tick before
freeing: `stop()` hands the playback back to the `AudioServer`, but the server
only lets go on its next mix. 0.05s turned out to be enough for one voice and
not for a pool of six, which is why `RELEASE_TICK_SECONDS` is 0.2 — an
empirical number with margin. Getting it wrong costs a leak warning at exit,
never a failed test.

An earlier attempt at this stopped the voices from `Sfx._exit_tree()` instead.
That was dropped: `NOTIFICATION_EXIT_TREE` reaches children before the parent,
so the players have already left the tree by the time it runs, and the
`enabled` guard removes the need entirely for every path that isn't a test
deliberately forcing playback on.

**The comment in `project.godot` is load-bearing but fragile** — the editor
rewrites that file and strips comments on save, which is why the reasoning for
the session category lives here as well.

Full suite green: 84/84 (was 72/72), no leaked instances at exit.

`docs/PLAN.md` section 10 listed audio as out of scope but "easy to add if the
architecture constraints above are respected". It was: `GameController` did
not change at all, and the M4 hook points held up exactly as intended.

### Not done
Verified headlessly on Linux, not on a device. What that leaves open is
whether the session-category fix produces audible sound on a physical iPhone
with the Ring/Silent switch engaged, and whether the sounds are pleasant at
`Tuning.SFX_VOLUME_DB` through a phone speaker. Both want a TestFlight build.
