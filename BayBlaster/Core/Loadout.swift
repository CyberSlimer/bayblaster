import CoreGraphics
import Foundation

// =====================================================================================
//  Loadout.swift — `UpgradeConfig` resolves everything the player has chosen into the
//  handful of numbers the run actually uses.
//
//  It is built ONCE at the start of a run (GameScene.init) and then read all over:
//  Player integrates with it, WaterSkipSystem judges landings with it, WorldSpawner
//  weights spawns with it. Nothing during a run may change it, which is what keeps the
//  simulation in Tools/sim.py able to mirror the game honestly.
//
//  Five inputs are folded together, in this order:
//    1. Upgrade tiers      — the five linear shop tracks (Constants.swift tables)
//    2. Crew perk          — the selected rider's passive (Core/Crew.swift)
//    3. Equipped gear      — up to one part per slot (Core/Gear.swift)
//    4. Prestige           — a permanent coin multiplier per cast-off
//    5. Daily modifier     — only on a daily-challenge run (Core/DailyChallenge.swift)
//
//  (This type used to live in Constants.swift; it moved out when it grew past a dozen
//  fields. Constants.swift stays a file of numbers.)
// =====================================================================================

struct UpgradeConfig {

    // MARK: Flight
    let launchSpeed: CGFloat
    let maxHull: CGFloat
    let skipHorizontalRetention: CGFloat
    let hardImpactThreshold: CGFloat
    let rocketCount: Int
    let rocketStrength: CGFloat
    let airDrag: CGFloat
    let gravityMultiplier: CGFloat
    let plowDrag: CGFloat
    let sailPush: CGFloat
    let stormPushesForward: Bool

    // MARK: Water
    /// Already includes the hull tier and any gear that widens the window.
    let skipMaxAngleDegrees: CGFloat
    let diveSkipMaxAngleDegrees: CGFloat
    let skipRestitution: CGFloat

    // MARK: Economy / world
    let boostWeightMultiplier: CGFloat
    let coinArcChance: CGFloat
    let coinMultiplier: CGFloat
    let damageMultiplier: CGFloat
    let magnetRadius: CGFloat
    let hazardFractionBonus: CGFloat

    // MARK: Loadout identity
    let crew: CrewMember
    let launcher: LauncherKind
    let equippedGear: [GearItem]
    let ability: Ability
    let abilityCooldown: CGFloat

    var hasMagnet: Bool { magnetRadius > 0 }

    init(save: SaveData, daily: DailyEffect? = nil) {
        func tier(_ k: UpgradeKind) -> Int { min(max(save.tier(of: k), 0), Tuning.upgradeMaxTier) }

        let rider = save.selectedCrewMember
        let perk = rider.perk
        let gear = save.equippedGearItems
        let effect = daily ?? DailyEffect()
        let launcherSpec = save.selectedLauncherKind.spec

        crew = rider
        launcher = save.selectedLauncherKind
        equippedGear = gear
        ability = rider.ability
        abilityCooldown = max(Tuning.abilityMinCooldown,
                              rider.ability.cooldown * perk.abilityCooldownMultiplier)

        // Start from the upgrade tables, then let each layer multiply in.
        var speed = Tuning.launchSpeedByTier[tier(.launcher)]
        var hull = Tuning.hullMaxByTier[tier(.hull)]
        var retention = Tuning.skipRetentionByTier[tier(.hull)]
        var rockets = Tuning.rocketCountByTier[tier(.rockets)]
        var rocketPower = Tuning.rocketStrengthByTier[tier(.rockets)]
        var drag = Tuning.airDragByTier[tier(.aero)]
        var boostWeight = Tuning.luckyLureByTier[tier(.lure)]

        var gravity: CGFloat = 1
        var plow = Tuning.plowDrag
        // The launcher contributes before crew and gear: it is part of the boat you set out in.
        var skipAngleBonus: CGFloat = launcherSpec.skipAngleBonus
        var restitution = Tuning.skipVerticalRestitution
        var sail: CGFloat = 0
        var stormForward = false
        var magnet: CGFloat = 0
        var arcChance = Tuning.coinArcChance
        var coins: CGFloat = 1
        var damage: CGFloat = 1

        // 2. Crew perk
        speed *= perk.launchSpeedMultiplier
        hull *= perk.hullMultiplier
        drag *= perk.airDragMultiplier
        retention += perk.skipRetentionBonus
        rockets += perk.bonusRockets
        coins *= perk.coinMultiplier
        damage *= perk.damageMultiplier

        // 3. Equipped gear
        for item in gear {
            let m = item.modifier
            plow *= m.plowDragMultiplier
            skipAngleBonus += m.skipAngleBonusDegrees
            restitution *= m.skipRestitutionMultiplier
            drag *= m.airDragMultiplier
            gravity *= m.gravityMultiplier
            speed *= m.launchSpeedMultiplier
            rocketPower *= m.rocketStrengthMultiplier
            rockets += m.bonusRockets
            sail += m.sailPush
            stormForward = stormForward || m.stormPushesForward
            magnet = max(magnet, m.magnetRadius)
            boostWeight *= m.boostWeightMultiplier
            arcChance += m.coinArcChanceBonus
            damage *= m.damageMultiplier
        }

        // 4. Prestige — cast-offs only ever pay in coins, so the pacing table stays true.
        coins *= 1 + CGFloat(save.prestigeLevel) * Tuning.prestigeCoinBonusPerLevel

        // 5. Daily-challenge modifier
        speed *= effect.launchSpeedMultiplier
        hull *= effect.hullMultiplier
        drag *= effect.airDragMultiplier
        gravity *= effect.gravityMultiplier
        rockets += effect.rocketCountDelta
        coins *= effect.coinMultiplier
        damage *= effect.damageMultiplier
        sail += effect.sailPush

        // The rocket upgrade table pairs a count with a strength; a rider or a vent that
        // hands out a rocket to someone who owns none needs a strength to go with it.
        if rocketPower <= 0 && rockets > 0 { rocketPower = Tuning.rocketStrengthByTier[1] }

        launchSpeed = speed
        maxHull = max(1, hull)
        skipHorizontalRetention = min(retention, Tuning.skipRetentionCeiling)
        hardImpactThreshold = Tuning.hardImpactThresholdByTier[tier(.hull)] + launcherSpec.hardImpactBonus
        rocketCount = max(0, rockets)
        rocketStrength = rocketPower
        airDrag = max(0, drag)
        gravityMultiplier = gravity
        plowDrag = plow
        sailPush = sail
        stormPushesForward = stormForward
        skipMaxAngleDegrees = Tuning.skipMaxAngleDegrees + skipAngleBonus
        diveSkipMaxAngleDegrees = Tuning.diveSkipMaxAngleDegrees + skipAngleBonus
        skipRestitution = min(restitution, Tuning.skipRestitutionCeiling)
        boostWeightMultiplier = boostWeight
        coinArcChance = clamp(arcChance, 0, 0.8)
        coinMultiplier = coins
        damageMultiplier = damage
        magnetRadius = magnet
        hazardFractionBonus = effect.hazardFractionBonus
    }

    /// Multiplies a coin payout by everything that boosts coins, rounding up so small
    /// payouts (a 5-coin arc coin) still feel the multiplier.
    func payout(_ base: Int, frenzied: Bool = false) -> Int {
        let m = coinMultiplier * (frenzied ? Tuning.abilityFrenzyCoinMultiplier : 1)
        return max(base, Int((CGFloat(base) * m).rounded()))
    }
}
