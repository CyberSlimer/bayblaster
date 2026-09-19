import SpriteKit

/// Every kind of world object the spawner can place. See the "HOW TO ADD A NEW BOOST / HAZARD"
/// note at the top of Constants.swift.
enum EntityKind: CaseIterable {
    // Boosts
    case buoy, whaleSpout, motor, birdFlock, coinBag, fuelCan, dolphin, balloon
    /// Small coin placed by the spawner in arcs; never picked from the weight table (weight 0).
    case coin
    // Hazards
    case rock, net, shark, stormCloud, mine, jellyfish, whirlpool

    struct Spec {
        let weight: CGFloat                    // relative spawn frequency within its group
        let heightRange: ClosedRange<CGFloat>  // spawn height above the water line
        let radius: CGFloat                    // contact radius
        let isHazard: Bool
        let isZone: Bool                       // continuous effect while overlapping (birds, cloud)
        let artKey: String
    }

    var spec: Spec {
        switch self {
        case .buoy:       return Spec(weight: 30, heightRange: 0...0,     radius: 28,  isHazard: false, isZone: false, artKey: "buoy")
        case .whaleSpout: return Spec(weight: 12, heightRange: 0...0,     radius: 40,  isHazard: false, isZone: false, artKey: "whaleSpout")
        case .motor:      return Spec(weight: 18, heightRange: 40...260,  radius: 26,  isHazard: false, isZone: false, artKey: "motor")
        case .birdFlock:  return Spec(weight: 15, heightRange: 300...900, radius: 110, isHazard: false, isZone: true,  artKey: "birdFlock")
        case .coinBag:    return Spec(weight: 15, heightRange: 60...500,  radius: 24,  isHazard: false, isZone: false, artKey: "coinBag")
        case .fuelCan:    return Spec(weight: 10, heightRange: 30...300,  radius: 24,  isHazard: false, isZone: false, artKey: "fuelCan")
        case .dolphin:    return Spec(weight: 14, heightRange: 0...0,     radius: 38,  isHazard: false, isZone: false, artKey: "dolphin")
        case .balloon:    return Spec(weight: 12, heightRange: 200...650, radius: 34,  isHazard: false, isZone: false, artKey: "balloon")
        case .coin:       return Spec(weight: 0,  heightRange: 0...0,     radius: 20,  isHazard: false, isZone: false, artKey: "coin")
        case .rock:       return Spec(weight: 35, heightRange: 0...0,     radius: 34,  isHazard: true,  isZone: false, artKey: "rock")
        case .net:        return Spec(weight: 25, heightRange: 0...0,     radius: 40,  isHazard: true,  isZone: false, artKey: "net")
        case .shark:      return Spec(weight: 20, heightRange: 0...0,     radius: 34,  isHazard: true,  isZone: false, artKey: "shark")
        case .stormCloud: return Spec(weight: 20, heightRange: 350...900, radius: 100, isHazard: true,  isZone: true,  artKey: "stormCloud")
        case .mine:       return Spec(weight: 18, heightRange: 0...0,     radius: 30,  isHazard: true,  isZone: false, artKey: "mine")
        case .jellyfish:  return Spec(weight: 20, heightRange: 20...180,  radius: 28,  isHazard: true,  isZone: false, artKey: "jellyfish")
        case .whirlpool:  return Spec(weight: 15, heightRange: 0...0,     radius: 90,  isHazard: true,  isZone: true,  artKey: "whirlpool")
        }
    }

    static let boosts = EntityKind.allCases.filter { !$0.spec.isHazard && $0.spec.weight > 0 }
    static let hazards = EntityKind.allCases.filter { $0.spec.isHazard && $0.spec.weight > 0 }

    /// Distance (metres) before this kind starts spawning, so the bay gets meaner as the player
    /// gets further and every run early on introduces at most a couple of new things.
    var unlockMetres: CGFloat {
        switch self {
        case .shark:      return 150
        case .balloon:    return 200
        case .jellyfish:  return 250
        case .stormCloud: return 300
        case .dolphin:    return 300
        case .mine:       return 400
        case .whirlpool:  return 700
        default:          return 0
        }
    }

    /// One-line tip shown the first time the boat ever touches this kind.
    var tip: (title: String, detail: String)? {
        switch self {
        case .buoy:       return ("BUOY", "Springy — bounces you back up.")
        case .whaleSpout: return ("WHALE SPOUT", "A huge vertical launch.")
        case .motor:      return ("OUTBOARD MOTOR", "A burst of forward speed.")
        case .birdFlock:  return ("SEAGULL FLOCK", "Fly through for lift and push.")
        case .dolphin:    return ("DOLPHIN", "Rides you forward at full speed.")
        case .balloon:    return ("BALLOONS", "Low gravity for a couple of seconds.")
        case .rock:       return ("ROCK", "Hurts and kills your speed.")
        case .net:        return ("FISHING NET", "Tangles you — big slowdown.")
        case .shark:      return ("SHARK", "Bites the hull, knocks you up.")
        case .stormCloud: return ("STORM CLOUD", "Pushes you down while inside.")
        case .mine:       return ("SEA MINE", "Hurts, but blasts you skyward!")
        case .jellyfish:  return ("JELLYFISH", "Stings — no rockets or dive for a moment.")
        case .whirlpool:  return ("WHIRLPOOL", "Drags you down. Skip clear of it!")
        case .coinBag, .fuelCan, .coin: return nil
        }
    }
    /// Waterline hazards are the ones that can form an unfair wall; the spawner spaces these out.
    var isWaterHazard: Bool { spec.isHazard && spec.heightRange.upperBound == 0 }
}

/// A spawned world object. Static physics body used purely for contact detection.
final class WorldEntity: SKNode {
    let kind: EntityKind
    var consumed = false
    private let art: SKNode

    init(kind: EntityKind) {
        self.kind = kind
        art = Art.sprite(kind.spec.artKey)
        super.init()
        addChild(art)

        let spec = kind.spec
        let body = SKPhysicsBody(circleOfRadius: spec.radius)
        body.isDynamic = false
        body.categoryBitMask = spec.isZone ? PhysicsCategory.zone : (spec.isHazard ? PhysicsCategory.hazard : PhysicsCategory.boost)
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        physicsBody = body
        zPosition = spec.isZone ? 20 : 30

        addIdleAnimation()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func addIdleAnimation() {
        switch kind {
        case .buoy:
            art.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.12, duration: 0.9), .rotate(toAngle: -0.12, duration: 0.9)
            ])))
        case .motor, .coinBag, .fuelCan:
            art.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 8, duration: 0.7), .moveBy(x: 0, y: -8, duration: 0.7)
            ])))
        case .coin:
            art.run(.repeatForever(.sequence([
                .scaleX(to: 0.3, duration: 0.35), .scaleX(to: 1, duration: 0.35)
            ])))
        case .balloon:
            art.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 14, duration: 1.1), .moveBy(x: 0, y: -14, duration: 1.1)
            ])))
        case .dolphin:
            art.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 10, duration: 0.5), .moveBy(x: 0, y: -10, duration: 0.5)
            ])))
        case .mine:
            art.run(.repeatForever(.sequence([
                .rotate(byAngle: .pi * 2, duration: 6)
            ])))
        case .jellyfish:
            art.run(.repeatForever(.sequence([
                .group([.scaleX(to: 1.15, duration: 0.6), .scaleY(to: 0.85, duration: 0.6), .moveBy(x: 0, y: -6, duration: 0.6)]),
                .group([.scaleX(to: 1.0, duration: 0.6), .scaleY(to: 1.0, duration: 0.6), .moveBy(x: 0, y: 6, duration: 0.6)])
            ])))
        case .whirlpool:
            art.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 1.6)))
        case .birdFlock:
            art.run(.repeatForever(.sequence([
                .scaleY(to: 0.85, duration: 0.25), .scaleY(to: 1.0, duration: 0.25)
            ])))
        case .whaleSpout:
            art.run(.repeatForever(.sequence([
                .scaleY(to: 1.08, duration: 0.5), .scaleY(to: 0.94, duration: 0.5)
            ])))
        case .shark:
            art.run(.repeatForever(.sequence([
                .moveBy(x: -12, y: 0, duration: 0.8), .moveBy(x: 12, y: 0, duration: 0.8)
            ])))
        case .stormCloud:
            art.run(.repeatForever(.sequence([
                .wait(forDuration: 1.6), .fadeAlpha(to: 0.6, duration: 0.05), .fadeAlpha(to: 1, duration: 0.1),
                .fadeAlpha(to: 0.7, duration: 0.05), .fadeAlpha(to: 1, duration: 0.2)
            ])))
        case .rock, .net:
            break
        }
    }

    // MARK: - Effects

    /// One-shot effect when the boat touches this entity. Zones are handled in `enterZone`/`exitZone`.
    /// Returns a short description of what happened so the scene can add juice.
    func apply(to player: Player, in scene: GameScene) {
        guard !consumed, !kind.spec.isZone else { return }
        consumed = true
        var v = player.velocity

        switch kind {
        case .buoy:
            // Springy bounce: only meaningful when coming down or sliding on the water.
            v.dy = abs(v.dy) * Tuning.buoyKeepFraction + Tuning.buoyBounceSpeed
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            art.run(.sequence([.scaleY(to: 0.6, duration: 0.06), .scaleY(to: 1.15, duration: 0.12), .scaleY(to: 1, duration: 0.1)]))
            scene.juice(.bump, at: position)
            consumed = false                                  // buoys can be used again on a later hop

        case .whaleSpout:
            v.dy = Tuning.whaleSpoutSpeed
            v.dx += Tuning.whaleSpoutForward
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            art.run(.sequence([.scaleY(to: 1.5, duration: 0.15), .scaleY(to: 1, duration: 0.4)]))
            scene.juice(.whale, at: position)

        case .motor:
            v.dx += Tuning.motorPush
            player.velocity = v
            player.rocketTrail.particleBirthRate = 200
            player.rocketTrail.run(.sequence([.wait(forDuration: 0.4), .run { [weak player] in player?.rocketTrail.particleBirthRate = 0 }]))
            scene.juice(.motor, at: position)
            vanish()

        case .coinBag:
            scene.awardCoins(Tuning.coinBagValue, at: position)
            vanish()

        case .fuelCan:
            scene.awardCoins(Tuning.fuelCanValue, at: position)
            vanish()

        case .coin:
            scene.awardCoins(Tuning.coinValue, at: position, quiet: true)
            vanish()

        case .dolphin:
            // Dolphin ride: keeps every bit of horizontal speed and adds a shove — the best water pickup.
            v.dy = max(v.dy, 0) * 0.3 + Tuning.dolphinBounceUp
            v.dx += Tuning.dolphinPushForward
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            art.run(.sequence([.moveBy(x: 30, y: 60, duration: 0.25), .moveBy(x: 30, y: -60, duration: 0.3), .removeFromParent()]))
            scene.juice(.dolphin, at: position)

        case .balloon:
            v.dy += Tuning.balloonLift
            player.velocity = v
            player.float(seconds: Tuning.balloonFloatSeconds)
            scene.juice(.balloon, at: position)
            vanish()

        case .mine:
            // Risk/reward: the blast hurts but hurls the boat back into the air.
            v.dx *= Tuning.mineSpeedMultiplier
            v.dy = max(v.dy, 0) + Tuning.mineKnockUp
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            scene.damagePlayer(Tuning.mineDamage, shake: 18)
            scene.juice(.explosion, at: position)
            vanish()

        case .jellyfish:
            v.dy *= Tuning.jellyfishVerticalMultiplier
            player.velocity = v
            player.stun(seconds: Tuning.jellyfishStunSeconds)
            scene.damagePlayer(Tuning.jellyfishDamage, shake: 6)
            art.run(.sequence([.scale(to: 1.3, duration: 0.1), .scale(to: 1, duration: 0.25)]))
            scene.juice(.sting, at: position)

        case .rock:
            v.dx *= Tuning.rockSpeedMultiplier
            player.velocity = v
            scene.damagePlayer(Tuning.rockDamage, shake: 10)
            scene.juice(.hurt, at: position)

        case .net:
            v.dx *= Tuning.netSpeedMultiplier
            v.dy *= Tuning.netVerticalMultiplier
            player.velocity = v
            art.run(.sequence([.scale(to: 1.25, duration: 0.1), .scale(to: 1, duration: 0.2)]))
            scene.juice(.net, at: position)

        case .shark:
            v.dx *= Tuning.sharkSpeedMultiplier
            v.dy = max(v.dy, 0) + Tuning.sharkKnockUp
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            scene.damagePlayer(Tuning.sharkDamage, shake: 8)
            art.run(.sequence([.moveBy(x: 0, y: 26, duration: 0.12), .moveBy(x: 0, y: -26, duration: 0.3)]))
            scene.juice(.hurt, at: position)

        case .birdFlock, .stormCloud, .whirlpool:
            break
        }
    }

    func enterZone(player: Player) {
        switch kind {
        case .birdFlock: player.liftZones += 1
        case .stormCloud: player.downdraftZones += 1
        case .whirlpool: player.whirlpoolZones += 1
        default: break
        }
    }

    func exitZone(player: Player) {
        switch kind {
        case .birdFlock: player.liftZones = max(0, player.liftZones - 1)
        case .stormCloud: player.downdraftZones = max(0, player.downdraftZones - 1)
        case .whirlpool: player.whirlpoolZones = max(0, player.whirlpoolZones - 1)
        default: break
        }
    }

    private func vanish() {
        physicsBody = nil
        run(.sequence([.group([.scale(to: 1.4, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
    }
}
