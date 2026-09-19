import SpriteKit

/// Procedurally places boosts and hazards ahead of the boat and recycles them once they are far
/// behind. Density and the hazard share both ramp with distance; the Lucky Lure upgrade scales
/// the boost share.
final class WorldSpawner {
    private weak var world: SKNode?
    private var entities: [WorldEntity] = []
    private var nextSpawnX: CGFloat = Tuning.spawnStartX
    private let boostWeightMultiplier: CGFloat
    private var lastWasWaterHazard = false

    init(world: SKNode, config: UpgradeConfig) {
        self.world = world
        boostWeightMultiplier = config.boostWeightMultiplier
    }

    func update(playerX: CGFloat) {
        // Spawn ahead
        while nextSpawnX < playerX + Tuning.spawnAheadDistance {
            spawn(at: nextSpawnX)
            let metres = nextSpawnX / Tuning.pointsPerMeter
            let density = 1 + clamp(metres / Tuning.densityRampMeters, 0, 1) * Tuning.densityRampMax
            let gap = CGFloat.random(in: Tuning.spawnIntervalMeters) * Tuning.pointsPerMeter / density
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
        // Two waterline hazards in a row make a wall the player can't do anything about.
        if lastWasWaterHazard { hazardFraction *= Tuning.hazardRepeatPenalty }
        let boostShare = (1 - hazardFraction) * boostWeightMultiplier
        let isBoost = CGFloat.random(in: 0..<1) < boostShare / (boostShare + hazardFraction)

        if isBoost, CGFloat.random(in: 0..<1) < Tuning.coinArcChance {
            spawnCoinArc(at: x, in: world)
            lastWasWaterHazard = false
            return
        }

        let kind = WorldSpawner.pick(from: isBoost ? EntityKind.boosts : EntityKind.hazards)
        lastWasWaterHazard = kind.isWaterHazard
        place(kind, at: CGPoint(x: x, y: Tuning.waterY + CGFloat.random(in: kind.spec.heightRange)), in: world)
    }

    /// A gentle parabola of small coins — a line the player can *aim* for. The arc peaks in the
    /// middle so following it through rewards a well-timed rocket or dive.
    private func spawnCoinArc(at x: CGFloat, in world: SKNode) {
        let count = Int.random(in: Tuning.coinArcCount)
        let peak = Tuning.waterY + CGFloat.random(in: Tuning.coinArcHeightRange)
        let rise = Tuning.coinArcRise * CGFloat.random(in: 0.5...1.2)
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

    private static func pick(from kinds: [EntityKind]) -> EntityKind {
        let total = kinds.reduce(CGFloat(0)) { $0 + $1.spec.weight }
        var r = CGFloat.random(in: 0..<total)
        for k in kinds {
            r -= k.spec.weight
            if r <= 0 { return k }
        }
        return kinds[kinds.count - 1]
    }

    func removeAll() {
        for e in entities { e.removeFromParent() }
        entities.removeAll()
        nextSpawnX = Tuning.spawnStartX
        lastWasWaterHazard = false
    }
}
