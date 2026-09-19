# Handoff — resume on the Mac

## What exists

Complete v1 of the game as specified: title / aim / flight / results / shop, water-skip
physics, 10 boost & hazard types, procedural spawning, camera, parallax day→night background,
HUD with safe-area layout, procedural audio, haptics, Codable save with corrupt-file recovery,
placeholder vector art with a one-drop PNG swap. ~3,300 lines across 19 Swift files.

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
| Fresh boat | 280–320 m |
| Run ~10 (L3 H3 R3 A2 U1) | ~1,660 m |
| Fully upgraded | ~6,500 m |

`python3 Tools/sim.py` reproduces this table and the coin-economy walkthrough.

## Suggested first prompt for Claude Code on the Mac

> Build BayBlaster for the iOS Simulator with xcodebuild, fix any compile errors, then run it
> in the Simulator and check that a run launches, skips, ends, and the shop purchase persists
> across relaunch.
