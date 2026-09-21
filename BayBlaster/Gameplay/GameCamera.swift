import SpriteKit

/// Follows the boat with horizontal lead and eased vertical/zoom changes, always keeping the
/// water line near the bottom of the screen. Also owns the impact shake.
final class GameCamera: SKCameraNode {
    /// Scale that shows `Tuning.cameraVisibleHeight` world points on this screen.
    private(set) var baseScale: CGFloat = 1
    private var zoom: CGFloat = 1                 // multiplier on top of baseScale
    private var lead: CGFloat = 0
    private var shakeAmount: CGFloat = 0
    private var shakeOffset: CGPoint = .zero
    /// Transient multiplier on the zoom, eased back to 1. A launch snaps this below 1 so the
    /// camera lurches in on the muzzle and then pulls out as the boat climbs away.
    private var punch: CGFloat = 1

    /// Camera scale currently applied (baseScale × zoom × punch).
    var effectiveScale: CGFloat { baseScale * zoom * punch }

    func configure(sceneSize: CGSize) {
        baseScale = Tuning.cameraVisibleHeight / max(sceneSize.height, 1)
        setScale(effectiveScale)
    }

    /// Jump straight to the target (used at scene start).
    func snap(to target: CGPoint) {
        zoom = 1
        punch = 1
        lead = 0
        position = CGPoint(x: target.x, y: restingY())
        setScale(effectiveScale)
    }

    func shake(_ amount: CGFloat) {
        shakeAmount = max(shakeAmount, amount)
    }

    /// Snap the view in (or out) and let `follow` ease it back. Below 1 = punch in.
    func punchZoom(_ amount: CGFloat) {
        punch = amount
    }

    /// Water line sits `cameraWaterFraction` of the way up the screen.
    private func restingY() -> CGFloat {
        let halfH = Tuning.cameraVisibleHeight / 2 * zoom
        return Tuning.waterY + halfH * (1 - 2 * Tuning.cameraWaterFraction)
    }

    func follow(target: CGPoint, velocity: CGVector, dt: CGFloat) {
        let halfH0 = Tuning.cameraVisibleHeight / 2
        // Zoom needed to keep the boat under the top edge while the water stays put.
        let topFactor = 1 + (1 - 2 * Tuning.cameraWaterFraction)            // top edge = waterY + topFactor * halfH
        let altitudeZoom = (target.y + Tuning.cameraTopMargin - Tuning.waterY) / (topFactor * halfH0)
        let speed = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot()
        let speedZoom = 1 + clamp(speed / Tuning.cameraSpeedZoomRef, 0, 1) * Tuning.cameraSpeedZoomMax
        let targetZoom = max(1, altitudeZoom, speedZoom)
        zoom = lerp(zoom, targetZoom, easeFactor(Tuning.cameraZoomEase, dt))
        punch = lerp(punch, 1, easeFactor(Tuning.cameraPunchEase, dt))

        let targetLead = clamp(velocity.dx * Tuning.cameraLeadFactor, 0, Tuning.cameraMaxLead) * zoom
        lead = lerp(lead, targetLead, easeFactor(Tuning.cameraLeadEase, dt))

        let targetY = restingY()
        let y = lerp(position.y - shakeOffset.y, targetY, easeFactor(Tuning.cameraYEase, dt))
        let x = target.x + lead

        // Shake
        if shakeAmount > 0.2 {
            shakeOffset = CGPoint(x: CGFloat.random(in: -shakeAmount...shakeAmount) * zoom,
                                  y: CGFloat.random(in: -shakeAmount...shakeAmount) * zoom)
            shakeAmount *= exp(-Tuning.cameraShakeDecay * dt)
        } else {
            shakeAmount = 0
            shakeOffset = .zero
        }

        position = CGPoint(x: x + shakeOffset.x, y: y + shakeOffset.y)
        setScale(effectiveScale)
    }
}
