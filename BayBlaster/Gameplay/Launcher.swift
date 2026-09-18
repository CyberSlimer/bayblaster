import SpriteKit

/// The Old Lighthouse Cannon. Sweeps an angle, then a power value; two taps lock them.
/// Purely visual + timing — GameScene reads `angleDegrees`/`power` and launches the boat.
final class Launcher: SKNode {

    enum AimState { case sweepingAngle, sweepingPower, fired }
    private(set) var aimState: AimState = .sweepingAngle

    private(set) var angleDegrees: CGFloat = 45
    private(set) var power: CGFloat = 0.5
    private var clock: CGFloat = 0

    private let tower: SKNode
    private let barrel: SKNode
    private let trajectory = SKNode()
    private var trajectoryDots: [SKShapeNode] = []
    private let muzzleFlash: SKEmitterNode

    /// World-space point at the end of the barrel.
    var muzzlePoint: CGPoint {
        let a = angleDegrees * .pi / 180
        return CGPoint(x: barrel.position.x + cos(a) * Tuning.launcherBarrelLength,
                       y: barrel.position.y + sin(a) * Tuning.launcherBarrelLength)
    }

    var barrelAngle: CGFloat { angleDegrees * .pi / 180 }

    override init() {
        tower = Art.sprite("lighthouse")
        barrel = Art.sprite("cannon")
        muzzleFlash = Launcher.makeMuzzleFlash()
        super.init()

        tower.position = CGPoint(x: Tuning.launcherPivotX - 40, y: Tuning.waterY)
        tower.zPosition = 5
        addChild(tower)

        barrel.position = CGPoint(x: Tuning.launcherPivotX, y: Tuning.waterY + Tuning.launchHeight)
        barrel.zPosition = 60          // in front of the boat so it looks loaded in the muzzle
        addChild(barrel)

        muzzleFlash.zPosition = 61
        addChild(muzzleFlash)

        trajectory.zPosition = 4
        trajectory.isHidden = true          // shown once the aim sweep starts
        addChild(trajectory)
        for i in 0..<14 {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = UIColor.white.withAlphaComponent(0.65 - CGFloat(i) * 0.035)
            dot.strokeColor = .clear
            trajectory.addChild(dot)
            trajectoryDots.append(dot)
        }
        updateBarrel()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Aim loop

    func update(dt: CGFloat, launchSpeed: CGFloat) {
        clock += dt
        trajectory.isHidden = aimState == .fired
        switch aimState {
        case .sweepingAngle:
            // Triangle wave between min and max angle.
            let phase = (clock / Tuning.angleSweepPeriod).truncatingRemainder(dividingBy: 1)
            let tri = phase < 0.5 ? phase * 2 : 2 - phase * 2
            angleDegrees = lerp(Tuning.launchAngleMinDegrees, Tuning.launchAngleMaxDegrees, tri)
            updateBarrel()
            updateTrajectory(speed: launchSpeed * 0.8)
        case .sweepingPower:
            let phase = (clock / Tuning.powerSweepPeriod).truncatingRemainder(dividingBy: 1)
            power = phase < 0.5 ? phase * 2 : 2 - phase * 2
            updateTrajectory(speed: launchSpeed * lerp(Tuning.minPowerFraction, 1, power))
        case .fired:
            break
        }
    }

    func lockAngle() {
        guard aimState == .sweepingAngle else { return }
        aimState = .sweepingPower
        clock = 0
        barrel.run(.sequence([.scale(to: 1.08, duration: 0.06), .scale(to: 1, duration: 0.1)]))
    }

    func lockPower() {
        guard aimState == .sweepingPower else { return }
        aimState = .fired
    }

    /// Recoil + flash. Call right after the boat leaves.
    func fire() {
        trajectory.run(.fadeOut(withDuration: 0.3))
        let a = barrelAngle
        let kick = CGVector(dx: -cos(a) * 14, dy: -sin(a) * 14)
        barrel.run(.sequence([
            .move(by: kick, duration: 0.05),
            .move(by: CGVector(dx: -kick.dx, dy: -kick.dy), duration: 0.35)
        ]))
        muzzleFlash.position = muzzlePoint
        muzzleFlash.emissionAngle = a
        muzzleFlash.resetSimulation()
        muzzleFlash.particleBirthRate = 600
        muzzleFlash.run(.sequence([.wait(forDuration: 0.12), .run { [weak self] in self?.muzzleFlash.particleBirthRate = 0 }]))
    }

    private func updateBarrel() {
        barrel.zRotation = barrelAngle
    }

    /// Preview arc for the current angle/speed (ignores drag; it's a hint, not a promise).
    private func updateTrajectory(speed: CGFloat) {
        let a = barrelAngle
        let vx = cos(a) * speed
        let vy = sin(a) * speed
        let start = muzzlePoint
        for (i, dot) in trajectoryDots.enumerated() {
            let t = CGFloat(i + 1) * 0.16
            let x = start.x + vx * t
            let y = start.y + vy * t + 0.5 * Tuning.gravity * t * t
            dot.position = CGPoint(x: x, y: y)
            dot.isHidden = y < Tuning.waterY
        }
    }

    private static func makeMuzzleFlash() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Art.particleTexture
        e.particleBirthRate = 0
        e.particleLifetime = 0.35
        e.particleLifetimeRange = 0.15
        e.particleSpeed = 320
        e.particleSpeedRange = 160
        e.emissionAngleRange = 0.7
        e.particleAlpha = 1
        e.particleAlphaSpeed = -2.5
        e.particleScale = 1.4
        e.particleScaleRange = 0.5
        e.particleScaleSpeed = -1.5
        e.particleColor = UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        return e
    }
}
