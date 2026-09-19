import SpriteKit

/// Physics category bits.
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let boost: UInt32 = 1 << 1
    static let hazard: UInt32 = 1 << 2
    static let zone: UInt32 = 1 << 3
}

/// Marlow + the dinghy. Owns the physics body, hull integrity, rockets, and the per-frame
/// integration of gravity/drag/zone forces (the physics world's own gravity is zero).
final class Player: SKNode {

    enum State { case idle, flying, plowing, sunk }

    let config: UpgradeConfig
    private(set) var state: State = .idle
    private(set) var hull: CGFloat
    private(set) var rockets: Int
    var isDiving = false

    /// Counters bumped by zone entities (bird flocks / storm clouds) on contact begin/end.
    var liftZones = 0
    var downdraftZones = 0

    private(set) var currentFlightTime: CGFloat = 0
    private(set) var longestFlightTime: CGFloat = 0

    static let bodyRadius: CGFloat = 22

    let visual = SKNode()            // rotated to face the velocity
    private let boatNode: SKNode
    private let fishNode: SKNode
    let rocketTrail: SKEmitterNode
    private let wake: SKEmitterNode
    private var fishBob: CGFloat = 0

    init(config: UpgradeConfig) {
        self.config = config
        hull = config.maxHull
        rockets = config.rocketCount
        boatNode = Art.sprite("boat")
        fishNode = Art.sprite("fish")
        rocketTrail = Player.makeRocketTrail()
        wake = Player.makeWake()
        super.init()

        fishNode.position = CGPoint(x: -4, y: 18)
        visual.addChild(boatNode)
        visual.addChild(fishNode)
        addChild(visual)

        rocketTrail.position = CGPoint(x: -34, y: -2)
        rocketTrail.zPosition = -1
        visual.addChild(rocketTrail)

        wake.position = CGPoint(x: -30, y: -8)
        wake.zPosition = -1
        addChild(wake)

        let body = SKPhysicsBody(circleOfRadius: Player.bodyRadius, center: CGPoint(x: 0, y: 2))
        body.affectedByGravity = false           // integrated manually in update(dt:)
        body.allowsRotation = false
        body.linearDamping = 0
        body.angularDamping = 0
        body.friction = 0
        body.restitution = 0
        body.mass = 1
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none      // never physically collide; all responses are custom
        body.contactTestBitMask = PhysicsCategory.boost | PhysicsCategory.hazard | PhysicsCategory.zone
        body.usesPreciseCollisionDetection = true
        physicsBody = body
        zPosition = 50
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Velocity access

    var velocity: CGVector {
        get { physicsBody?.velocity ?? .zero }
        set { physicsBody?.velocity = newValue }
    }

    var boatSpeed: CGFloat {
        let v = velocity
        return (v.dx * v.dx + v.dy * v.dy).squareRoot()
    }

    var hullFraction: CGFloat { max(0, hull / config.maxHull) }

    // MARK: - State transitions

    func launch(velocity v: CGVector) {
        state = .flying
        velocity = v
        currentFlightTime = 0
        physicsBody?.isDynamic = true
    }

    /// Called by WaterSkipSystem when the boat lands too steep/slow to skip.
    func beginPlowing() {
        guard state == .flying else { return }
        state = .plowing
        position.y = Tuning.waterY + Tuning.plowOffsetY
        velocity = CGVector(dx: velocity.dx, dy: 0)
        endFlightSegment()
        wake.particleBirthRate = 60
    }

    /// A buoy / whale / shark can throw a plowing boat back into the air.
    func resumeFlying() {
        guard state == .plowing else { return }
        state = .flying
        currentFlightTime = 0
        wake.particleBirthRate = 0
    }

    func endFlightSegment() {
        longestFlightTime = max(longestFlightTime, currentFlightTime)
        currentFlightTime = 0
    }

    func sink() {
        state = .sunk
        endFlightSegment()
        wake.particleBirthRate = 0
        rocketTrail.particleBirthRate = 0
        physicsBody?.isDynamic = false
        let tilt = SKAction.rotate(toAngle: -0.9, duration: 0.8, shortestUnitArc: true)
        tilt.timingMode = .easeIn
        visual.run(tilt)
        let drop = SKAction.moveBy(x: 30, y: -70, duration: 1.4)
        drop.timingMode = .easeIn
        run(SKAction.group([drop, SKAction.fadeAlpha(to: 0.15, duration: 1.4)]))
    }

    /// Returns true if the hull is now empty (boat should sink).
    @discardableResult
    func applyDamage(_ amount: CGFloat) -> Bool {
        guard state != .sunk, amount > 0 else { return false }
        hull = max(0, hull - amount)
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
            SKAction.wait(forDuration: 0.08),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.2)
        ])
        for child in boatNode.children { child.run(flash) }
        return hull <= 0
    }

    /// Fire one rocket if airborne and any remain. Returns true on success.
    func fireRocket() -> Bool {
        guard state == .flying, rockets > 0 else { return false }
        rockets -= 1
        var v = velocity
        v.dx += config.rocketStrength
        v.dy += config.rocketStrength * Tuning.rocketVerticalFraction
        velocity = v
        rocketTrail.particleBirthRate = 220
        rocketTrail.removeAction(forKey: "trailOff")
        rocketTrail.run(SKAction.sequence([
            SKAction.wait(forDuration: Tuning.rocketBurstDuration),
            SKAction.run { [weak self] in self?.rocketTrail.particleBirthRate = 0 }
        ]), withKey: "trailOff")
        return true
    }

    // MARK: - Per-frame integration

    /// Integrates gravity, drag and zone forces into the physics velocity. SpriteKit then moves
    /// the body during its simulation step.
    func update(dt: CGFloat) {
        switch state {
        case .flying:
            var v = velocity
            let g = Tuning.gravity * (isDiving ? Tuning.diveGravityMultiplier : 1)
            v.dy += g * dt
            if liftZones > 0 {
                v.dy += Tuning.birdLift * dt
                v.dx += Tuning.birdPush * dt
            }
            if downdraftZones > 0 {
                v.dy -= Tuning.stormCloudPush * dt
            }
            let drag = max(0, 1 - config.airDrag * dt)
            v.dx *= drag
            v.dy *= drag
            velocity = v
            currentFlightTime += dt

            // Face the direction of travel; a nose-dive pitches further down.
            let target = clamp(atan2(v.dy, max(v.dx, 1)), -0.9, 0.7) - (isDiving ? 0.25 : 0)
            visual.zRotation = lerp(visual.zRotation, target, easeFactor(8, dt))

        case .plowing:
            var v = velocity
            v.dx *= exp(-Tuning.plowDrag * dt)
            v.dy = 0
            velocity = v
            position.y = Tuning.waterY + Tuning.plowOffsetY
            visual.zRotation = lerp(visual.zRotation, 0.05 * sin(fishBob * 6), easeFactor(6, dt))
            wake.particleBirthRate = max(0, v.dx / 12)

        case .idle, .sunk:
            break   // aim phase: GameScene points the visual along the cannon barrel
        }

        // Marlow bobs a little so he reads as alive.
        fishBob += dt
        fishNode.position.y = 18 + sin(fishBob * 7) * 1.5
    }

    // MARK: - Emitters

    private static func makeRocketTrail() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Art.particleTexture
        e.particleBirthRate = 0
        e.particleLifetime = 0.45
        e.particleLifetimeRange = 0.2
        e.particleSpeed = 140
        e.particleSpeedRange = 60
        e.emissionAngle = .pi
        e.emissionAngleRange = 0.5
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -2
        e.particleScale = 0.9
        e.particleScaleRange = 0.3
        e.particleScaleSpeed = -1.2
        e.particleColor = UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 1),
            UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1),
            UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        ], times: [0, 0.3, 1])
        e.particleBlendMode = .add
        return e
    }

    private static func makeWake() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Art.particleTexture
        e.particleBirthRate = 0
        e.particleLifetime = 0.5
        e.particleSpeed = 60
        e.particleSpeedRange = 40
        e.emissionAngle = .pi * 0.75
        e.emissionAngleRange = 0.8
        e.particleAlpha = 0.8
        e.particleAlphaSpeed = -1.6
        e.particleScale = 0.7
        e.particleScaleSpeed = -0.8
        e.particleColor = .white
        e.particleColorBlendFactor = 1
        return e
    }

    /// The emitters need `targetNode` set to the scene so particles are left behind in world space.
    func attachEmitters(to scene: SKScene) {
        rocketTrail.targetNode = scene
        wake.targetNode = scene
    }
}
