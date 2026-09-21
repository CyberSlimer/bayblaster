# Bay Blaster — project notes for Claude Code

SpriteKit launch-and-skip distance game (iOS 17+, landscape only, SwiftUI hosts a SpriteView,
no third-party packages). You pick a rider, bolt parts onto a dinghy, pick a launcher, and get
fired out over the bay. See README.md for the file map and HANDOFF.md for current status.

## Status (as of 2026-09-19)

- All v1 features are implemented. Written on Windows without Xcode; first compiled on a Mac
  on 2026-09-18 with Xcode 26.6 (one fix: `Player.speed` renamed to `boatSpeed`, since
  `SKNode` already declares a mutable `speed`). Builds with zero warnings. Smoke-tested on the
  iPhone 16 Pro Max Simulator: title → aim → flight → splashdown → shop purchase → save
  persists across relaunch. Remaining work is play-testing/tuning (see HANDOFF.md).
- 2026-09-18 additions: 6 new entity kinds, coin arcs, skip combos + PERFECT skips, milestone
  flags, hazard spacing, and rotating missions (`Core/Missions.swift`; `RunStats` is gathered
  in GameScene — add a field there when a new mission kind needs new data). Debug builds accept `BB_ANGLE` / `BB_POWER` env vars to force the aim
  locks for reproducible test runs.
- 2026-09-19 "locker" update (compiled and smoke-tested on the Mac the same day, see HANDOFF.md):
  8 unlockable riders each with a passive perk and an in-flight ability, 9 bolt-on gear parts
  in 3 slots, 4 launchers with 3 different aim rituals, 25 achievements, a seeded daily
  challenge, and prestige. New `LockerScene`. `save.version` is now 2; v1 saves load fine.

- 2026-09-21 "smash" update (also NOT YET COMPILED): breakable walls on their own spawn track,
  a high-air spawn track and an altitude-driven sky so a big launch is not flying through
  nothing, plus a proper launch sequence (punch-zoom, shockwave, smoke, whiteout, tumble).
  21 entity kinds, 16 mission kinds, 29 trophies.

## Three spawn tracks

`WorldSpawner` runs three independent passes, each with its own cadence:

- **low** — the original one, water level to ~900 points, weighted by `Spec.weight`
- **high air** — above `Tuning.highAirStartHeight`, weighted by `Spec.highAirWeight`, so a kind
  can appear in both pools at different rates
- **barrier** — breakable walls, `Tuning.barrierIntervalMeters` apart

A wall is the one kind that is neither boost nor hazard: `WorldEntity` builds it as a stack of
bricks with a *rectangular* body and a `toughness`. Keep barrier toughness a gentle ramp with a
low cap — speed in this game tracks the player's upgrade tier, not distance, and it decays
across a run, so a steep ramp just parks an unbreakable wall at the end of every run.

## The loadout pipeline

Anything that changes how a run plays must end up in `UpgradeConfig` (`Core/Loadout.swift`),
which is built ONCE per run and never mutated. It folds five layers in this order:

    upgrade tiers → crew perk → equipped gear → prestige → daily modifier

Read from `config`, not from `Tuning`, anywhere a rider or a part could plausibly change the
number (skip window, restitution, plow drag, gravity, damage, coin payouts). `Tuning` holds
the *base* values those layers multiply.

- New rider/ability → `Core/Crew.swift` + a `switch` arm in `Player.beginAbility`/`update`
  (and `GameScene.useAbility` if it needs the world).
- New part → `Core/Gear.swift`; add a field to `GearItem.Modifier` if the rule can't be
  expressed with the existing ones, then read it wherever that rule lives.
- New launcher → `Core/Launchers.swift`; a brand-new ritual needs an `AimMode` case handled
  in `Launcher.update` and in `HUD.setLauncherStyle`.
- New trophy → `Core/Achievements.swift`; new data for it goes in `RunStats`.
- Anything that owns `player.visual.zRotation` must say so: `Player.update` eases it toward the
  direction of travel every frame, so the launch tumble suppresses that with `tumbleRemaining`
  rather than running an action alongside it.
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
  (`decodeIfPresent` with defaults) so old saves never crash a new build. `SaveData.sanitizeLocker()`
  runs after every decode and every locker change — it drops unknown raw values and guarantees
  the starter rider and cannon are owned and selected. Extend it when you add a locker field.
- Daily runs must stay reproducible: every random draw that places a world object goes through
  `RandomSource` (`Core/DailyChallenge.swift`), never `CGFloat.random` directly. Never seed
  from `String.hashValue` — Swift salts it per process.
