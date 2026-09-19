import CoreGraphics
import Foundation

// =====================================================================================
//  Crew.swift — the riders you unlock and the in-flight ability each one brings.
//
//  A crew member is two things:
//    1. A PERK — a passive multiplier folded into `UpgradeConfig` at the start of a run
//       (see Core/Loadout.swift). Perks never stack with each other; exactly one rider
//       is selected at a time.
//    2. An ABILITY — the third in-flight verb, fired from the HUD button. Tap is still a
//       rocket and hold is still a nose-dive; the ability is on its own cooldown and can
//       be used all run, which is what makes the flight something you play rather than
//       watch.
//
//  HOW TO ADD A RIDER
//  1. Add a case here and fill in `displayName` / `species` / `perk` / `ability`.
//  2. Add its price to `Tuning.crewPrices` and its numbers to the "Crew perks" block in
//     Constants.swift.
//  3. Add a placeholder drawing in `Placeholders` (Core/Art.swift) under `artKey`.
//  4. If it needs a brand-new ability, add an `Ability` case and handle it in
//     `Player.beginAbility` / `Player.update` (and `GameScene.useAbility` if the
//     effect needs to reach into the world).
// =====================================================================================

/// The in-flight move a rider brings. Timed abilities run for `duration`; instant ones
/// (duration 0) fire and are done. Every ability shares one cooldown slot.
enum Ability: String, Codable, CaseIterable {
    case tuck, puff, glide, shell, inkJet, slam, swoop, frenzy

    var title: String {
        switch self {
        case .tuck:   return "TUCK"
        case .puff:   return "PUFF UP"
        case .glide:  return "GLIDE"
        case .shell:  return "SHELL UP"
        case .inkJet: return "INK JET"
        case .slam:   return "BELLY SLAM"
        case .swoop:  return "SWOOP"
        case .frenzy: return "FRENZY"
        }
    }

    /// One line shown on the crew card and in the first-use banner.
    var hint: String {
        switch self {
        case .tuck:   return "Fins in: air drag almost vanishes for a moment."
        case .puff:   return "Every landing is a guaranteed skip while inflated."
        case .glide:  return "Wings out: barely any gravity, drifting forward."
        case .shell:  return "Soaks up the next hazard completely."
        case .inkJet: return "A short, sharp forward jet. Quick cooldown."
        case .slam:   return "Slam down hard — the landing becomes a huge skip."
        case .swoop:  return "Snaps your flight toward the next pickup ahead."
        case .frenzy: return "Double coins and hazards stop slowing you down."
        }
    }

    /// Seconds the effect lasts. 0 = instant.
    var duration: CGFloat {
        switch self {
        case .tuck:   return Tuning.abilityTuckSeconds
        case .puff:   return Tuning.abilityPuffSeconds
        case .glide:  return Tuning.abilityGlideSeconds
        case .frenzy: return Tuning.abilityFrenzySeconds
        case .shell, .inkJet, .slam, .swoop: return 0
        }
    }

    /// Seconds before it can be fired again (before the rider's cooldown multiplier).
    var cooldown: CGFloat {
        switch self {
        case .tuck:   return Tuning.abilityTuckCooldown
        case .puff:   return Tuning.abilityPuffCooldown
        case .glide:  return Tuning.abilityGlideCooldown
        case .shell:  return Tuning.abilityShellCooldown
        case .inkJet: return Tuning.abilityInkJetCooldown
        case .slam:   return Tuning.abilitySlamCooldown
        case .swoop:  return Tuning.abilitySwoopCooldown
        case .frenzy: return Tuning.abilityFrenzyCooldown
        }
    }

    /// Short label for the HUD button.
    var buttonLabel: String {
        switch self {
        case .tuck:   return "TUCK"
        case .puff:   return "PUFF"
        case .glide:  return "GLIDE"
        case .shell:  return "SHELL"
        case .inkJet: return "JET"
        case .slam:   return "SLAM"
        case .swoop:  return "SWOOP"
        case .frenzy: return "FRENZY"
        }
    }
}

/// One unlockable rider. `marlow` is free and selected on a fresh save.
enum CrewMember: String, Codable, CaseIterable {
    case marlow, bristle, nixie, gilly, bruno, tock, pip, chum

    /// Passive modifiers folded into `UpgradeConfig`. Defaults are all no-ops so a new
    /// rider only has to name the one or two fields it actually changes.
    struct Perk {
        var launchSpeedMultiplier: CGFloat = 1
        var hullMultiplier: CGFloat = 1
        var airDragMultiplier: CGFloat = 1
        var skipRetentionBonus: CGFloat = 0     // added to the hull tier's retention
        var bonusRockets: Int = 0
        var coinMultiplier: CGFloat = 1
        var damageMultiplier: CGFloat = 1
        var abilityCooldownMultiplier: CGFloat = 1
    }

    var displayName: String {
        switch self {
        case .marlow:  return "Marlow"
        case .bristle: return "Bristle"
        case .nixie:   return "Nixie"
        case .gilly:   return "Gilly"
        case .bruno:   return "Bruno"
        case .tock:    return "Tock"
        case .pip:     return "Pip"
        case .chum:    return "Chum"
        }
    }

    var species: String {
        switch self {
        case .marlow:  return "Mackerel"
        case .bristle: return "Pufferfish"
        case .nixie:   return "Flying Fish"
        case .gilly:   return "Squid"
        case .bruno:   return "Sea Otter"
        case .tock:    return "Hermit Crab"
        case .pip:     return "Seagull"
        case .chum:    return "Baby Shark"
        }
    }

    var perk: Perk {
        switch self {
        case .marlow:
            // The starter. Deliberately no distance perk, so the pacing table in sim.py
            // still describes a stock run; his edge is getting the ability back sooner.
            return Perk(abilityCooldownMultiplier: Tuning.crewMarlowCooldownMultiplier)
        case .bristle:
            return Perk(hullMultiplier: Tuning.crewBristleHullMultiplier,
                        airDragMultiplier: Tuning.crewBristleDragMultiplier,
                        skipRetentionBonus: Tuning.crewBristleRetentionBonus)
        case .nixie:
            return Perk(airDragMultiplier: Tuning.crewNixieDragMultiplier)
        case .gilly:
            return Perk(bonusRockets: Tuning.crewGillyBonusRockets)
        case .bruno:
            return Perk(airDragMultiplier: Tuning.crewBrunoDragMultiplier,
                        skipRetentionBonus: Tuning.crewBrunoRetentionBonus)
        case .tock:
            return Perk(hullMultiplier: Tuning.crewTockHullMultiplier,
                        airDragMultiplier: Tuning.crewTockDragMultiplier,
                        damageMultiplier: Tuning.crewTockDamageMultiplier)
        case .pip:
            return Perk(coinMultiplier: Tuning.crewPipCoinMultiplier)
        case .chum:
            return Perk(launchSpeedMultiplier: Tuning.crewChumLaunchMultiplier,
                        hullMultiplier: Tuning.crewChumHullMultiplier,
                        airDragMultiplier: Tuning.crewChumDragMultiplier)
        }
    }

    var ability: Ability {
        switch self {
        case .marlow:  return .tuck
        case .bristle: return .puff
        case .nixie:   return .glide
        case .gilly:   return .inkJet
        case .bruno:   return .slam
        case .tock:    return .shell
        case .pip:     return .swoop
        case .chum:    return .frenzy
        }
    }

    /// One line describing the passive, for the crew card.
    var perkText: String {
        switch self {
        case .marlow:  return "Ability cooldown −\(Self.percentOff(Tuning.crewMarlowCooldownMultiplier))%"
        case .bristle: return "Hull +\(Self.percentUp(Tuning.crewBristleHullMultiplier))%, a little less drag"
        case .nixie:   return "Air drag −\(Self.percentOff(Tuning.crewNixieDragMultiplier))%"
        case .gilly:   return "+\(Tuning.crewGillyBonusRockets) rocket"
        case .bruno:   return "Skips keep +\(String(format: "%.1f", Tuning.crewBrunoRetentionBonus * 100))% speed, drag −\(Self.percentOff(Tuning.crewBrunoDragMultiplier))%"
        case .tock:    return "Hazard damage −\(Self.percentOff(Tuning.crewTockDamageMultiplier))%, hull +\(Self.percentUp(Tuning.crewTockHullMultiplier))%, drag −\(Self.percentOff(Tuning.crewTockDragMultiplier))%"
        case .pip:     return "Coins ×\(String(format: "%.2g", Tuning.crewPipCoinMultiplier))"
        case .chum:    return "Launch +\(Self.percentUp(Tuning.crewChumLaunchMultiplier))%, drag −\(Self.percentOff(Tuning.crewChumDragMultiplier))%, hull −\(Self.percentOff(Tuning.crewChumHullMultiplier))%"
        }
    }

    var price: Int { Tuning.crewPrices[self] ?? 0 }

    /// Marlow keeps the original "fish" art key so an existing PNG drop still works.
    var artKey: String { self == .marlow ? "fish" : "crew" + rawValue.capitalizedFirst }

    static let starter: CrewMember = .marlow

    private static func percentUp(_ multiplier: CGFloat) -> Int { Int(((multiplier - 1) * 100).rounded()) }
    private static func percentOff(_ multiplier: CGFloat) -> Int { Int(((1 - multiplier) * 100).rounded()) }
}

extension String {
    /// "bristle" → "Bristle". Used to build art keys from enum raw values.
    var capitalizedFirst: String {
        guard let f = first else { return self }
        return String(f).uppercased() + dropFirst()
    }
}
