import CoreGraphics
import Foundation

/// Resolves the boat against the water line every frame. The water is deliberately *not* a
/// physics body: whether a landing skips or plows depends on impact angle and speed, and the
/// bounce keeps a tuned fraction of each velocity component — none of which SKPhysicsBody's
/// single restitution value can express.
///
/// Every threshold it reads comes from `player.config` rather than `Tuning` directly, because
/// the skip window and the bounce are both things gear and riders change (Pontoons widen the
/// window, a Spring Keel makes the bounce livelier). Two abilities can also override the
/// verdict outright: Bristle's puff turns any landing into a skip, and Bruno's belly slam
/// turns the landing it caused into a very big one.
struct WaterSkipSystem {

    enum Outcome {
        /// Bounced off the surface. `impactSpeed` is the speed just before the bounce; `perfect`
        /// means the landing was shallow enough to earn the bonus; `forced` means an ability
        /// made it skip when it otherwise would not have.
        case skipped(impactSpeed: CGFloat, hardImpact: Bool, damage: CGFloat, perfect: Bool, forced: Bool)
        /// Landed too steep or too slow: now sliding in the water under heavy drag.
        case plowed(impactSpeed: CGFloat, hardImpact: Bool, damage: CGFloat)
    }

    /// Call once per frame *after* the physics step has moved the body.
    func resolve(player: Player) -> Outcome? {
        guard player.state == .flying else { return nil }
        guard player.position.y <= Tuning.waterY else { return nil }

        let config = player.config
        let v = player.velocity
        // Rising through the water line (e.g. thrown up by a whale) — just let it go.
        guard v.dy < 0 else {
            player.position.y = Tuning.waterY + 0.5
            return nil
        }

        let impactSpeed = (v.dx * v.dx + v.dy * v.dy).squareRoot()
        let impactAngle = atan2(-v.dy, max(v.dx, 0.001))          // 0 = grazing, π/2 = straight down
        let maxAngle = (player.isDiving ? config.diveSkipMaxAngleDegrees : config.skipMaxAngleDegrees) * .pi / 180

        // Hull damage from slamming in fast, regardless of skip/plow.
        var damage: CGFloat = 0
        let threshold = config.hardImpactThreshold
        if impactSpeed > threshold {
            damage = (impactSpeed - threshold) / 100 * Tuning.hardImpactDamagePer100
        }
        let hard = damage > 0

        // An armed belly slam is spent here whether or not the landing needed the help.
        let slammed = player.consumeSlam()
        let forced = slammed || player.forcesSkip

        let naturalSkip = -v.dy > Tuning.skipMinVerticalSpeed
            && v.dx > Tuning.skipMinHorizontalSpeed
            && impactAngle < maxAngle
        // A forced skip still needs *some* forward speed, or the boat would bounce on the spot.
        let canSkip = naturalSkip || (forced && v.dx > Tuning.skipMinHorizontalSpeed)

        player.position.y = Tuning.waterY

        if canSkip {
            var restitution = config.skipRestitution
            if player.isDiving { restitution *= Tuning.diveSkipRestitutionBonus }
            if player.activeAbility == .puff { restitution *= Tuning.abilityPuffRestitutionMultiplier }
            if slammed { restitution *= Tuning.abilitySlamRestitutionMultiplier }
            restitution = min(restitution, Tuning.skipRestitutionCeiling)

            let perfect = impactAngle < Tuning.perfectSkipAngleDegrees * .pi / 180
            var retentionRaw = config.skipHorizontalRetention
            if perfect { retentionRaw *= Tuning.perfectSkipSpeedBonus }
            // A belly slam trades height for forward speed, otherwise it is just a pogo stick:
            // each forced bounce would shed horizontal speed and the move would lose distance.
            if slammed { retentionRaw *= Tuning.abilitySlamForwardBonus }
            let retention = min(retentionRaw, Tuning.skipRetentionCeiling)
            // A forced skip off a near-flat landing would otherwise bounce with almost no
            // vertical speed and re-land on the next frame, so give it a floor.
            var bounce = -v.dy * restitution
            if forced && !naturalSkip { bounce = max(bounce, Tuning.forcedSkipMinBounce) }
            player.velocity = CGVector(dx: v.dx * retention, dy: bounce)
            player.endFlightSegment()
            return .skipped(impactSpeed: impactSpeed, hardImpact: hard, damage: damage,
                            perfect: perfect, forced: forced && !naturalSkip)
        } else {
            player.beginPlowing()
            return .plowed(impactSpeed: impactSpeed, hardImpact: hard, damage: damage)
        }
    }
}
