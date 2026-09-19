import Foundation

/// Lifetime statistics shown on the title screen.
struct Stats: Codable, Equatable {
    var totalRuns: Int = 0
    var totalDistance: Double = 0          // metres
    var longestFlightTime: Double = 0      // seconds airborne in a single hop
    var bestRunCoins: Int = 0
    var abilitiesUsed: Int = 0             // lifetime ability activations

    init() {}

    // Tolerant decoding: any missing key falls back to its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalRuns = try c.decodeIfPresent(Int.self, forKey: .totalRuns) ?? 0
        totalDistance = try c.decodeIfPresent(Double.self, forKey: .totalDistance) ?? 0
        longestFlightTime = try c.decodeIfPresent(Double.self, forKey: .longestFlightTime) ?? 0
        bestRunCoins = try c.decodeIfPresent(Int.self, forKey: .bestRunCoins) ?? 0
        abilitiesUsed = try c.decodeIfPresent(Int.self, forKey: .abilitiesUsed) ?? 0
    }
}

/// Everything that persists between launches of the app.
///
/// Decoding is deliberately forgiving — every key is `decodeIfPresent` with a default — so a
/// save written by an older build never crashes a newer one. A v1 save (before crew, gear,
/// launchers, achievements, prestige and the daily challenge existed) loads straight into a
/// v2 save with the starter rider and the cannon selected.
struct SaveData: Codable, Equatable {
    static let currentVersion = 2

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

    // MARK: Locker (v2)
    var ownedCrew: [String] = [CrewMember.starter.rawValue]        // CrewMember.rawValue
    var selectedCrew: String = CrewMember.starter.rawValue
    var ownedGear: [String] = []                                   // GearItem.rawValue
    var equippedGear: [String: String] = [:]                       // GearSlot.rawValue → GearItem.rawValue
    var ownedLaunchers: [String] = [LauncherKind.starter.rawValue] // LauncherKind.rawValue
    var selectedLauncher: String = LauncherKind.starter.rawValue
    var seenAbilities: [String] = []                               // Ability.rawValue, for the first-use tip

    // MARK: Long tail (v2)
    var achievements: [String] = []        // Achievement.rawValue
    var prestigeLevel: Int = 0
    var dailyDateKey: String = ""          // the day `dailyBestDistance` belongs to
    var dailyBestDistance: Double = 0
    var dailyRewardClaimed: Bool = false
    var dailyStreak: Int = 0
    var dailyLastClaimedKey: String = ""

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

        ownedCrew = try c.decodeIfPresent([String].self, forKey: .ownedCrew) ?? []
        selectedCrew = try c.decodeIfPresent(String.self, forKey: .selectedCrew) ?? CrewMember.starter.rawValue
        ownedGear = try c.decodeIfPresent([String].self, forKey: .ownedGear) ?? []
        equippedGear = try c.decodeIfPresent([String: String].self, forKey: .equippedGear) ?? [:]
        ownedLaunchers = try c.decodeIfPresent([String].self, forKey: .ownedLaunchers) ?? []
        selectedLauncher = try c.decodeIfPresent(String.self, forKey: .selectedLauncher) ?? LauncherKind.starter.rawValue
        seenAbilities = try c.decodeIfPresent([String].self, forKey: .seenAbilities) ?? []

        achievements = try c.decodeIfPresent([String].self, forKey: .achievements) ?? []
        prestigeLevel = max(0, try c.decodeIfPresent(Int.self, forKey: .prestigeLevel) ?? 0)
        dailyDateKey = try c.decodeIfPresent(String.self, forKey: .dailyDateKey) ?? ""
        dailyBestDistance = try c.decodeIfPresent(Double.self, forKey: .dailyBestDistance) ?? 0
        dailyRewardClaimed = try c.decodeIfPresent(Bool.self, forKey: .dailyRewardClaimed) ?? false
        dailyStreak = max(0, try c.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0)
        dailyLastClaimedKey = try c.decodeIfPresent(String.self, forKey: .dailyLastClaimedKey) ?? ""

        // Clamp anything a hand-edited (or older) file might have pushed out of range.
        for (k, v) in upgrades { upgrades[k] = min(max(v, 0), Tuning.upgradeMaxTier) }
        sanitizeLocker()
    }

    /// Drop unknown raw values, guarantee the starter rider/launcher, and make sure the
    /// selection and the equipped parts are things the player actually owns. Runs after
    /// every decode and after every locker change.
    mutating func sanitizeLocker() {
        let crewNames = Set(CrewMember.allCases.map { $0.rawValue })
        ownedCrew = Array(Set(ownedCrew.filter { crewNames.contains($0) })).sorted()
        if !ownedCrew.contains(CrewMember.starter.rawValue) { ownedCrew.append(CrewMember.starter.rawValue) }
        if !ownedCrew.contains(selectedCrew) { selectedCrew = CrewMember.starter.rawValue }

        let launcherNames = Set(LauncherKind.allCases.map { $0.rawValue })
        ownedLaunchers = Array(Set(ownedLaunchers.filter { launcherNames.contains($0) })).sorted()
        if !ownedLaunchers.contains(LauncherKind.starter.rawValue) { ownedLaunchers.append(LauncherKind.starter.rawValue) }
        if !ownedLaunchers.contains(selectedLauncher) { selectedLauncher = LauncherKind.starter.rawValue }

        let gearNames = Set(GearItem.allCases.map { $0.rawValue })
        ownedGear = Array(Set(ownedGear.filter { gearNames.contains($0) })).sorted()
        for (slot, item) in equippedGear {
            let slotIsReal = GearSlot(rawValue: slot) != nil
            let itemIsOwned = ownedGear.contains(item)
            let itemFitsSlot = GearItem(rawValue: item)?.slot.rawValue == slot
            if !slotIsReal || !itemIsOwned || !itemFitsSlot { equippedGear[slot] = nil }
        }

        let achievementNames = Set(Achievement.allCases.map { $0.rawValue })
        achievements = Array(Set(achievements.filter { achievementNames.contains($0) })).sorted()
    }

    func tier(of kind: UpgradeKind) -> Int { upgrades[kind.rawValue] ?? 0 }
    mutating func setTier(_ tier: Int, of kind: UpgradeKind) { upgrades[kind.rawValue] = tier }

    // MARK: Locker convenience

    var ownedCrewMembers: [CrewMember] { ownedCrew.compactMap { CrewMember(rawValue: $0) } }
    var selectedCrewMember: CrewMember { CrewMember(rawValue: selectedCrew) ?? .starter }
    var ownedGearItems: [GearItem] { ownedGear.compactMap { GearItem(rawValue: $0) } }
    var ownedLauncherKinds: [LauncherKind] { ownedLaunchers.compactMap { LauncherKind(rawValue: $0) } }
    var selectedLauncherKind: LauncherKind { LauncherKind(rawValue: selectedLauncher) ?? .starter }

    func owns(_ crew: CrewMember) -> Bool { ownedCrew.contains(crew.rawValue) }
    func owns(_ item: GearItem) -> Bool { ownedGear.contains(item.rawValue) }
    func owns(_ launcher: LauncherKind) -> Bool { ownedLaunchers.contains(launcher.rawValue) }

    func equippedItem(in slot: GearSlot) -> GearItem? {
        equippedGear[slot.rawValue].flatMap { GearItem(rawValue: $0) }
    }

    /// The equipped parts, at most one per slot, in slot order.
    var equippedGearItems: [GearItem] { GearSlot.allCases.compactMap { equippedItem(in: $0) } }

    func isEquipped(_ item: GearItem) -> Bool { equippedGear[item.slot.rawValue] == item.rawValue }

    /// True once every shop track is at max tier — the gate on casting off.
    var canPrestige: Bool { UpgradeKind.allCases.allSatisfy { tier(of: $0) >= Tuning.upgradeMaxTier } }
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
        data.version = SaveData.currentVersion
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

    // MARK: Locker

    /// Buy a rider. A newly bought rider is selected straight away — you bought it to use it.
    @discardableResult
    func buyCrew(_ crew: CrewMember) -> Bool {
        guard !data.owns(crew), data.coins >= crew.price else { return false }
        mutate {
            $0.coins -= crew.price
            $0.ownedCrew.append(crew.rawValue)
            $0.selectedCrew = crew.rawValue
            $0.sanitizeLocker()
        }
        return true
    }

    @discardableResult
    func selectCrew(_ crew: CrewMember) -> Bool {
        guard data.owns(crew) else { return false }
        mutate { $0.selectedCrew = crew.rawValue }
        return true
    }

    /// Buy a part. It is equipped immediately, replacing whatever was in its slot.
    @discardableResult
    func buyGear(_ item: GearItem) -> Bool {
        guard !data.owns(item), data.coins >= item.price else { return false }
        mutate {
            $0.coins -= item.price
            $0.ownedGear.append(item.rawValue)
            $0.equippedGear[item.slot.rawValue] = item.rawValue
            $0.sanitizeLocker()
        }
        return true
    }

    /// Equip an owned part, or unequip it if it is already in its slot (running a slot
    /// empty is a legitimate build — pontoons cost you air drag, plating costs you speed).
    @discardableResult
    func toggleGear(_ item: GearItem) -> Bool {
        guard data.owns(item) else { return false }
        let alreadyOn = data.isEquipped(item)
        mutate {
            $0.equippedGear[item.slot.rawValue] = alreadyOn ? nil : item.rawValue
            $0.sanitizeLocker()
        }
        return true
    }

    @discardableResult
    func buyLauncher(_ launcher: LauncherKind) -> Bool {
        guard !data.owns(launcher), data.coins >= launcher.price else { return false }
        mutate {
            $0.coins -= launcher.price
            $0.ownedLaunchers.append(launcher.rawValue)
            $0.selectedLauncher = launcher.rawValue
            $0.sanitizeLocker()
        }
        return true
    }

    @discardableResult
    func selectLauncher(_ launcher: LauncherKind) -> Bool {
        guard data.owns(launcher) else { return false }
        mutate { $0.selectedLauncher = launcher.rawValue }
        return true
    }

    // MARK: Prestige

    /// Cast off: hand back the coins and all five upgrade tracks for a permanent coin
    /// multiplier. The locker (riders, gear, launchers), achievements, best distance and
    /// lifetime stats all survive — only the grind resets.
    @discardableResult
    func prestige() -> Bool {
        guard data.canPrestige else { return false }
        mutate {
            $0.coins = 0
            $0.upgrades = [:]
            $0.prestigeLevel += 1
        }
        return true
    }

    // MARK: Runs

    /// Record the outcome of a run. Returns true if it set a new best distance.
    @discardableResult
    func recordRun(distance: Double, coins: Int, longestFlight: Double, abilitiesUsed: Int = 0) -> Bool {
        var isNewBest = false
        mutate {
            $0.coins += coins
            $0.stats.totalRuns += 1
            $0.stats.totalDistance += distance
            $0.stats.longestFlightTime = max($0.stats.longestFlightTime, longestFlight)
            $0.stats.bestRunCoins = max($0.stats.bestRunCoins, coins)
            $0.stats.abilitiesUsed += abilitiesUsed
            if distance > $0.bestDistance {
                $0.bestDistance = distance
                isNewBest = true
            }
        }
        return isNewBest
    }

    // MARK: Daily challenge

    /// Roll the stored daily state over to `challenge` if it belongs to an earlier day.
    /// Safe to call as often as you like.
    func refreshDaily(_ challenge: DailyChallenge) {
        guard data.dailyDateKey != challenge.dateKey else { return }
        mutate {
            $0.dailyDateKey = challenge.dateKey
            $0.dailyBestDistance = 0
            $0.dailyRewardClaimed = false
            // A missed day breaks the streak; the day before today still counts.
            if $0.dailyLastClaimedKey != challenge.previousDateKey && $0.dailyLastClaimedKey != challenge.dateKey {
                $0.dailyStreak = 0
            }
        }
    }

    struct DailyOutcome {
        let reward: Int          // 0 if today's reward was already claimed
        let isFirstToday: Bool
        let isDailyBest: Bool
        let streak: Int
    }

    /// Record a finished daily run. The reward is paid once per day; later attempts still
    /// update the day's best distance for the title screen.
    @discardableResult
    func recordDaily(distance: Double, challenge: DailyChallenge) -> DailyOutcome {
        refreshDaily(challenge)
        var reward = 0
        var isFirst = false
        var isBest = false
        var streak = data.dailyStreak
        mutate {
            if distance > $0.dailyBestDistance {
                $0.dailyBestDistance = distance
                isBest = true
            }
            if !$0.dailyRewardClaimed {
                isFirst = true
                $0.dailyRewardClaimed = true
                $0.dailyStreak = ($0.dailyLastClaimedKey == challenge.previousDateKey) ? $0.dailyStreak + 1 : 1
                $0.dailyLastClaimedKey = challenge.dateKey
                streak = $0.dailyStreak
                reward = challenge.reward(metres: distance, streak: streak)
                $0.coins += reward
            }
        }
        return DailyOutcome(reward: reward, isFirstToday: isFirst, isDailyBest: isBest, streak: streak)
    }
}
