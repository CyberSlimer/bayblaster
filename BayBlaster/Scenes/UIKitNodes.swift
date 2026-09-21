import SpriteKit

/// Rounded, tappable button with press feedback. Handles its own touches so the parent scene's
/// gameplay touch handlers never see taps on UI.
final class ButtonNode: SKNode {
    var action: (() -> Void)?

    private let background: SKShapeNode
    private let label = SKLabelNode(fontNamed: Tuning.fontHeavy)
    private let subLabel = SKLabelNode(fontNamed: Tuning.fontMedium)
    private var baseColor: UIColor
    private var tracking = false
    /// The font sizes the button was built with, and the width its text has to fit inside.
    /// `shrinkToFit` only ever reduces, so re-fitting after a text change has to start from
    /// these rather than from whatever the last string shrank the label to.
    private let baseFontSize: CGFloat
    private let subBaseFontSize: CGFloat
    private let textWidth: CGFloat

    var isEnabled = true {
        didSet {
            alpha = isEnabled ? 1 : 0.4
            background.fillColor = isEnabled ? baseColor : UIColor.gray
        }
    }

    /// Setting this re-fits the label: several buttons are built with placeholder text and
    /// given their real, longer string later ("CAST OFF (max all first)", "BUY 12345").
    var text: String {
        get { label.text ?? "" }
        set {
            label.text = newValue
            label.fontSize = baseFontSize
            label.shrinkToFit(width: textWidth)
        }
    }

    var subtitle: String? {
        get { subLabel.text }
        set {
            subLabel.text = newValue
            subLabel.isHidden = newValue == nil
            if newValue != nil {
                subLabel.fontSize = subBaseFontSize
                subLabel.shrinkToFit(width: textWidth)
            }
            label.position.y = newValue == nil ? 0 : 7
        }
    }

    init(text: String, size: CGSize, color: UIColor, fontSize: CGFloat = 22) {
        background = SKShapeNode(rectOf: size, cornerRadius: min(size.height / 2, 16))
        baseColor = color
        baseFontSize = fontSize
        subBaseFontSize = fontSize * 0.55
        textWidth = size.width - 20
        super.init()
        background.fillColor = color
        background.strokeColor = color.darker(0.2)
        background.lineWidth = 3
        addChild(background)

        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.shrinkToFit(width: textWidth)
        addChild(label)

        subLabel.fontSize = subBaseFontSize
        subLabel.fontColor = UIColor.white.withAlphaComponent(0.85)
        subLabel.verticalAlignmentMode = .center
        subLabel.horizontalAlignmentMode = .center
        subLabel.position = CGPoint(x: 0, y: -9)
        subLabel.isHidden = true
        addChild(subLabel)

        isUserInteractionEnabled = true
        zPosition = 10
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setColor(_ color: UIColor) {
        baseColor = color
        background.fillColor = isEnabled ? color : UIColor.gray
        background.strokeColor = color.darker(0.2)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        tracking = true
        run(.scale(to: 0.93, duration: 0.06))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking, let t = touches.first else { return }
        let inside = background.frame.contains(t.location(in: self))
        run(.scale(to: inside ? 0.93 : 1, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking, let t = touches.first else { return }
        tracking = false
        run(.scale(to: 1, duration: 0.08))
        if background.frame.contains(t.location(in: self)) {
            AudioManager.shared.play(.tick, volume: 0.7)
            action?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        tracking = false
        run(.scale(to: 1, duration: 0.08))
    }
}

/// Translucent rounded panel used behind overlays.
final class PanelNode: SKShapeNode {
    init(size: CGSize, color: UIColor = UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 0.88)) {
        super.init()
        path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                      cornerWidth: 22, cornerHeight: 22, transform: nil)
        fillColor = color
        strokeColor = UIColor.white.withAlphaComponent(0.25)
        lineWidth = 2
        isUserInteractionEnabled = true      // swallow touches so gameplay underneath is not triggered
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// Convenience for building labels with the game's fonts.
extension SKLabelNode {
    static func make(_ text: String, size: CGFloat, font: String = Tuning.fontBold, color: UIColor = .white,
                     align: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .center
        return l
    }

    /// Steps the font size down until the text fits `width` (never below `minimum`), so a long
    /// label like "LAUNCH AGAIN" or "Old Lighthouse Cannon" stays inside its button or card.
    func shrinkToFit(width: CGFloat, minimum: CGFloat = 9) {
        while frame.width > width && fontSize - 0.5 >= minimum { fontSize -= 0.5 }
    }
}

/// Scene switching with a consistent transition.
enum SceneRouter {
    static func present(_ scene: SKScene, from current: SKScene, reveal: Bool = false) {
        guard let view = current.view else { return }
        scene.scaleMode = .resizeFill
        let transition: SKTransition = reveal
            ? SKTransition.push(with: .left, duration: 0.4)
            : SKTransition.fade(with: .black, duration: 0.45)
        view.presentScene(scene, transition: transition)
    }
}
