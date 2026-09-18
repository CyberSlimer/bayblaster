# Bay Blaster — project notes for Claude Code

SpriteKit launch-and-skip distance game (iOS 17+, landscape only, SwiftUI hosts a SpriteView,
no third-party packages). Hero: Marlow the Mackerel in a dinghy, fired from the Old
Lighthouse Cannon. See README.md for the file map and HANDOFF.md for current status.

## Status (as of 2026-09-18)

- All v1 features are implemented; **the code has never been compiled**. It was written on a
  Windows machine without Xcode and only self-reviewed. First task on a Mac: build it and fix
  whatever the compiler reports, then play a few runs on the Simulator.
- Pacing constants were tuned with `Tools/sim.py` (a Python mirror of the physics). If you change
  anything in `Tuning` that affects distance, mirror it in `sim.py` and re-run
  `python3 Tools/sim.py` so the pacing table stays honest.

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
