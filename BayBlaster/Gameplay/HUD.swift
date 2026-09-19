import SpriteKit

/// In-flight overlay. Add as a child of the camera: camera children are laid out in screen
/// points regardless of zoom, so everything here is positioned relative to the screen centre.
final class HUD: SKNode {

    private let distanceLabel = SKLabelNode(fontNamed: Tuning.fontHeavy)
    private let coinsLabel = SKLabelNode(fontNamed: Tuning.fontBold)
    private let coinIcon: SKNode
    private let rocketsLabel = SKLabelNode(fontNamed: Tuning.fontBold)
    private let rocketIcon: SKNode
    private let hullBack = SKShapeNode(rectOf: CGSize(width: 150, height: 14), cornerRadius: 7)
    private let hullFill = SKSpriteNode(color: UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1), size: CGSize(width: 146, height: 10))
    private let hullLabel = SKLabelNode(fontNamed: Tuning.fontMedium)
    private let hintLabel = SKLabelNode(fontNamed: Tuning.fontBold)
    private let pauseHint = SKLabelNode(fontNamed: Tuning.fontMedium)

    // Aim-phase widgets
    private let powerBack = SKShapeNode(rectOf: CGSize(width: 22, height: 160), cornerRadius: 8)
    private let powerFill = SKSpriteNode(color: UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1), size: CGSize(width: 16, height: 154))
    private let powerLabel = SKLabelNode(fontNamed: Tuning.fontMedium)
    private let angleLabel = SKLabelNode(fontNamed: Tuning.fontHeavy)
    /// The green band on a .castTiming launcher, and the red "it's about to snap" zone on a
    /// .charge one. Hidden for the plain two-sweep launchers.
    private let sweetBand = SKShapeNode(rectOf: CGSize(width: 22, height: 10), cornerRadius: 4)

    // Ability button (the third in-flight verb)
    private let abilityRing = SKShapeNode(circleOfRadius: 34)
    private let abilityFill = SKShapeNode(circleOfRadius: 30)
    private let abilityLabel = SKLabelNode(fontNamed: Tuning.fontHeavy)
    private let abilityShieldPip = SKLabelNode(fontNamed: Tuning.fontBold)
    /// Where the ability button sits on screen, so GameScene can decide whether a touch was
    /// meant for it rather than for a rocket/dive.
    private(set) var abilityButtonCentre: CGPoint = .zero
    static let abilityButtonRadius: CGFloat = 40
    private var abilityEnabled = false

    private var lastRockets = -1
    private var lastCoins = -1

    override init() {
        coinIcon = Art.sprite("coinIcon")
        rocketIcon = Art.sprite("rocketIcon")
        super.init()
        zPosition = 1000

        distanceLabel.fontSize = 34
        distanceLabel.horizontalAlignmentMode = .left
        distanceLabel.verticalAlignmentMode = .top
        distanceLabel.fontColor = .white
        addChild(distanceLabel)

        coinsLabel.fontSize = 22
        coinsLabel.horizontalAlignmentMode = .left
        coinsLabel.verticalAlignmentMode = .center
        coinsLabel.fontColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)
        addChild(coinsLabel)
        addChild(coinIcon)

        rocketsLabel.fontSize = 22
        rocketsLabel.horizontalAlignmentMode = .right
        rocketsLabel.verticalAlignmentMode = .center
        rocketsLabel.fontColor = .white
        addChild(rocketsLabel)
        addChild(rocketIcon)

        hullBack.fillColor = UIColor.black.withAlphaComponent(0.35)
        hullBack.strokeColor = UIColor.white.withAlphaComponent(0.6)
        hullBack.lineWidth = 1.5
        addChild(hullBack)
        hullFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(hullFill)
        hullLabel.fontSize = 12
        hullLabel.text = "HULL"
        hullLabel.fontColor = .white
        hullLabel.horizontalAlignmentMode = .left
        hullLabel.verticalAlignmentMode = .bottom
        addChild(hullLabel)

        hintLabel.fontSize = 22
        hintLabel.fontColor = .white
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        addChild(hintLabel)

        pauseHint.fontSize = 14
        pauseHint.fontColor = UIColor.white.withAlphaComponent(0.7)
        pauseHint.horizontalAlignmentMode = .center
        pauseHint.verticalAlignmentMode = .bottom
        pauseHint.text = "TAP: rocket   ·   HOLD: nose-dive"
        addChild(pauseHint)

        powerBack.fillColor = UIColor.black.withAlphaComponent(0.35)
        powerBack.strokeColor = UIColor.white.withAlphaComponent(0.7)
        powerBack.lineWidth = 1.5
        addChild(powerBack)
        powerFill.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(powerFill)
        powerLabel.fontSize = 12
        powerLabel.text = "POWER"
        powerLabel.fontColor = .white
        powerLabel.verticalAlignmentMode = .top
        addChild(powerLabel)

        angleLabel.fontSize = 26
        angleLabel.fontColor = .white
        angleLabel.verticalAlignmentMode = .top
        addChild(angleLabel)

        sweetBand.fillColor = UIColor(red: 0.3, green: 0.95, blue: 0.5, alpha: 0.55)
        sweetBand.strokeColor = UIColor(red: 0.5, green: 1, blue: 0.7, alpha: 0.95)
        sweetBand.lineWidth = 2
        sweetBand.isHidden = true
        addChild(sweetBand)

        abilityRing.fillColor = UIColor.black.withAlphaComponent(0.35)
        abilityRing.strokeColor = UIColor.white.withAlphaComponent(0.7)
        abilityRing.lineWidth = 2
        addChild(abilityRing)
        abilityFill.fillColor = UIColor(red: 0.35, green: 0.75, blue: 1, alpha: 0.85)
        abilityFill.strokeColor = .clear
        addChild(abilityFill)
        abilityLabel.fontSize = 13
        abilityLabel.fontColor = .white
        abilityLabel.verticalAlignmentMode = .center
        abilityLabel.horizontalAlignmentMode = .center
        addChild(abilityLabel)
        abilityShieldPip.fontSize = 12
        abilityShieldPip.fontColor = UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        abilityShieldPip.verticalAlignmentMode = .center
        abilityShieldPip.horizontalAlignmentMode = .center
        abilityShieldPip.text = ""
        addChild(abilityShieldPip)
        setAbilityVisible(false)

        setAimWidgets(visible: false)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Layout (screen points, origin at centre)

    func layout(sceneSize: CGSize, insets: UIEdgeInsets) {
        let w = sceneSize.width, h = sceneSize.height
        let left = -w / 2 + insets.left + 16
        let right = w / 2 - insets.right - 16
        let top = h / 2 - insets.top - 12
        let bottom = -h / 2 + insets.bottom + 14

        distanceLabel.position = CGPoint(x: left, y: top)
        coinIcon.position = CGPoint(x: left + 10, y: top - 52)
        coinsLabel.position = CGPoint(x: left + 26, y: top - 52)

        rocketIcon.position = CGPoint(x: right - 10, y: top - 18)
        rocketsLabel.position = CGPoint(x: right - 30, y: top - 18)

        hullBack.position = CGPoint(x: right - 75, y: bottom + 8)
        hullFill.position = CGPoint(x: right - 148, y: bottom + 8)
        hullLabel.position = CGPoint(x: right - 150, y: bottom + 18)

        hintLabel.position = CGPoint(x: 0, y: h * 0.28)
        pauseHint.position = CGPoint(x: 0, y: bottom)

        powerBack.position = CGPoint(x: left + 40, y: 0)
        powerFill.position = CGPoint(x: left + 40, y: -77)
        powerLabel.position = CGPoint(x: left + 40, y: -88)
        angleLabel.position = CGPoint(x: left + 40, y: 96)
        sweetBand.position = CGPoint(x: left + 40, y: 0)

        // Bottom-right, above the hull bar, comfortably inside the thumb's reach.
        abilityButtonCentre = CGPoint(x: right - 54, y: bottom + 74)
        abilityRing.position = abilityButtonCentre
        abilityFill.position = abilityButtonCentre
        abilityLabel.position = abilityButtonCentre
        abilityShieldPip.position = CGPoint(x: abilityButtonCentre.x + 26, y: abilityButtonCentre.y + 26)
    }

    // MARK: - Updates

    func setDistance(_ metres: CGFloat) {
        distanceLabel.text = "\(Int(metres)) m"
    }

    func setCoins(_ coins: Int) {
        guard coins != lastCoins else { return }
        lastCoins = coins
        coinsLabel.text = "\(coins)"
        coinsLabel.removeAllActions()
        coinsLabel.setScale(1.25)
        coinsLabel.run(.scale(to: 1, duration: 0.15))
    }

    func setRockets(_ n: Int) {
        guard n != lastRockets else { return }
        lastRockets = n
        rocketsLabel.text = "× \(n)"
        let dim = n == 0
        rocketsLabel.alpha = dim ? 0.4 : 1
        rocketIcon.alpha = dim ? 0.4 : 1
    }

    func setHull(fraction: CGFloat) {
        let f = clamp(fraction, 0, 1)
        hullFill.size.width = 146 * f
        hullFill.color = f > 0.5
            ? UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1)
            : (f > 0.25 ? UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1) : UIColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1))
    }

    func showHint(_ text: String?) {
        hintLabel.removeAllActions()
        if let text = text {
            hintLabel.text = text
            hintLabel.alpha = 1
            hintLabel.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        } else {
            hintLabel.run(.fadeOut(withDuration: 0.2))
        }
    }

    func setAimWidgets(visible: Bool) {
        powerBack.isHidden = !visible
        powerFill.isHidden = !visible
        powerLabel.isHidden = !visible
        angleLabel.isHidden = !visible
        if !visible { sweetBand.isHidden = true }
        pauseHint.isHidden = visible
    }

    func setAim(angleDegrees: CGFloat, power: CGFloat, showPower: Bool) {
        angleLabel.text = "\(Int(angleDegrees.rounded()))°"
        powerFill.size.height = 154 * clamp(power, 0.02, 1)
        powerFill.alpha = showPower ? 1 : 0.35
        powerFill.color = power > 0.85
            ? UIColor(red: 0.3, green: 0.95, blue: 0.5, alpha: 1)
            : UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
    }

    /// Dress the power bar for the selected launcher: a green band to tap inside for a rod &
    /// reel, a red "about to snap" zone at the top for a slingshot, nothing for the rest.
    func setLauncherStyle(_ launcher: Launcher) {
        let barBottom: CGFloat = -77
        let barHeight: CGFloat = 154
        switch launcher.aimMode {
        case .twoSweep:
            sweetBand.isHidden = true
        case .castTiming:
            let centre = barBottom + barHeight * launcher.sweetSpot
            let height = max(8, barHeight * launcher.sweetSpotHalfWidth * 2)
            sweetBand.path = CGPath(roundedRect: CGRect(x: -11, y: -height / 2, width: 22, height: height),
                                    cornerWidth: 4, cornerHeight: 4, transform: nil)
            sweetBand.fillColor = UIColor(red: 0.3, green: 0.95, blue: 0.5, alpha: 0.55)
            sweetBand.strokeColor = UIColor(red: 0.5, green: 1, blue: 0.7, alpha: 0.95)
            sweetBand.position = CGPoint(x: powerBack.position.x, y: centre)
            sweetBand.isHidden = false
        case .charge:
            // The top slice of the bar is the danger zone: full draw, about to let go.
            let height: CGFloat = 20
            sweetBand.path = CGPath(roundedRect: CGRect(x: -11, y: -height / 2, width: 22, height: height),
                                    cornerWidth: 4, cornerHeight: 4, transform: nil)
            sweetBand.fillColor = UIColor(red: 0.95, green: 0.3, blue: 0.25, alpha: 0.5)
            sweetBand.strokeColor = UIColor(red: 1, green: 0.5, blue: 0.4, alpha: 0.95)
            sweetBand.position = CGPoint(x: powerBack.position.x, y: barBottom + barHeight - height / 2)
            sweetBand.isHidden = false
        }
    }

    // MARK: - Ability button

    func setAbilityVisible(_ visible: Bool) {
        abilityRing.isHidden = !visible
        abilityFill.isHidden = !visible
        abilityLabel.isHidden = !visible
        abilityShieldPip.isHidden = !visible
    }

    func configureAbility(_ ability: Ability) {
        abilityLabel.text = ability.buttonLabel
        abilityLabel.fontSize = ability.buttonLabel.count > 5 ? 11 : 13
        setAbilityVisible(true)
    }

    /// `charge` is 0…1 (1 = ready). The disc fills as the cooldown runs down and brightens
    /// the moment it is usable, so the button reads at a glance mid-flight.
    func setAbility(charge: CGFloat, ready: Bool, shields: Int) {
        let f = clamp(charge, 0, 1)
        // A disc that grows from the centre is cheaper than redrawing a pie slice each frame
        // and reads just as clearly at this size.
        abilityFill.setScale(max(0.08, f))
        abilityFill.fillColor = ready
            ? UIColor(red: 0.35, green: 0.85, blue: 1, alpha: 0.95)
            : UIColor(red: 0.35, green: 0.55, blue: 0.75, alpha: 0.6)
        abilityRing.strokeColor = ready ? UIColor.white : UIColor.white.withAlphaComponent(0.45)
        abilityLabel.alpha = ready ? 1 : 0.55
        if ready != abilityEnabled {
            abilityEnabled = ready
            if ready {
                abilityRing.removeAllActions()
                abilityRing.run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1, duration: 0.12)]))
            }
        }
        abilityShieldPip.text = shields > 0 ? "◈\(shields)" : ""
    }

    /// True if `point` (in HUD/camera space) is on the ability button.
    func abilityButtonContains(_ point: CGPoint) -> Bool {
        guard !abilityRing.isHidden else { return false }
        let dx = point.x - abilityButtonCentre.x, dy = point.y - abilityButtonCentre.y
        return dx * dx + dy * dy <= HUD.abilityButtonRadius * HUD.abilityButtonRadius
    }

    func flashAbility() {
        abilityRing.removeAllActions()
        abilityRing.run(.sequence([.scale(to: 0.85, duration: 0.06), .scale(to: 1, duration: 0.12)]))
    }

    /// The bottom-of-screen control hint, which now has three verbs to explain.
    func setControlHint(ability: Ability?) {
        if let ability = ability {
            pauseHint.text = "TAP: rocket   ·   HOLD: dive   ·   \(ability.buttonLabel): \(ability.title.lowercased())"
        } else {
            pauseHint.text = "TAP: rocket   ·   HOLD: nose-dive"
        }
    }
}

/// Screen-space banner (tips, MISSION COMPLETE). Slides in under the top HUD, holds, fades.
/// Only one shows at a time; a new one replaces the current.
final class Banner {
    private static var current: SKNode?

    static func show(title: String, subtitle: String? = nil, in camera: SKNode, sceneSize: CGSize, insets: UIEdgeInsets,
                     color: UIColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), duration: TimeInterval = 2.4) {
        current?.removeFromParent()
        let node = SKNode()
        node.zPosition = 900
        let top = sceneSize.height / 2 - insets.top
        node.position = CGPoint(x: 0, y: top - 74)

        let t = SKLabelNode(fontNamed: Tuning.fontHeavy)
        t.text = title
        t.fontSize = 24
        t.fontColor = color
        t.verticalAlignmentMode = .center
        node.addChild(t)
        if let subtitle = subtitle {
            let sub = SKLabelNode(fontNamed: Tuning.fontMedium)
            sub.text = subtitle
            sub.fontSize = 15
            sub.fontColor = UIColor.white.withAlphaComponent(0.9)
            sub.verticalAlignmentMode = .center
            sub.position = CGPoint(x: 0, y: -22)
            node.addChild(sub)
        }
        let width = max(t.frame.width, (node.children.last?.frame.width ?? 0)) + 44
        let height: CGFloat = subtitle == nil ? 40 : 60
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 12)
        bg.fillColor = UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 0.8)
        bg.strokeColor = color.withAlphaComponent(0.6)
        bg.lineWidth = 2
        bg.position = CGPoint(x: 0, y: subtitle == nil ? 0 : -11)
        bg.zPosition = -1
        node.addChild(bg)

        node.alpha = 0
        node.setScale(0.8)
        camera.addChild(node)
        current = node
        node.run(.sequence([
            .group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.2)]),
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}

/// Rising "+40" style label. Add to the world at the pickup position.
final class FloatingLabel {
    static func show(_ text: String, at position: CGPoint, in parent: SKNode, color: UIColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), fontSize: CGFloat = 26) {
        let label = SKLabelNode(fontNamed: Tuning.fontHeavy)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = position
        label.zPosition = 500
        label.setScale(0.6)
        parent.addChild(label)
        label.run(.sequence([
            .group([
                .scale(to: 1.1, duration: 0.15),
                .moveBy(x: 0, y: 70, duration: 0.9),
                .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])
            ]),
            .removeFromParent()
        ]))
    }
}
