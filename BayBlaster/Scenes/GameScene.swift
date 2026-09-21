import SpriteKit

/// One run: aim → fly → results. Owns the camera, world, player, spawner and HUD.
///
/// A run is either a normal run or a DAILY CHALLENGE (`init(size:daily:)`). A daily run seeds
/// the spawner from the date so the bay is identical for every attempt that day, folds the
/// modifier of the day into the loadout, and pays its reward once per day on the results card.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    enum Phase { case aiming, flying, ended }

    /// Feedback requests from entities (see WorldEntity.apply).
    enum JuiceKind { case bump, whale, motor, hurt, net, dolphin, balloon, explosion, sting, blocked, smash, shieldSmash, clang, ring }

    private var phase: Phase = .aiming
    private let cam = GameCamera()
    private let world = SKNode()
    private let config: UpgradeConfig
    private let skipSystem = WaterSkipSystem()

    private var player: Player!
    private var launcher: Launcher!
    private var hud: HUD!
    private var background: Background!
    private var spawner: WorldSpawner!
    private var milestones: Milestones!
    private var splashTemplate: SKEmitterNode!
    private var resultsOverlay: SKNode?
    /// Full-screen white sprite on the camera, flashed on launch and on a big smash.
    private var flashOverlay: SKSpriteNode!

    private var didBuild = false
    private var lastUpdateTime: TimeInterval = 0
    private var runCoins = 0
    private var distanceMetres: CGFloat = 0
    private var coinedMetres = 0
    private var skipsThisRun = 0
    private var skipCombo = 0            // consecutive skips since the last plow
    private var bestCombo = 0
    private var perfectSkips = 0
    private var flyingSeconds: CGFloat = 0
    private var rocketsFired = 0
    private var hazardsHit = 0
    private var entityHits: [String: Int] = [:]
    private var missionCheckTimer: CGFloat = 0
    private var announcedMissionIds: Set<Int> = []
    private var abilitiesUsed = 0
    private var barriersSmashed = 0
    private var peakAltitude: CGFloat = 0

    /// Non-nil on a daily-challenge run.
    private let daily: DailyChallenge?
    private var isDaily: Bool { daily != nil }

    private var holdTouch: UITouch?
    private var touchDownTime: TimeInterval = 0
    private static let tapHoldThreshold: TimeInterval = 0.18

    private var pendingOneShots: [WorldEntity] = []
    private var pendingZoneChanges: [(entity: WorldEntity, entered: Bool)] = []

    // MARK: - Lifecycle

    override init(size: CGSize) {
        Missions.refill()                        // swap out anything completed last run
        daily = nil
        config = UpgradeConfig(save: SaveManager.shared.data)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    /// A daily-challenge run: seeded bay, modifier of the day, reward paid once per day.
    init(size: CGSize, daily: DailyChallenge?) {
        Missions.refill()
        self.daily = daily
        config = UpgradeConfig(save: SaveManager.shared.data, daily: daily?.modifier.effect)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        Art.view = view
        AudioManager.shared.warmUp()
        Haptics.prepare()
        backgroundColor = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1)
        physicsWorld.gravity = .zero            // gravity is integrated in Player.update
        physicsWorld.contactDelegate = self
        if !didBuild { build() }
        layoutHUD()
    }

    private func build() {
        didBuild = true
        addChild(world)

        camera = cam
        addChild(cam)
        cam.configure(sceneSize: size)

        background = Background(scene: self, camera: cam)

        launcher = Launcher(kind: config.launcher)
        world.addChild(launcher)

        player = Player(config: config)
        player.attachEmitters(to: self)
        world.addChild(player)
        placePlayerAtMuzzle()

        spawner = WorldSpawner(world: world, config: config, seed: daily?.seed)
        milestones = Milestones(world: world, bestDistance: CGFloat(SaveManager.shared.data.bestDistance))
        milestones.onPass = { [weak self] metres, isBest in self?.passedMilestone(metres: metres, isBest: isBest) }

        hud = HUD()
        cam.addChild(hud)
        hud.setAimWidgets(visible: true)
        hud.showHint("TAP to lock the angle")
        hud.setRockets(player.rockets)
        hud.setCoins(0)
        hud.setDistance(0)
        hud.setHull(fraction: 1)
        hud.configureAbility(config.ability)
        hud.setAbilityVisible(false)             // shown once the boat is in the air
        hud.setControlHint(ability: config.ability)

        splashTemplate = GameScene.makeSplashTemplate()

        flashOverlay = SKSpriteNode(color: .white, size: CGSize(width: size.width * 3, height: size.height * 3))
        flashOverlay.zPosition = 1500
        flashOverlay.alpha = 0
        cam.addChild(flashOverlay)

        cam.snap(to: player.position)

        if let daily = daily {
            Banner.show(title: "DAILY · \(daily.modifier.title)", subtitle: daily.modifier.detail,
                        in: cam, sceneSize: size, insets: view?.safeAreaInsets ?? .zero,
                        color: UIColor(red: 0.6, green: 1, blue: 0.8, alpha: 1), duration: 3.2)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard didBuild else { return }
        cam.configure(sceneSize: size)
        background.layout(sceneSize: size)
        layoutHUD()
    }

    private func layoutHUD() {
        hud?.layout(sceneSize: size, insets: view?.safeAreaInsets ?? .zero)
        flashOverlay?.size = CGSize(width: size.width * 3, height: size.height * 3)
        // The cast band / draw-danger zone is positioned relative to the power bar, so it has
        // to be re-styled after every layout pass.
        if let hud = hud, let launcher = launcher { hud.setLauncherStyle(launcher) }
    }

    private func placePlayerAtMuzzle() {
        let m = launcher.muzzlePoint
        player.position = CGPoint(x: m.x - 6, y: m.y)
        player.visual.zRotation = launcher.barrelAngle
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        var dt = CGFloat(currentTime - lastUpdateTime)
        if lastUpdateTime == 0 || dt > Tuning.maxDeltaTime { dt = Tuning.maxDeltaTime }
        if dt < 0 { dt = 0 }
        lastUpdateTime = currentTime

        switch phase {
        case .aiming:
            launcher.update(dt: dt, launchSpeed: config.launchSpeed)
            placePlayerAtMuzzle()
            hud.setAim(angleDegrees: launcher.angleDegrees, power: launcher.power,
                       showPower: launcher.aimState == .sweepingPower)
            player.update(dt: dt)
            cam.follow(target: player.position, velocity: .zero, dt: dt)
            background.update(camera: cam, distanceMetres: 0, dt: dt)
            // Every launcher funnels through the same exit: the moment its aim ritual reaches
            // `.fired` we launch. That covers a tap-lock, a released draw, and a band that
            // snapped on its own without the player letting go.
            if launcher.aimState == .fired { fire() }

        case .flying:
            player.isDiving = holdTouch != nil && (currentTime - touchDownTime) >= GameScene.tapHoldThreshold
            player.update(dt: dt)
            if player.state == .flying { flyingSeconds += dt }
            spawner.update(playerX: player.position.x)
            milestones.update(playerX: player.position.x)
            updateDistance()
            peakAltitude = max(peakAltitude, player.altitude)
            cam.follow(target: player.position, velocity: player.velocity, dt: dt)
            background.update(camera: cam, distanceMetres: distanceMetres, altitude: player.altitude, dt: dt)
            hud.setDistance(distanceMetres)
            hud.setAltitude(player.altitude)
            hud.setCoins(runCoins)
            hud.setRockets(player.rockets)
            hud.setHull(fraction: player.hullFraction)
            hud.setAbility(charge: player.abilityChargeFraction, ready: player.isAbilityReady,
                           shields: player.shieldCharges)
            updateMagnet(dt: dt)
            missionCheckTimer += dt
            if missionCheckTimer > 0.4 {
                missionCheckTimer = 0
                checkMissionsMidRun()
            }
            checkRunEnd()

        case .ended:
            player.update(dt: dt)
            cam.follow(target: player.position, velocity: player.velocity, dt: dt)
            background.update(camera: cam, distanceMetres: distanceMetres, altitude: player.altitude, dt: dt)
        }
    }

    override func didSimulatePhysics() {
        guard phase == .flying else { return }
        if let outcome = skipSystem.resolve(player: player) { handle(outcome) }
        processContacts()
    }

    /// Coin Magnet: drag uncollected arc coins toward the boat so a near miss still pays.
    /// The physics contact still does the collecting — this only moves the coins.
    private func updateMagnet(dt: CGFloat) {
        guard config.hasMagnet, player.state != .sunk else { return }
        let step = Tuning.gearMagnetPullSpeed * dt
        for coin in spawner.magnetisableCoins(near: player.position, radius: config.magnetRadius) {
            let dx = player.position.x - coin.position.x
            let dy = player.position.y - coin.position.y
            let distance = (dx * dx + dy * dy).squareRoot()
            guard distance > 1 else { continue }
            let move = min(step, distance)
            coin.position = CGPoint(x: coin.position.x + dx / distance * move,
                                    y: coin.position.y + dy / distance * move)
        }
    }

    private func updateDistance() {
        let metres = max(0, (player.position.x - Tuning.launchX) / Tuning.pointsPerMeter)
        distanceMetres = max(distanceMetres, metres)
        let whole = Int(distanceMetres)
        if whole > coinedMetres {
            runCoins += payout((whole - coinedMetres) * Tuning.coinsPerMeter)
            coinedMetres = whole
        }
    }

    private func checkRunEnd() {
        switch player.state {
        case .plowing where player.velocity.dx < Tuning.runEndSpeed:
            endRun(sunk: false)
        case .sunk:
            endRun(sunk: true)
        default:
            // Safety valve: a run should never last this long.
            if flyingSeconds > 180 { endRun(sunk: false) }
        }
    }

    // MARK: - Water

    private func handle(_ outcome: WaterSkipSystem.Outcome) {
        switch outcome {
        case .skipped(let impactSpeed, let hard, let damage, let perfect, let forced):
            skipsThisRun += 1
            skipCombo += 1
            bestCombo = max(bestCombo, skipCombo)
            splash(at: player.position, intensity: clamp(impactSpeed / 1800, 0.3, 1.2))
            AudioManager.shared.play(.splash, volume: 0.7)
            Haptics.skip()

            // Combo pays a little more each consecutive skip; a shallow "perfect" landing pays extra.
            var bonus = Tuning.skipComboCoinStep * skipCombo
            if perfect {
                perfectSkips += 1
                bonus += Tuning.perfectSkipCoins
                AudioManager.shared.play(.perfect, volume: 0.8)
                Haptics.medium(0.8)
                FloatingLabel.show("PERFECT!", at: player.position + CGPoint(x: 0, y: 64), in: world,
                                   color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), fontSize: 26)
            }
            runCoins += payout(bonus)
            if forced {
                // An ability saved a landing that would otherwise have ended the combo.
                FloatingLabel.show("SAVED!", at: player.position + CGPoint(x: 0, y: 92), in: world,
                                   color: UIColor(red: 0.6, green: 1, blue: 0.75, alpha: 1), fontSize: 22)
            }
            let comboColor = skipCombo >= 5 ? UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
                                            : UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 1)
            FloatingLabel.show("SKIP ×\(skipCombo)  +\(bonus)", at: player.position + CGPoint(x: 0, y: 36), in: world,
                               color: comboColor, fontSize: skipCombo >= 5 ? 24 : 20)
            if hard {
                cam.shake(Tuning.hardImpactShake)
                Haptics.heavy()
                damagePlayer(damage, shake: 0)
            }
        case .plowed(let impactSpeed, let hard, let damage):
            if skipCombo >= 3 {
                FloatingLabel.show("COMBO ×\(skipCombo) ENDED", at: player.position + CGPoint(x: 0, y: 40), in: world,
                                   color: UIColor.white.withAlphaComponent(0.8), fontSize: 18)
            }
            skipCombo = 0
            splash(at: player.position, intensity: clamp(impactSpeed / 1400, 0.5, 1.5))
            AudioManager.shared.play(.splash, volume: 1)
            Haptics.medium()
            cam.shake(hard ? Tuning.hardImpactShake : 5)
            if hard {
                Haptics.heavy()
                damagePlayer(damage, shake: 0)
            }
        }
    }

    // MARK: - Contacts (queued; applied in didSimulatePhysics)

    func didBegin(_ contact: SKPhysicsContact) {
        guard let entity = entity(in: contact) else { return }
        if entity.kind.spec.isZone {
            pendingZoneChanges.append((entity: entity, entered: true))
        } else {
            pendingOneShots.append(entity)
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        guard let entity = entity(in: contact), entity.kind.spec.isZone else { return }
        pendingZoneChanges.append((entity: entity, entered: false))
    }

    private func entity(in contact: SKPhysicsContact) -> WorldEntity? {
        (contact.bodyA.node as? WorldEntity) ?? (contact.bodyB.node as? WorldEntity)
    }

    private func processContacts() {
        let zones = pendingZoneChanges
        pendingZoneChanges.removeAll()
        for change in zones {
            if change.entered {
                change.entity.enterZone(player: player)
                noteHit(change.entity.kind)
            } else {
                change.entity.exitZone(player: player)
            }
        }
        let hits = pendingOneShots
        pendingOneShots.removeAll()
        for e in hits where phase == .flying {
            // Tock's shell eats the whole hazard, so it never counts as a hit either.
            if e.kind.spec.isHazard, !e.consumed, player.consumeShield() {
                e.blockByShield(in: self)
                continue
            }
            if !e.consumed { noteHit(e.kind) }
            e.apply(to: player, in: self)
        }
    }

    // MARK: - Milestones

    private func passedMilestone(metres: CGFloat, isBest: Bool) {
        guard phase == .flying else { return }
        if isBest {
            FloatingLabel.show("NEW BEST!", at: player.position + CGPoint(x: 0, y: 90), in: world,
                               color: UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), fontSize: 34)
            AudioManager.shared.play(.purchase)
            Haptics.success()
            cam.shake(5)
        } else {
            FloatingLabel.show("\(Int(metres)) m", at: player.position + CGPoint(x: 0, y: 80), in: world,
                               color: .white, fontSize: 28)
            AudioManager.shared.play(.milestone, volume: 0.6)
            Haptics.medium(0.5)
        }
    }

    /// Mission bookkeeping: what the boat touched this run.
    private func noteHit(_ kind: EntityKind) {
        let key = kind.spec.artKey
        entityHits[key, default: 0] += 1
        if kind.spec.isHazard { hazardsHit += 1 }

        // First time ever touching this kind: explain it.
        if let tip = kind.tip, !SaveManager.shared.data.seenEntities.contains(key) {
            SaveManager.shared.mutate { $0.seenEntities.append(key) }
            Banner.show(title: tip.title, subtitle: tip.detail, in: cam, sceneSize: size,
                        insets: view?.safeAreaInsets ?? .zero,
                        color: kind.spec.isHazard ? UIColor(red: 1, green: 0.55, blue: 0.4, alpha: 1)
                                                  : UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1))
        }
    }

    private func currentRunStats() -> RunStats {
        var stats = RunStats()
        stats.distance = Double(distanceMetres)
        stats.coins = runCoins
        stats.skips = skipsThisRun
        stats.bestCombo = bestCombo
        stats.perfects = perfectSkips
        stats.rocketsFired = rocketsFired
        stats.hazardsHit = hazardsHit
        stats.hits = entityHits
        stats.abilitiesUsed = abilitiesUsed
        stats.barriersSmashed = barriersSmashed
        stats.peakAltitude = Double(peakAltitude / Tuning.pointsPerMeter)
        stats.endHullFraction = Double(player.hullFraction)
        stats.isDaily = isDaily
        return stats
    }

    /// Announce a mission the moment it is satisfied (payment still happens at run end).
    /// "Untouched" can't be known until the run ends, so it is skipped here.
    private func checkMissionsMidRun() {
        for m in Missions.satisfied(by: currentRunStats()) where !announcedMissionIds.contains(m.id) && m.kind != .untouched {
            announcedMissionIds.insert(m.id)
            Banner.show(title: "MISSION COMPLETE  +\(m.reward)", subtitle: m.title, in: cam, sceneSize: size,
                        insets: view?.safeAreaInsets ?? .zero,
                        color: UIColor(red: 0.6, green: 1, blue: 0.6, alpha: 1))
            AudioManager.shared.play(.purchase, volume: 0.8)
            Haptics.success()
        }
    }

    // MARK: - Entity callbacks

    /// `quiet` is for rapid pickups (coin arcs): a lighter sound and no haptic so eight coins
    /// in a row don't buzz the phone.
    /// Everything that scales a coin payout: the rider, the prestige level, the daily
    /// modifier (all baked into `config`) and Chum's frenzy, which is live.
    func payout(_ base: Int) -> Int {
        config.payout(base, frenzied: player?.activeAbility == .frenzy)
    }

    func awardCoins(_ amount: Int, at position: CGPoint, quiet: Bool = false) {
        let paid = payout(amount)
        runCoins += paid
        if quiet {
            FloatingLabel.show("+\(paid)", at: position, in: world, fontSize: 16)
            AudioManager.shared.play(.coin, volume: 0.45)
        } else {
            FloatingLabel.show("+\(paid)", at: position, in: world)
            AudioManager.shared.play(.coin)
            Haptics.medium(0.6)
        }
    }

    /// Called by a wall the moment it breaks, so missions and trophies can count it.
    func noteBarrierSmashed() {
        barriersSmashed += 1
    }

    /// A brief full-screen whiteout. `strength` is the peak alpha.
    func flash(_ strength: CGFloat, duration: TimeInterval) {
        guard let flashOverlay = flashOverlay else { return }
        flashOverlay.removeAllActions()
        flashOverlay.alpha = clamp(strength, 0, 1)
        flashOverlay.run(.fadeAlpha(to: 0, duration: duration))
    }

    func damagePlayer(_ amount: CGFloat, shake: CGFloat) {
        guard phase == .flying else { return }
        if shake > 0 { cam.shake(shake) }
        let shown = player.effectiveDamage(amount)
        let sunk = player.applyDamage(amount)
        hud.setHull(fraction: player.hullFraction)
        FloatingLabel.show("-\(max(1, Int(shown.rounded())))", at: player.position + CGPoint(x: 0, y: 30), in: world,
                           color: UIColor(red: 1, green: 0.4, blue: 0.35, alpha: 1), fontSize: 22)
        if sunk {
            player.sink()
            splash(at: player.position, intensity: 1.6)
            AudioManager.shared.play(.sink)
            Haptics.failure()
            endRun(sunk: true)
        }
    }

    func juice(_ kind: JuiceKind, at position: CGPoint) {
        switch kind {
        case .bump:
            AudioManager.shared.play(.bump)
            Haptics.medium()
            splash(at: position, intensity: 0.6)
            FloatingLabel.show("BOING!", at: position + CGPoint(x: 0, y: 50), in: world, color: .white, fontSize: 22)
        case .whale:
            AudioManager.shared.play(.whale)
            Haptics.medium()
            splash(at: position, intensity: 1.4)
            FloatingLabel.show("SPOUT!", at: position + CGPoint(x: 0, y: 90), in: world, color: UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 1))
        case .motor:
            AudioManager.shared.play(.rocket, volume: 0.8)
            Haptics.medium(0.8)
            FloatingLabel.show("VROOM!", at: position + CGPoint(x: 0, y: 40), in: world, color: UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1))
        case .hurt:
            AudioManager.shared.play(.hurt)
            Haptics.heavy()
        case .net:
            AudioManager.shared.play(.splash, volume: 0.5)
            Haptics.medium()
            FloatingLabel.show("TANGLED", at: position + CGPoint(x: 0, y: 40), in: world, color: UIColor(red: 1, green: 0.6, blue: 0.4, alpha: 1), fontSize: 20)
        case .dolphin:
            AudioManager.shared.play(.whale, volume: 0.8)
            Haptics.medium()
            splash(at: position, intensity: 1.0)
            FloatingLabel.show("DOLPHIN RIDE!", at: position + CGPoint(x: 0, y: 70), in: world, color: UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1))
        case .balloon:
            AudioManager.shared.play(.pop)
            Haptics.medium(0.7)
            FloatingLabel.show("FLOAT!", at: position + CGPoint(x: 0, y: 44), in: world, color: UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 1), fontSize: 22)
        case .explosion:
            AudioManager.shared.play(.explosion)
            Haptics.heavy()
            splash(at: position, intensity: 1.8)
            FloatingLabel.show("KABOOM!", at: position + CGPoint(x: 0, y: 80), in: world, color: UIColor(red: 1, green: 0.45, blue: 0.2, alpha: 1), fontSize: 30)
        case .sting:
            AudioManager.shared.play(.hurt, volume: 0.7)
            Haptics.medium()
            FloatingLabel.show("STUNG! no rockets", at: position + CGPoint(x: 0, y: 40), in: world, color: UIColor(red: 0.85, green: 0.6, blue: 1, alpha: 1), fontSize: 20)
        case .blocked:
            AudioManager.shared.play(.bump, volume: 0.9)
            Haptics.medium(0.9)
            FloatingLabel.show("BLOCKED!", at: position + CGPoint(x: 0, y: 50), in: world,
                               color: UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 1), fontSize: 24)
        case .smash:
            AudioManager.shared.play(.explosion, volume: 0.9)
            Haptics.heavy()
            cam.shake(13)
            flash(0.28, duration: 0.16)
            debris(at: position, tint: UIColor(red: 0.75, green: 0.6, blue: 0.4, alpha: 1))
            FloatingLabel.show("SMASH!", at: position + CGPoint(x: 0, y: 70), in: world,
                               color: UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), fontSize: 32)
        case .shieldSmash:
            AudioManager.shared.play(.explosion, volume: 1)
            Haptics.heavy()
            cam.shake(16)
            flash(0.35, duration: 0.18)
            debris(at: position, tint: UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 1))
            FloatingLabel.show("SHELL SMASH!", at: position + CGPoint(x: 0, y: 70), in: world,
                               color: UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 1), fontSize: 30)
        case .clang:
            AudioManager.shared.play(.hurt, volume: 1)
            Haptics.failure()
            cam.shake(16)
            FloatingLabel.show("TOO SLOW!", at: position + CGPoint(x: 0, y: 60), in: world,
                               color: UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1), fontSize: 28)
        case .ring:
            AudioManager.shared.play(.perfect, volume: 0.7)
            Haptics.medium(0.7)
            FloatingLabel.show("CLEAN!", at: position + CGPoint(x: 0, y: 56), in: world,
                               color: UIColor(red: 0.4, green: 1, blue: 0.8, alpha: 1), fontSize: 24)
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        switch phase {
        case .aiming:
            switch launcher.aimState {
            case .sweepingAngle:
                launcher.lockAngle()
                Haptics.lock()
                AudioManager.shared.play(.lock)
                hud.showHint(launcher.kind.powerHint)
            case .sweepingPower:
                // A .charge launcher draws while the finger is down and fires on release;
                // the others lock on the tap itself. `update` does the actual firing once
                // the launcher reports `.fired`.
                if launcher.aimMode == .charge {
                    launcher.beginCharge()
                    Haptics.medium(0.5)
                } else {
                    launcher.lockPower()
                    Haptics.lock()
                }
            case .fired:
                break
            }
        case .flying:
            // The ability button owns its corner of the screen; a touch there is never a
            // rocket and never a dive.
            if hud.abilityButtonContains(touch.location(in: hud)) {
                useAbility()
                return
            }
            if holdTouch == nil {
                holdTouch = touch
                touchDownTime = touch.timestamp
            }
        case .ended:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if phase == .aiming, launcher.aimMode == .charge, launcher.aimState == .sweepingPower {
            launcher.releaseCharge()
            Haptics.lock()
            return
        }
        releaseTouch(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if phase == .aiming, launcher.aimMode == .charge, launcher.aimState == .sweepingPower {
            launcher.releaseCharge()
            return
        }
        releaseTouch(touches)
    }

    private func releaseTouch(_ touches: Set<UITouch>) {
        guard let held = holdTouch, touches.contains(held) else { return }
        let heldFor = held.timestamp - touchDownTime
        holdTouch = nil
        player.isDiving = false
        if phase == .flying, heldFor < GameScene.tapHoldThreshold {
            fireRocket()
        }
    }

    // MARK: - Ability

    /// The third in-flight verb. `Player.beginAbility` applies everything that only touches
    /// the boat; anything that needs the world (Pip's swoop) is finished here.
    private func useAbility() {
        guard phase == .flying else { return }
        guard let fired = player.beginAbility() else {
            AudioManager.shared.play(.tick, volume: 0.35)
            return
        }
        abilitiesUsed += 1
        hud.flashAbility()
        hud.setAbility(charge: player.abilityChargeFraction, ready: false, shields: player.shieldCharges)

        if fired == .swoop, let target = nearestPickupAhead() {
            player.swoop(toward: target)
        }

        AudioManager.shared.play(abilitySound(fired), volume: 0.9)
        Haptics.medium(0.9)
        cam.shake(fired == .slam ? 8 : 4)
        FloatingLabel.show(fired.title, at: player.position + CGPoint(x: 0, y: 58), in: world,
                           color: UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 1), fontSize: 24)

        // First time this rider's move is used, say what it does.
        if !SaveManager.shared.data.seenAbilities.contains(fired.rawValue) {
            SaveManager.shared.mutate { $0.seenAbilities.append(fired.rawValue) }
            Banner.show(title: fired.title, subtitle: fired.hint, in: cam, sceneSize: size,
                        insets: view?.safeAreaInsets ?? .zero,
                        color: UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1))
        }
    }

    private func abilitySound(_ ability: Ability) -> AudioManager.Sound {
        switch ability {
        case .inkJet, .slam, .swoop: return .rocket
        case .puff, .glide:          return .pop
        case .shell:                 return .lock
        case .frenzy:                return .explosion
        case .tuck:                  return .whale
        }
    }

    /// The closest boost or coin ahead of the boat, for Pip's swoop.
    private func nearestPickupAhead() -> CGPoint? {
        var best: CGPoint?
        var bestDistance = Tuning.abilitySwoopRange
        for node in world.children {
            guard let entity = node as? WorldEntity,
                  !entity.consumed,
                  !entity.kind.spec.isHazard,
                  entity.position.x > player.position.x,
                  entity.position.y - player.position.y > Tuning.abilitySwoopMinTargetY else { continue }
            let dx = entity.position.x - player.position.x
            let dy = entity.position.y - player.position.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < bestDistance {
                bestDistance = distance
                best = entity.position
            }
        }
        return best
    }

    private func fireRocket() {
        if player.fireRocket() {
            rocketsFired += 1
            AudioManager.shared.play(.rocket)
            Haptics.medium()
            cam.shake(4)
            hud.setRockets(player.rockets)
            FloatingLabel.show("ROCKET!", at: player.position + CGPoint(x: 0, y: 44), in: world,
                               color: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), fontSize: 22)
        } else if player.state == .flying {
            AudioManager.shared.play(.tick, volume: 0.4)
        }
    }

    private func fire() {
        guard phase == .aiming else { return }
        let speed = config.launchSpeed * launcher.speedMultiplier
            * lerp(launcher.minPowerFraction, 1, launcher.power)
        let a = launcher.barrelAngle
        player.launch(velocity: CGVector(dx: cos(a) * speed, dy: sin(a) * speed))
        player.visual.zRotation = a
        launcher.fire()
        phase = .flying
        hud.setAimWidgets(visible: false)
        hud.showHint(nil)
        hud.setAbilityVisible(true)
        hud.setAbility(charge: 1, ready: true, shields: 0)

        // The launch beat: a whiteout, a punch-in on the muzzle that eases back out as the boat
        // climbs away, a hard shake, and a tumble out of the barrel that settles into flight.
        flash(0.55, duration: Tuning.launchFlashDuration)
        cam.punchZoom(Tuning.launchCameraPunch)
        cam.shake(Tuning.launchShake)
        Haptics.heavy()
        AudioManager.shared.play(.launch)
        AudioManager.shared.play(.explosion, volume: 0.45)

        player.tumble(turns: Tuning.launchTumbleTurns, seconds: Tuning.launchTumbleDuration)

        // Tell the player how their launch went, when the launcher has something to say.
        if launcher.didHitSweetSpot {
            FloatingLabel.show("CLEAN CAST!", at: player.position + CGPoint(x: 0, y: 70), in: world,
                               color: UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1), fontSize: 26)
            AudioManager.shared.play(.perfect, volume: 0.9)
            Haptics.success()
        } else if launcher.didSnap {
            FloatingLabel.show("SNAP!", at: player.position + CGPoint(x: 0, y: 70), in: world,
                               color: UIColor(red: 1, green: 0.5, blue: 0.4, alpha: 1), fontSize: 26)
            Haptics.failure()
        }
    }

    // MARK: - Run end + results

    private func endRun(sunk: Bool) {
        guard phase == .flying else { return }
        phase = .ended
        holdTouch = nil
        player.isDiving = false
        player.endFlightSegment()
        hud.setDistance(distanceMetres)
        hud.setCoins(runCoins)

        let stats = currentRunStats()
        let isNewBest = SaveManager.shared.recordRun(distance: Double(distanceMetres),
                                                     coins: runCoins,
                                                     longestFlight: Double(player.longestFlightTime),
                                                     abilitiesUsed: abilitiesUsed)
        let missionResults = Missions.evaluate(run: stats)
        // A daily run pays its own reward once per day, on top of the coins from the run.
        var dailyOutcome: SaveManager.DailyOutcome?
        if let daily = daily {
            dailyOutcome = SaveManager.shared.recordDaily(distance: Double(distanceMetres), challenge: daily)
        }
        // Achievements are checked last, against the save as it now stands, so "fly 100,000 m
        // in total" can be won by the very run that is being reported.
        let earned = Achievements.evaluate(run: stats)

        run(.sequence([
            .wait(forDuration: sunk ? 1.4 : 0.7),
            .run { [weak self] in
                self?.showResults(sunk: sunk, newBest: isNewBest, missions: missionResults,
                                  achievements: earned, dailyOutcome: dailyOutcome)
            }
        ]))
    }

    private func showResults(sunk: Bool, newBest: Bool, missions: [MissionResult],
                             achievements: [Achievement], dailyOutcome: SaveManager.DailyOutcome?) {
        let overlay = SKNode()
        overlay.zPosition = 2000
        let missionRows = missions.count
        let missionBlock = CGFloat(missionRows) * 22 + (missionRows > 0 ? 14 : 0)
        // Trophies won this run get a row each, and a daily run gets one line for its payout.
        let trophyBlock = CGFloat(achievements.count) * 20 + (achievements.isEmpty ? 0 : 10)
        let dailyBlock: CGFloat = dailyOutcome == nil ? 0 : 22
        let extraBlock = missionBlock + trophyBlock + dailyBlock
        let panel = PanelNode(size: CGSize(width: 480, height: 272 + extraBlock))
        overlay.addChild(panel)
        // Everything above the buttons shifts up by half the extra block; buttons shift down.
        let up = extraBlock / 2

        var headline = sunk ? "GLUG GLUG… SUNK!" : "SPLASHDOWN!"
        if let daily = daily { headline = "DAILY · \(daily.modifier.title)" }
        let title = SKLabelNode.make(headline, size: 26, font: Tuning.fontHeavy,
                                     color: sunk ? UIColor(red: 1, green: 0.5, blue: 0.4, alpha: 1) : UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1))
        title.position = CGPoint(x: 0, y: 104 + up)
        panel.addChild(title)

        let distance = SKLabelNode.make("0 m", size: 52, font: Tuning.fontHeavy)
        distance.position = CGPoint(x: 0, y: 52 + up)
        panel.addChild(distance)
        let finalMetres = Int(distanceMetres)
        distance.run(.customAction(withDuration: Tuning.resultsCountUpDuration) { node, elapsed in
            let t = CGFloat(elapsed) / CGFloat(Tuning.resultsCountUpDuration)
            let eased = 1 - pow(1 - min(t, 1), 3)
            (node as? SKLabelNode)?.text = "\(Int(CGFloat(finalMetres) * eased)) m"
        })

        var summary = "+\(runCoins) coins   ·   \(skipsThisRun) skips"
        if bestCombo >= 3 { summary += "   ·   best combo ×\(bestCombo)" }
        if perfectSkips > 0 { summary += "   ·   \(perfectSkips) perfect" }
        let coins = SKLabelNode.make(summary, size: bestCombo >= 3 || perfectSkips > 0 ? 17 : 20,
                                     color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1))
        coins.position = CGPoint(x: 0, y: 12 + up)
        panel.addChild(coins)

        // Mission rows: "✓ Skip 5 times in one run  +180" or "Ride 2 dolphins  1/2".
        var rowY = -20 + up - 28          // first row sits just under the Best / NEW BEST line
        for (i, r) in missions.enumerated() {
            let done = r.mission.completed
            let name = SKLabelNode.make((done ? "✓  " : "•  ") + r.mission.title, size: 15, font: Tuning.fontMedium,
                                        color: done ? UIColor(red: 0.6, green: 1, blue: 0.6, alpha: 1) : UIColor.white.withAlphaComponent(0.85),
                                        align: .left)
            // The row's value is right-aligned at +218; keep the title clear of it. Mission
            // names got longer with the wall and altitude kinds ("Reach 500 m above the water").
            name.shrinkToFit(width: 360)
            name.position = CGPoint(x: -218, y: rowY)
            panel.addChild(name)
            let status = SKLabelNode.make(r.justCompleted ? "+\(r.mission.reward)" : (done ? "done" : "\(r.progress)/\(r.mission.target)"),
                                          size: 15, font: Tuning.fontHeavy,
                                          color: done ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : UIColor.white.withAlphaComponent(0.6),
                                          align: .right)
            status.position = CGPoint(x: 218, y: rowY)
            panel.addChild(status)
            if r.justCompleted {
                status.setScale(0.1)
                status.run(.sequence([
                    .wait(forDuration: Tuning.resultsCountUpDuration + 0.25 * Double(i)),
                    .run { AudioManager.shared.play(.purchase, volume: 0.8); Haptics.success() },
                    .scale(to: 1.3, duration: 0.15), .scale(to: 1, duration: 0.1)
                ]))
                name.run(.sequence([.wait(forDuration: Tuning.resultsCountUpDuration + 0.25 * Double(i)),
                                    .run { name.fontColor = UIColor(red: 0.6, green: 1, blue: 0.6, alpha: 1) }]))
                name.fontColor = UIColor.white.withAlphaComponent(0.85)
            }
            rowY -= 22
        }

        // Trophies won by this run, each with its payout.
        for (i, a) in achievements.enumerated() {
            let row = SKLabelNode.make("🏆  \(a.title)", size: 14, font: Tuning.fontHeavy,
                                       color: UIColor(red: 1, green: 0.85, blue: 0.35, alpha: 1), align: .left)
            row.shrinkToFit(width: 360)
            row.position = CGPoint(x: -218, y: rowY)
            panel.addChild(row)
            let value = SKLabelNode.make("+\(a.reward)", size: 14, font: Tuning.fontHeavy,
                                         color: UIColor(red: 1, green: 0.85, blue: 0.35, alpha: 1), align: .right)
            value.position = CGPoint(x: 218, y: rowY)
            panel.addChild(value)
            let delay = Tuning.resultsCountUpDuration + 0.2 * Double(i)
            row.alpha = 0
            value.alpha = 0
            row.run(.sequence([.wait(forDuration: delay),
                               .run { AudioManager.shared.play(.purchase, volume: 0.7); Haptics.success() },
                               .fadeIn(withDuration: 0.2)]))
            value.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.2)]))
            rowY -= 20
        }

        // The daily payout line.
        if let outcome = dailyOutcome {
            let text: String
            let colour: UIColor
            if outcome.isFirstToday {
                text = "Daily reward +\(outcome.reward)" + (outcome.streak > 1 ? "   ·   \(outcome.streak)-day streak" : "")
                colour = UIColor(red: 0.6, green: 1, blue: 0.75, alpha: 1)
            } else {
                text = outcome.isDailyBest ? "New daily best! (reward already claimed today)"
                                           : "Today's best: \(Int(SaveManager.shared.data.dailyBestDistance)) m"
                colour = UIColor.white.withAlphaComponent(0.75)
            }
            let line = SKLabelNode.make(text, size: 15, font: Tuning.fontBold, color: colour)
            line.position = CGPoint(x: 0, y: rowY - 2)
            panel.addChild(line)
            rowY -= 22
        }

        if newBest {
            let best = SKLabelNode.make("★ NEW BEST ★", size: 22, font: Tuning.fontHeavy, color: UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1))
            best.position = CGPoint(x: 0, y: -20 + up)
            best.setScale(0.1)
            panel.addChild(best)
            best.run(.sequence([
                .wait(forDuration: Tuning.resultsCountUpDuration * 0.8),
                .run { Haptics.success(); AudioManager.shared.play(.purchase) },
                .scale(to: 1.2, duration: 0.2),
                .scale(to: 1, duration: 0.1),
                .repeatForever(.sequence([.scale(to: 1.06, duration: 0.5), .scale(to: 1, duration: 0.5)]))
            ]))
        } else {
            let bestMetres = Int(SaveManager.shared.data.bestDistance)
            let short = bestMetres - Int(distanceMetres)
            let close = short > 0 && CGFloat(short) <= max(50, CGFloat(bestMetres) * Tuning.nearBestFraction)
            let best = SKLabelNode.make(close ? "Only \(short) m short of your best!" : "Best: \(bestMetres) m", size: 18,
                                        font: close ? Tuning.fontHeavy : Tuning.fontBold,
                                        color: close ? UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1) : UIColor.white.withAlphaComponent(0.7))
            best.position = CGPoint(x: 0, y: -20 + up)
            panel.addChild(best)
            if close {
                best.run(.repeatForever(.sequence([.scale(to: 1.05, duration: 0.5), .scale(to: 1, duration: 0.5)])))
            }
        }

        // Three buttons across a 480-wide panel: 145 each with 10 pt gaps, centred at ±155/0.
        let againDaily = daily
        let again = ButtonNode(text: "LAUNCH AGAIN", size: CGSize(width: 145, height: 54), color: UIColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 1), fontSize: 17)
        again.position = CGPoint(x: -155, y: -84 - up)
        again.action = { [weak self] in
            guard let self = self else { return }
            // Re-running a daily stays on the daily; the bay is the same all day.
            SceneRouter.present(GameScene(size: self.size, daily: againDaily), from: self)
        }
        panel.addChild(again)

        let shop = ButtonNode(text: "SHOP", size: CGSize(width: 145, height: 54), color: UIColor(red: 0.25, green: 0.6, blue: 0.95, alpha: 1), fontSize: 19)
        shop.position = CGPoint(x: 0, y: -84 - up)
        shop.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(ShopScene(size: self.size), from: self, reveal: true)
        }
        panel.addChild(shop)

        let locker = ButtonNode(text: "LOCKER", size: CGSize(width: 145, height: 54), color: UIColor(red: 0.55, green: 0.35, blue: 0.75, alpha: 1), fontSize: 19)
        locker.position = CGPoint(x: 155, y: -84 - up)
        locker.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(LockerScene(size: self.size), from: self, reveal: true)
        }
        panel.addChild(locker)

        overlay.setScale(0.7)
        overlay.alpha = 0
        cam.addChild(overlay)
        overlay.run(.group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.3)]))
        resultsOverlay = overlay
    }

    // MARK: - Splash particles

    private static func makeSplashTemplate() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Art.particleTexture
        e.particleBirthRate = 900
        e.numParticlesToEmit = 30
        e.particleLifetime = 0.7
        e.particleLifetimeRange = 0.3
        e.particleSpeed = 300
        e.particleSpeedRange = 140
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 1.3
        e.yAcceleration = -900
        e.particleAlpha = 0.95
        e.particleAlphaSpeed = -1.3
        e.particleScale = 0.9
        e.particleScaleRange = 0.4
        e.particleScaleSpeed = -0.7
        e.particleColor = UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 1)
        e.particleColorBlendFactor = 1
        e.zPosition = 45
        return e
    }

    /// Chunky burst for a smashed wall or crate — heavier and slower than a splash, and
    /// tinted to whatever just broke.
    private func debris(at position: CGPoint, tint: UIColor) {
        let e = SKEmitterNode()
        e.particleTexture = Art.particleTexture
        e.particleBirthRate = 1400
        e.numParticlesToEmit = 42
        e.particleLifetime = 0.9
        e.particleLifetimeRange = 0.5
        e.particleSpeed = 420
        e.particleSpeedRange = 240
        e.emissionAngleRange = .pi * 2
        e.yAcceleration = -1100
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.1
        e.particleScale = 0.8
        e.particleScaleRange = 0.5
        e.particleScaleSpeed = -0.4
        e.particleColor = tint
        e.particleColorBlendFactor = 1
        e.particleRotationRange = .pi
        e.particleRotationSpeed = 5
        e.position = position
        e.zPosition = 60
        world.addChild(e)
        e.run(.sequence([.wait(forDuration: 1.8), .removeFromParent()]))
    }

    private func splash(at position: CGPoint, intensity: CGFloat) {
        guard let e = splashTemplate.copy() as? SKEmitterNode else { return }
        e.position = CGPoint(x: position.x, y: Tuning.waterY)
        e.numParticlesToEmit = Int(30 * intensity)
        e.particleSpeed = 300 * intensity
        e.particleScale = 0.9 * clamp(intensity, 0.5, 1.4)
        world.addChild(e)
        e.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
    }
}

// MARK: - CGPoint helpers

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}
