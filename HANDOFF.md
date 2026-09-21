# Handoff — resume on the Mac

## ▶ START HERE — next session, on a Mac with Xcode

Two jobs, in order. Everything below this section is background; you do not need it unless
something breaks.

### Job 1 — make it compile

```bash
git checkout claude/game-expansion-unlockables-wlcezz
git pull
xcodebuild -project BayBlaster.xcodeproj -scheme BayBlaster \
  -destination 'generic/platform=iOS Simulator' build 2>&1 \
  | tee /tmp/bb-build.log | grep -E "(error|warning):" | sort -u
```

The branch carries the **"smash" update** — roughly 1,000 lines written on Linux with no Swift
toolchain, which no compiler has seen. The locker update underneath it already built clean.

Fix whatever comes back, then rebuild until there are **zero errors and zero warnings** — this
project has held zero warnings since the first build and that is worth keeping.

Where the unseen code lives, in rough order of risk:

| File | What is new |
|---|---|
| `Gameplay/Entities.swift` | `.barrier` — the only kind with a *rectangular* body; brick stacking in `init`, smash/reject logic in `apply` |
| `Gameplay/WorldSpawner.swift` | three spawn tracks (low / high-air / barrier) and a `pick` that takes a weight selector |
| `Gameplay/Background.swift` | `update` gained an `altitude:` parameter (defaulted, so old call sites still compile) |
| `Gameplay/Launcher.swift` | charge glow, muzzle smoke, shockwave |
| `Gameplay/Player.swift` | `tumble(turns:seconds:)` and `jetStreamZones` |
| `Scenes/GameScene.swift` | launch sequence, `debris`, `flash`, four new `JuiceKind` cases |
| `Core/Art.swift` | 8 new placeholder drawings |

Two known error shapes, both already swept for — mentioned so you recognise them:

- **`Int`/`Double` mixing.** The locker branch's single compile error was
  `CGFloat(5.5 + i * 3)`. The correct spelling is `CGFloat(i * 3) + 5.5`. I found none of
  that shape in the new code, but the placeholder drawings are full of loop-index arithmetic.
- **"unable to type-check this expression in reasonable time."** Deeply nested `SKAction`
  literals cause this. I hoisted the two worst into named locals; if a third turns up, do the
  same rather than trying to simplify the expression in place.

Then sanity-check in the Simulator: a wall should read as breakable *before* you reach it,
a sky gate should feel fair rather than cheap, and the launch whiteout should not be painful.

### Job 2 — TestFlight

**Blocked on a browser step that has never been done.** `xcodebuild` can upload but cannot
create the App Store Connect record, and an earlier attempt failed with `missingApp` for
exactly this reason. Whoever owns the Apple ID must, once:

1. Register the bundle id — https://developer.apple.com/account/resources/identifiers/list
   → **+** → App IDs → App → Description `Bay Blaster`, Bundle ID **Explicit**
   `com.cyberslimer.bayblaster`. No capabilities.
2. Create the app — https://appstoreconnect.apple.com/apps → **+ New App** → iOS,
   name **Bay Blaster**, English (U.S.), that bundle id, SKU `bayblaster`, Full Access.

Then, only once Job 1 is clean:

```bash
Tools/ship.sh testflight
```

Archives Release, exports via `ExportOptions.plist` (build number auto-increments), uploads.
It appears under TestFlight after 5–15 minutes of processing; add yourself to an internal
group for install without review. Export compliance: the app uses no encryption, answer
**No** — or add `ITSAppUsesNonExemptEncryption = NO` to `Info.plist` to stop being asked.

Failure modes are listed at the bottom of `docs/DEVICE_AND_TESTFLIGHT.md`.

### Do not

- Re-tune balance. It was measured with `Tools/sim.py`, the numbers are in the pacing table
  below, and changing a `Tuning` constant without re-running the sim makes that table a lie.
- Hand-edit the `.pbxproj` file list. The target uses a synchronized folder group; new files
  under `BayBlaster/` join automatically.

---


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
  +6% drag), Spring Keel 5,000 (+26% bounce)
- **Rig**: Storm Sail 16,000 (constant push; squalls blow you along instead of down),
  Box Kite 5,500 (−16% gravity), Jet Vent 20,000 (+15% rockets and +1)
- **Trinket**: Coin Magnet 3,500 (60 m pull), Lucky Horseshoe 5,000 (boosts ×2, far more coin
  arcs), Barnacle Plating 5,000 (−50% damage, −4% launch)

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

## Added 2026-09-21 — the "smash" update (⚠️ NOT YET COMPILED)

Written on Linux again, on top of the compiled locker branch. Three pieces of play-test
feedback: the launch felt flat, the sky was empty once you got up there, and there was nothing
to interact with mid-flight.

### Breakable walls (`.barrier`)

The Burrito Bison beat. A wall is a stack of `Tuning.barrierBlockSize` bricks standing on the
water with a **rectangular** body — the only kind that isn't a circle — and a `toughness`.
Fast enough and it explodes for coins per brick, keeping 94% of your speed; too slow and it
stops you where you stand. Tock's shell counts as fast enough, which is finally a reason to
hold it. Plank → stone → iron reads the toughness from across the bay. Floating supply crates
(`.crate`) always break, so the mechanic teaches itself before the first real wall.

Barriers are neither boost nor hazard: they sit on their own spawn track and do not count
toward `hazardsHit` or the "untouched" mission.

### The high air

The low spawn bands stop at 900 points, so any launch that cleared them flew through nothing.
`WorldSpawner` now runs **three** independent tracks — low, high-air and barrier — and
`EntityKind.Spec` gained a `highAirWeight` so a kind can appear in both pools at different
rates. New up there: `.blimp` (a trampoline), `.boostRing` (fly clean through for a shove and
a payout) and `.jetStream` (a zone that carries you).

`Background` now answers to **altitude** as well as distance: the sky blends toward space, the
stars and moon come out however early in the day it is, the low cloud deck thins out beneath
you and a cirrus deck appears above. New altitude readout on the HUD.

### Launch

Anticipation and a harder recoil on the barrel, a charge glow that swells with the power you
are winding up, trajectory dots that flow along the arc; on firing, a whiteout, a shockwave
ring, powder smoke, a camera punch-zoom that eases back out as the boat climbs away, and a
tumble out of the barrel. **The tumble lives in `Player`**, because `Player.update` owns
`visual.zRotation` every frame — an action running alongside it would have fought it.

### What the simulator caught this round

- **Wall toughness cannot scale steeply with distance.** The first cut did, which parked an
  unbreakable wall at the end of every run whatever the build: speed in this game tracks your
  upgrade *tier*, not how far you have flown, and it decays across a run. Measuring
  speed-vs-distance per tier is what showed it. Gentle ramp, low cap.
- **Walls were being flown over** — only 4–8% were ever hit. They are taller now, and one in
  four is a sky gate tall enough to catch a big launch: 22–53% depending on tier.
- **Smashing at 86% speed cost a max-tier run a third of its distance** over the four or five
  walls it broke. 94% puts the curve back.
- A wall you fail to break used to re-hit you every time you crept back into it while grinding
  to a halt — three or four lots of damage and "TOO SLOW!". It now spends its rejection once.

### Also in this pass

Two new mission kinds (`smashed`, `altitude`) and four new trophies (Wrecker, Demolition Crew,
High Flyer, Stratospheric). 21 entity kinds, 16 mission kinds, 29 trophies.

`ButtonNode` now re-fits its label whenever `text` is set, not only at init — several buttons
are built with placeholder text and given their real, longer string later ("CAST OFF (max all
first)", "BUY 12345"), so the `shrinkToFit` added on the Mac was never reaching them. Resetting
to a stored base size first matters: `shrinkToFit` only ever reduces, so re-fitting without a
reset ratchets the font down every refresh.

## What has NOT been done

1. **Compile the smash update.** The locker branch built with one error in ~4,000 lines; this
   pass adds ~1,000 more that no compiler has seen. It has been script-checked the same way
   (every `Tuning.` member resolves, every art key has a drawing, every `switch` over
   `EntityKind` is exhaustive, braces balance) and audited specifically for the `Int`/`Double`
   mix that was the locker branch's one error — there are none of that shape. Highest-risk
   spots: the rectangular physics body and brick stacking in `WorldEntity.init`, the three
   spawn tracks in `WorldSpawner.update`, and `Background.update`'s new `altitude` parameter.
2. **Feel-check the new mechanics.** Does a wall read as smashable *before* you reach it? Is
   the plank/stone/iron tier legible at speed? Does a sky gate feel fair or cheap? Is the
   launch whiteout too strong?
3. **Play-test the locker layers by hand.** The sim says the numbers are sane and the smoke
   test says everything fires, but nobody has yet judged feel:
   - Ability button placement/size (`HUD.abilityButtonCentre`, `HUD.abilityButtonRadius`).
   - The rod's green band and the slingshot's red danger zone (`HUD.setLauncherStyle`).
   - Whether the torpedo's low launch reads as exciting or as "I hit the water instantly".
   - Cosmetic: the results card sits over the PUFF button and the milestone flag, and on the
     title screen the DAILY button covers part of the launcher art.
4. **Original v1 play-test items still open**: camera `cameraVisibleHeight`, aim sweep periods,
   `skipMaxAngleDegrees`, entity contact radii vs the baked textures, audio levels.
5. **TestFlight**: pipeline is done; still blocked only on creating the App Store Connect app
   record for `com.cyberslimer.bayblaster` (`docs/DEVICE_AND_TESTFLIGHT.md`).
6. **120 Hz check** on a ProMotion device.

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

| Build | v1 | after the locker | now | note |
|---|---|---|---|---|
| Fresh boat, clumsy | ~280 m | 348 m | **328 m** | |
| Fresh boat, decent | 280–320 m | 429 m | **429 m** | |
| L1 H1 R1 | ~640 m | 889 m | **810 m** | |
| Mid-late (L3 H2 R2 A2 U1) | ~1,500 m | 2,014 m | **1,836 m** | |
| Fully upgraded, decent | ~6,500 m | 8,558 m | **6,849 m** | 1% of runs sink |
| Max + best distance build | — | 12,174 m | **8,843 m** | skilled, 28.8 walls met, 8.6 smashed |
| Max + coin build + prestige 3 | — | 20,282 coins | **37,440 coins** | 11,737 m — but **69% of runs sink** |

Walls cost the curve 10–20%, which is the point of them. The endgame came back down to about
where v1 sat, and the run is busier: a mid-late run now meets 5.6 walls and smashes 2.

**The one number to look at by hand:** the max-tier coin build (Pip + Spring Keel / Jet Vent /
Coin Magnet + Rod & Reel, prestige 3) sinks 69% of the time and its spread is enormous
(p10 3,686 m, p90 25,239 m). That is a glass cannon with no hull gear doing 3,500+ into the
water, and Barnacle Plating / Bristle / Tock are the answer — so it is arguably working as
designed. It still wants a human eye on whether losing two runs in three feels like a build
choice or like a bug.

### Launcher character (mid-late, skill 0.6 → 0.9)

| Launcher | 0.6 | 0.9 | Identity |
|---|---|---|---|
| Cannon | 1,783 | 2,053 | The honest baseline |
| Rod & Reel | 1,829 | 2,331 | Skill-gated: +3% at low skill, +14% once you hit the band |
| Slingshot | 1,809 | 2,425 | Skill-gated: +1% at low skill, +18% once you stop letting it snap |
| Torpedo Tube | 1,955 | 2,091 | 6.1 skips and 3.8 PERFECTs a run vs the cannon's 3.2 and 0.3 — and it smashes 5 of the 6 walls it meets, because it flies at wall height |

The torpedo turning into the wall-smashing launcher was not designed, it fell out of the
geometry: it launches flat and low, which is exactly where the walls are.

### Riders and gear (mid-late)

Riders span 1,787–2,196 m; Pip trades distance for 3,718 coins against a 2,152 baseline. Gear
spans 1,800–2,430 m, and the prices were re-derived from measured value per coin after this
run: the Storm Sail was the second-strongest part in the game at the cheapest price, and the
Lucky Horseshoe was the most expensive trinket for a 1.03× run.

### Locker economy

The five shop tracks max out in 15 runs; the locker is the long tail after that. Every unlock
costs 3–10 runs of saving at the tier you first want it, ~290,000 coins for all nineteen —
before missions, trophies and the daily, which the simulation does not count. Prestige's
+25%/level coin multiplier is what makes a second pass quick.

## Suggested next prompt

> Build BayBlaster for the Simulator and fix the compile errors — the smash update was
> written without a Swift toolchain. Then check a wall reads as breakable before you reach it,
> that a sky gate feels fair, and that the launch whiteout isn't too much. Then install it on
> my iPhone with `Tools/ship.sh device`.
