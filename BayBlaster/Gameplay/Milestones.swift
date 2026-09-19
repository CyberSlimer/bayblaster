import SpriteKit

/// Distance flags along the bay: one every `Tuning.milestoneIntervalMeters`, plus a gold
/// "YOUR BEST" flag at the saved best distance. Purely decorative nodes (no physics); the scene
/// is told when the boat passes one so it can celebrate.
final class Milestones {
    private weak var world: SKNode?
    private var flags: [(x: CGFloat, node: SKNode, isBest: Bool)] = []
    private var nextFlagMetres: CGFloat = Tuning.milestoneIntervalMeters
    private var bestMetres: CGFloat
    private var bestPlaced = false
    private var passedMetres: CGFloat = 0

    /// Called when the boat crosses a flag. `metres` is the flag's distance; `isBest` for the gold flag.
    var onPass: ((_ metres: CGFloat, _ isBest: Bool) -> Void)?

    init(world: SKNode, bestDistance: CGFloat) {
        self.world = world
        bestMetres = bestDistance
    }

    func update(playerX: CGFloat) {
        guard let world = world else { return }
        let playerMetres = playerX / Tuning.pointsPerMeter
        let horizon = playerMetres + Tuning.milestoneSpawnAhead / Tuning.pointsPerMeter

        // Regular flags
        while nextFlagMetres < horizon {
            // Don't stack a regular flag on top of the best flag.
            if abs(nextFlagMetres - bestMetres) > 8 {
                place(metres: nextFlagMetres, isBest: false, in: world)
            }
            nextFlagMetres += Tuning.milestoneIntervalMeters
        }
        // Best flag (only meaningful once a run has been recorded)
        if !bestPlaced, bestMetres > 0, bestMetres < horizon {
            place(metres: bestMetres, isBest: true, in: world)
            bestPlaced = true
        }

        // Passing + recycling
        for flag in flags where flag.x <= playerX && flag.x / Tuning.pointsPerMeter > passedMetres {
            passedMetres = flag.x / Tuning.pointsPerMeter
            celebrate(flag.node)
            onPass?(passedMetres, flag.isBest)
        }
        flags.removeAll { flag in
            if flag.x < playerX - Tuning.despawnBehindDistance {
                flag.node.removeFromParent()
                return true
            }
            return false
        }
    }

    private func place(metres: CGFloat, isBest: Bool, in world: SKNode) {
        let node = SKNode()
        node.position = CGPoint(x: metres * Tuning.pointsPerMeter, y: Tuning.waterY)
        node.zPosition = 15

        let flag = Art.sprite(isBest ? "bestFlag" : "flag")
        node.addChild(flag)

        let label = SKLabelNode.make(isBest ? "★ YOUR BEST ★" : "\(Int(metres)) m", size: isBest ? 16 : 18,
                                     font: Tuning.fontHeavy,
                                     color: isBest ? UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1) : .white)
        label.position = CGPoint(x: 0, y: 96)
        node.addChild(label)

        // Idle flutter
        flag.run(.repeatForever(.sequence([
            .scaleX(to: 0.92, duration: 0.5), .scaleX(to: 1.0, duration: 0.5)
        ])))

        world.addChild(node)
        flags.append((x: node.position.x, node: node, isBest: isBest))
    }

    private func celebrate(_ node: SKNode) {
        node.run(.sequence([
            .scale(to: 1.25, duration: 0.12),
            .scale(to: 1.0, duration: 0.2)
        ]))
    }

    func removeAll() {
        for f in flags { f.node.removeFromParent() }
        flags.removeAll()
    }
}
