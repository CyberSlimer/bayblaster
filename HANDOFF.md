# Handoff — resume on the Mac

## What exists

Complete v1 of the game as specified: title / aim / flight / results / shop, water-skip
physics, 10 boost & hazard types, procedural spawning, camera, parallax day→night background,
HUD with safe-area layout, procedural audio, haptics, Codable save with corrupt-file recovery,
placeholder vector art with a one-drop PNG swap. ~3,300 lines across 19 Swift files.

## What has NOT been done

1. **Compile.** Written on Windows; never built. Open `BayBlaster.xcodeproj` in Xcode 16+,
   set your signing team, build for a Simulator, fix errors. The riskiest spots (reviewed but
   unverified): implicit-member `SKAction` chains in array literals (`Entities.swift`,
   `GameScene.swift`), `Codable` `init(from:)` in `SaveManager.swift`, the synthesized
   `Voice` memberwise init in `AudioManager.swift`.
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
