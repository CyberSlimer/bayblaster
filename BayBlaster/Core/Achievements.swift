import CoreGraphics
import Foundation

// =====================================================================================
//  Achievements.swift — one-time trophies, each paying coins the first time it is earned.
//
//  Missions (Core/Missions.swift) rotate and are about THIS run; achievements are
//  permanent and mostly about the account: how far you have ever flown, how much of the
//  locker you own, how deep the upgrade tracks go. They are checked once, at the end of
//  every run, against the save as it stands *after* the run was recorded.
//
//  HOW TO ADD ONE
//  Add a case, give it a title/detail/reward, and add its arm to `isEarned`. If it needs
//  something the run doesn't already report, add a field to `RunStats` (Missions.swift)
//  and fill it in `GameScene.currentRunStats()`.
// =====================================================================================

enum Achievement: String, Codable, CaseIterable {
    // Distance
    case firstSplash, fly500, fly1000, fly2500, fly5000
    // Skill in a single run
    case skipper, comboKing, perfectionist, bigHaul, unscathed, daredevil, abilityAce
    // Lifetime
    case trekker, voyager, regular, veteran
    // Collection
    case crewOfThree, fullCrew, firstPart, fullGarage, fullArsenal
    // End-game
    case maxedOut, castOff, dailyDoer, weekStreak

    var title: String {
        switch self {
        case .firstSplash:   return "Wet Behind the Fins"
        case .fly500:        return "Out Past the Buoys"
        case .fly1000:       return "Kilometre Club"
        case .fly2500:       return "Open Water"
        case .fly5000:       return "Over the Horizon"
        case .skipper:       return "Skipper"
        case .comboKing:     return "Combo King"
        case .perfectionist: return "Perfectionist"
        case .bigHaul:       return "Big Haul"
        case .unscathed:     return "Not a Scratch"
        case .daredevil:     return "Daredevil"
        case .abilityAce:    return "Show-off"
        case .trekker:       return "Trekker"
        case .voyager:       return "Voyager"
        case .regular:       return "Regular"
        case .veteran:       return "Harbour Veteran"
        case .crewOfThree:   return "Crewed Up"
        case .fullCrew:      return "All Hands"
        case .firstPart:     return "Bolted On"
        case .fullGarage:    return "Full Garage"
        case .fullArsenal:   return "Full Arsenal"
        case .maxedOut:      return "Fully Kitted"
        case .castOff:       return "Cast Off"
        case .dailyDoer:     return "Daily Dip"
        case .weekStreak:    return "Seven Days Straight"
        }
    }

    var detail: String {
        switch self {
        case .firstSplash:   return "Finish your first run."
        case .fly500:        return "Fly 500 m in one run."
        case .fly1000:       return "Fly 1,000 m in one run."
        case .fly2500:       return "Fly 2,500 m in one run."
        case .fly5000:       return "Fly 5,000 m in one run."
        case .skipper:       return "Skip 15 times in one run."
        case .comboKing:     return "Chain a 10-skip combo."
        case .perfectionist: return "Land 5 PERFECT skips in one run."
        case .bigHaul:       return "Earn 1,500 coins in one run."
        case .unscathed:     return "Finish a 500 m run with a full hull."
        case .daredevil:     return "Survive 3 mine blasts in one run."
        case .abilityAce:    return "Use your ability 8 times in one run."
        case .trekker:       return "Fly 25,000 m in total."
        case .voyager:       return "Fly 100,000 m in total."
        case .regular:       return "Finish 25 runs."
        case .veteran:       return "Finish 150 runs."
        case .crewOfThree:   return "Have three riders in the crew."
        case .fullCrew:      return "Unlock every rider."
        case .firstPart:     return "Buy your first piece of gear."
        case .fullGarage:    return "Own every piece of gear."
        case .fullArsenal:   return "Own every launcher."
        case .maxedOut:      return "Max out all five shop upgrades."
        case .castOff:       return "Cast off once and start again."
        case .dailyDoer:     return "Finish a daily challenge."
        case .weekStreak:    return "Keep a 7-day daily streak."
        }
    }

    var reward: Int { Tuning.achievementRewards[self] ?? 200 }

    /// Checked at the end of every run. `save` is the state *after* the run was recorded,
    /// so lifetime totals already include it.
    func isEarned(run: RunStats, save: SaveData) -> Bool {
        switch self {
        case .firstSplash:   return save.stats.totalRuns >= 1
        case .fly500:        return run.distance >= 500
        case .fly1000:       return run.distance >= 1_000
        case .fly2500:       return run.distance >= 2_500
        case .fly5000:       return run.distance >= 5_000
        case .skipper:       return run.skips >= 15
        case .comboKing:     return run.bestCombo >= 10
        case .perfectionist: return run.perfects >= 5
        case .bigHaul:       return run.coins >= 1_500
        case .unscathed:     return run.distance >= 500 && run.endHullFraction >= 1
        case .daredevil:     return (run.hits["mine"] ?? 0) >= 3
        case .abilityAce:    return run.abilitiesUsed >= 8
        case .trekker:       return save.stats.totalDistance >= 25_000
        case .voyager:       return save.stats.totalDistance >= 100_000
        case .regular:       return save.stats.totalRuns >= 25
        case .veteran:       return save.stats.totalRuns >= 150
        case .crewOfThree:   return save.ownedCrewMembers.count >= 3
        case .fullCrew:      return save.ownedCrewMembers.count >= CrewMember.allCases.count
        case .firstPart:     return !save.ownedGearItems.isEmpty
        case .fullGarage:    return save.ownedGearItems.count >= GearItem.allCases.count
        case .fullArsenal:   return save.ownedLauncherKinds.count >= LauncherKind.allCases.count
        case .maxedOut:      return UpgradeKind.allCases.allSatisfy { save.tier(of: $0) >= Tuning.upgradeMaxTier }
        case .castOff:       return save.prestigeLevel >= 1
        case .dailyDoer:     return run.isDaily && run.distance > 0
        case .weekStreak:    return save.dailyStreak >= 7
        }
    }
}

enum Achievements {
    /// Award anything newly earned and return it, so the scene can show a banner and the
    /// results card can list it. Coins are paid here.
    @discardableResult
    static func evaluate(run: RunStats) -> [Achievement] {
        var earned: [Achievement] = []
        SaveManager.shared.mutate { d in
            for a in Achievement.allCases where !d.achievements.contains(a.rawValue) {
                guard a.isEarned(run: run, save: d) else { continue }
                d.achievements.append(a.rawValue)
                d.coins += a.reward
                earned.append(a)
            }
        }
        return earned
    }

    static var earnedCount: Int {
        let owned = Set(SaveManager.shared.data.achievements)
        return Achievement.allCases.filter { owned.contains($0.rawValue) }.count
    }

    static func isEarned(_ a: Achievement) -> Bool {
        SaveManager.shared.data.achievements.contains(a.rawValue)
    }
}
