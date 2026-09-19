# Bay Blaster

A SpriteKit launch-and-skip distance game. Pick a rider, bolt parts onto the dinghy, choose
what fires you out over the bay, then skip as far as you can, collect coins and spend them on
more of all three. Landscape only, iOS 17+, no third-party packages, all placeholder art is
drawn in code.

## What a run is made of

| Layer | Where you change it | What it does |
|---|---|---|
| **Rider** (8) | Locker → CREW | A passive perk *and* the in-flight ability on the HUD button |
| **Gear** (9, one per slot) | Locker → GEAR | Beach wheels, pontoons, a storm sail, a coin magnet… each with a real cost |
| **Launcher** (4) | Locker → LAUNCHERS | Cannon, rod & reel, slingshot or torpedo tube — a different aim ritual each |
| **Upgrades** (5 tracks × 5 tiers) | Shop | The linear power curve: launch speed, hull, rockets, drag, boost luck |
| **Prestige** | Shop → CAST OFF | Trade coins and all five tracks for a permanent coin multiplier |
| **Missions / Trophies / Daily** | Title, Locker → TROPHIES | 14 rotating goals, 25 one-time trophies, one seeded challenge bay per day |

All five layers are folded into one `UpgradeConfig` before a run starts — see
`Core/Loadout.swift`. Nothing during a run can change it, which is what lets `Tools/sim.py`
mirror the game honestly.

## Open it

1. Open `BayBlaster.xcodeproj` in **Xcode 16 or newer** (the project uses a synchronized folder
   group, so every file under `BayBlaster/` is part of the target automatically — nothing to add).
2. Select the **BayBlaster** target → *Signing & Capabilities* → pick your Team.
   (`PRODUCT_BUNDLE_IDENTIFIER` is `com.cyberslimer.bayblaster`, team `5X895J3VYD` — already set.)
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

## Play on your iPhone / TestFlight

See `docs/DEVICE_AND_TESTFLIGHT.md`. Short version: plug the phone in and run
`Tools/ship.sh device`; for TestFlight create the App Store Connect record once, then
`Tools/ship.sh testflight`.

## Where things live

| Area | File |
|---|---|
| Every tunable number | `Core/Constants.swift` |
| Resolved per-run numbers (`UpgradeConfig`) | `Core/Loadout.swift` |
| Riders and their in-flight abilities | `Core/Crew.swift` |
| Bolt-on parts and their slots | `Core/Gear.swift` |
| Launchers and their aim modes | `Core/Launchers.swift` |
| One-time trophies | `Core/Achievements.swift` |
| Seeded daily challenge + `SplitMix64` / `RandomSource` | `Core/DailyChallenge.swift` |
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
| Aim phase: all four launchers | `Gameplay/Launcher.swift` |
| In-flight HUD, floating labels | `Gameplay/HUD.swift` |
| Parallax sky, day→night, shoreline, water | `Gameplay/Background.swift` |
| Title / Game / Shop / Locker scenes | `Scenes/` |
| Pacing simulation used to tune Constants | `Tools/sim.py` |

## Swapping placeholder art for real sprites

Add a PNG to `Assets.xcassets` named exactly like the key used in code. `Art.sprite(key)`
finds it and uses it; no code changes. Keep the image centred on the same origin the
placeholder uses (the boat's waterline, the cannon's pivot, etc.).

- **World**: `boat`, `buoy`, `whaleSpout`, `motor`, `birdFlock`, `coinBag`, `fuelCan`, `coin`,
  `dolphin`, `balloon`, `rock`, `net`, `shark`, `stormCloud`, `mine`, `jellyfish`, `whirlpool`,
  `flag`, `bestFlag`, `cloud`
- **Riders**: `fish` (Marlow — the original key, kept so an existing PNG still works),
  `crewBristle`, `crewNixie`, `crewGilly`, `crewBruno`, `crewTock`, `crewPip`, `crewChum`.
  Draw them all to Marlow's footprint (~34×18, origin at the belly) so the swap doesn't move
  anything.
- **Gear**: `gearWheels`, `gearPontoons`, `gearSpringKeel`, `gearStormSail`, `gearBoxKite`,
  `gearJetVent`, `gearCoinMagnet`, `gearLuckyHorseshoe`, `gearBarnaclePlate`. Hull parts hang
  below the hull, rigs stand above it, trinkets sit on the gunwale (see `Player.addGearArt`).
- **Launchers**, each a tower + a barrel: `lighthouse`/`cannon`, `rodStand`/`rodReel`,
  `slingPost`/`slingshot`, `torpedoRig`/`torpedoTube`. The barrel's origin is its pivot.
- **UI**: `coinIcon`, `rocketIcon`, `trophyIcon`

## Adding content

Each of these has a "how to add one" comment block at the top of its file:

| To add a… | Read |
|---|---|
| boost or hazard | `Core/Constants.swift` |
| rider or ability | `Core/Crew.swift` |
| bolt-on part | `Core/Gear.swift` |
| launcher | `Core/Launchers.swift` |
| trophy | `Core/Achievements.swift` |

The pattern is the same every time: one enum case, its numbers in `Tuning`, one placeholder
drawing in `Core/Art.swift`, and one `switch` arm wherever the effect lives. If the new thing
changes distance, mirror it in `Tools/sim.py` and re-run `python3 Tools/sim.py`.
