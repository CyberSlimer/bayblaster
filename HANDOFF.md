# Handoff — resume on the Mac

## What exists

Complete v1 of the game as specified: title / aim / flight / results / shop, water-skip
physics, procedural spawning, camera, parallax day→night background, HUD with safe-area
layout, procedural audio, haptics, Codable save with corrupt-file recovery, placeholder
vector art with a one-drop PNG swap.

Added 2026-09-18 (Mac session), aimed at the genre's retention hooks:
- **16 entity kinds** (was 10). New hazards: sea mine (big hull hit *but* hurls you back into
  the air — risk/reward), jellyfish (sting + 1.5 s stun: no rockets, no dive), whirlpool
  (zone that drags you down / slows a plow). New boosts: dolphin (forward bounce, keeps all
  speed), balloons (2.2 s low-gravity float). Small `coin` kind used only by coin arcs.
- **Coin arcs**: 22% of boost spawns become a 6–9 coin parabola — a line to aim for.
- **Skip combos**: consecutive skips pay `3 × combo` coins; a plow ends the combo. A landing
  shallower than 22° is a **PERFECT** skip (+15 coins, +4% speed). Results card shows best
  combo and perfect count.
- **Milestone flags** every 250 m and a gold **★ YOUR BEST ★** flag at the saved best.
- **Spawn fairness**: the hazard share is ×0.45 right after a waterline hazard.
- Debug-only test hook: launch with env `BB_ANGLE=32 BB_POWER=1` to force the aim locks
  (`SIMCTL_CHILD_` prefix for `simctl launch`). See `Launcher.swift`.

## What has NOT been done

1. ~~**Compile.**~~ Done 2026-09-18 (Xcode 26.6, iPhone 16 Pro Max Simulator). Only error was
   `Player.speed` colliding with `SKNode.speed` → renamed `boatSpeed`. Zero warnings. A full
   run, a shop purchase and a relaunch all behaved; `Documents/bayblaster-save.json` was
   written as expected.
2. **Play-test.** Things to feel out on device, all tunable in `Constants.swift`:
   - Camera: `cameraVisibleHeight` (boat may look small on iPhone), `cameraLeadFactor`.
   - Aim feel: `angleSweepPeriod`, `powerSweepPeriod`.
   - Skip window: `skipMaxAngleDegrees` (42°) — if skips feel too rare/easy, move this first.
   - Entity contact radii in `EntityKind.spec` vs the baked placeholder textures.
   - Audio levels in `AudioManager.render` (all synthesized; tweak `amp`).
3. **120 Hz check.** `CADisableMinimumFrameDurationOnPhone` is in `Info.plist`; confirm
   `SpriteView(preferredFramesPerSecond: 120)` actually reports 120 on a ProMotion device.

## Pacing targets (sim, median of 300 runs)

| Build | Distance |
|---|---|
| Fresh boat | 280–310 m |
| Mid-late (L3 H2 R2 A2 U1) | ~1,500 m |
| Fully upgraded | ~6,800 m |

Re-checked after the 2026-09-18 additions: distances within ±4% of before, coins +3–9% from
combos. Play-test ideas still open: whether mines feel fair (35 hull), whether the stun reads
clearly enough, milestone label overlapping the HUD when the boat is near the top of screen.

`python3 Tools/sim.py` reproduces this table and the coin-economy walkthrough.

## Suggested first prompt for Claude Code on the Mac

> Build BayBlaster for the iOS Simulator with xcodebuild, fix any compile errors, then run it
> in the Simulator and check that a run launches, skips, ends, and the shop purchase persists
> across relaunch.
