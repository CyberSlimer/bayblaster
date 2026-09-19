import CoreGraphics
import Foundation

// =====================================================================================
//  DailyChallenge.swift — one fixed bay per day, plus the seeded RNG that makes it fixed.
//
//  A daily run is an ordinary run with two differences:
//    · WorldSpawner draws from `RandomSource(seed:)` instead of the system RNG, so the
//      whole bay — every hazard, every coin arc — is laid out identically all day.
//    · A modifier of the day is folded into `UpgradeConfig` (see Core/Loadout.swift):
//      half a hull, no rockets, double coins, a headwind…
//
//  Your best distance for the day is kept, and the reward is paid the first time you
//  finish a daily run. Finishing on consecutive days builds a streak, which pays more.
// =====================================================================================

/// SplitMix64 — a tiny, fast, well-distributed seedable generator. Swift's own
/// `SystemRandomNumberGenerator` is (correctly) unseedable, and `String.hashValue` is
/// salted per process, so neither can give everybody the same bay on the same day.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A random source that is either seeded (daily challenge: reproducible) or the system
/// generator (a normal run). Everything that places world objects draws from one of these
/// so the two paths cannot drift apart.
struct RandomSource {
    private var seeded: SplitMix64?

    init(seed: UInt64?) { seeded = seed.map { SplitMix64(seed: $0) } }

    var isSeeded: Bool { seeded != nil }

    // `SplitMix64` is a struct, so each call has to copy the generator out, advance it and
    // put it back — otherwise the seeded sequence would restart on every draw.
    mutating func unit() -> CGFloat {
        guard var g = seeded else { return CGFloat.random(in: 0..<1) }
        let v = CGFloat.random(in: 0..<1, using: &g)
        seeded = g
        return v
    }

    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        guard range.lowerBound < range.upperBound else { return range.lowerBound }
        guard var g = seeded else { return CGFloat.random(in: range) }
        let v = CGFloat.random(in: range, using: &g)
        seeded = g
        return v
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        guard range.lowerBound < range.upperBound else { return range.lowerBound }
        guard var g = seeded else { return Int.random(in: range) }
        let v = Int.random(in: range, using: &g)
        seeded = g
        return v
    }
}

/// Everything a daily modifier can change about a run. Same shape as `GearItem.Modifier`:
/// defaults are no-ops, so a modifier only names what it actually twists.
struct DailyEffect {
    var coinMultiplier: CGFloat = 1
    var hullMultiplier: CGFloat = 1
    var rocketCountDelta: Int = 0
    var airDragMultiplier: CGFloat = 1
    var gravityMultiplier: CGFloat = 1
    var launchSpeedMultiplier: CGFloat = 1
    var damageMultiplier: CGFloat = 1
    var hazardFractionBonus: CGFloat = 0
    var sailPush: CGFloat = 0
}

enum DailyModifier: String, Codable, CaseIterable {
    case doubleCoins, glassHull, noRockets, headwind, squally, featherweight, rocketRush, ironFish

    var title: String {
        switch self {
        case .doubleCoins:   return "PAYDAY"
        case .glassHull:     return "GLASS HULL"
        case .noRockets:     return "DEAD WEIGHT"
        case .headwind:      return "HEADWIND"
        case .squally:       return "SQUALLY"
        case .featherweight: return "FEATHERWEIGHT"
        case .rocketRush:    return "ROCKET RUSH"
        case .ironFish:      return "IRON FISH"
        }
    }

    var detail: String {
        switch self {
        case .doubleCoins:   return "Every coin is worth double."
        case .glassHull:     return "A hull made of nothing. Big payout."
        case .noRockets:     return "No rockets today. Fly it clean."
        case .headwind:      return "Thick air, but the launcher is hot — and it pays."
        case .squally:       return "The bay is meaner than usual."
        case .featherweight: return "Barely any gravity — and barely any push."
        case .rocketRush:    return "Pockets full of rockets, air like soup."
        case .ironFish:      return "Almost nothing hurts. Almost nothing helps."
        }
    }

    var effect: DailyEffect {
        switch self {
        case .doubleCoins:
            return DailyEffect(coinMultiplier: 2)
        case .glassHull:
            return DailyEffect(coinMultiplier: 1.6, hullMultiplier: 0.4)
        case .noRockets:
            // Halves your distance, so it has to pay properly.
            return DailyEffect(coinMultiplier: 2.6, rocketCountDelta: -99)
        case .headwind:
            return DailyEffect(coinMultiplier: 2.0, airDragMultiplier: 1.8, launchSpeedMultiplier: 1.1)
        case .squally:
            return DailyEffect(coinMultiplier: 1.5, hazardFractionBonus: 0.18)
        case .featherweight:
            return DailyEffect(gravityMultiplier: 0.7, launchSpeedMultiplier: 0.85)
        case .rocketRush:
            return DailyEffect(rocketCountDelta: 3, airDragMultiplier: 1.5)
        case .ironFish:
            return DailyEffect(coinMultiplier: 1.3, launchSpeedMultiplier: 0.9, damageMultiplier: 0.4)
        }
    }
}

struct DailyChallenge {
    let dateKey: String          // "2026-09-19" in the device's own calendar
    let seed: UInt64
    let modifier: DailyModifier

    /// Today's challenge. The seed comes from the calendar date only — never from a hash
    /// of the string, because Swift salts `String.hashValue` per process and the bay would
    /// change every time the app relaunched.
    static var today: DailyChallenge { challenge(for: Date()) }

    static func challenge(for date: Date) -> DailyChallenge {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = parts.year ?? 2026, m = parts.month ?? 1, d = parts.day ?? 1
        let ordinal = UInt64(y * 10_000 + m * 100 + d)
        // Mix once so consecutive days give completely different bays.
        var mixer = SplitMix64(seed: ordinal &* 0x2545F4914F6CDD1D)
        let seed = mixer.next()
        let all = DailyModifier.allCases
        let modifier = all[Int(mixer.next() % UInt64(all.count))]
        return DailyChallenge(dateKey: String(format: "%04d-%02d-%02d", y, m, d), seed: seed, modifier: modifier)
    }

    /// Yesterday's key, used to decide whether a completion extends the streak.
    var previousDateKey: String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                              to: DailyChallenge.date(from: dateKey) ?? Date()) ?? Date()
        return DailyChallenge.challenge(for: yesterday).dateKey
    }

    private static func date(from key: String) -> Date? {
        let bits = key.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        var c = DateComponents()
        c.year = bits[0]; c.month = bits[1]; c.day = bits[2]
        return Calendar.current.date(from: c)
    }

    /// What finishing a daily run at `metres` pays, the first time it is finished today.
    func reward(metres: Double, streak: Int) -> Int {
        let base = Tuning.dailyBaseReward + Int(metres * Tuning.dailyCoinsPerMetre)
        let streakBonus = min(streak, Tuning.dailyStreakCap) * Tuning.dailyStreakBonus
        return base + streakBonus
    }
}
