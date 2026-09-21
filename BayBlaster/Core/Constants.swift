import CoreGraphics
import Foundation

// =====================================================================================
//  Constants.swift — every tunable number in Bay Blaster lives here.
//
//  UNITS: the world is measured in SpriteKit points. 1 metre (the distance the HUD
//  shows) = `pointsPerMeter` points. Speeds are points/second, accelerations points/s².
//  Gravity is integrated by hand in Player.update (physicsWorld.gravity stays zero) so
//  these numbers are exact and independent of SpriteKit's 150-points-per-metre rule.
//
//  PACING (from the simulation in sim.py, median of 300 runs, average player):
//     fresh boat            ≈ 280–320 m      run 10 (L3 H3 R3 A2 U1) ≈ 1,650 m
//     L1 H1 R1              ≈ 640 m          fully upgraded          ≈ 6,500 m
//
//  HOW TO ADD A NEW BOOST / HAZARD
//  1. Add a case to `EntityKind` in Gameplay/Entities.swift and fill in its `spec`
//     (weight, height band, radius, isHazard, isZone, artKey).
//  2. Add a placeholder drawing in `Placeholders` (Core/Art.swift) under that artKey.
//     Drop a PNG named artKey into Assets.xcassets later and it replaces the drawing.
//  3. Add its effect in `WorldEntity.apply(to:in:)` (Entities.swift). Zones (things the
//     boat flies *through*) bump a counter on Player; one-shots edit velocity/hull.
//  4. Put its numbers below under "Entity effects". That's it — the spawner reads the
//     weight table automatically.
// =====================================================================================

enum Tuning {

    // MARK: - World scale
    static let pointsPerMeter: CGFloat = 10
    static let waterY: CGFloat = 0                 // world y of the water line
    static let launchX: CGFloat = 0                // distance is measured from here
    static let maxDeltaTime: CGFloat = 1.0 / 30    // clamp dt after hitches so physics never explodes

    // MARK: - Flight physics
    static let gravity: CGFloat = -400             // pt/s² (negative = down)
    static let diveGravityMultiplier: CGFloat = 1.6   // touch-and-hold "nose dive"

    // MARK: - Water skipping (WaterSkipSystem)
    static let skipMinVerticalSpeed: CGFloat = 90     // must be falling faster than this to skip
    static let skipMinHorizontalSpeed: CGFloat = 90   // …and moving forward faster than this
    static let skipMaxAngleDegrees: CGFloat = 42      // impact angle (below horizontal) allowed for a skip
    static let diveSkipMaxAngleDegrees: CGFloat = 64  // wider window while nose-diving
    static let skipVerticalRestitution: CGFloat = 0.62   // bounce keeps this much vertical speed (~60%)
    static let diveSkipRestitutionBonus: CGFloat = 1.22  // multiplied in while diving → higher, farther skip
    // Horizontal retention per skip comes from the hull tier table below (~90%).
    static let plowDrag: CGFloat = 1.8                // per-second exponential drag while "plowing"
    static let plowOffsetY: CGFloat = 2               // boat sits this far above water while plowing
    static let runEndSpeed: CGFloat = 45              // plowing slower than this ends the run
    static let hardImpactDamagePer100: CGFloat = 6    // hull damage per 100 pt/s over the hull's threshold
    static let hardImpactShake: CGFloat = 14          // camera shake (points) on a hard impact
    static let skipComboCoinStep = 3                  // coins awarded per skip = step × current combo length
    static let perfectSkipAngleDegrees: CGFloat = 22  // impact angle under this is a PERFECT skip. Each skip flattens the next landing, so a flat launch earns these mid-combo; diving (steeper) trades them for a wider skip window.
    static let perfectSkipSpeedBonus: CGFloat = 1.04  // horizontal speed multiplier on a perfect skip (on top of retention)
    static let perfectSkipCoins = 15
    static let forcedSkipMinBounce: CGFloat = 260  // floor on the bounce when an ability forces a skip off a flat landing

    // MARK: - Launcher (aim phase)
    static let launchAngleMinDegrees: CGFloat = 15
    static let launchAngleMaxDegrees: CGFloat = 75
    static let angleSweepPeriod: CGFloat = 2.4        // seconds for a full min→max→min sweep
    static let powerSweepPeriod: CGFloat = 1.4        // seconds for a full 0→1→0 sweep
    static let minPowerFraction: CGFloat = 0.45       // worst possible power lock still launches at 45%
    static let launchHeight: CGFloat = 60             // muzzle height above the water line
    static let launcherPivotX: CGFloat = -70          // cannon pivot x (boat starts at the muzzle)
    static let launcherBarrelLength: CGFloat = 78

    // MARK: - Rockets
    static let rocketVerticalFraction: CGFloat = 0.18 // part of rocket strength applied upward
    static let rocketBurstDuration: TimeInterval = 0.5

    // MARK: - Camera
    static let cameraVisibleHeight: CGFloat = 520     // world points visible top→bottom at zoom 1
    static let cameraWaterFraction: CGFloat = 0.22    // water line sits this far up the screen
    static let cameraTopMargin: CGFloat = 100         // zoom out so the boat stays this far below the top
    static let cameraLeadFactor: CGFloat = 0.20       // horizontal lead = vx * factor
    static let cameraMaxLead: CGFloat = 240
    static let cameraLeadEase: CGFloat = 3.0
    static let cameraZoomEase: CGFloat = 3.0          // higher = snappier
    static let cameraYEase: CGFloat = 4.0
    static let cameraSpeedZoomMax: CGFloat = 0.6      // extra zoom-out at very high speed
    static let cameraSpeedZoomRef: CGFloat = 2600     // speed that gives the max extra zoom
    static let cameraShakeDecay: CGFloat = 9.0
    static let cameraPunchEase: CGFloat = 2.6        // how fast a launch punch-zoom eases back to normal

    // MARK: - World spawning (WorldSpawner)
    static let spawnStartX: CGFloat = 450             // no objects before this (clear launch zone)
    static let spawnAheadDistance: CGFloat = 6000     // keep objects generated this far ahead of the boat
    static let despawnBehindDistance: CGFloat = 1500  // remove objects this far behind the boat
    static let spawnIntervalMeters: ClosedRange<CGFloat> = 55...110 // gap between objects (before density ramp)
    static let hazardFractionStart: CGFloat = 0.32    // share of spawns that are hazards at 0 m…
    static let hazardFractionAt5000m: CGFloat = 0.50  // …ramping linearly to this at 5,000 m
    static let densityRampMeters: CGFloat = 4000      // object density rises over this distance…
    static let densityRampMax: CGFloat = 0.6          // …to (1 + this) × base density
    static let hazardRepeatPenalty: CGFloat = 0.45    // hazard chance is multiplied by this right after a hazard (no unfair walls)
    static let coinArcChance: CGFloat = 0.22          // share of boost spawns that become a coin arc instead of a single item
    static let coinArcCount: ClosedRange<Int> = 6...9 // coins per arc
    static let coinArcSpacing: CGFloat = 46           // horizontal gap between coins in an arc (points)
    static let coinArcHeightRange: ClosedRange<CGFloat> = 80...420 // arc peak height above the water
    static let coinArcRise: CGFloat = 90              // how much the arc curves (0 = flat line)

    // MARK: - The high air
    // Everything above `highAirStartHeight` used to be empty: the low spawn bands stop at 900
    // points, so a big launch flew through nothing at all. The spawner now runs a second,
    // independent track up here (see WorldSpawner), and the sky itself reacts to altitude.
    static let highAirStartHeight: CGFloat = 900      // points above the water where the high air begins
    static let highAirTopHeight: CGFloat = 3000       // …and where it thins out again
    static let highSpawnStartMeters: CGFloat = 60     // no high-air objects before this
    static let highSpawnIntervalMeters: ClosedRange<CGFloat> = 90...170
    static let altitudeHudHeight: CGFloat = 300       // the altitude readout appears above this
    static let skySpaceStartHeight: CGFloat = 1000    // sky starts darkening toward space here…
    static let skySpaceFullHeight: CGFloat = 3200     // …and is fully "up there" here
    static let highCloudAltitude: CGFloat = 1900      // the cirrus deck you climb through
    static let highCloudParallax: CGFloat = 0.12

    // MARK: - Barriers (breakable walls)
    // The Burrito Bison beat: a wall you either smash through because you are fast enough, or
    // bounce off because you are not. They get their own spawn track so the cadence is
    // predictable, and their toughness ramps with distance so the question stays live.
    static let barrierStartMeters: CGFloat = 120
    static let barrierIntervalMeters: ClosedRange<CGFloat> = 240...420
    static let barrierBlockSize: CGFloat = 64         // one brick; a wall is a stack of these
    static let barrierBlocks: ClosedRange<Int> = 4...12
    // One wall in four is a towering sky gate. Without these, a late-game launch simply flies
    // over every wall in the run and the whole mechanic stops existing at the top end.
    static let barrierTallGateChance: CGFloat = 0.25
    static let barrierTallBlocks: ClosedRange<Int> = 14...26
    // Toughness is deliberately a GENTLE ramp with a low cap. Speed in this game tracks your
    // upgrade tier, not how far you have flown, and it decays across a run — a steep ramp just
    // put a wall you cannot break at the end of every run, whatever your build.
    static let barrierBaseToughness: CGFloat = 380    // speed needed to smash the earliest walls
    static let barrierToughnessPerMetre: CGFloat = 0.18
    static let barrierMaxToughness: CGFloat = 1400
    static let barrierStoneToughness: CGFloat = 700   // visual tier thresholds (plank → stone → iron)
    static let barrierIronToughness: CGFloat = 1050
    static let barrierSmashSpeedKeep: CGFloat = 0.94  // smashing through costs a little speed…
    static let barrierSmashCoinsPerBlock = 9          // …and pays per brick, so a tall gate is a real payday
    static let barrierBounceSpeedMultiplier: CGFloat = 0.18  // failing to smash nearly stops you
    static let barrierBounceBack: CGFloat = 46        // …and shoves you clear so you don't re-hit it
    static let barrierDamage: CGFloat = 12

    // MARK: - Entity effects
    static let buoyBounceSpeed: CGFloat = 520         // upward speed added by a buoy
    static let buoyKeepFraction: CGFloat = 0.5        // fraction of incoming |vy| kept on the bounce
    static let whaleSpoutSpeed: CGFloat = 950         // vertical launch from a whale spout
    static let whaleSpoutForward: CGFloat = 80
    static let motorPush: CGFloat = 480               // outboard-motor pickup: horizontal burst
    static let birdLift: CGFloat = 380                // pt/s² upward while inside a seagull flock
    static let birdPush: CGFloat = 120                // pt/s² forward while inside a seagull flock
    static let coinBagValue = 40
    static let fuelCanValue = 25
    static let rockSpeedMultiplier: CGFloat = 0.6
    static let rockDamage: CGFloat = 25
    static let netSpeedMultiplier: CGFloat = 0.45
    static let netVerticalMultiplier: CGFloat = 0.5
    static let sharkSpeedMultiplier: CGFloat = 0.75
    static let sharkKnockUp: CGFloat = 200
    static let sharkDamage: CGFloat = 20
    static let stormCloudPush: CGFloat = 700          // pt/s² downward inside a storm cloud
    static let coinValue = 5                          // one small coin in a coin arc
    static let mineDamage: CGFloat = 35               // sea mine: big hull hit…
    static let mineKnockUp: CGFloat = 650             // …but the blast throws the boat back into the air (risk/reward)
    static let mineSpeedMultiplier: CGFloat = 0.8
    static let jellyfishDamage: CGFloat = 10
    static let jellyfishVerticalMultiplier: CGFloat = 0.5
    static let jellyfishStunSeconds: CGFloat = 1.5    // no rockets / no dive while stung
    static let whirlpoolPull: CGFloat = 900           // pt/s² downward while over a whirlpool
    static let whirlpoolDrag: CGFloat = 0.35          // extra per-second horizontal drag while over a whirlpool
    static let dolphinBounceUp: CGFloat = 700         // dolphin ride: moderate up…
    static let dolphinPushForward: CGFloat = 260      // …and a solid forward shove, keeps all horizontal speed
    static let balloonFloatSeconds: CGFloat = 2.2     // popping balloons cuts gravity for this long
    static let balloonGravityMultiplier: CGFloat = 0.3
    static let balloonLift: CGFloat = 220             // instant upward kick when the balloons pop
    static let crateCoins = 30                        // floating supply crate: always breakable, teaches the smash
    static let crateSpeedKeep: CGFloat = 0.97
    static let blimpBounceSpeed: CGFloat = 760        // high-air trampoline
    static let blimpKeepFraction: CGFloat = 0.35
    static let blimpForward: CGFloat = 120
    static let boostRingSpeed: CGFloat = 420          // fly through the hoop for a shove…
    static let boostRingCoins = 20                    // …and a payout, for flying precisely
    static let jetStreamPush: CGFloat = 900           // pt/s² forward inside the jet stream
    static let jetStreamLift: CGFloat = 90            // …and a gentle updraft that keeps you in it

    // MARK: - Economy
    static let coinsPerMeter = 1
    static let upgradePriceGrowth: Double = 2.2       // each tier costs this × the previous
    static let upgradeMaxTier = 5                     // tiers 1…5 purchasable; tier 0 = stock

    // MARK: - Upgrade tables (index = current tier, 0 = stock)
    static let launchSpeedByTier: [CGFloat]          = [1250, 1450, 1680, 1950, 2250, 2600]
    static let hullMaxByTier: [CGFloat]              = [100, 130, 160, 200, 250, 300]
    static let skipRetentionByTier: [CGFloat]        = [0.88, 0.895, 0.91, 0.925, 0.94, 0.95]
    static let hardImpactThresholdByTier: [CGFloat]  = [1400, 1550, 1700, 1900, 2100, 2300]
    static let rocketCountByTier: [Int]              = [0, 1, 2, 3, 3, 3]
    static let rocketStrengthByTier: [CGFloat]       = [0, 420, 420, 420, 600, 800]
    static let airDragByTier: [CGFloat]              = [0.12, 0.10, 0.085, 0.07, 0.055, 0.04] // per second
    static let luckyLureByTier: [CGFloat]            = [1.0, 1.25, 1.5, 1.8, 2.1, 2.5]       // boost-weight multiplier
    static let basePrices: [UpgradeKind: Int]        = [.launcher: 260, .hull: 200, .rockets: 320, .aero: 360, .lure: 220]

    // MARK: - Crew perks (Core/Crew.swift)
    // Marlow is deliberately the only rider with no distance perk, so the pacing table in
    // sim.py still describes a stock run. Everyone else trades something for something.
    static let crewMarlowCooldownMultiplier: CGFloat = 0.8    // Marlow: abilities come back sooner
    static let crewBristleHullMultiplier: CGFloat = 1.35      // Bristle the pufferfish
    static let crewBristleRetentionBonus: CGFloat = 0.012     // …and a rounder hull skips a little better
    static let crewBristleDragMultiplier: CGFloat = 0.88      // …and pushes a little less air. Hull alone measured at ~1.0x: a mid-tier run almost never sinks, so pure forgiveness is invisible in the pacing table.
    static let crewNixieDragMultiplier: CGFloat = 0.68        // Nixie the flying fish
    static let crewGillyBonusRockets = 1                      // Gilly the squid
    static let crewBrunoRetentionBonus: CGFloat = 0.045       // Bruno the otter, added to the hull tier
    static let crewBrunoDragMultiplier: CGFloat = 0.88        // …retention alone was only worth ~3%; drag is what actually carries a run
    static let crewTockDamageMultiplier: CGFloat = 0.50       // Tock the hermit crab
    static let crewTockHullMultiplier: CGFloat = 1.25         // …plus a thicker shell…
    static let crewTockDragMultiplier: CGFloat = 0.80         // …and a low, streamlined profile, so the perk pays on a clean run too
    static let crewPipCoinMultiplier: CGFloat = 1.7           // Pip the seagull
    static let crewChumDragMultiplier: CGFloat = 0.80         // Chum the baby shark: slippery…
    static let crewChumLaunchMultiplier: CGFloat = 1.20       // …fast…
    static let crewChumHullMultiplier: CGFloat = 0.85         // …and fragile
    // Ordered by the measured power ladder in HANDOFF.md, not by flavour — Pip sits early
    // because buying the coin rider speeds up everything after it.
    //
    // The absolute numbers come from the coins-per-run figures sim.py prints: the five shop
    // tracks max out in ~15 runs, and the locker is deliberately the long tail *after* that,
    // so nothing here should be affordable in one or two runs at the tier you first want it.
    static let crewPrices: [CrewMember: Int] = [
        .marlow: 0, .bristle: 2_500, .bruno: 5_500, .pip: 8_000,
        .tock: 11_000, .chum: 17_000, .gilly: 24_000, .nixie: 32_000
    ]

    // MARK: - Abilities (the third in-flight verb; HUD button)
    static let abilityMinCooldown: CGFloat = 2.0              // floor, however much a perk shortens it
    static let abilityFrenzyCoinMultiplier: CGFloat = 2.0

    static let abilityTuckSeconds: CGFloat = 1.2
    static let abilityTuckCooldown: CGFloat = 7
    static let abilityTuckDragMultiplier: CGFloat = 0.55      // air drag while tucked. Drag dominates distance, so this is deliberately mild — at 0.15 a single rider was worth 2x the whole run.
    static let abilityTuckPush: CGFloat = 100                 // pt/s² forward while tucked

    static let abilityPuffSeconds: CGFloat = 2.2
    static let abilityPuffCooldown: CGFloat = 7
    static let abilityPuffRestitutionMultiplier: CGFloat = 1.15

    static let abilityGlideSeconds: CGFloat = 1.6
    static let abilityGlideCooldown: CGFloat = 7
    static let abilityGlideGravityMultiplier: CGFloat = 0.55
    static let abilityGlidePush: CGFloat = 70                 // pt/s² forward while gliding

    static let abilityShellCooldown: CGFloat = 6
    static let abilityShellCharges = 2                        // hazards soaked up per use

    static let abilityInkJetCooldown: CGFloat = 5
    static let abilityInkJetForward: CGFloat = 150
    static let abilityInkJetUp: CGFloat = 40

    static let abilitySlamCooldown: CGFloat = 6
    static let abilitySlamDownSpeed: CGFloat = 900            // vertical speed the slam forces
    static let abilitySlamRestitutionMultiplier: CGFloat = 1.50 // …paid back on the landing it causes
    static let abilitySlamForwardBonus: CGFloat = 1.22        // …and the slam landing keeps extra horizontal speed, so it reads as a dive-bomb for distance rather than a pogo

    static let abilitySwoopCooldown: CGFloat = 5
    static let abilitySwoopRange: CGFloat = 900               // how far ahead it looks for a pickup
    static let abilitySwoopMinTargetY: CGFloat = -200         // ignore pickups more than this far below: diving for one costs more speed than it pays
    static let abilitySwoopSpeedKeep: CGFloat = 1.08          // speed kept when the flight is redirected (slightly over 1: the snap itself is the reward)

    static let abilityFrenzySeconds: CGFloat = 4.0
    static let abilityFrenzyCooldown: CGFloat = 10

    // MARK: - Gear (Core/Gear.swift)
    static let gearWheelsPlowDragMultiplier: CGFloat = 0.35   // Beach Wheels: you roll on after splashdown
    static let gearPontoonsSkipAngleBonus: CGFloat = 14       // Pontoons: degrees added to the skip window
    static let gearPontoonsDragMultiplier: CGFloat = 1.06     // …at the cost of air drag
    static let gearSpringKeelRestitutionMultiplier: CGFloat = 1.26
    static let gearStormSailPush: CGFloat = 32                // pt/s² forward while airborne. Higher than this and you arrive at the water fast enough to hole the hull on nearly every run.
    static let gearBoxKiteGravityMultiplier: CGFloat = 0.84
    static let gearJetVentRocketMultiplier: CGFloat = 1.15
    static let gearJetVentBonusRockets = 1
    static let gearCoinMagnetRadius: CGFloat = 600            // points; coins inside this home in
    static let gearMagnetPullSpeed: CGFloat = 900             // pt/s a magnetised coin travels
    static let gearHorseshoeBoostMultiplier: CGFloat = 2.0
    static let gearHorseshoeCoinArcBonus: CGFloat = 0.28      // added to coinArcChance
    static let gearBarnacleLaunchMultiplier: CGFloat = 0.96
    static let gearBarnacleDamageMultiplier: CGFloat = 0.5
    // Priced on measured value per coin, not on flavour. The first cut had the Storm Sail at
    // 6,000 for a 1.27x run and the Lucky Horseshoe at 13,000 for a 1.03x one — the cheapest
    // part in the game was the second strongest, and the most expensive trinket was a trap.
    // Barnacle Plating measures at ~1.0x because a mid-tier run never sinks; it is priced for
    // what it does at max tier, where the fastest builds drown themselves.
    static let gearPrices: [GearItem: Int] = [
        .wheels: 3_000, .pontoons: 4_500, .springKeel: 5_000,
        .stormSail: 16_000, .boxKite: 5_500, .jetVent: 20_000,
        .coinMagnet: 3_500, .luckyHorseshoe: 5_000, .barnaclePlate: 5_000
    ]

    // MARK: - Launchers (Core/Launchers.swift)
    // The cannon reuses the Launcher block above; these are the three unlockables.
    // Surf Rod & Reel — narrower, faster angle sweep, then a cast bar with a sweet zone.
    static let rodAngleMinDegrees: CGFloat = 25
    static let rodAngleMaxDegrees: CGFloat = 65
    static let rodAngleSweepPeriod: CGFloat = 1.8
    static let rodCastPeriod: CGFloat = 0.9                   // the cast bar sweeps fast
    static let rodMinPowerFraction: CGFloat = 0.40
    static let rodSpeedMultiplier: CGFloat = 0.95             // below the cannon *unless* you hit the band
    static let rodMuzzleHeight: CGFloat = 74
    static let rodBarrelLength: CGFloat = 92
    static let rodSweetSpot: CGFloat = 0.82                   // centre of the green band, in power units
    static let rodSweetSpotHalfWidth: CGFloat = 0.11
    static let rodSweetSpotBonus: CGFloat = 1.28              // speed multiplier for a banded cast

    // Tidal Slingshot — hold to draw. Hold past full and the band snaps.
    static let slingAngleMinDegrees: CGFloat = 20
    static let slingAngleMaxDegrees: CGFloat = 70
    static let slingAngleSweepPeriod: CGFloat = 2.0
    static let slingDrawSeconds: CGFloat = 1.1                // 0 → full draw
    static let slingMinPowerFraction: CGFloat = 0.30
    static let slingSpeedMultiplier: CGFloat = 1.18
    static let slingMuzzleHeight: CGFloat = 52
    static let slingBarrelLength: CGFloat = 70
    static let slingOverchargeGrace: CGFloat = 0.35           // seconds at full draw before it snaps
    static let slingSnapPower: CGFloat = 0.30                 // what the power collapses to on a snap

    // Torpedo Tube — low, flat and very fast. You start the run already skipping.
    static let torpedoAngleMinDegrees: CGFloat = 6
    static let torpedoAngleMaxDegrees: CGFloat = 28
    static let torpedoAngleSweepPeriod: CGFloat = 1.6
    static let torpedoPowerPeriod: CGFloat = 1.1
    static let torpedoMinPowerFraction: CGFloat = 0.60
    static let torpedoSpeedMultiplier: CGFloat = 1.12
    static let torpedoMuzzleHeight: CGFloat = 34
    static let torpedoBarrelLength: CGFloat = 84
    static let torpedoSkipAngleBonus: CGFloat = 8             // it is shaped to skim, so the window is wider…
    static let torpedoHardImpactBonus: CGFloat = 600          // …and the casing takes a flat landing that would hole the dinghy
    // The big-ticket items: a new launcher changes how every run *starts*, so each one is
    // meant to be a goal you save toward for a while rather than an incidental purchase.
    static let launcherPrices: [LauncherKind: Int] = [
        .cannon: 0, .rodReel: 22_000, .slingshot: 40_000, .torpedo: 65_000
    ]

    // MARK: - Loadout ceilings
    // Crew and gear stack multiplicatively; these stop a fully-kitted build from reaching a
    // skip that loses no energy at all (which would make a run never end).
    static let skipRetentionCeiling: CGFloat = 0.985
    static let skipRestitutionCeiling: CGFloat = 0.90

    // MARK: - Prestige ("cast off")
    static let prestigeCoinBonusPerLevel: CGFloat = 0.25      // +25% coins per cast-off, forever

    // MARK: - Daily challenge
    static let dailyBaseReward = 250
    static let dailyCoinsPerMetre = 0.5
    static let dailyStreakBonus = 120                         // per day of streak…
    static let dailyStreakCap = 10                            // …up to this many days

    // MARK: - Achievements
    static let achievementRewards: [Achievement: Int] = [
        .firstSplash: 150, .fly500: 200, .fly1000: 400, .fly2500: 800, .fly5000: 1600,
        .skipper: 400, .comboKing: 600, .perfectionist: 600, .bigHaul: 500,
        .unscathed: 500, .daredevil: 700, .abilityAce: 500,
        .wrecker: 500, .demolition: 1200, .highFlyer: 400, .stratosphere: 1200,
        .trekker: 700, .voyager: 2000, .regular: 400, .veteran: 1800,
        .crewOfThree: 500, .fullCrew: 2500, .firstPart: 250, .fullGarage: 2500,
        .fullArsenal: 2500, .maxedOut: 2000, .castOff: 1500, .dailyDoer: 300, .weekStreak: 1500
    ]

    // MARK: - Missions
    static let missionLevelEvery = 3                  // difficulty level rises every N completed missions
    static let missionRewardByLevel = [100, 180, 300, 500, 800, 1200]
    static let missionDistanceStretch: Double = 1.1   // distance missions ask for at least best × this

    // MARK: - Milestones
    static let milestoneIntervalMeters: CGFloat = 250 // a flag every this many metres
    static let milestoneSpawnAhead: CGFloat = 5000    // place flags this far ahead of the boat (points)

    // MARK: - Presentation
    static let dayNightMeters: CGFloat = 3000         // sky is fully night after this distance
    static let launchFlashDuration: TimeInterval = 0.22   // white screen flash on firing
    static let launchShockwaveRadius: CGFloat = 300        // expanding ring at the muzzle
    static let launchCameraPunch: CGFloat = 0.84           // camera snaps to this zoom, then eases back out
    static let launchTumbleTurns: CGFloat = 1.5            // how many times the boat spins out of the barrel
    static let launchTumbleDuration: TimeInterval = 0.5
    static let launchShake: CGFloat = 16
    static let aimChargeGlowScale: CGFloat = 1.9           // barrel glow at full power during the aim sweep
    static let resultsCountUpDuration: TimeInterval = 1.4
    static let nearBestFraction: CGFloat = 0.2        // "only N m short of your best" shows within this fraction of best
    static let fontHeavy = "AvenirNext-Heavy"
    static let fontBold = "AvenirNext-Bold"
    static let fontMedium = "AvenirNext-DemiBold"
}

// MARK: - Upgrade definitions

enum UpgradeKind: String, CaseIterable, Codable {
    case launcher, hull, rockets, aero, lure

    var title: String {
        switch self {
        case .launcher: return "Launcher Power"
        case .hull:     return "Boat Hull"
        case .rockets:  return "Rockets"
        case .aero:     return "Fish Aerodynamics"
        case .lure:     return "Lucky Lure"
        }
    }

    var blurb: String {
        switch self {
        case .launcher: return "Bigger bang, whichever launcher you pick."
        case .hull:     return "Tougher hull, slicker skips."
        case .rockets:  return "Tap in the air for a burst of speed."
        case .aero:     return "Your rider tucks in. Less air drag."
        case .lure:     return "More boosts spawn along the bay."
        }
    }

    /// Price to buy `tier` (1…maxTier).
    func price(forTier tier: Int) -> Int {
        let base = Double(Tuning.basePrices[self] ?? 300)
        return Int((base * pow(Tuning.upgradePriceGrowth, Double(tier - 1))).rounded())
    }

    /// Human-readable effect of being at `tier`.
    func effectDescription(tier: Int) -> String {
        let t = min(max(tier, 0), Tuning.upgradeMaxTier)
        switch self {
        case .launcher: return "Launch speed \(Int(Tuning.launchSpeedByTier[t] / Tuning.pointsPerMeter)) m/s"
        case .hull:     return "Hull \(Int(Tuning.hullMaxByTier[t])) · skips keep \(Int(Tuning.skipRetentionByTier[t] * 100))%"
        case .rockets:
            let n = Tuning.rocketCountByTier[t]
            return n == 0 ? "No rockets" : "\(n) rocket\(n == 1 ? "" : "s") · +\(Int(Tuning.rocketStrengthByTier[t] / Tuning.pointsPerMeter)) m/s each"
        case .aero:     return "Air drag \(String(format: "%.0f", Tuning.airDragByTier[t] * 100))%"
        case .lure:     return "Boosts ×\(String(format: "%.2g", Tuning.luckyLureByTier[t]))"
        }
    }
}

/// `UpgradeConfig` — the resolved per-run numbers — now lives in Core/Loadout.swift, where
/// it folds these tables together with the selected rider, the equipped gear, the prestige
/// level and (on a daily run) the modifier of the day.

// MARK: - Small math helpers used across the game

@inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
@inline(__always) func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }
/// Frame-rate independent easing factor: fraction of the remaining gap to close this frame.
@inline(__always) func easeFactor(_ rate: CGFloat, _ dt: CGFloat) -> CGFloat { 1 - exp(-rate * dt) }
