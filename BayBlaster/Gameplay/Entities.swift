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
    /// Smashables and the high air. `barrier` is neither a boost nor a hazard: it is an
    /// obstacle with a speed check, placed on its own spawn track.
    case barrier, crate, blimp, boostRing, jetStream

    struct Spec {
        let weight: CGFloat                    // relative spawn frequency on the low track
        let heightRange: ClosedRange<CGFloat>  // spawn height above the water line
        let radius: CGFloat                    // contact radius
        let isHazard: Bool
        let isZone: Bool                       // continuous effect while overlapping (birds, cloud)
        let artKey: String
        /// Relative frequency on the HIGH-AIR track (WorldSpawner's second, independent pass
        /// that fills the sky above `Tuning.highAirStartHeight`). 0 = never spawns up there.
        var highAirWeight: CGFloat = 0
    }

    var spec: Spec {
        switch self {
        case .buoy:       return Spec(weight: 30, heightRange: 0...0,     radius: 28,  isHazard: false, isZone: false, artKey: "buoy")
        case .whaleSpout: return Spec(weight: 12, heightRange: 0...0,     radius: 40,  isHazard: false, isZone: false, artKey: "whaleSpout")
        case .motor:      return Spec(weight: 18, heightRange: 40...260,  radius: 26,  isHazard: false, isZone: false, artKey: "motor")
        case .birdFlock:  return Spec(weight: 15, heightRange: 300...900, radius: 110, isHazard: false, isZone: true,  artKey: "birdFlock", highAirWeight: 22)
        case .coinBag:    return Spec(weight: 15, heightRange: 60...500,  radius: 24,  isHazard: false, isZone: false, artKey: "coinBag")
        case .fuelCan:    return Spec(weight: 10, heightRange: 30...300,  radius: 24,  isHazard: false, isZone: false, artKey: "fuelCan")
        case .dolphin:    return Spec(weight: 14, heightRange: 0...0,     radius: 38,  isHazard: false, isZone: false, artKey: "dolphin")
        case .balloon:    return Spec(weight: 12, heightRange: 200...650, radius: 34,  isHazard: false, isZone: false, artKey: "balloon")
        case .coin:       return Spec(weight: 0,  heightRange: 0...0,     radius: 20,  isHazard: false, isZone: false, artKey: "coin")
        case .rock:       return Spec(weight: 35, heightRange: 0...0,     radius: 34,  isHazard: true,  isZone: false, artKey: "rock")
        case .net:        return Spec(weight: 25, heightRange: 0...0,     radius: 40,  isHazard: true,  isZone: false, artKey: "net")
        case .shark:      return Spec(weight: 20, heightRange: 0...0,     radius: 34,  isHazard: true,  isZone: false, artKey: "shark")
        case .stormCloud: return Spec(weight: 20, heightRange: 350...900, radius: 100, isHazard: true,  isZone: true,  artKey: "stormCloud", highAirWeight: 14)
        case .mine:       return Spec(weight: 18, heightRange: 0...0,     radius: 30,  isHazard: true,  isZone: false, artKey: "mine")
        case .jellyfish:  return Spec(weight: 20, heightRange: 20...180,  radius: 28,  isHazard: true,  isZone: false, artKey: "jellyfish")
        case .whirlpool:  return Spec(weight: 15, heightRange: 0...0,     radius: 90,  isHazard: true,  isZone: true,  artKey: "whirlpool")
        // Barriers are placed by their own track, so their low-track weight is 0. The radius
        // is unused: a wall builds a rectangle body sized to its block count.
        case .barrier:    return Spec(weight: 0,  heightRange: 0...0,     radius: 40,  isHazard: false, isZone: false, artKey: "barrierWood")
        case .crate:      return Spec(weight: 14, heightRange: 0...220,   radius: 26,  isHazard: false, isZone: false, artKey: "crate")
        case .blimp:      return Spec(weight: 0,  heightRange: 900...2200, radius: 70, isHazard: false, isZone: false, artKey: "blimp", highAirWeight: 24)
        case .boostRing:  return Spec(weight: 10, heightRange: 200...1800, radius: 44, isHazard: false, isZone: false, artKey: "boostRing", highAirWeight: 26)
        case .jetStream:  return Spec(weight: 0,  heightRange: 1100...2600, radius: 170, isHazard: false, isZone: true, artKey: "jetStream", highAirWeight: 18)
        }
    }

    static let boosts = EntityKind.allCases.filter { !$0.spec.isHazard && $0.spec.weight > 0 }
    static let hazards = EntityKind.allCases.filter { $0.spec.isHazard && $0.spec.weight > 0 }
    /// The pool the high-air track draws from — see `Tuning.highAirStartHeight`.
    static let highAir = EntityKind.allCases.filter { $0.spec.highAirWeight > 0 }

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
        case .boostRing:  return 80
        case .barrier:    return Tuning.barrierStartMeters
        case .blimp:      return 400
        case .jetStream:  return 900
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
        case .barrier:    return ("WALL", "Smash it at speed. Too slow and it stops you dead.")
        case .crate:      return ("SUPPLY CRATE", "Always breaks. Free coins.")
        case .blimp:      return ("BLIMP", "A trampoline in the sky.")
        case .boostRing:  return ("BOOST RING", "Fly clean through for a shove and a payout.")
        case .jetStream:  return ("JET STREAM", "A river of wind. Stay in it.")
        case .coinBag, .fuelCan, .coin: return nil
        }
    }
    /// Waterline hazards are the ones that can form an unfair wall; the spawner spaces these out.
    var isWaterHazard: Bool { spec.isHazard && spec.heightRange.upperBound == 0 }
}

/// A spawned world object. Static physics body used purely for contact detection.
///
/// Most kinds are a single sprite with a circular body. A `.barrier` is the exception: it is a
/// stack of `blocks` bricks standing on the water with a rectangular body, and it carries a
/// `toughness` — the speed you have to be doing to smash through it.
final class WorldEntity: SKNode {
    let kind: EntityKind
    var consumed = false
    /// Barriers only: the speed needed to break through, and how many bricks tall the wall is.
    let toughness: CGFloat
    let blocks: Int
    private let art: SKNode

    init(kind: EntityKind, toughness: CGFloat = 0, blocks: Int = 0) {
        self.kind = kind
        self.toughness = toughness
        self.blocks = blocks
        let spec = kind.spec

        if kind == .barrier {
            // One brick per block, stacked from the water line up. The tier art is chosen by
            // toughness so a wall's difficulty reads at a glance: planks, then stone, then iron.
            let stack = SKNode()
            let key = WorldEntity.barrierArtKey(toughness: toughness)
            for i in 0..<max(1, blocks) {
                let brick = Art.sprite(key)
                brick.position = CGPoint(x: 0, y: Tuning.barrierBlockSize * (CGFloat(i) + 0.5))
                stack.addChild(brick)
            }
            art = stack
        } else {
            art = Art.sprite(spec.artKey)
        }
        super.init()
        addChild(art)

        let body: SKPhysicsBody
        if kind == .barrier {
            let height = Tuning.barrierBlockSize * CGFloat(max(1, blocks))
            body = SKPhysicsBody(rectangleOf: CGSize(width: Tuning.barrierBlockSize * 0.7, height: height),
                                 center: CGPoint(x: 0, y: height / 2))
        } else {
            body = SKPhysicsBody(circleOfRadius: spec.radius)
        }
        body.isDynamic = false
        body.categoryBitMask = spec.isZone ? PhysicsCategory.zone : (spec.isHazard ? PhysicsCategory.hazard : PhysicsCategory.boost)
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        physicsBody = body
        zPosition = spec.isZone ? 20 : 30

        addIdleAnimation()
    }

    /// Plank / stone / iron, by how hard the wall is to break.
    static func barrierArtKey(toughness: CGFloat) -> String {
        if toughness >= Tuning.barrierIronToughness { return "barrierIron" }
        if toughness >= Tuning.barrierStoneToughness { return "barrierStone" }
        return "barrierWood"
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
        case .blimp:
            art.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 16, duration: 1.4), .moveBy(x: 0, y: -16, duration: 1.4)
            ])))
        case .boostRing:
            art.run(.repeatForever(.sequence([
                .scaleX(to: 0.86, duration: 0.8), .scaleX(to: 1, duration: 0.8)
            ])))
        case .jetStream:
            art.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.1), .fadeAlpha(to: 0.9, duration: 1.1)
            ])))
        case .crate:
            art.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.08, duration: 1.2), .rotate(toAngle: -0.08, duration: 1.2)
            ])))
        case .rock, .net, .barrier:
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
            if !player.ignoresHazardSlowdown { v.dx *= Tuning.mineSpeedMultiplier }
            v.dy = max(v.dy, 0) + Tuning.mineKnockUp
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            scene.damagePlayer(Tuning.mineDamage, shake: 18)
            scene.juice(.explosion, at: position)
            vanish()

        case .jellyfish:
            if !player.ignoresHazardSlowdown { v.dy *= Tuning.jellyfishVerticalMultiplier }
            player.velocity = v
            player.stun(seconds: Tuning.jellyfishStunSeconds)
            scene.damagePlayer(Tuning.jellyfishDamage, shake: 6)
            art.run(.sequence([.scale(to: 1.3, duration: 0.1), .scale(to: 1, duration: 0.25)]))
            scene.juice(.sting, at: position)

        case .rock:
            if !player.ignoresHazardSlowdown { v.dx *= Tuning.rockSpeedMultiplier }
            player.velocity = v
            scene.damagePlayer(Tuning.rockDamage, shake: 10)
            scene.juice(.hurt, at: position)

        case .net:
            if !player.ignoresHazardSlowdown {
                v.dx *= Tuning.netSpeedMultiplier
                v.dy *= Tuning.netVerticalMultiplier
            }
            player.velocity = v
            art.run(.sequence([.scale(to: 1.25, duration: 0.1), .scale(to: 1, duration: 0.2)]))
            scene.juice(.net, at: position)

        case .shark:
            if !player.ignoresHazardSlowdown { v.dx *= Tuning.sharkSpeedMultiplier }
            v.dy = max(v.dy, 0) + Tuning.sharkKnockUp
            player.resumeFlying()
            player.position.y = max(player.position.y, Tuning.waterY + 1)
            player.velocity = v
            scene.damagePlayer(Tuning.sharkDamage, shake: 8)
            art.run(.sequence([.moveBy(x: 0, y: 26, duration: 0.12), .moveBy(x: 0, y: -26, duration: 0.3)]))
            scene.juice(.hurt, at: position)

        case .barrier:
            // The Burrito Bison beat. Fast enough and the wall explodes; too slow and it stops
            // you where you stand. Tock's shell counts as "fast enough" — shelling up right
            // before a wall you can't break is exactly the play the ability is for.
            let speed = player.boatSpeed
            if speed >= toughness {
                smash(player: player, in: scene, shielded: false)
            } else if player.consumeShield() {
                smash(player: player, in: scene, shielded: true)
            } else {
                v.dx *= Tuning.barrierBounceSpeedMultiplier
                v.dy = min(v.dy, 0)
                player.velocity = v
                player.position.x -= Tuning.barrierBounceBack     // shove clear so it can't re-trigger
                scene.damagePlayer(Tuning.barrierDamage, shake: 14)
                scene.juice(.clang, at: CGPoint(x: position.x, y: player.position.y))
                art.run(.sequence([.moveBy(x: 7, y: 0, duration: 0.05),
                                   .moveBy(x: -14, y: 0, duration: 0.08),
                                   .moveBy(x: 7, y: 0, duration: 0.06)]))
                consumed = false                                   // the wall is still standing
            }

        case .crate:
            v.dx *= Tuning.crateSpeedKeep
            player.velocity = v
            scene.awardCoins(Tuning.crateCoins, at: position)
            scene.juice(.smash, at: position)
            vanish()

        case .blimp:
            v.dy = abs(v.dy) * Tuning.blimpKeepFraction + Tuning.blimpBounceSpeed
            v.dx += Tuning.blimpForward
            player.velocity = v
            art.run(.sequence([.scaleY(to: 0.7, duration: 0.08), .scaleY(to: 1.12, duration: 0.14), .scaleY(to: 1, duration: 0.1)]))
            scene.juice(.bump, at: position)
            consumed = false                                       // bounce off it again later

        case .boostRing:
            // Keep the direction you were flying, just faster — the reward is for lining it up.
            let current = (v.dx * v.dx + v.dy * v.dy).squareRoot()
            if current > 1 {
                let boosted = current + Tuning.boostRingSpeed
                v.dx = v.dx / current * boosted
                v.dy = v.dy / current * boosted
            } else {
                v.dx += Tuning.boostRingSpeed
            }
            player.velocity = v
            scene.awardCoins(Tuning.boostRingCoins, at: position)
            scene.juice(.ring, at: position)
            physicsBody = nil          // the ring is spent; don't keep generating contacts
            art.run(.sequence([.scale(to: 1.5, duration: 0.14), .fadeOut(withDuration: 0.2)]))
            run(.sequence([.wait(forDuration: 0.4), .removeFromParent()]))

        case .birdFlock, .stormCloud, .whirlpool, .jetStream:
            break
        }
    }

    /// Break through a wall: lose a little speed, gain coins per brick, and scatter the bricks.
    private func smash(player: Player, in scene: GameScene, shielded: Bool) {
        var v = player.velocity
        v.dx *= Tuning.barrierSmashSpeedKeep
        player.velocity = v
        scene.awardCoins(Tuning.barrierSmashCoinsPerBlock * max(1, blocks), at: CGPoint(x: position.x, y: player.position.y))
        scene.juice(shielded ? .shieldSmash : .smash, at: CGPoint(x: position.x, y: player.position.y))
        scene.noteBarrierSmashed()
        shatter()
    }

    /// Fling the bricks apart instead of just fading the wall out.
    private func shatter() {
        physicsBody = nil
        for brick in art.children {
            let dx = CGFloat.random(in: 60...240)
            let dy = CGFloat.random(in: 40...260)
            brick.run(.sequence([
                .group([.moveBy(x: dx, y: dy, duration: 0.35),
                        .rotate(byAngle: CGFloat.random(in: -4...4), duration: 0.6),
                        .sequence([.wait(forDuration: 0.15), .fadeOut(withDuration: 0.45)]),
                        .sequence([.wait(forDuration: 0.35), .moveBy(x: dx * 0.5, y: -dy - 200, duration: 0.45)])]),
                .removeFromParent()
            ]))
        }
        run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
    }

    /// Tock's shell soaking up a hazard before it lands. Spends the charge, removes the
    /// entity and applies nothing at all — no damage, no speed loss, no stun.
    func blockByShield(in scene: GameScene) {
        guard !consumed else { return }
        consumed = true
        scene.juice(.blocked, at: position)
        vanish()
    }

    func enterZone(player: Player) {
        switch kind {
        case .birdFlock: player.liftZones += 1
        case .stormCloud: player.downdraftZones += 1
        case .whirlpool: player.whirlpoolZones += 1
        case .jetStream: player.jetStreamZones += 1
        default: break
        }
    }

    func exitZone(player: Player) {
        switch kind {
        case .birdFlock: player.liftZones = max(0, player.liftZones - 1)
        case .stormCloud: player.downdraftZones = max(0, player.downdraftZones - 1)
        case .whirlpool: player.whirlpoolZones = max(0, player.whirlpoolZones - 1)
        case .jetStream: player.jetStreamZones = max(0, player.jetStreamZones - 1)
        default: break
        }
    }

    private func vanish() {
        physicsBody = nil
        run(.sequence([.group([.scale(to: 1.4, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
    }
}
