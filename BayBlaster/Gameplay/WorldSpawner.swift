import SpriteKit

/// Procedurally places boosts and hazards ahead of the boat and recycles them once they are far
/// behind. Density and the hazard share both ramp with distance; the Lucky Lure upgrade and the
/// Lucky Horseshoe trinket scale the boost share, and a daily modifier can push the hazard share
/// up for the day.
///
/// Every random draw goes through `RandomSource`. On a normal run that is the system generator;
/// on a daily challenge it is seeded from the date, so the whole bay is laid out identically for
/// every attempt that day.
final class WorldSpawner {
    private weak var world: SKNode?
    private var entities: [WorldEntity] = []
    private var nextSpawnX: CGFloat = Tuning.spawnStartX
    private let boostWeightMultiplier: CGFloat
    private let coinArcChance: CGFloat
    private let hazardFractionBonus: CGFloat
    private var lastWasWaterHazard = false
    private var rng: RandomSource

    init(world: SKNode, config: UpgradeConfig, seed: UInt64? = nil) {
        self.world = world
        boostWeightMultiplier = config.boostWeightMultiplier
        coinArcChance = config.coinArcChance
        hazardFractionBonus = config.hazardFractionBonus
        rng = RandomSource(seed: seed)
    }

    func update(playerX: CGFloat) {
        // Spawn ahead
        while nextSpawnX < playerX + Tuning.spawnAheadDistance {
            spawn(at: nextSpawnX)
            let metres = nextSpawnX / Tuning.pointsPerMeter
            let density = 1 + clamp(metres / Tuning.densityRampMeters, 0, 1) * Tuning.densityRampMax
            let gap = rng.cgFloat(in: Tuning.spawnIntervalMeters) * Tuning.pointsPerMeter / density
            nextSpawnX += gap
        }
        // Recycle behind (and drop anything that already removed itself)
        entities.removeAll { e in
            if e.parent == nil { return true }
            if e.position.x < playerX - Tuning.despawnBehindDistance {
                e.removeFromParent()
                return true
            }
            return false
        }
    }

    private func spawn(at x: CGFloat) {
        guard let world = world else { return }
        let metres = x / Tuning.pointsPerMeter
        var hazardFraction = lerp(Tuning.hazardFractionStart, Tuning.hazardFractionAt5000m, clamp(metres / 5000, 0, 1))
        hazardFraction = clamp(hazardFraction + hazardFractionBonus, 0, 0.85)
        // Two waterline hazards in a row make a wall the player can't do anything about.
        if lastWasWaterHazard { hazardFraction *= Tuning.hazardRepeatPenalty }
        let boostShare = (1 - hazardFraction) * boostWeightMultiplier
        let isBoost = rng.unit() < boostShare / (boostShare + hazardFraction)

        if isBoost, rng.unit() < coinArcChance {
            spawnCoinArc(at: x, in: world)
            lastWasWaterHazard = false
            return
        }

        let pool = (isBoost ? EntityKind.boosts : EntityKind.hazards).filter { $0.unlockMetres <= metres }
        let kind = pick(from: pool)
        lastWasWaterHazard = kind.isWaterHazard
        let height = kind.spec.heightRange
        place(kind, at: CGPoint(x: x, y: Tuning.waterY + rng.cgFloat(in: height)), in: world)
    }

    /// A gentle parabola of small coins — a line the player can *aim* for. The arc peaks in the
    /// middle so following it through rewards a well-timed rocket or dive.
    private func spawnCoinArc(at x: CGFloat, in world: SKNode) {
        let count = rng.int(in: Tuning.coinArcCount)
        let peak = Tuning.waterY + rng.cgFloat(in: Tuning.coinArcHeightRange)
        let rise = Tuning.coinArcRise * rng.cgFloat(in: 0.5...1.2)
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(max(count - 1, 1))       // 0…1 along the arc
            let curve = 1 - pow((t - 0.5) * 2, 2)                  // 0 at ends, 1 in the middle
            let y = max(peak - rise + rise * curve, Tuning.waterY + 30)
            place(.coin, at: CGPoint(x: x + CGFloat(i) * Tuning.coinArcSpacing, y: y), in: world)
        }
        // Skip ahead so the next spawn doesn't land inside the arc.
        nextSpawnX += CGFloat(count) * Tuning.coinArcSpacing
    }

    private func place(_ kind: EntityKind, at position: CGPoint, in world: SKNode) {
        let entity = WorldEntity(kind: kind)
        entity.position = position
        world.addChild(entity)
        entities.append(entity)
    }

    private func pick(from kinds: [EntityKind]) -> EntityKind {
        let total = kinds.reduce(CGFloat(0)) { $0 + $1.spec.weight }
        var r = rng.cgFloat(in: 0...total)
        for k in kinds {
            r -= k.spec.weight
            if r <= 0 { return k }
        }
        return kinds[kinds.count - 1]
    }

    /// Uncollected coins within `radius` of `point` — the Coin Magnet's shopping list.
    func magnetisableCoins(near point: CGPoint, radius: CGFloat) -> [WorldEntity] {
        guard radius > 0 else { return [] }
        let r2 = radius * radius
        return entities.filter { e in
            guard e.kind == .coin, !e.consumed, e.parent != nil else { return false }
            let dx = e.position.x - point.x, dy = e.position.y - point.y
            return dx * dx + dy * dy <= r2
        }
    }

    func removeAll() {
        for e in entities { e.removeFromParent() }
        entities.removeAll()
        nextSpawnX = Tuning.spawnStartX
        lastWasWaterHazard = false
    }
}
