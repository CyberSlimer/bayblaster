# Bay Blaster

A SpriteKit launch-and-skip distance game. Marlow the Mackerel rides a dinghy out of the Old
Lighthouse Cannon, skips across the bay, collects coins and buys upgrades. Landscape only,
iOS 17+, no third-party packages, all placeholder art is drawn in code.

## Open it

1. Open `BayBlaster.xcodeproj` in **Xcode 16 or newer** (the project uses a synchronized folder
   group, so every file under `BayBlaster/` is part of the target automatically — nothing to add).
2. Select the **BayBlaster** target → *Signing & Capabilities* → pick your Team.
   (`PRODUCT_BUNDLE_IDENTIFIER` is `com.example.bayblaster`; change it if you like.)
3. Pick any iPhone/iPad simulator or device, press Run.

Command-line build for the Simulator:

```bash
xcodebuild -project BayBlaster.xcodeproj -scheme BayBlaster -destination 'generic/platform=iOS Simulator' build
```

If Xcode asks to "create a scheme" the first time, accept the auto-generated one.

### Dropping into an existing project instead

Copy the `BayBlaster/App`, `Core`, `Gameplay` and `Scenes` folders into your project, replace
your `ContentView` with the one in `App/ContentView.swift`, and add
`CADisableMinimumFrameDurationOnPhone = YES` to your Info.plist for 120 Hz. Lock the
target to landscape in *General → Deployment Info*.

## Where things live

| Area | File |
|---|---|
| Every tunable number | `Core/Constants.swift` |
| Save file (Documents/bayblaster-save.json) | `Core/SaveManager.swift` |
| Missions (kinds, targets, rotation, evaluation) | `Core/Missions.swift` |
| Procedural sounds (AVAudioEngine synth) | `Core/AudioManager.swift` |
| Haptics | `Core/Haptics.swift` |
| Placeholder art + swap mechanism | `Core/Art.swift` |
| Boat, hull, rockets, gravity/drag integration | `Gameplay/Player.swift` |
| Skip-vs-plow water resolution | `Gameplay/WaterSkipSystem.swift` |
| Boost / hazard definitions and effects | `Gameplay/Entities.swift` |
| Procedural spawning, coin arcs, hazard spacing | `Gameplay/WorldSpawner.swift` |
| Distance flags + "your best" flag | `Gameplay/Milestones.swift` |
| Camera lead / zoom / shake | `Gameplay/GameCamera.swift` |
| Aim phase cannon | `Gameplay/Launcher.swift` |
| In-flight HUD, floating labels | `Gameplay/HUD.swift` |
| Parallax sky, day→night, shoreline, water | `Gameplay/Background.swift` |
| Title / Game / Shop scenes | `Scenes/` |
| Pacing simulation used to tune Constants | `Tools/sim.py` |

## Swapping placeholder art for real sprites

Add a PNG to `Assets.xcassets` named exactly like the key used in code — `boat`, `fish`,
`buoy`, `whaleSpout`, `motor`, `birdFlock`, `coinBag`, `fuelCan`, `coin`, `dolphin`, `balloon`,
`rock`, `net`, `shark`, `stormCloud`, `mine`, `jellyfish`, `whirlpool`, `flag`, `bestFlag`,
`lighthouse`, `cannon`, `cloud`, `coinIcon`, `rocketIcon`. `Art.sprite(key)`
finds it and uses it; no code changes. Keep the image centred on the same origin the
placeholder uses (the boat's waterline, the cannon's pivot, etc.).

## Adding a boost or hazard

See the comment block at the top of `Core/Constants.swift`: one enum case, one drawing, one
`switch` arm for the effect, and its numbers in `Tuning`.
