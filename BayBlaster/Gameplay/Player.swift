import SpriteKit

/// Physics category bits.
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let boost: UInt32 = 1 << 1
    static let hazard: UInt32 = 1 << 2
    static let zone: UInt32 = 1 << 3
}

/// The rider + the dinghy. Owns the physics body, hull integrity, rockets, the ability
/// cooldown, and the per-frame integration of gravity/drag/zone forces (the physics
/// world's own gravity is zero).
///
/// Which rider is drawn, which ability the ability button fires and which parts are bolted
/// to the hull all come from `config` (Core/Loadout.swift), which is resolved once before
/// the run starts and never changes during it.
final class Player: SKNode {

    enum State { case idle, flying, plowing, sunk }

    let config: UpgradeConfig
    private(set) var state: State = .idle
    private(set) var hull: CGFloat
    private(set) var rockets: Int
    var isDiving = false

    /// Counters bumped by zone entities (bird flocks / storm clouds / whirlpools) on contact begin/end.
    var liftZones = 0
    var downdraftZones = 0
    var whirlpoolZones = 0
    var jetStreamZones = 0

    /// Timed status effects (seconds remaining). Stun: jellyfish sting, no rockets or dive.
    /// Float: popped balloons, reduced gravity.
    private(set) var stunRemaining: CGFloat = 0
    private(set) var floatRemaining: CGFloat = 0
    var isStunned: Bool { stunRemaining > 0 }
    var isFloating: Bool { floatRemaining > 0 }

    // MARK: Ability state
    /// The rider's ability, its cooldown, and whichever timed effect is currently running.
    private(set) var activeAbility: Ability?
    private(set) var abilityActiveRemaining: CGFloat = 0
    private(set) var abilityCooldownRemaining: CGFloat = 0
    /// Hazards that will be soaked up before they land (Tock's shell).
    private(set) var shieldCharges = 0
    /// Armed by Bruno's belly slam; the landing it causes is a guaranteed, very bouncy skip.
    private(set) var slamArmed = false
    private(set) var abilityUses = 0

    var ability: Ability { config.ability }
    var isAbilityReady: Bool { abilityCooldownRemaining <= 0 && state == .flying && !isStunned }
    /// 0 = just fired, 1 = ready. Drives the HUD button's fill.
    var abilityChargeFraction: CGFloat {
        guard config.abilityCooldown > 0 else { return 1 }
        return clamp(1 - abilityCooldownRemaining / config.abilityCooldown, 0, 1)
    }
    var hasShield: Bool { shieldCharges > 0 }
    /// Chum's frenzy: hazards stop bleeding your speed (they still hurt the hull).
    var ignoresHazardSlowdown: Bool { activeAbility == .frenzy }
    /// Bristle's puff and Bruno's slam both force the next landing to skip.
    var forcesSkip: Bool { activeAbility == .puff || slamArmed }

    /// Seconds left of the launch tumble. While this is running the spin action owns
    /// `visual.zRotation`; `update` keeps its hands off so the two don't fight over it.
    private var tumbleRemaining: CGFloat = 0

    private(set) var currentFlightTime: CGFloat = 0
    private(set) var longestFlightTime: CGFloat = 0

    static let bodyRadius: CGFloat = 22

    let visual = SKNode()            // rotated to face the velocity
    private let boatNode: SKNode
    private let riderNode: SKNode
    private let gearNodes = SKNode()
    let rocketTrail: SKEmitterNode
    private let wake: SKEmitterNode
    private let abilityAura: SKShapeNode
    private var fishBob: CGFloat = 0

    init(config: UpgradeConfig) {
        self.config = config
        hull = config.maxHull
        rockets = config.rocketCount
        boatNode = Art.sprite("boat")
        riderNode = Art.sprite(config.crew.artKey)
        rocketTrail = Player.makeRocketTrail()
        wake = Player.makeWake()
        abilityAura = SKShapeNode(circleOfRadius: Player.bodyRadius + 16)
        super.init()

        riderNode.position = CGPoint(x: -4, y: 18)
        visual.addChild(gearNodes)                 // parts sit under the hull…
        visual.addChild(boatNode)
        visual.addChild(riderNode)
        addChild(visual)
        addGearArt()

        abilityAura.fillColor = .clear
        abilityAura.strokeColor = UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 0.9)
        abilityAura.lineWidth = 3
        abilityAura.alpha = 0
        abilityAura.zPosition = -2
        visual.addChild(abilityAura)

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

    /// Bolt the equipped parts onto the hull. Hull parts go underneath, rigs above, trinkets
    /// on the gunwale — so a kitted-out boat reads as kitted-out at a glance.
    private func addGearArt() {
        for item in config.equippedGear {
            let node = Art.sprite(item.artKey)
            switch item.slot {
            case .hull:    node.position = CGPoint(x: 0, y: -14)
            case .rig:     node.position = CGPoint(x: 2, y: 26); node.zPosition = -0.5
            case .trinket: node.position = CGPoint(x: 22, y: 8)
            }
            gearNodes.addChild(node)
        }
    }

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

    /// Height above the water line, in world points.
    var altitude: CGFloat { max(0, position.y - Tuning.waterY) }

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
        endTumble()
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
        endTumble()
        endFlightSegment()
        wake.particleBirthRate = 0
        rocketTrail.particleBirthRate = 0
        abilityAura.alpha = 0
        physicsBody?.isDynamic = false
        let tilt = SKAction.rotate(toAngle: -0.9, duration: 0.8, shortestUnitArc: true)
        tilt.timingMode = .easeIn
        visual.run(tilt)
        let drop = SKAction.moveBy(x: 30, y: -70, duration: 1.4)
        drop.timingMode = .easeIn
        run(SKAction.group([drop, SKAction.fadeAlpha(to: 0.15, duration: 1.4)]))
    }

    /// Returns true if the hull is now empty (boat should sink). `amount` is the raw hazard
    /// damage; the rider's and the plating's damage multipliers are applied here so no caller
    /// has to remember them.
    @discardableResult
    func applyDamage(_ amount: CGFloat) -> Bool {
        guard state != .sunk, amount > 0 else { return false }
        hull = max(0, hull - amount * config.damageMultiplier)
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05),
            SKAction.wait(forDuration: 0.08),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.2)
        ])
        for child in boatNode.children { child.run(flash) }
        return hull <= 0
    }

    /// Damage after the multipliers, for the "-25" floating label.
    func effectiveDamage(_ amount: CGFloat) -> CGFloat { amount * config.damageMultiplier }

    /// Spin out of the barrel, then hand the rotation back to `update`, which eases it toward
    /// the direction of travel from wherever the tumble finished.
    func tumble(turns: CGFloat, seconds: TimeInterval) {
        guard seconds > 0 else { return }
        tumbleRemaining = CGFloat(seconds)
        let spin = SKAction.rotate(byAngle: -.pi * 2 * turns, duration: seconds)
        spin.timingMode = .easeOut
        visual.removeAction(forKey: "tumble")
        visual.run(spin, withKey: "tumble")
    }

    private func endTumble() {
        tumbleRemaining = 0
        visual.removeAction(forKey: "tumble")
    }

    func stun(seconds: CGFloat) {
        stunRemaining = max(stunRemaining, seconds)
        isDiving = false
        let wobble = SKAction.sequence([
            SKAction.rotate(byAngle: 0.18, duration: 0.08), SKAction.rotate(byAngle: -0.36, duration: 0.16),
            SKAction.rotate(byAngle: 0.18, duration: 0.08)
        ])
        riderNode.run(SKAction.repeat(wobble, count: max(1, Int(seconds / 0.32))), withKey: "stun")
    }

    func float(seconds: CGFloat) {
        floatRemaining = max(floatRemaining, seconds)
    }

    /// Fire one rocket if airborne, not stunned, and any remain. Returns true on success.
    func fireRocket() -> Bool {
        guard state == .flying, rockets > 0, !isStunned else { return false }
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

    // MARK: - Abilities

    /// Fire the rider's ability if it is off cooldown. Everything the ability can do to the
    /// player itself happens here; `.swoop` additionally needs a target from the world, so
    /// GameScene finishes that one off.
    ///
    /// Returns the ability that fired, or nil if it wasn't ready.
    @discardableResult
    func beginAbility() -> Ability? {
        guard isAbilityReady else { return nil }
        let a = config.ability
        abilityCooldownRemaining = config.abilityCooldown
        abilityUses += 1

        if a.duration > 0 {
            activeAbility = a
            abilityActiveRemaining = a.duration
            showAura(for: a)
        }

        var v = velocity
        switch a {
        case .shell:
            shieldCharges += Tuning.abilityShellCharges
            showAura(for: a, seconds: 0)
        case .inkJet:
            v.dx += Tuning.abilityInkJetForward
            v.dy += Tuning.abilityInkJetUp
            velocity = v
            rocketTrail.particleBirthRate = 180
            rocketTrail.removeAction(forKey: "trailOff")
            rocketTrail.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.3),
                SKAction.run { [weak self] in self?.rocketTrail.particleBirthRate = 0 }
            ]), withKey: "trailOff")
        case .slam:
            v.dy = -max(Tuning.abilitySlamDownSpeed, -v.dy)
            velocity = v
            slamArmed = true
        case .tuck, .puff, .glide, .frenzy, .swoop:
            break   // timed effects run in update(dt:); swoop is finished by the scene
        }
        return a
    }

    /// GameScene's half of `.swoop`: point the flight at `target`, keeping almost all speed.
    func swoop(toward target: CGPoint) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 1 else { return }
        let speed = boatSpeed * Tuning.abilitySwoopSpeedKeep
        velocity = CGVector(dx: dx / length * speed, dy: dy / length * speed)
    }

    /// Spend a shield on an incoming hazard. Returns true if one was available.
    func consumeShield() -> Bool {
        guard shieldCharges > 0 else { return false }
        shieldCharges -= 1
        if shieldCharges == 0 { abilityAura.removeAllActions(); abilityAura.run(.fadeOut(withDuration: 0.2)) }
        return true
    }

    /// Consumed by WaterSkipSystem the moment the slam lands.
    func consumeSlam() -> Bool {
        guard slamArmed else { return false }
        slamArmed = false
        return true
    }

    private func showAura(for ability: Ability, seconds: CGFloat? = nil) {
        let colour: UIColor
        switch ability {
        case .tuck:   colour = UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)
        case .puff:   colour = UIColor(red: 1, green: 0.85, blue: 0.45, alpha: 1)
        case .glide:  colour = UIColor(red: 0.75, green: 1, blue: 0.85, alpha: 1)
        case .shell:  colour = UIColor(red: 1, green: 0.75, blue: 0.35, alpha: 1)
        case .frenzy: colour = UIColor(red: 1, green: 0.45, blue: 0.45, alpha: 1)
        default:      colour = UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1)
        }
        abilityAura.strokeColor = colour
        abilityAura.removeAllActions()
        abilityAura.alpha = 0.9
        let hold = seconds ?? ability.duration
        if hold > 0 {
            abilityAura.run(.sequence([
                .repeat(.sequence([.scale(to: 1.12, duration: 0.3), .scale(to: 1, duration: 0.3)]),
                        count: max(1, Int(hold / 0.6))),
                .fadeOut(withDuration: 0.2)
            ]))
        } else {
            // Shell has no duration — the ring stays until a hazard eats it.
            abilityAura.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.5),
                                                      .fadeAlpha(to: 0.9, duration: 0.5)])))
        }
    }

    // MARK: - Per-frame integration

    /// Integrates gravity, drag and zone forces into the physics velocity. SpriteKit then moves
    /// the body during its simulation step.
    func update(dt: CGFloat) {
        stunRemaining = max(0, stunRemaining - dt)
        floatRemaining = max(0, floatRemaining - dt)
        abilityCooldownRemaining = max(0, abilityCooldownRemaining - dt)
        tumbleRemaining = max(0, tumbleRemaining - dt)
        if abilityActiveRemaining > 0 {
            abilityActiveRemaining -= dt
            if abilityActiveRemaining <= 0 { abilityActiveRemaining = 0; activeAbility = nil }
        }
        if isStunned { isDiving = false }

        switch state {
        case .flying:
            var v = velocity
            var gMult: CGFloat = isDiving ? Tuning.diveGravityMultiplier : 1
            if isFloating { gMult *= Tuning.balloonGravityMultiplier }
            gMult *= config.gravityMultiplier                     // Box Kite, featherweight days
            var dragRate = config.airDrag

            // The rider's timed ability, if one is running.
            if let active = activeAbility {
                switch active {
                case .tuck:
                    dragRate *= Tuning.abilityTuckDragMultiplier
                    v.dx += Tuning.abilityTuckPush * dt
                case .glide:
                    gMult *= Tuning.abilityGlideGravityMultiplier
                    v.dx += Tuning.abilityGlidePush * dt
                case .puff, .frenzy:
                    break   // read by WaterSkipSystem / GameScene, not by the integrator
                case .shell, .inkJet, .slam, .swoop:
                    break   // instant: never left running
                }
            }

            v.dy += Tuning.gravity * gMult * dt
            v.dx += config.sailPush * dt                          // Storm Sail
            if liftZones > 0 {
                v.dy += Tuning.birdLift * dt
                v.dx += Tuning.birdPush * dt
            }
            if jetStreamZones > 0 {
                // A river of wind high up: a hard forward shove and just enough lift to keep
                // you in it, so climbing into one is the pay-off for a big launch.
                v.dx += Tuning.jetStreamPush * dt
                v.dy += Tuning.jetStreamLift * dt
            }
            if downdraftZones > 0 {
                // With a Storm Sail rigged, a squall drives you along instead of down.
                if config.stormPushesForward {
                    v.dx += Tuning.stormCloudPush * dt
                } else {
                    v.dy -= Tuning.stormCloudPush * dt
                }
            }
            var drag = max(0, 1 - dragRate * dt)
            if whirlpoolZones > 0 {
                v.dy -= Tuning.whirlpoolPull * dt
                drag *= max(0, 1 - Tuning.whirlpoolDrag * dt)
            }
            v.dx *= drag
            v.dy *= drag
            velocity = v
            currentFlightTime += dt

            // Face the direction of travel; a nose-dive pitches further down. Skipped while the
            // launch tumble is spinning, which owns the rotation until it finishes.
            if tumbleRemaining <= 0 {
                let target = clamp(atan2(v.dy, max(v.dx, 1)), -0.9, 0.7) - (isDiving ? 0.25 : 0)
                visual.zRotation = lerp(visual.zRotation, target, easeFactor(8, dt))
            }

        case .plowing:
            var v = velocity
            v.dx *= exp(-config.plowDrag * dt)                    // Beach Wheels live here
            if whirlpoolZones > 0 { v.dx *= exp(-Tuning.whirlpoolDrag * 3 * dt) }
            v.dy = 0
            velocity = v
            position.y = Tuning.waterY + Tuning.plowOffsetY
            visual.zRotation = lerp(visual.zRotation, 0.05 * sin(fishBob * 6), easeFactor(6, dt))
            wake.particleBirthRate = max(0, v.dx / 12)

        case .idle, .sunk:
            break   // aim phase: GameScene points the visual along the cannon barrel
        }

        // The rider bobs a little so they read as alive.
        fishBob += dt
        riderNode.position.y = 18 + sin(fishBob * 7) * 1.5
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
