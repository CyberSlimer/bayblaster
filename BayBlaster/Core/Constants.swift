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

    // MARK: - World spawning (WorldSpawner)
    static let spawnStartX: CGFloat = 450             // no objects before this (clear launch zone)
    static let spawnAheadDistance: CGFloat = 6000     // keep objects generated this far ahead of the boat
    static let despawnBehindDistance: CGFloat = 1500  // remove objects this far behind the boat
    static let spawnIntervalMeters: ClosedRange<CGFloat> = 55...110 // gap between objects (before density ramp)
    static let hazardFractionStart: CGFloat = 0.32    // share of spawns that are hazards at 0 m…
    static let hazardFractionAt5000m: CGFloat = 0.50  // …ramping linearly to this at 5,000 m
    static let densityRampMeters: CGFloat = 4000      // object density rises over this distance…
    static let densityRampMax: CGFloat = 0.6          // …to (1 + this) × base density

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

    // MARK: - Presentation
    static let dayNightMeters: CGFloat = 3000         // sky is fully night after this distance
    static let resultsCountUpDuration: TimeInterval = 1.4
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
        case .launcher: return "Bigger bang from the lighthouse cannon."
        case .hull:     return "Tougher hull, slicker skips."
        case .rockets:  return "Tap in the air for a burst of speed."
        case .aero:     return "Marlow tucks his fins. Less air drag."
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

/// Snapshot of what the current upgrade tiers mean in physics terms. Built once per run.
struct UpgradeConfig {
    let launchSpeed: CGFloat
    let maxHull: CGFloat
    let skipHorizontalRetention: CGFloat
    let hardImpactThreshold: CGFloat
    let rocketCount: Int
    let rocketStrength: CGFloat
    let airDrag: CGFloat
    let boostWeightMultiplier: CGFloat

    init(save: SaveData) {
        func tier(_ k: UpgradeKind) -> Int { min(max(save.tier(of: k), 0), Tuning.upgradeMaxTier) }
        launchSpeed = Tuning.launchSpeedByTier[tier(.launcher)]
        maxHull = Tuning.hullMaxByTier[tier(.hull)]
        skipHorizontalRetention = Tuning.skipRetentionByTier[tier(.hull)]
        hardImpactThreshold = Tuning.hardImpactThresholdByTier[tier(.hull)]
        rocketCount = Tuning.rocketCountByTier[tier(.rockets)]
        rocketStrength = Tuning.rocketStrengthByTier[tier(.rockets)]
        airDrag = Tuning.airDragByTier[tier(.aero)]
        boostWeightMultiplier = Tuning.luckyLureByTier[tier(.lure)]
    }
}

// MARK: - Small math helpers used across the game

@inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
@inline(__always) func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }
/// Frame-rate independent easing factor: fraction of the remaining gap to close this frame.
@inline(__always) func easeFactor(_ rate: CGFloat, _ dt: CGFloat) -> CGFloat { 1 - exp(-rate * dt) }
