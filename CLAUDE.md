# Bay Blaster — project notes for Claude Code

SpriteKit launch-and-skip distance game (iOS 17+, landscape only, SwiftUI hosts a SpriteView,
no third-party packages). Hero: Marlow the Mackerel in a dinghy, fired from the Old
Lighthouse Cannon. See README.md for the file map and HANDOFF.md for current status.

## Status (as of 2026-09-18)

- All v1 features are implemented. Written on Windows without Xcode; first compiled on a Mac
  on 2026-09-18 with Xcode 26.6 (one fix: `Player.speed` renamed to `boatSpeed`, since
  `SKNode` already declares a mutable `speed`). Builds with zero warnings. Smoke-tested on the
  iPhone 16 Pro Max Simulator: title → aim → flight → splashdown → shop purchase → save
  persists across relaunch. Remaining work is play-testing/tuning (see HANDOFF.md).
- 2026-09-18 additions: 6 new entity kinds, coin arcs, skip combos + PERFECT skips, milestone
  flags, hazard spacing, and rotating missions (`Core/Missions.swift`; `RunStats` is gathered
  in GameScene — add a field there when a new mission kind needs new data). Debug builds accept `BB_ANGLE` / `BB_POWER` env vars to force the aim
  locks for reproducible test runs.
- Pacing constants were tuned with `Tools/sim.py` (a Python mirror of the physics). If you change
  anything in `Tuning` that affects distance, mirror it in `sim.py` and re-run
  `python3 Tools/sim.py` so the pacing table stays honest.

## Device / TestFlight

`Tools/ship.sh device` (plugged-in iPhone) and `Tools/ship.sh testflight` (archive + upload).
Team 5X895J3VYD is paid (Xcode's cached "Personal Team" label is stale). Details and the
one-time App Store Connect setup: `docs/DEVICE_AND_TESTFLIGHT.md`.

## Build

```bash
xcodebuild -project BayBlaster.xcodeproj -scheme BayBlaster \
  -destination 'generic/platform=iOS Simulator' build
```

Xcode 16+ is required (synchronized folder group in the .pbxproj — new files under
`BayBlaster/` join the target automatically; do not hand-edit file lists).

## Conventions

- Every tunable number goes in `BayBlaster/Core/Constants.swift` (`Tuning`), with a comment.
- Art is requested by key through `Art.sprite("key")`; real PNGs replace placeholders by being
  added to `Assets.xcassets` under that key. Never reference textures directly elsewhere.
- Gravity/drag are integrated in `Player.update(dt:)`; `physicsWorld.gravity` stays zero.
  Water is not a physics body — `WaterSkipSystem` resolves it.
- New boosts/hazards: follow the recipe at the top of `Constants.swift`.
- Save file is `Documents/bayblaster-save.json` via `SaveManager`; keep decoding tolerant
  (`decodeIfPresent` with defaults) so old saves never crash a new build.
