import CoreGraphics
import Foundation

// =====================================================================================
//  Launchers.swift — what fires you out over the bay.
//
//  The Old Lighthouse Cannon is now the FIRST of four launchers rather than the only one.
//  Each has its own aim ritual, so unlocking one changes how the first three seconds of a
//  run are played — not just how far you go:
//
//    cannon     two sweeps (angle, then power)       — the original, forgiving
//    rodReel    angle sweep, then a CAST timing bar  — nail the sweet spot for a big bonus
//    slingshot  angle sweep, then HOLD to draw back  — hold too long and the band snaps
//    torpedo    two fast sweeps, low and flat        — starts you near the water, all skips
//
//  `Launcher` (Gameplay/Launcher.swift) reads the spec and drives the matching aim mode;
//  `HUD` reads it to show the right widget.
//
//  HOW TO ADD A LAUNCHER
//  1. Add a case and fill in its `spec`.
//  2. Add its price to `Tuning.launcherPrices` and its numbers to Constants.swift.
//  3. Add placeholder drawings for `spec.towerArtKey` and `spec.barrelArtKey` in
//     Core/Art.swift.
//  4. A brand-new ritual needs an `AimMode` case handled in `Launcher.update` and `HUD`.
// =====================================================================================

/// How the power half of the aim phase is played.
enum AimMode {
    /// Power sweeps up and down; one tap locks it. (cannon, torpedo)
    case twoSweep
    /// Power sweeps fast past a marked sweet zone; locking inside it pays a speed bonus. (rodReel)
    case castTiming
    /// Power builds while you hold; release to fire. Hold past full and the band snaps. (slingshot)
    case charge
}

enum LauncherKind: String, Codable, CaseIterable {
    case cannon, rodReel, slingshot, torpedo

    struct Spec {
        let aimMode: AimMode
        let angleRange: ClosedRange<CGFloat>   // degrees
        let angleSweepPeriod: CGFloat          // seconds for a full min→max→min sweep
        let powerPeriod: CGFloat               // sweep period, or draw time in .charge
        let minPowerFraction: CGFloat          // the worst lock still launches at this fraction
        let speedMultiplier: CGFloat           // applied on top of the Launcher Power upgrade
        let muzzleHeight: CGFloat              // above the water line
        let barrelLength: CGFloat
        /// Added to the skip window and the hard-impact threshold. The torpedo launches you
        /// flat and fast, which without these would just mean hitting the water hard enough
        /// to hole the hull on the first landing — it is *built* to skip, so it gets to.
        let skipAngleBonus: CGFloat
        let hardImpactBonus: CGFloat
        /// .castTiming only: the centre and half-width of the sweet zone, in power units.
        let sweetSpot: CGFloat
        let sweetSpotHalfWidth: CGFloat
        let sweetSpotBonus: CGFloat            // speed multiplier for a sweet-zone cast
        /// .charge only: seconds you may hold past full before the band snaps, and what
        /// the power collapses to when it does.
        let overchargeGrace: CGFloat
        let snapPower: CGFloat
        let towerArtKey: String
        let barrelArtKey: String
    }

    var spec: Spec {
        switch self {
        case .cannon:
            return Spec(aimMode: .twoSweep,
                        angleRange: Tuning.launchAngleMinDegrees...Tuning.launchAngleMaxDegrees,
                        angleSweepPeriod: Tuning.angleSweepPeriod,
                        powerPeriod: Tuning.powerSweepPeriod,
                        minPowerFraction: Tuning.minPowerFraction,
                        speedMultiplier: 1,
                        muzzleHeight: Tuning.launchHeight,
                        barrelLength: Tuning.launcherBarrelLength,
                        skipAngleBonus: 0, hardImpactBonus: 0,
                        sweetSpot: 0, sweetSpotHalfWidth: 0, sweetSpotBonus: 1,
                        overchargeGrace: 0, snapPower: 0,
                        towerArtKey: "lighthouse", barrelArtKey: "cannon")
        case .rodReel:
            return Spec(aimMode: .castTiming,
                        angleRange: Tuning.rodAngleMinDegrees...Tuning.rodAngleMaxDegrees,
                        angleSweepPeriod: Tuning.rodAngleSweepPeriod,
                        powerPeriod: Tuning.rodCastPeriod,
                        minPowerFraction: Tuning.rodMinPowerFraction,
                        speedMultiplier: Tuning.rodSpeedMultiplier,
                        muzzleHeight: Tuning.rodMuzzleHeight,
                        barrelLength: Tuning.rodBarrelLength,
                        skipAngleBonus: 0, hardImpactBonus: 0,
                        sweetSpot: Tuning.rodSweetSpot,
                        sweetSpotHalfWidth: Tuning.rodSweetSpotHalfWidth,
                        sweetSpotBonus: Tuning.rodSweetSpotBonus,
                        overchargeGrace: 0, snapPower: 0,
                        towerArtKey: "rodStand", barrelArtKey: "rodReel")
        case .slingshot:
            return Spec(aimMode: .charge,
                        angleRange: Tuning.slingAngleMinDegrees...Tuning.slingAngleMaxDegrees,
                        angleSweepPeriod: Tuning.slingAngleSweepPeriod,
                        powerPeriod: Tuning.slingDrawSeconds,
                        minPowerFraction: Tuning.slingMinPowerFraction,
                        speedMultiplier: Tuning.slingSpeedMultiplier,
                        muzzleHeight: Tuning.slingMuzzleHeight,
                        barrelLength: Tuning.slingBarrelLength,
                        skipAngleBonus: 0, hardImpactBonus: 0,
                        sweetSpot: 0, sweetSpotHalfWidth: 0, sweetSpotBonus: 1,
                        overchargeGrace: Tuning.slingOverchargeGrace,
                        snapPower: Tuning.slingSnapPower,
                        towerArtKey: "slingPost", barrelArtKey: "slingshot")
        case .torpedo:
            return Spec(aimMode: .twoSweep,
                        angleRange: Tuning.torpedoAngleMinDegrees...Tuning.torpedoAngleMaxDegrees,
                        angleSweepPeriod: Tuning.torpedoAngleSweepPeriod,
                        powerPeriod: Tuning.torpedoPowerPeriod,
                        minPowerFraction: Tuning.torpedoMinPowerFraction,
                        speedMultiplier: Tuning.torpedoSpeedMultiplier,
                        muzzleHeight: Tuning.torpedoMuzzleHeight,
                        barrelLength: Tuning.torpedoBarrelLength,
                        skipAngleBonus: Tuning.torpedoSkipAngleBonus,
                        hardImpactBonus: Tuning.torpedoHardImpactBonus,
                        sweetSpot: 0, sweetSpotHalfWidth: 0, sweetSpotBonus: 1,
                        overchargeGrace: 0, snapPower: 0,
                        towerArtKey: "torpedoRig", barrelArtKey: "torpedoTube")
        }
    }

    var displayName: String {
        switch self {
        case .cannon:    return "Old Lighthouse Cannon"
        case .rodReel:   return "Surf Rod & Reel"
        case .slingshot: return "Tidal Slingshot"
        case .torpedo:   return "Torpedo Tube"
        }
    }

    var blurb: String {
        switch self {
        case .cannon:    return "Two taps: lock the angle, lock the power. Honest work."
        case .rodReel:   return "Cast it. Hit the green band for a big launch bonus."
        case .slingshot: return "Hold to draw back. Let go late and the band snaps."
        case .torpedo:   return "Flat, fast and low. You start skipping immediately."
        }
    }

    /// The one line the aim HUD shows for the power half of this launcher.
    var powerHint: String {
        switch spec.aimMode {
        case .twoSweep:   return "TAP to lock the power"
        case .castTiming: return "TAP inside the green band"
        case .charge:     return "HOLD to draw — release to fire"
        }
    }

    var price: Int { Tuning.launcherPrices[self] ?? 0 }

    static let starter: LauncherKind = .cannon
}
