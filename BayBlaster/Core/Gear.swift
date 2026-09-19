import CoreGraphics
import Foundation

// =====================================================================================
//  Gear.swift — bolt-on parts for the dinghy. This is the "add wheels to it" layer.
//
//  Three slots, three parts each. A part is bought once (permanently owned) and can then
//  be equipped or unequipped freely; equipping a part fills its slot, replacing whatever
//  was in it. Unlike the five shop upgrade tracks — which are linear and always on — gear
//  is a CHOICE: every part has a real downside or an opportunity cost, so two players with
//  the same coins can build very different boats.
//
//  HOW TO ADD A PART
//  1. Add a case here, put it in a slot, and fill in `modifier`.
//  2. Add its price to `Tuning.gearPrices` and its numbers to the "Gear" block in
//     Constants.swift.
//  3. Add a placeholder drawing in `Placeholders` (Core/Art.swift) under `artKey`.
//  4. If the part needs a rule the modifier fields can't express, add a field to
//     `Modifier` and read it wherever the rule lives (Player, WaterSkipSystem, spawner).
// =====================================================================================

enum GearSlot: String, Codable, CaseIterable {
    case hull, rig, trinket

    var title: String {
        switch self {
        case .hull:    return "HULL"
        case .rig:     return "RIG"
        case .trinket: return "TRINKET"
        }
    }

    var blurb: String {
        switch self {
        case .hull:    return "What the boat sits on."
        case .rig:     return "What catches the air."
        case .trinket: return "Something in the tackle box."
        }
    }
}

enum GearItem: String, Codable, CaseIterable {
    // Hull
    case wheels, pontoons, springKeel
    // Rig
    case stormSail, boxKite, jetVent
    // Trinket
    case coinMagnet, luckyHorseshoe, barnaclePlate

    /// Everything a part can change. All defaults are no-ops.
    struct Modifier {
        var plowDragMultiplier: CGFloat = 1        // < 1 = you keep rolling after splashdown
        var skipAngleBonusDegrees: CGFloat = 0     // widens the skip window
        var skipRestitutionMultiplier: CGFloat = 1 // bouncier skips
        var airDragMultiplier: CGFloat = 1
        var gravityMultiplier: CGFloat = 1
        var launchSpeedMultiplier: CGFloat = 1
        var rocketStrengthMultiplier: CGFloat = 1
        var bonusRockets: Int = 0
        var sailPush: CGFloat = 0                  // constant forward accel while airborne
        var stormPushesForward = false             // storm clouds shove you along instead of down
        var magnetRadius: CGFloat = 0              // coins inside this radius home in on you
        var boostWeightMultiplier: CGFloat = 1
        var coinArcChanceBonus: CGFloat = 0
        var damageMultiplier: CGFloat = 1
    }

    var slot: GearSlot {
        switch self {
        case .wheels, .pontoons, .springKeel:            return .hull
        case .stormSail, .boxKite, .jetVent:             return .rig
        case .coinMagnet, .luckyHorseshoe, .barnaclePlate: return .trinket
        }
    }

    var displayName: String {
        switch self {
        case .wheels:         return "Beach Wheels"
        case .pontoons:       return "Pontoons"
        case .springKeel:     return "Spring Keel"
        case .stormSail:      return "Storm Sail"
        case .boxKite:        return "Box Kite"
        case .jetVent:        return "Jet Vent"
        case .coinMagnet:     return "Coin Magnet"
        case .luckyHorseshoe: return "Lucky Horseshoe"
        case .barnaclePlate:  return "Barnacle Plating"
        }
    }

    var modifier: Modifier {
        switch self {
        case .wheels:
            return Modifier(plowDragMultiplier: Tuning.gearWheelsPlowDragMultiplier)
        case .pontoons:
            return Modifier(skipAngleBonusDegrees: Tuning.gearPontoonsSkipAngleBonus,
                            airDragMultiplier: Tuning.gearPontoonsDragMultiplier)
        case .springKeel:
            return Modifier(skipRestitutionMultiplier: Tuning.gearSpringKeelRestitutionMultiplier)
        case .stormSail:
            return Modifier(sailPush: Tuning.gearStormSailPush, stormPushesForward: true)
        case .boxKite:
            return Modifier(gravityMultiplier: Tuning.gearBoxKiteGravityMultiplier)
        case .jetVent:
            return Modifier(rocketStrengthMultiplier: Tuning.gearJetVentRocketMultiplier,
                            bonusRockets: Tuning.gearJetVentBonusRockets)
        case .coinMagnet:
            return Modifier(magnetRadius: Tuning.gearCoinMagnetRadius)
        case .luckyHorseshoe:
            return Modifier(boostWeightMultiplier: Tuning.gearHorseshoeBoostMultiplier,
                            coinArcChanceBonus: Tuning.gearHorseshoeCoinArcBonus)
        case .barnaclePlate:
            return Modifier(launchSpeedMultiplier: Tuning.gearBarnacleLaunchMultiplier,
                            damageMultiplier: Tuning.gearBarnacleDamageMultiplier)
        }
    }

    /// Two lines for the gear card: what it gives you, and what it costs you.
    var upside: String {
        switch self {
        case .wheels:         return "Roll on after splashdown — \(Self.percentOff(Tuning.gearWheelsPlowDragMultiplier))% less water drag"
        case .pontoons:       return "Skip window +\(Int(Tuning.gearPontoonsSkipAngleBonus))°"
        case .springKeel:     return "Skips bounce +\(Self.percentUp(Tuning.gearSpringKeelRestitutionMultiplier))% higher"
        case .stormSail:      return "Constant forward push; storms blow you along"
        case .boxKite:        return "Gravity −\(Self.percentOff(Tuning.gearBoxKiteGravityMultiplier))%"
        case .jetVent:        return "Rockets +\(Self.percentUp(Tuning.gearJetVentRocketMultiplier))% and +\(Tuning.gearJetVentBonusRockets)"
        case .coinMagnet:     return "Coins within \(Int(Tuning.gearCoinMagnetRadius / Tuning.pointsPerMeter)) m fly to you"
        case .luckyHorseshoe: return "Boosts ×\(String(format: "%.2g", Tuning.gearHorseshoeBoostMultiplier)), more coin arcs"
        case .barnaclePlate:  return "Hazard damage −\(Self.percentOff(Tuning.gearBarnacleDamageMultiplier))%"
        }
    }

    var downside: String? {
        switch self {
        case .pontoons:      return "Air drag +\(Self.percentUp(Tuning.gearPontoonsDragMultiplier))%"
        case .barnaclePlate: return "Launch speed −\(Self.percentOff(Tuning.gearBarnacleLaunchMultiplier))%"
        case .wheels, .springKeel, .stormSail, .boxKite, .jetVent, .coinMagnet, .luckyHorseshoe:
            return "Takes the \(slot.title.lowercased()) slot"
        }
    }

    var price: Int { Tuning.gearPrices[self] ?? 0 }

    var artKey: String { "gear" + rawValue.capitalizedFirst }

    static func items(in slot: GearSlot) -> [GearItem] { GearItem.allCases.filter { $0.slot == slot } }

    private static func percentUp(_ multiplier: CGFloat) -> Int { Int(((multiplier - 1) * 100).rounded()) }
    private static func percentOff(_ multiplier: CGFloat) -> Int { Int(((1 - multiplier) * 100).rounded()) }
}
