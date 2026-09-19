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
