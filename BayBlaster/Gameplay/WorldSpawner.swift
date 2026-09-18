import SpriteKit

/// Procedurally places boosts and hazards ahead of the boat and recycles them once they are far
/// behind. Density and the hazard share both ramp with distance; the Lucky Lure upgrade scales
/// the boost share.
final class WorldSpawner {
    private weak var world: SKNode?
    private var entities: [WorldEntity] = []
    private var nextSpawnX: CGFloat = Tuning.spawnStartX
    private let boostWeightMultiplier: CGFloat

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
        let hazardFraction = lerp(Tuning.hazardFractionStart, Tuning.hazardFractionAt5000m, clamp(metres / 5000, 0, 1))
        let boostShare = (1 - hazardFraction) * boostWeightMultiplier
        let isBoost = CGFloat.random(in: 0..<1) < boostShare / (boostShare + hazardFraction)
        let kind = WorldSpawner.pick(from: isBoost ? EntityKind.boosts : EntityKind.hazards)

        let entity = WorldEntity(kind: kind)
        let spec = kind.spec
        entity.position = CGPoint(x: x, y: Tuning.waterY + CGFloat.random(in: spec.heightRange))
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
    }
}
