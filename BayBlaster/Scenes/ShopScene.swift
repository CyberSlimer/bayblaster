import SpriteKit

/// Persistent upgrade shop. Five tracks, five tiers each; prices grow ×2.2 per tier.
final class ShopScene: SKScene {

    private final class Row {
        let kind: UpgradeKind
        let container = SKNode()
        let name: SKLabelNode
        let effect: SKLabelNode
        let pips: [SKShapeNode]
        let buy: ButtonNode
        let stripe: SKShapeNode

        init(kind: UpgradeKind) {
            self.kind = kind
            name = SKLabelNode.make(kind.title, size: 18, font: Tuning.fontHeavy, align: .left)
            effect = SKLabelNode.make("", size: 13, font: Tuning.fontMedium, color: UIColor.white.withAlphaComponent(0.8), align: .left)
            pips = (0..<Tuning.upgradeMaxTier).map { _ in SKShapeNode(circleOfRadius: 6) }
            buy = ButtonNode(text: "", size: CGSize(width: 150, height: 44), color: UIColor(red: 0.2, green: 0.75, blue: 0.4, alpha: 1), fontSize: 18)
            stripe = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 10)
            container.addChild(stripe)
            container.addChild(name)
            container.addChild(effect)
            for p in pips {
                p.strokeColor = UIColor.white.withAlphaComponent(0.6)
                p.lineWidth = 1.5
                container.addChild(p)
            }
            container.addChild(buy)
        }
    }

    private var rows: [Row] = []
    private let backdrop = SKSpriteNode(texture: nil, color: UIColor(red: 0.05, green: 0.12, blue: 0.25, alpha: 1), size: CGSize(width: 10, height: 10))
    private let title = SKLabelNode.make("THE BAIT SHOP", size: 30, font: Tuning.fontHeavy, color: UIColor(red: 1, green: 0.93, blue: 0.5, alpha: 1), align: .left)
    private let coinsLabel = SKLabelNode.make("", size: 22, font: Tuning.fontHeavy, color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), align: .right)
    private var coinIcon: SKNode!
    private var backButton: ButtonNode!
    private var lockerButton: ButtonNode!
    private var resetButton: ButtonNode!
    private var prestigeButton: ButtonNode!
    private var confirmOverlay: SKNode?
    private var didBuild = false
    private var showBlurb = true       // wide screens get the flavour text too

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        Art.view = view
        backgroundColor = UIColor(red: 0.05, green: 0.12, blue: 0.25, alpha: 1)
        if !didBuild { build() }
        layout()
    }

    private func build() {
        didBuild = true
        backdrop.zPosition = -10
        addChild(backdrop)
        addChild(title)
        addChild(coinsLabel)
        coinIcon = Art.sprite("coinIcon")
        coinIcon.setScale(1.3)
        addChild(coinIcon)

        backButton = ButtonNode(text: "◀ BACK", size: CGSize(width: 120, height: 44), color: UIColor(red: 0.25, green: 0.6, blue: 0.95, alpha: 1), fontSize: 18)
        backButton.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(TitleScene(size: self.size), from: self)
        }
        addChild(backButton)

        lockerButton = ButtonNode(text: "LOCKER ▶", size: CGSize(width: 130, height: 44),
                                  color: UIColor(red: 0.55, green: 0.35, blue: 0.75, alpha: 1), fontSize: 16)
        lockerButton.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(LockerScene(size: self.size), from: self, reveal: true)
        }
        addChild(lockerButton)

        for kind in UpgradeKind.allCases {
            let row = Row(kind: kind)
            row.buy.action = { [weak self, weak row] in
                guard let self = self, let row = row else { return }
                self.purchase(row.kind)
            }
            addChild(row.container)
            rows.append(row)
        }

        resetButton = ButtonNode(text: "Reset save", size: CGSize(width: 130, height: 34), color: UIColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 1), fontSize: 13)
        resetButton.action = { [weak self] in self?.showResetConfirmation() }
        addChild(resetButton)

        // Unlocked only once all five tracks are maxed; see SaveData.canPrestige.
        prestigeButton = ButtonNode(text: "CAST OFF", size: CGSize(width: 170, height: 34),
                                    color: UIColor(red: 0.7, green: 0.35, blue: 0.6, alpha: 1), fontSize: 14)
        prestigeButton.action = { [weak self] in self?.showPrestigeConfirmation() }
        addChild(prestigeButton)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard didBuild else { return }
        layout()
    }

    private func layout() {
        let insets = view?.safeAreaInsets ?? .zero
        let w = size.width, h = size.height
        let left = -w / 2 + insets.left + 20
        let right = w / 2 - insets.right - 20
        let top = h / 2 - insets.top - 14
        let bottom = -h / 2 + insets.bottom + 10

        backdrop.size = CGSize(width: w + 4, height: h + 4)

        title.position = CGPoint(x: left, y: top - 20)
        coinsLabel.position = CGPoint(x: right - 30, y: top - 20)
        coinIcon.position = CGPoint(x: right - 12, y: top - 20)
        backButton.position = CGPoint(x: left + 60 + title.frame.width + 30, y: top - 20)
        lockerButton.position = CGPoint(x: backButton.position.x + 132, y: top - 20)

        let headerBottom = top - 46
        let footerTop = bottom + 40
        let rowH = min(66, (headerBottom - footerTop) / CGFloat(rows.count))
        let compact = rowH < 56
        let contentW = right - left

        for (i, row) in rows.enumerated() {
            let y = headerBottom - rowH * (CGFloat(i) + 0.5)
            row.container.position = CGPoint(x: 0, y: y)
            row.stripe.path = CGPath(roundedRect: CGRect(x: left, y: -rowH / 2 + 3, width: contentW, height: rowH - 6), cornerWidth: 12, cornerHeight: 12, transform: nil)
            row.stripe.fillColor = UIColor.white.withAlphaComponent(i % 2 == 0 ? 0.08 : 0.04)
            row.stripe.strokeColor = .clear

            row.name.fontSize = compact ? 16 : 19
            row.name.position = CGPoint(x: left + 14, y: compact ? 10 : 12)
            row.effect.fontSize = compact ? 12 : 13.5
            row.effect.position = CGPoint(x: left + 14, y: compact ? -9 : -11)

            let pipStart = left + contentW * 0.5 - 6
            for (j, p) in row.pips.enumerated() {
                p.position = CGPoint(x: pipStart + CGFloat(j) * 18, y: 0)
            }
            row.buy.position = CGPoint(x: right - 80, y: 0)
        }

        resetButton.position = CGPoint(x: -110, y: bottom + 18)
        prestigeButton.position = CGPoint(x: 100, y: bottom + 18)
        confirmOverlay?.position = .zero
        showBlurb = contentW > 900
        refresh()
    }

    private func refresh() {
        let save = SaveManager.shared.data
        coinsLabel.text = "\(save.coins)"
        let canCastOff = save.canPrestige
        prestigeButton.isEnabled = canCastOff
        prestigeButton.text = canCastOff ? "CAST OFF ★" : "CAST OFF (max all first)"
        prestigeButton.subtitle = save.prestigeLevel > 0 ? "cast off ×\(save.prestigeLevel)" : nil
        for row in rows {
            let tier = save.tier(of: row.kind)
            for (j, p) in row.pips.enumerated() {
                p.fillColor = j < tier ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : UIColor.white.withAlphaComponent(0.12)
            }
            if tier >= Tuning.upgradeMaxTier {
                row.effect.text = "MAXED · " + row.kind.effectDescription(tier: tier)
                row.buy.text = "MAXED"
                row.buy.subtitle = nil
                row.buy.isEnabled = false
                row.buy.setColor(UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1))
            } else {
                let price = row.kind.price(forTier: tier + 1)
                row.effect.text = "Next: " + row.kind.effectDescription(tier: tier + 1) + (showBlurb ? "  —  " + row.kind.blurb : "")
                row.buy.text = "BUY  \(price)"
                row.buy.subtitle = "tier \(tier + 1) of \(Tuning.upgradeMaxTier)"
                row.buy.setColor(UIColor(red: 0.2, green: 0.75, blue: 0.4, alpha: 1))
                row.buy.isEnabled = save.coins >= price
            }
        }
    }

    private func purchase(_ kind: UpgradeKind) {
        if SaveManager.shared.buy(kind) {
            AudioManager.shared.play(.purchase)
            Haptics.success()
            refresh()
            if let row = rows.first(where: { $0.kind == kind }) {
                row.container.run(.sequence([.scale(to: 1.03, duration: 0.08), .scale(to: 1, duration: 0.12)]))
                let tier = SaveManager.shared.data.tier(of: kind)
                if tier - 1 < row.pips.count {
                    let pip = row.pips[tier - 1]
                    pip.run(.sequence([.scale(to: 1.8, duration: 0.12), .scale(to: 1, duration: 0.15)]))
                }
            }
        } else {
            Haptics.failure()
            refresh()
        }
    }

    // MARK: - Reset confirmation

    private func showResetConfirmation() {
        guard confirmOverlay == nil else { return }
        let overlay = SKNode()
        overlay.zPosition = 500
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.6), size: CGSize(width: size.width + 10, height: size.height + 10))
        dim.isUserInteractionEnabled = true
        overlay.addChild(dim)
        let panel = PanelNode(size: CGSize(width: 400, height: 190))
        overlay.addChild(panel)
        let t = SKLabelNode.make("Reset all progress?", size: 24, font: Tuning.fontHeavy)
        t.position = CGPoint(x: 0, y: 52)
        panel.addChild(t)
        let sub = SKLabelNode.make("Coins, upgrades, crew, gear, launchers, trophies and stats will be erased.", size: 14, font: Tuning.fontMedium, color: UIColor.white.withAlphaComponent(0.8))
        sub.position = CGPoint(x: 0, y: 20)
        panel.addChild(sub)
        let yes = ButtonNode(text: "RESET", size: CGSize(width: 150, height: 48), color: UIColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1), fontSize: 18)
        yes.position = CGPoint(x: -90, y: -45)
        yes.action = { [weak self] in
            SaveManager.shared.resetAll()
            AudioManager.shared.play(.sink, volume: 0.6)
            Haptics.heavy()
            self?.dismissConfirmation()
            self?.refresh()
        }
        panel.addChild(yes)
        let no = ButtonNode(text: "KEEP", size: CGSize(width: 150, height: 48), color: UIColor(red: 0.25, green: 0.6, blue: 0.95, alpha: 1), fontSize: 18)
        no.position = CGPoint(x: 90, y: -45)
        no.action = { [weak self] in self?.dismissConfirmation() }
        panel.addChild(no)
        addChild(overlay)
        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.15))
        confirmOverlay = overlay
    }

    /// Casting off is the one destructive-looking action that is actually progress, so the
    /// dialog spells out exactly what survives it.
    private func showPrestigeConfirmation() {
        guard confirmOverlay == nil, SaveManager.shared.data.canPrestige else { return }
        let nextLevel = SaveManager.shared.data.prestigeLevel + 1
        let multiplier = 1 + Double(nextLevel) * Double(Tuning.prestigeCoinBonusPerLevel)
        let overlay = SKNode()
        overlay.zPosition = 500
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.6), size: CGSize(width: size.width + 10, height: size.height + 10))
        dim.isUserInteractionEnabled = true
        overlay.addChild(dim)
        let panel = PanelNode(size: CGSize(width: 460, height: 230))
        overlay.addChild(panel)
        let t = SKLabelNode.make("Cast off?", size: 24, font: Tuning.fontHeavy,
                                 color: UIColor(red: 1, green: 0.75, blue: 0.95, alpha: 1))
        t.position = CGPoint(x: 0, y: 74)
        panel.addChild(t)
        let lines = [
            "Your coins and all five upgrade tracks go back to zero.",
            "Your crew, gear, launchers, trophies and best distance stay.",
            "From then on every coin you earn is worth ×\(String(format: "%.2g", multiplier))."
        ]
        for (i, line) in lines.enumerated() {
            let l = SKLabelNode.make(line, size: 14, font: Tuning.fontMedium,
                                     color: UIColor.white.withAlphaComponent(i == 2 ? 1 : 0.8))
            l.position = CGPoint(x: 0, y: 38 - CGFloat(i) * 21)
            panel.addChild(l)
        }
        let yes = ButtonNode(text: "CAST OFF", size: CGSize(width: 170, height: 48),
                             color: UIColor(red: 0.7, green: 0.35, blue: 0.6, alpha: 1), fontSize: 18)
        yes.position = CGPoint(x: -95, y: -62)
        yes.action = { [weak self] in
            SaveManager.shared.prestige()
            AudioManager.shared.play(.purchase)
            Haptics.success()
            self?.dismissConfirmation()
            self?.refresh()
        }
        panel.addChild(yes)
        let no = ButtonNode(text: "NOT YET", size: CGSize(width: 170, height: 48),
                            color: UIColor(red: 0.25, green: 0.6, blue: 0.95, alpha: 1), fontSize: 18)
        no.position = CGPoint(x: 95, y: -62)
        no.action = { [weak self] in self?.dismissConfirmation() }
        panel.addChild(no)
        addChild(overlay)
        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.15))
        confirmOverlay = overlay
    }

    private func dismissConfirmation() {
        guard let o = confirmOverlay else { return }
        confirmOverlay = nil
        o.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
    }
}
