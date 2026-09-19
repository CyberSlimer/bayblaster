import SpriteKit

/// Whatever is firing you out over the bay. Sweeps an angle, then plays the selected
/// launcher's power ritual; GameScene reads `angleDegrees` / `power` / `speedMultiplier`
/// and launches the boat.
///
/// Three rituals, chosen by `LauncherKind.spec.aimMode` (see Core/Launchers.swift):
///
///   .twoSweep    angle sweeps, tap; power sweeps, tap.  (cannon, torpedo)
///   .castTiming  angle sweeps, tap; a fast cast bar runs past a green band — tap inside it
///                for `sweetSpotBonus` speed.            (rod & reel)
///   .charge      angle sweeps, tap; then HOLD to draw the band back and release to fire.
///                Hold past full draw for longer than `overchargeGrace` and it snaps.
///                                                       (slingshot)
final class Launcher: SKNode {

    enum AimState { case sweepingAngle, sweepingPower, fired }
    private(set) var aimState: AimState = .sweepingAngle

    let kind: LauncherKind
    private let spec: LauncherKind.Spec

    private(set) var angleDegrees: CGFloat
    private(set) var power: CGFloat = 0.5
    /// True once a .charge launcher has been held past full draw and let go.
    private(set) var didSnap = false
    /// True when a .castTiming lock landed inside the green band.
    private(set) var didHitSweetSpot = false

    private var clock: CGFloat = 0
    private var chargeHeld = false
    private var overchargeClock: CGFloat = 0

    private let tower: SKNode
    private let barrel: SKNode
    private let trajectory = SKNode()
    private var trajectoryDots: [SKShapeNode] = []
    private let muzzleFlash: SKEmitterNode

    /// Everything that scales the launch speed on top of the Launcher Power upgrade: the
    /// launcher's own character, plus a clean cast if this one rewards timing.
    var speedMultiplier: CGFloat {
        spec.speedMultiplier * (didHitSweetSpot ? spec.sweetSpotBonus : 1)
    }

    var minPowerFraction: CGFloat { spec.minPowerFraction }
    var aimMode: AimMode { spec.aimMode }
    var sweetSpot: CGFloat { spec.sweetSpot }
    var sweetSpotHalfWidth: CGFloat { spec.sweetSpotHalfWidth }
    var muzzleHeight: CGFloat { spec.muzzleHeight }

    /// World-space point at the end of the barrel.
    var muzzlePoint: CGPoint {
        let a = angleDegrees * .pi / 180
        return CGPoint(x: barrel.position.x + cos(a) * spec.barrelLength,
                       y: barrel.position.y + sin(a) * spec.barrelLength)
    }

    var barrelAngle: CGFloat { angleDegrees * .pi / 180 }

    init(kind: LauncherKind = SaveManager.shared.data.selectedLauncherKind) {
        self.kind = kind
        let spec = kind.spec
        self.spec = spec
        angleDegrees = (spec.angleRange.lowerBound + spec.angleRange.upperBound) / 2
        tower = Art.sprite(spec.towerArtKey)
        barrel = Art.sprite(spec.barrelArtKey)
        muzzleFlash = Launcher.makeMuzzleFlash()
        super.init()

        tower.position = CGPoint(x: Tuning.launcherPivotX - 40, y: Tuning.waterY)
        tower.zPosition = 5
        addChild(tower)

        barrel.position = CGPoint(x: Tuning.launcherPivotX, y: Tuning.waterY + spec.muzzleHeight)
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
            // Triangle wave between this launcher's min and max angle.
            let phase = (clock / spec.angleSweepPeriod).truncatingRemainder(dividingBy: 1)
            let tri = phase < 0.5 ? phase * 2 : 2 - phase * 2
            angleDegrees = lerp(spec.angleRange.lowerBound, spec.angleRange.upperBound, tri)
            updateBarrel()
            updateTrajectory(speed: launchSpeed * spec.speedMultiplier * 0.8)

        case .sweepingPower:
            switch spec.aimMode {
            case .twoSweep, .castTiming:
                let phase = (clock / spec.powerPeriod).truncatingRemainder(dividingBy: 1)
                power = phase < 0.5 ? phase * 2 : 2 - phase * 2
            case .charge:
                if chargeHeld {
                    if power >= 1 {
                        // Full draw. There is a moment of grace, then the band lets go.
                        power = 1
                        overchargeClock += dt
                        if overchargeClock >= spec.overchargeGrace {
                            didSnap = true
                            power = spec.snapPower
                            lockPower()
                            return
                        }
                    } else {
                        power = min(1, power + dt / max(spec.powerPeriod, 0.05))
                    }
                }
            }
            updateTrajectory(speed: launchSpeed * speedMultiplier * lerp(spec.minPowerFraction, 1, power))

        case .fired:
            break
        }
    }

    func lockAngle() {
        guard aimState == .sweepingAngle else { return }
        aimState = .sweepingPower
        clock = 0
        overchargeClock = 0
        power = spec.aimMode == .charge ? 0 : power
        #if DEBUG
        if let forced = Launcher.debugForcedAngle { angleDegrees = forced; updateBarrel() }
        #endif
        barrel.run(.sequence([.scale(to: 1.08, duration: 0.06), .scale(to: 1, duration: 0.1)]))
    }

    /// `.charge` only: the player has put a finger down and is drawing the band back.
    func beginCharge() {
        guard aimState == .sweepingPower, spec.aimMode == .charge else { return }
        chargeHeld = true
    }

    /// `.charge` only: finger lifted. Returns true if the release actually fires the shot
    /// (it will not if the band already snapped on its own).
    @discardableResult
    func releaseCharge() -> Bool {
        guard aimState == .sweepingPower, spec.aimMode == .charge, chargeHeld else { return false }
        chargeHeld = false
        lockPower()
        return true
    }

    func lockPower() {
        guard aimState == .sweepingPower else { return }
        aimState = .fired
        if spec.aimMode == .castTiming {
            didHitSweetSpot = abs(power - spec.sweetSpot) <= spec.sweetSpotHalfWidth
        }
        #if DEBUG
        if let forced = Launcher.debugForcedPower {
            power = forced
            if spec.aimMode == .castTiming {
                didHitSweetSpot = abs(power - spec.sweetSpot) <= spec.sweetSpotHalfWidth
            }
        }
        #endif
    }

    #if DEBUG
    /// Test hook: launch the app with `SIMCTL_CHILD_BB_ANGLE=35 SIMCTL_CHILD_BB_POWER=1` (or set the
    /// env vars in the Xcode scheme) and every lock uses those values instead of the sweep, so
    /// automated runs and screenshots are reproducible. Debug builds only.
    private static let debugForcedAngle: CGFloat? = ProcessInfo.processInfo.environment["BB_ANGLE"].flatMap { Double($0) }.map { CGFloat($0) }
    private static let debugForcedPower: CGFloat? = ProcessInfo.processInfo.environment["BB_POWER"].flatMap { Double($0) }.map { CGFloat($0) }
    #endif

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
