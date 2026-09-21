import Foundation

// =====================================================================================
//  Missions — three rotating per-run goals ("skip 5 times", "ride 2 dolphins", "fly 800 m").
//  Completing one pays coins on the results card; it is replaced at the start of the next
//  run with a slightly harder one. Difficulty steps up every `Tuning.missionLevelEvery`
//  completions. All numbers live in `MissionKind.targets` / `Tuning.missionRewardByLevel`.
// =====================================================================================

/// What a mission counts. Every kind is measured over a single run.
enum MissionKind: String, Codable, CaseIterable {
    case distance, skips, combo, perfect, coins, dolphins, buoys, whales, balloons, mines, rockets, untouched
    case abilities, cleanHull, smashed, altitude

    /// Target per difficulty level 0…5.
    var targets: [Int] {
        switch self {
        case .distance:  return [300, 500, 800, 1200, 2000, 3500]
        case .skips:     return [2, 3, 5, 7, 10, 14]
        case .combo:     return [2, 3, 4, 6, 8, 10]
        case .perfect:   return [1, 1, 2, 3, 4, 6]
        case .coins:     return [300, 500, 900, 1500, 2500, 4000]
        case .dolphins:  return [1, 1, 2, 2, 3, 4]
        case .buoys:     return [1, 2, 2, 3, 4, 5]
        case .whales:    return [1, 1, 2, 2, 3, 3]
        case .balloons:  return [1, 1, 2, 2, 3, 3]
        case .mines:     return [1, 1, 1, 2, 2, 3]
        case .rockets:   return [1, 2, 3, 3, 3, 3]
        case .untouched: return [1, 1, 1, 1, 1, 1]
        case .abilities: return [2, 3, 4, 6, 8, 10]
        case .cleanHull: return [200, 400, 700, 1100, 1700, 2600]   // metres, finishing at full hull
        case .smashed:   return [1, 2, 3, 5, 7, 10]
        case .altitude:  return [60, 100, 160, 240, 340, 500]        // metres above the water
        }
    }

    /// Lowest level at which this kind is offered (perfects and "untouched" need some skill).
    var minLevel: Int {
        switch self {
        case .perfect, .untouched, .mines, .cleanHull, .altitude: return 1
        default: return 0
        }
    }

    func title(target: Int) -> String {
        func s(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? one : many }
        switch self {
        case .distance:  return "Fly \(target) m in one run"
        case .skips:     return "Skip \(target) times in one run"
        case .combo:     return "Chain a \(target)-skip combo"
        case .perfect:   return "Land \(target) PERFECT \(s(target, "skip", "skips"))"
        case .coins:     return "Earn \(target) coins in one run"
        case .dolphins:  return "Ride \(target) \(s(target, "dolphin", "dolphins"))"
        case .buoys:     return "Bounce off \(target) \(s(target, "buoy", "buoys"))"
        case .whales:    return "Catch \(target) whale \(s(target, "spout", "spouts"))"
        case .balloons:  return "Pop \(target) balloon \(s(target, "bunch", "bunches"))"
        case .mines:     return "Survive \(target) mine \(s(target, "blast", "blasts"))"
        case .rockets:   return "Fire \(target) \(s(target, "rocket", "rockets")) in one run"
        case .untouched: return "Finish a run without hitting a hazard"
        case .abilities: return "Use your ability \(target) times in one run"
        case .cleanHull: return "Fly \(target) m and finish at full hull"
        case .smashed:   return "Smash \(target) \(s(target, "wall", "walls")) in one run"
        case .altitude:  return "Reach \(target) m above the water"
        }
    }

    /// Progress toward `target` given what happened in a run.
    func progress(in run: RunStats) -> Int {
        switch self {
        case .distance:  return Int(run.distance)
        case .skips:     return run.skips
        case .combo:     return run.bestCombo
        case .perfect:   return run.perfects
        case .coins:     return run.coins
        case .dolphins:  return run.hits["dolphin"] ?? 0
        case .buoys:     return run.hits["buoy"] ?? 0
        case .whales:    return run.hits["whaleSpout"] ?? 0
        case .balloons:  return run.hits["balloon"] ?? 0
        case .mines:     return run.hits["mine"] ?? 0
        case .rockets:   return run.rocketsFired
        case .untouched: return run.hazardsHit == 0 && run.distance > 0 ? 1 : 0
        case .abilities: return run.abilitiesUsed
        case .cleanHull: return run.endHullFraction >= 1 ? Int(run.distance) : 0
        case .smashed:   return run.barriersSmashed
        case .altitude:  return Int(run.peakAltitude)
        }
    }
}

/// One active mission. `completed` stays true until the next run replaces it, so the
/// results card and title screen can show the tick.
struct Mission: Codable, Equatable {
    var id: Int
    var kind: MissionKind
    var target: Int
    var reward: Int
    var completed: Bool = false

    var title: String { kind.title(target: target) }

    init(id: Int, kind: MissionKind, target: Int, reward: Int) {
        self.id = id; self.kind = kind; self.target = target; self.reward = reward
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        kind = try c.decodeIfPresent(MissionKind.self, forKey: .kind) ?? .distance
        target = max(1, try c.decodeIfPresent(Int.self, forKey: .target) ?? 1)
        reward = max(0, try c.decodeIfPresent(Int.self, forKey: .reward) ?? 0)
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
    }
}

/// Everything a mission can ask about, gathered by GameScene during a run.
struct RunStats {
    var distance: Double = 0
    var coins = 0
    var skips = 0
    var bestCombo = 0
    var perfects = 0
    var rocketsFired = 0
    var hazardsHit = 0
    var hits: [String: Int] = [:]     // EntityKind artKey → times touched
    var abilitiesUsed = 0             // times the rider's ability was fired
    var endHullFraction: Double = 1   // 1 = finished without a scratch
    var isDaily = false               // this run was a daily challenge
    var barriersSmashed = 0           // breakable walls broken through
    var peakAltitude: Double = 0      // highest point of the run, in metres above the water
}

/// Outcome of checking one mission against a run.
struct MissionResult {
    let mission: Mission
    let progress: Int
    let justCompleted: Bool
}

enum Missions {
    static let activeCount = 3

    /// Difficulty level from lifetime completions.
    static func level(completed: Int) -> Int {
        min(completed / Tuning.missionLevelEvery, 5)
    }

    /// Top up the active list to `activeCount`, dropping completed ones first.
    /// Called at the start of every run and on the title screen.
    static func refill() {
        SaveManager.shared.mutate { d in
            d.missions.removeAll { $0.completed }
            var attempts = 0
            while d.missions.count < activeCount && attempts < 40 {
                attempts += 1
                if let m = generate(save: d) { d.missions.append(m); d.nextMissionId = m.id + 1 }
            }
        }
    }

    private static func generate(save: SaveData) -> Mission? {
        let lvl = level(completed: save.missionsCompleted)
        let taken = Set(save.missions.map { $0.kind })
        let hasRockets = save.tier(of: .rockets) > 0
        let pool = MissionKind.allCases.filter { kind in
            !taken.contains(kind) && kind.minLevel <= lvl && (kind != .rockets || hasRockets)
        }
        guard let kind = pool.randomElement() else { return nil }

        // ±1 level of jitter so three missions at the same level don't feel identical
        // (never downward at level 0, so a replacement is never easier than the starter).
        let li = min(max(lvl + Int.random(in: (lvl == 0 ? 0 : -1)...1), 0), 5)
        var target = kind.targets[li]
        if kind == .distance {
            // Distance missions should always be a stretch past the current best.
            let stretch = Int((save.bestDistance * Tuning.missionDistanceStretch / 50).rounded(.up)) * 50
            target = max(target, stretch)
        }
        return Mission(id: save.nextMissionId, kind: kind, target: target, reward: Tuning.missionRewardByLevel[li])
    }

    /// Non-mutating: which active, uncompleted missions would be satisfied by `run` right now.
    /// Used mid-run for the MISSION COMPLETE banner; payment happens in `evaluate`.
    static func satisfied(by run: RunStats) -> [Mission] {
        SaveManager.shared.data.missions.filter { !$0.completed && $0.kind.progress(in: run) >= $0.target }
    }

    /// Check every active mission against a finished run, pay out the ones that completed,
    /// and return the per-mission status for the results card.
    @discardableResult
    static func evaluate(run: RunStats) -> [MissionResult] {
        var results: [MissionResult] = []
        SaveManager.shared.mutate { d in
            for i in d.missions.indices {
                let m = d.missions[i]
                let p = m.kind.progress(in: run)
                let done = !m.completed && p >= m.target
                if done {
                    d.missions[i].completed = true
                    d.coins += m.reward
                    d.missionsCompleted += 1
                }
                results.append(MissionResult(mission: d.missions[i], progress: min(p, m.target), justCompleted: done))
            }
        }
        return results
    }
}
