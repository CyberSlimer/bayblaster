# Handoff — resume on the Mac

## What exists

Complete v1 of the game as specified: title / aim / flight / results / shop, water-skip
physics, procedural spawning, camera, parallax day→night background, HUD with safe-area
layout, procedural audio, haptics, Codable save with corrupt-file recovery, placeholder
vector art with a one-drop PNG swap.

Added 2026-09-18 (Mac session): 16 entity kinds, coin arcs, skip combos + PERFECT skips,
milestone flags, progressive unlocks with first-touch tips, and 12 rotating missions. All
compiled and smoke-tested.

## Added 2026-09-19 — the "locker" update (⚠️ NOT YET COMPILED)

Written on Linux with no Swift toolchain, exactly like the original Windows session. **The
first job on the Mac is to build it and fix whatever the compiler finds.** Everything below is
cross-checked by script (every `Tuning.` member resolves, every art key has a drawing, every
`switch` over the new enums is exhaustive, every price/reward table covers every case, braces
balance) but that is not a compiler.

The one thing it answers to the original brief: there was nothing to *collect*, and in the air
you only had two verbs. Now there are four unlock tracks and a third verb.

### 1. Riders (`Core/Crew.swift`) — 8, one selected at a time

Each brings a **passive perk** and an **in-flight ability** fired from a new HUD button
(bottom-right, fills as it cools down). Tap is still a rocket, hold is still a nose-dive.

| Rider | Price | Perk | Ability |
|---|---|---|---|
| Marlow the mackerel | free | ability cooldown −20% | **Tuck** — drag almost vanishes for 1.2 s |
| Bristle the pufferfish | 800 | hull +35%, drag −12% | **Puff up** — every landing skips while inflated |
| Bruno the sea otter | 1,800 | skips keep +4.5%, drag −12% | **Belly slam** — slam down; the landing becomes a huge skip |
| Pip the seagull | 2,600 | coins ×1.7 | **Swoop** — snap your flight at the next pickup |
| Tock the hermit crab | 3,000 | damage −50%, hull +25%, drag −20% | **Shell up** — soaks the next two hazards whole |
| Chum the baby shark | 5,200 | launch +20%, drag −20%, hull −15% | **Frenzy** — double coins, hazards stop slowing you |
| Gilly the squid | 6,500 | +1 rocket | **Ink jet** — a short forward jet on a short cooldown |
| Nixie the flying fish | 8,000 | drag −32% | **Glide** — wings out, barely any gravity |

### 2. Gear (`Core/Gear.swift`) — 9 parts, 3 slots, one part per slot

Bought once, then equipped/unequipped freely. Every part is a trade, and every part is
visible on the boat (`Player.addGearArt`).

- **Hull**: Beach Wheels (roll on after splashdown), Pontoons (+14° skip window, +6% drag),
  Spring Keel (+26% bounce)
- **Rig**: Storm Sail (constant push; squalls blow you along instead of down), Box Kite
  (−16% gravity), Jet Vent (+15% rockets and +1)
- **Trinket**: Coin Magnet (60 m pull), Lucky Horseshoe (boosts ×2, far more coin arcs),
  Barnacle Plating (−50% damage, −4% launch)

### 3. Launchers (`Core/Launchers.swift`) — 4, each a different aim ritual

This is the "casting a lure" idea, kept additive: the cannon is now the first of four rather
than the only one, so nothing that already worked was thrown away.

| Launcher | Price | Ritual |
|---|---|---|
| Old Lighthouse Cannon | free | Two taps: lock the angle, lock the power |
| Surf Rod & Reel | 5,000 | Angle, then a fast **cast bar** — tap inside the green band for ×1.28 |
| Tidal Slingshot | 9,000 | Angle, then **hold to draw**; hold past full and the band snaps to 30% |
| Torpedo Tube | 14,000 | Two fast sweeps, 6–28° and low. Wider skip window and a tougher casing, so you start the run already skipping |

### 4. Long tail

- **25 achievements** (`Core/Achievements.swift`), each paying once, listed on a TROPHIES tab.
- **Daily challenge** (`Core/DailyChallenge.swift`): the bay is seeded from the date via
  `SplitMix64`, so every attempt that day is the same layout, plus one of 8 modifiers of the
  day. Reward paid once per day; consecutive days build a streak.
- **Prestige** ("CAST OFF", in the shop): once all five upgrade tracks are maxed, trade coins
  and all five tracks for a permanent +25%/level coin multiplier. Crew, gear, launchers,
  trophies, best distance and lifetime stats all survive.
- **New scene**: `Scenes/LockerScene.swift` — CREW / GEAR / LAUNCHERS / TROPHIES tabs, a paged
  card grid, one tap to buy or equip.
- **Two new mission kinds**: "use your ability N times", "fly N m and finish at full hull".

### Save compatibility

`SaveData.currentVersion` is now 2. Every new key is `decodeIfPresent` with a default and
`sanitizeLocker()` runs after each decode, so a v1 save loads straight in with Marlow and the
cannon selected. **Worth explicitly testing on the Mac**: install the old build, make a save,
then install this one over it.

## What has NOT been done

1. **Compile.** Not attempted — no Swift toolchain on Linux. Expect a handful of errors.
   Highest-risk spots, in order: `GameScene` has two designated initialisers now
   (`init(size:)` and `init(size:daily:)`); `LockerScene.CardSpec` is `fileprivate` so the
   `LockerCard` further down the file can see it; `RandomSource` copies its generator out and
   back on every draw; the `Placeholders` drawings use a lot of `CGFloat(...)` conversions.
2. **Play-test the new layers.** The sim says the numbers are sane but it cannot say whether
   the ability button is reachable with a thumb, whether the cast band is readable at speed,
   or whether the slingshot's snap feels fair. Specifically:
   - Ability button placement/size (`HUD.abilityButtonCentre`, `HUD.abilityButtonRadius`).
   - The rod's green band and the slingshot's red danger zone (`HUD.setLauncherStyle`).
   - Whether the torpedo's low launch reads as exciting or as "I hit the water instantly".
   - Whether 9 gear cards on a 3×3 grid are legible on a small iPhone in landscape.
3. **Original v1 play-test items still open**: camera `cameraVisibleHeight`, aim sweep periods,
   `skipMaxAngleDegrees`, entity contact radii vs the baked textures, audio levels.
4. **TestFlight**: pipeline is done; still blocked only on creating the App Store Connect app
   record for `com.cyberslimer.bayblaster` (`docs/DEVICE_AND_TESTFLIGHT.md`).
5. **120 Hz check** on a ProMotion device.

## Balance work done with the simulator

`Tools/sim.py` now mirrors the whole loadout pipeline (the five layers in `UpgradeConfig.init`,
plus each ability and a plausible player model for when they'd fire it). It caught four things
that would have been miserable to find by hand, all since fixed:

- **Tuck was a 2.6× distance multiplier on its own.** Air drag dominates distance in this game,
  so cutting it to 15% for 1.4 s every 4 s was worth more than the entire upgrade tree. Every
  ability is now measured against a perkless, abilityless baseline and sits in a 1.05–1.36×
  band.
- **The belly slam was worse than not using it** (0.85×) — each forced bounce shed horizontal
  speed, so it was a pogo stick. It now carries a forward bonus on the landing it causes
  (`Tuning.abilitySlamForwardBonus`), making it the dive-bomb it reads as.
- **The torpedo tube, the most expensive launcher, was the worst** and sank 74% of runs: a
  flat fast launch just means holing the hull on the first landing. It now gets a wider skip
  window and a tougher casing (`torpedoSkipAngleBonus`, `torpedoHardImpactBonus`).
- **Hull perks were invisible.** A mid-tier run essentially never sinks, so Bristle and Tock
  measured at ~1.00× and were strictly worse buys than the free starter. Both now also carry
  an air-drag component, and the rider prices were re-derived from the measured power ladder
  rather than from flavour.

Re-run it with `python3 Tools/sim.py`. It prints the core progression, then every rider, part,
launcher and daily modifier measured against a baseline, then the coin economy walkthrough.

