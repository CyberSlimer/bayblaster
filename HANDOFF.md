# Handoff — resume on the Mac

## What exists

Complete v1 of the game as specified: title / aim / flight / results / shop, water-skip
physics, procedural spawning, camera, parallax day→night background, HUD with safe-area
layout, procedural audio, haptics, Codable save with corrupt-file recovery, placeholder
vector art with a one-drop PNG swap.

Added 2026-09-18 (Mac session): 16 entity kinds, coin arcs, skip combos + PERFECT skips,
milestone flags, progressive unlocks with first-touch tips, and 12 rotating missions. All
compiled and smoke-tested.

## Added 2026-09-19 — the "locker" update

Written on Linux with no Swift toolchain, then compiled and smoke-tested on the Mac the same
evening (Xcode 26.6). The only compile error in ~4,000 lines was one `Int`/`Double` mix in a
`Placeholders` drawing; zero warnings. See "Smoke test" below for what was verified.

The one thing it answers to the original brief: there was nothing to *collect*, and in the air
you only had two verbs. Now there are four unlock tracks and a third verb.

### 1. Riders (`Core/Crew.swift`) — 8, one selected at a time

Each brings a **passive perk** and an **in-flight ability** fired from a new HUD button
(bottom-right, fills as it cools down). Tap is still a rocket, hold is still a nose-dive.

| Rider | Price | Perk | Ability |
|---|---|---|---|
| Marlow the mackerel | free | ability cooldown −20% | **Tuck** — drag almost vanishes for 1.2 s |
| Bristle the pufferfish | 2,500 | hull +35%, drag −12% | **Puff up** — every landing skips while inflated |
| Bruno the sea otter | 5,500 | skips keep +4.5%, drag −12% | **Belly slam** — slam down; the landing becomes a huge skip |
| Pip the seagull | 8,000 | coins ×1.7 | **Swoop** — snap your flight at the next pickup |
| Tock the hermit crab | 11,000 | damage −50%, hull +25%, drag −20% | **Shell up** — soaks the next two hazards whole |
| Chum the baby shark | 17,000 | launch +20%, drag −20%, hull −15% | **Frenzy** — double coins, hazards stop slowing you |
| Gilly the squid | 24,000 | +1 rocket | **Ink jet** — a short forward jet on a short cooldown |
| Nixie the flying fish | 32,000 | drag −32% | **Glide** — wings out, barely any gravity |

### 2. Gear (`Core/Gear.swift`) — 9 parts, 3 slots, one part per slot

Bought once, then equipped/unequipped freely. Every part is a trade, and every part is
visible on the boat (`Player.addGearArt`).

- **Hull**: Beach Wheels 3,000 (roll on after splashdown), Pontoons 4,500 (+14° skip window,
  +6% drag), Spring Keel 11,000 (+26% bounce)
- **Rig**: Storm Sail 6,000 (constant push; squalls blow you along instead of down),
  Box Kite 9,000 (−16% gravity), Jet Vent 16,000 (+15% rockets and +1)
- **Trinket**: Coin Magnet 3,500 (60 m pull), Lucky Horseshoe 13,000 (boosts ×2, far more coin
  arcs), Barnacle Plating 7,000 (−50% damage, −4% launch)

### 3. Launchers (`Core/Launchers.swift`) — 4, each a different aim ritual

This is the "casting a lure" idea, kept additive: the cannon is now the first of four rather
than the only one, so nothing that already worked was thrown away.

| Launcher | Price | Ritual |
|---|---|---|
| Old Lighthouse Cannon | free | Two taps: lock the angle, lock the power |
| Surf Rod & Reel | 22,000 | Angle, then a fast **cast bar** — tap inside the green band for ×1.28 |
| Tidal Slingshot | 40,000 | Angle, then **hold to draw**; hold past full and the band snaps to 30% |
| Torpedo Tube | 65,000 | Two fast sweeps, 6–28° and low. Wider skip window and a tougher casing, so you start the run already skipping |

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

## Smoke test (Mac, 2026-09-19, iPhone 16 Pro Max + iPhone 16 Pro simulators)

All of the handoff checklist passed:

- **v1 save → v2 build**: installed `main`, played a run (178 m / 178 coins), installed this
  branch over it. Title showed the old best/coins/missions with Marlow + cannon selected;
  the file was rewritten as `version: 2` with every new key present.
- **Locker**: all four tabs draw on both phone sizes (two-row grids, ellipsised text). Bought
  Bristle and the Surf Rod & Reel; both survived a kill + relaunch and the title footer and
  launcher art followed.
- **Ability button**: PUFF fired mid-run — `stats.abilitiesUsed` and `seenAbilities` updated,
  and the coin maths on the results card reconciled to the coin (run + trophies + mission).
- **Launcher rituals**: rod cast band, slingshot hold-to-draw with the red overcharge zone,
  and the torpedo's low two-tap sweep all work. A forced-lock torpedo run went 1,209 m with a
  ×6 combo and 2 PERFECTs — the skip-chain identity the sim predicted reads on screen.
- **Trophies / missions**: `firstSplash`, `fly500`, `unscathed`, `fullArsenal`, `kilometre`
  paid out on the results card alongside a completed mission.

Fixed while testing: `SKLabelNode.shrinkToFit(width:)` (in `UIKitNodes.swift`) — `ButtonNode`
and locker card titles now step the font down until the text fits, which stops "LAUNCH AGAIN"
and "Old Lighthouse Cannon" spilling out of their boxes.

Testing gotcha: if another session (e.g. Krunkball) is iterating on the same simulator, its
installs keep stealing the foreground and taps land on the home screen. Boot a second device
(`xcrun simctl boot`) and pass `device:` on every simulator-tool call.

## What has NOT been done

1. **Play-test the new layers by hand.** The sim says the numbers are sane and the smoke test
   says everything fires, but nobody has yet judged feel:
   - Ability button placement/size (`HUD.abilityButtonCentre`, `HUD.abilityButtonRadius`).
   - The rod's green band and the slingshot's red danger zone (`HUD.setLauncherStyle`).
   - Whether the torpedo's low launch reads as exciting or as "I hit the water instantly".
   - (Fixed 2026-09-21: the title's SHOP / DAILY / LOCKER now share one row so nothing sits on
     the launcher or the boat, and the results card hides the ability button and flight hint
     and dims the world behind it. Checked on the 16 Pro and 16 Pro Max simulators.)
2. **Original v1 play-test items still open**: camera `cameraVisibleHeight`, aim sweep periods,
   `skipMaxAngleDegrees`, entity contact radii vs the baked textures, audio levels.
3. **TestFlight**: pipeline is done; still blocked only on creating the App Store Connect app
   record for `com.cyberslimer.bayblaster` (`docs/DEVICE_AND_TESTFLIGHT.md`).
4. **120 Hz check** on a ProMotion device.

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

## Pacing (sim, median of 300 runs, Marlow + cannon + no gear unless stated)

| Build | v1 | now | note |
|---|---|---|---|
| Fresh boat, clumsy | ~280 m | **348 m** | |
| Fresh boat, decent | 280–320 m | **429 m** | |
| L1 H1 R1 | ~640 m | **889 m** | |
| Mid-late (L3 H2 R2 A2 U1) | ~1,500 m | **2,014 m** | |
| Fully upgraded, decent | ~6,500 m | **8,558 m** | 5% of runs sink |
| Max + best distance build | — | **12,174 m** | Chum + wheels/kite/horseshoe + torpedo, skilled |
| Max + coin build + prestige 3 | — | 6,694 m / **20,282 coins** | Pip + keel/vent/magnet + rod & reel |

**The whole curve moved up about a third, and that is the abilities.** The shape is unchanged
and the shop prices are untouched — the greedy-buyer walkthrough still maxes all five tracks in
15 runs, exactly as it did in v1 — but every rider now has a third verb worth 1.05–1.36×, so a
run goes further at every tier. If play-testing says the early game got too easy, the cheapest
dial is `Tuning.abilityTuckCooldown` (Marlow is the only rider a new player has), then the
per-ability duration/cooldown pairs; do **not** reach for the launch-speed tables, which is
what the whole upgrade curve is built on.

### Launcher character (mid-late, skill 0.6 → 0.9)

| Launcher | 0.6 | 0.9 | Identity |
|---|---|---|---|
| Cannon | 2,058 | 2,417 | The honest baseline |
| Rod & Reel | 1,824 | 2,673 | Skill-gated: worse than the cannon until you hit the band |
| Slingshot | 1,974 | 2,615 | Skill-gated: worse until you stop letting the band snap |
| Torpedo Tube | 2,656 | 2,927 | ~4.5 PERFECT skips a run vs the cannon's 0.7 — it is the skip-chain launcher |

That the two mid launchers *lose* to the cannon at low skill and beat it at high skill is
deliberate, and it is the main thing to confirm by hand: a player has to be able to feel the
band and the draw, or those two are just worse.

### Locker economy

The five shop tracks max out in 15 runs; the locker is the long tail after that. Every unlock
costs 3–10 runs of saving at the tier you first want it, ~300,000 coins for all nineteen —
before missions, trophies and the daily, which the simulation does not count. Prestige's
+25%/level coin multiplier is what makes a second pass quick.

## Suggested next prompt

> Install BayBlaster on my iPhone with `Tools/ship.sh device` so I can feel out the ability
> button, the cast band and the slingshot draw; then walk me through creating the App Store
> Connect record so `Tools/ship.sh testflight` goes through.
