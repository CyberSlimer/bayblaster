import CoreGraphics
import Foundation

/// Resolves the boat against the water line every frame. The water is deliberately *not* a
/// physics body: whether a landing skips or plows depends on impact angle and speed, and the
/// bounce keeps a tuned fraction of each velocity component — none of which SKPhysicsBody's
/// single restitution value can express.
struct WaterSkipSystem {

    enum Outcome {
        /// Bounced off the surface. `impactSpeed` is the speed just before the bounce.
        case skipped(impactSpeed: CGFloat, hardImpact: Bool, damage: CGFloat)
        /// Landed too steep or too slow: now sliding in the water under heavy drag.
        case plowed(impactSpeed: CGFloat, hardImpact: Bool, damage: CGFloat)
    }

    /// Call once per frame *after* the physics step has moved the body.
    func resolve(player: Player) -> Outcome? {
        guard player.state == .flying else { return nil }
        guard player.position.y <= Tuning.waterY else { return nil }

        let v = player.velocity
        // Rising through the water line (e.g. thrown up by a whale) — just let it go.
        guard v.dy < 0 else {
            player.position.y = Tuning.waterY + 0.5
            return nil
        }

        let impactSpeed = (v.dx * v.dx + v.dy * v.dy).squareRoot()
        let impactAngle = atan2(-v.dy, max(v.dx, 0.001))          // 0 = grazing, π/2 = straight down
        let maxAngle = (player.isDiving ? Tuning.diveSkipMaxAngleDegrees : Tuning.skipMaxAngleDegrees) * .pi / 180

        // Hull damage from slamming in fast, regardless of skip/plow.
        var damage: CGFloat = 0
        let threshold = player.config.hardImpactThreshold
        if impactSpeed > threshold {
            damage = (impactSpeed - threshold) / 100 * Tuning.hardImpactDamagePer100
        }
        let hard = damage > 0

        let canSkip = -v.dy > Tuning.skipMinVerticalSpeed
            && v.dx > Tuning.skipMinHorizontalSpeed
            && impactAngle < maxAngle

        player.position.y = Tuning.waterY

        if canSkip {
            let restitution = Tuning.skipVerticalRestitution * (player.isDiving ? Tuning.diveSkipRestitutionBonus : 1)
            player.velocity = CGVector(dx: v.dx * player.config.skipHorizontalRetention,
                                       dy: -v.dy * restitution)
            player.endFlightSegment()
            return .skipped(impactSpeed: impactSpeed, hardImpact: hard, damage: damage)
        } else {
            player.beginPlowing()
            return .plowed(impactSpeed: impactSpeed, hardImpact: hard, damage: damage)
        }
    }
}
