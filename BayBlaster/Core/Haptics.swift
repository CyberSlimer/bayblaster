import UIKit

/// Thin wrapper around UIKit feedback generators. Generators are kept alive and prepared so
/// the first tap of a run doesn't feel late.
enum Haptics {
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private static let notifyGen = UINotificationFeedbackGenerator()

    static func prepare() {
        lightGen.prepare(); mediumGen.prepare(); heavyGen.prepare(); rigidGen.prepare(); notifyGen.prepare()
    }

    /// Water-skip tick.
    static func skip() { lightGen.impactOccurred(intensity: 0.7) }
    /// Rocket fire, buoy bounce, pickups.
    static func medium(_ intensity: CGFloat = 1) { mediumGen.impactOccurred(intensity: intensity) }
    /// Launch and hard impacts.
    static func heavy() { heavyGen.impactOccurred() }
    /// Angle/power lock.
    static func lock() { rigidGen.impactOccurred(intensity: 0.8) }
    /// Purchases, new best.
    static func success() { notifyGen.notificationOccurred(.success) }
    static func failure() { notifyGen.notificationOccurred(.error) }
}
