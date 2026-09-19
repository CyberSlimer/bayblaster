import Foundation

/// Lifetime statistics shown on the title screen.
struct Stats: Codable, Equatable {
    var totalRuns: Int = 0
    var totalDistance: Double = 0          // metres
    var longestFlightTime: Double = 0      // seconds airborne in a single hop
    var bestRunCoins: Int = 0

    init() {}

    // Tolerant decoding: any missing key falls back to its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalRuns = try c.decodeIfPresent(Int.self, forKey: .totalRuns) ?? 0
        totalDistance = try c.decodeIfPresent(Double.self, forKey: .totalDistance) ?? 0
        longestFlightTime = try c.decodeIfPresent(Double.self, forKey: .longestFlightTime) ?? 0
        bestRunCoins = try c.decodeIfPresent(Int.self, forKey: .bestRunCoins) ?? 0
    }
}

/// Everything that persists between launches of the app.
struct SaveData: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = SaveData.currentVersion
    var coins: Int = 0
    var upgrades: [String: Int] = [:]      // UpgradeKind.rawValue → tier (0…5)
    var bestDistance: Double = 0           // metres
    var stats = Stats()
    var muted: Bool = false
    var missions: [Mission] = []
    var missionsCompleted: Int = 0
    var nextMissionId: Int = 1
    var seenEntities: [String] = []        // art keys the boat has touched at least once (first-touch tips)

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? SaveData.currentVersion
        let rawCoins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        coins = max(0, rawCoins)
        upgrades = try c.decodeIfPresent([String: Int].self, forKey: .upgrades) ?? [:]
        bestDistance = try c.decodeIfPresent(Double.self, forKey: .bestDistance) ?? 0
        stats = try c.decodeIfPresent(Stats.self, forKey: .stats) ?? Stats()
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        missions = try c.decodeIfPresent([Mission].self, forKey: .missions) ?? []
        missionsCompleted = try c.decodeIfPresent(Int.self, forKey: .missionsCompleted) ?? 0
        nextMissionId = try c.decodeIfPresent(Int.self, forKey: .nextMissionId) ?? 1
        seenEntities = try c.decodeIfPresent([String].self, forKey: .seenEntities) ?? []
        // Clamp anything a hand-edited file might have pushed out of range.
        for (k, v) in upgrades { upgrades[k] = min(max(v, 0), Tuning.upgradeMaxTier) }
    }

    func tier(of kind: UpgradeKind) -> Int { upgrades[kind.rawValue] ?? 0 }
    mutating func setTier(_ tier: Int, of kind: UpgradeKind) { upgrades[kind.rawValue] = tier }
}

/// Owns the single `SaveData` instance and the JSON file in Documents.
final class SaveManager {
    static let shared = SaveManager()

    private(set) var data: SaveData
    private let fileURL: URL
    private let backupURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = docs.appendingPathComponent("bayblaster-save.json")
        backupURL = docs.appendingPathComponent("bayblaster-save.corrupt.json")
        data = SaveManager.load(from: fileURL, backupTo: backupURL)
    }

    /// Missing file → fresh save. Corrupt file → moved aside as *.corrupt.json, fresh save.
    private static func load(from url: URL, backupTo backup: URL) -> SaveData {
        guard FileManager.default.fileExists(atPath: url.path) else { return SaveData() }
        do {
            let raw = try Data(contentsOf: url)
            return try JSONDecoder().decode(SaveData.self, from: raw)
        } catch {
            print("[SaveManager] save file unreadable (\(error)); starting fresh")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return SaveData()
        }
    }

    /// Apply a change and write it to disk immediately (atomic write).
    func mutate(_ change: (inout SaveData) -> Void) {
        change(&data)
        persist()
    }

    func resetAll() {
        data = SaveData()
        persist()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: [.atomic])
        } catch {
            print("[SaveManager] failed to write save: \(error)")
        }
    }

    // MARK: Convenience

    var coins: Int { data.coins }
    var isMuted: Bool { data.muted }

    func toggleMute() { mutate { $0.muted.toggle() } }

    /// Returns true if the purchase went through.
    @discardableResult
    func buy(_ kind: UpgradeKind) -> Bool {
        let current = data.tier(of: kind)
        guard current < Tuning.upgradeMaxTier else { return false }
        let price = kind.price(forTier: current + 1)
        guard data.coins >= price else { return false }
        mutate {
            $0.coins -= price
            $0.setTier(current + 1, of: kind)
        }
        return true
    }

    /// Record the outcome of a run. Returns true if it set a new best distance.
    @discardableResult
    func recordRun(distance: Double, coins: Int, longestFlight: Double) -> Bool {
        var isNewBest = false
        mutate {
            $0.coins += coins
            $0.stats.totalRuns += 1
            $0.stats.totalDistance += distance
            $0.stats.longestFlightTime = max($0.stats.longestFlightTime, longestFlight)
            $0.stats.bestRunCoins = max($0.stats.bestRunCoins, coins)
            if distance > $0.bestDistance {
                $0.bestDistance = distance
                isNewBest = true
            }
        }
        return isNewBest
    }
}
