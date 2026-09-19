import SpriteKit

// =====================================================================================
//  LockerScene — everything you unlock that isn't a shop upgrade tier.
//
//  Four tabs, one paged grid of cards:
//    CREW       the rider: a passive perk and the in-flight ability they bring
//    GEAR       bolt-on parts, one per slot, bought once then equipped freely
//    LAUNCHERS  what fires you; each has its own aim ritual
//    TROPHIES   read-only achievement board
//
//  The shop (ShopScene) still sells the five linear upgrade tracks; this is the "what do I
//  want to be today" half of the meta, and every card is one tap: buy it, or equip it.
// =====================================================================================

final class LockerScene: SKScene {

    enum Tab: Int, CaseIterable {
        case crew, gear, launchers, trophies

        var title: String {
            switch self {
            case .crew:      return "CREW"
            case .gear:      return "GEAR"
            case .launchers: return "LAUNCHERS"
            case .trophies:  return "TROPHIES"
            }
        }

        /// Cards per page, as (columns, rows). Gear is 3×3 so each row is one slot.
        var grid: (columns: Int, rows: Int) {
            switch self {
            case .crew:      return (4, 2)
            case .gear:      return (3, 3)
            case .launchers: return (4, 1)
            case .trophies:  return (4, 3)
            }
        }
    }

    /// Everything a card needs to draw itself and to know what a tap should do.
    /// `fileprivate` rather than `private` so `LockerCard`, further down this file, can see it.
    fileprivate struct CardSpec {
        let artKey: String
        let title: String
        let subtitle: String
        let detail: String
        let footnote: String?
        let status: String
        let statusColor: UIColor
        let highlighted: Bool        // currently selected / equipped
        let dimmed: Bool             // can't afford it, or locked
        let action: (() -> Void)?
    }

    private var tab: Tab = .crew
    private var page = 0

    private let backdrop = SKSpriteNode(texture: nil, color: UIColor(red: 0.05, green: 0.12, blue: 0.25, alpha: 1),
                                        size: CGSize(width: 10, height: 10))
    private let title = SKLabelNode.make("THE LOCKER", size: 28, font: Tuning.fontHeavy,
                                         color: UIColor(red: 1, green: 0.93, blue: 0.5, alpha: 1), align: .left)
    private let coinsLabel = SKLabelNode.make("", size: 22, font: Tuning.fontHeavy,
                                              color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), align: .right)
    private let hintLabel = SKLabelNode.make("", size: 13, font: Tuning.fontMedium,
                                             color: UIColor.white.withAlphaComponent(0.65))
    private let pageLabel = SKLabelNode.make("", size: 13, font: Tuning.fontMedium,
                                             color: UIColor.white.withAlphaComponent(0.7))
    private var coinIcon: SKNode!
    private var backButton: ButtonNode!
    private var shopButton: ButtonNode!
    private var prevButton: ButtonNode!
    private var nextButton: ButtonNode!
    private var tabButtons: [ButtonNode] = []
    private let cardLayer = SKNode()
    private var didBuild = false

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
        addChild(hintLabel)
        addChild(pageLabel)
        addChild(cardLayer)

        coinIcon = Art.sprite("coinIcon")
        coinIcon.setScale(1.3)
        addChild(coinIcon)

        backButton = ButtonNode(text: "◀ BACK", size: CGSize(width: 116, height: 40),
                                color: UIColor(red: 0.25, green: 0.6, blue: 0.95, alpha: 1), fontSize: 16)
        backButton.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(TitleScene(size: self.size), from: self)
        }
        addChild(backButton)

        shopButton = ButtonNode(text: "SHOP ▶", size: CGSize(width: 116, height: 40),
                                color: UIColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1), fontSize: 16)
        shopButton.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(ShopScene(size: self.size), from: self, reveal: true)
        }
        addChild(shopButton)

        for t in Tab.allCases {
            let b = ButtonNode(text: t.title, size: CGSize(width: 132, height: 38),
                               color: UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1), fontSize: 15)
            b.action = { [weak self] in self?.select(tab: t) }
            tabButtons.append(b)
            addChild(b)
        }

        prevButton = ButtonNode(text: "◀", size: CGSize(width: 46, height: 34),
                                color: UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1), fontSize: 16)
        prevButton.action = { [weak self] in self?.turnPage(-1) }
        addChild(prevButton)

        nextButton = ButtonNode(text: "▶", size: CGSize(width: 46, height: 34),
                                color: UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1), fontSize: 16)
        nextButton.action = { [weak self] in self?.turnPage(1) }
        addChild(nextButton)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard didBuild else { return }
        layout()
    }

    private func select(tab newTab: Tab) {
        guard newTab != tab else { return }
        tab = newTab
        page = 0
        AudioManager.shared.play(.tick, volume: 0.6)
        layout()
    }

    private func turnPage(_ delta: Int) {
        let count = specs().count
        let perPage = tab.grid.columns * tab.grid.rows
        let pages = max(1, Int((Double(count) / Double(perPage)).rounded(.up)))
        page = (page + delta + pages) % pages
        AudioManager.shared.play(.tick, volume: 0.5)
        layout()
    }

    // MARK: - Layout

    private func layout() {
        let insets = view?.safeAreaInsets ?? .zero
        let w = size.width, h = size.height
        let left = -w / 2 + insets.left + 20
        let right = w / 2 - insets.right - 20
        let top = h / 2 - insets.top - 14
        let bottom = -h / 2 + insets.bottom + 10

        backdrop.size = CGSize(width: w + 4, height: h + 4)
        title.position = CGPoint(x: left, y: top - 18)
        coinsLabel.position = CGPoint(x: right - 30, y: top - 18)
        coinIcon.position = CGPoint(x: right - 12, y: top - 18)
        backButton.position = CGPoint(x: left + 58 + title.frame.width + 26, y: top - 18)
        shopButton.position = CGPoint(x: backButton.position.x + 130, y: top - 18)

        // Tab row, centred.
        let tabWidth: CGFloat = 132, tabGap: CGFloat = 8
        let totalTabs = CGFloat(tabButtons.count) * tabWidth + CGFloat(tabButtons.count - 1) * tabGap
        var tx = -totalTabs / 2 + tabWidth / 2
        for (i, b) in tabButtons.enumerated() {
            b.position = CGPoint(x: tx, y: top - 56)
            let active = i == tab.rawValue
            b.setColor(active ? UIColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1)
                              : UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1))
            tx += tabWidth + tabGap
        }

        hintLabel.position = CGPoint(x: 0, y: bottom + 14)
        pageLabel.position = CGPoint(x: 0, y: bottom + 34)
        prevButton.position = CGPoint(x: -84, y: bottom + 34)
        nextButton.position = CGPoint(x: 84, y: bottom + 34)

        rebuildCards(in: CGRect(x: left, y: bottom + 54, width: right - left, height: (top - 78) - (bottom + 54)))
        refreshChrome()
    }

    private func refreshChrome() {
        coinsLabel.text = "\(SaveManager.shared.data.coins)"
        switch tab {
        case .crew:      hintLabel.text = "Tap a rider to equip. Each brings a passive perk and their own in-flight ability."
        case .gear:      hintLabel.text = "One part per slot. Tap an owned part to equip it, tap it again to run the slot empty."
        case .launchers: hintLabel.text = "Each launcher has its own aim ritual — the way you start a run changes completely."
        case .trophies:  hintLabel.text = "\(Achievements.earnedCount) of \(Achievement.allCases.count) earned. They pay out the moment you finish the run that wins them."
        }
        let count = specs().count
        let perPage = tab.grid.columns * tab.grid.rows
        let pages = max(1, Int((Double(count) / Double(perPage)).rounded(.up)))
        pageLabel.text = pages > 1 ? "\(page + 1) / \(pages)" : ""
        prevButton.isHidden = pages <= 1
        nextButton.isHidden = pages <= 1
    }

    private func rebuildCards(in rect: CGRect) {
        cardLayer.removeAllChildren()
        let all = specs()
        let (cols, rows) = tab.grid
        let perPage = cols * rows
        let start = min(page * perPage, max(0, all.count - 1))
        let slice = Array(all[start..<min(start + perPage, all.count)])
        guard !slice.isEmpty, rect.width > 0, rect.height > 0 else { return }

        let gap: CGFloat = 12
        let cardW = (rect.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let cardH = (rect.height - gap * CGFloat(rows - 1)) / CGFloat(rows)

        for (i, spec) in slice.enumerated() {
            let col = i % cols, row = i / cols
            let x = rect.minX + cardW / 2 + CGFloat(col) * (cardW + gap)
            let y = rect.maxY - cardH / 2 - CGFloat(row) * (cardH + gap)
            let card = LockerCard(size: CGSize(width: cardW, height: cardH), spec: spec)
            card.position = CGPoint(x: x, y: y)
            cardLayer.addChild(card)
        }
    }

    // MARK: - Card contents per tab

    private func specs() -> [CardSpec] {
        let save = SaveManager.shared.data
        switch tab {
        case .crew:
            return CrewMember.allCases.map { crew in
                let owned = save.owns(crew)
                let selected = save.selectedCrew == crew.rawValue
                let affordable = save.coins >= crew.price
                return CardSpec(
                    artKey: crew.artKey,
                    title: crew.displayName,
                    subtitle: crew.species,
                    detail: crew.perkText,
                    footnote: "\(crew.ability.title) — \(crew.ability.hint)",
                    status: selected ? "RIDING" : (owned ? "TAP TO RIDE" : "\(crew.price)"),
                    statusColor: selected ? UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
                                          : (owned ? .white : (affordable ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                                                                          : UIColor(red: 1, green: 0.5, blue: 0.45, alpha: 1))),
                    highlighted: selected,
                    dimmed: !owned && !affordable,
                    action: { [weak self] in
                        if owned { self?.act(SaveManager.shared.selectCrew(crew)) }
                        else { self?.act(SaveManager.shared.buyCrew(crew), bought: true) }
                    })
            }

        case .gear:
            // Ordered slot by slot so each row of the 3×3 grid is one slot.
            return GearSlot.allCases.flatMap { slot in
                GearItem.items(in: slot).map { item in
                    let owned = save.owns(item)
                    let equipped = save.isEquipped(item)
                    let affordable = save.coins >= item.price
                    return CardSpec(
                        artKey: item.artKey,
                        title: item.displayName,
                        subtitle: slot.title,
                        detail: item.upside,
                        footnote: item.downside,
                        status: equipped ? "EQUIPPED" : (owned ? "TAP TO FIT" : "\(item.price)"),
                        statusColor: equipped ? UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
                                              : (owned ? .white : (affordable ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                                                                              : UIColor(red: 1, green: 0.5, blue: 0.45, alpha: 1))),
                        highlighted: equipped,
                        dimmed: !owned && !affordable,
                        action: { [weak self] in
                            if owned { self?.act(SaveManager.shared.toggleGear(item)) }
                            else { self?.act(SaveManager.shared.buyGear(item), bought: true) }
                        })
                }
            }

        case .launchers:
            return LauncherKind.allCases.map { launcher in
                let owned = save.owns(launcher)
                let selected = save.selectedLauncher == launcher.rawValue
                let affordable = save.coins >= launcher.price
                return CardSpec(
                    artKey: launcher.spec.barrelArtKey,
                    title: launcher.displayName,
                    subtitle: aimRitualName(launcher),
                    detail: launcher.blurb,
                    footnote: launcherNumbers(launcher),
                    status: selected ? "LOADED" : (owned ? "TAP TO LOAD" : "\(launcher.price)"),
                    statusColor: selected ? UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
                                          : (owned ? .white : (affordable ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                                                                          : UIColor(red: 1, green: 0.5, blue: 0.45, alpha: 1))),
                    highlighted: selected,
                    dimmed: !owned && !affordable,
                    action: { [weak self] in
                        if owned { self?.act(SaveManager.shared.selectLauncher(launcher)) }
                        else { self?.act(SaveManager.shared.buyLauncher(launcher), bought: true) }
                    })
            }

        case .trophies:
            // Earned first, so the board reads as a collection rather than a to-do list.
            let earned = Achievement.allCases.filter { Achievements.isEarned($0) }
            let locked = Achievement.allCases.filter { !Achievements.isEarned($0) }
            return (earned + locked).map { a in
                let got = Achievements.isEarned(a)
                return CardSpec(
                    artKey: "trophyIcon",
                    title: a.title,
                    subtitle: got ? "EARNED" : "LOCKED",
                    detail: a.detail,
                    footnote: nil,
                    status: "+\(a.reward)",
                    statusColor: got ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                                     : UIColor.white.withAlphaComponent(0.4),
                    highlighted: got,
                    dimmed: !got,
                    action: nil)
            }
        }
    }

    private func aimRitualName(_ launcher: LauncherKind) -> String {
        switch launcher.spec.aimMode {
        case .twoSweep:   return "TWO TAPS"
        case .castTiming: return "TIMED CAST"
        case .charge:     return "HOLD & RELEASE"
        }
    }

    private func launcherNumbers(_ launcher: LauncherKind) -> String {
        let s = launcher.spec
        let base = "\(Int(s.angleRange.lowerBound))–\(Int(s.angleRange.upperBound))°  ·  speed ×\(String(format: "%.2g", s.speedMultiplier))"
        if s.aimMode == .castTiming {
            return base + "  ·  band ×\(String(format: "%.2g", s.sweetSpotBonus))"
        }
        return base
    }

    /// Shared feedback for every buy/equip tap.
    private func act(_ succeeded: Bool, bought: Bool = false) {
        if succeeded {
            AudioManager.shared.play(bought ? .purchase : .lock, volume: bought ? 1 : 0.8)
            Haptics.success()
        } else {
            AudioManager.shared.play(.tick, volume: 0.4)
            Haptics.failure()
        }
        layout()
    }
}

/// One tappable card in the locker grid. Rebuilt whenever the tab, page or save changes,
/// so it is deliberately cheap and stateless.
private final class LockerCard: SKNode {
    private let action: (() -> Void)?
    private let background: SKShapeNode
    private var tracking = false
    private let cardSize: CGSize

    init(size: CGSize, spec: LockerScene.CardSpec) {
        action = spec.action
        cardSize = size
        background = SKShapeNode(rectOf: size, cornerRadius: 14)
        super.init()

        background.fillColor = spec.highlighted
            ? UIColor(red: 0.16, green: 0.32, blue: 0.28, alpha: 1)
            : UIColor.white.withAlphaComponent(0.07)
        background.strokeColor = spec.highlighted
            ? UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 0.9)
            : UIColor.white.withAlphaComponent(0.18)
        background.lineWidth = spec.highlighted ? 2.5 : 1.5
        addChild(background)

        // Lay the card out top-down with a cursor, reserving the status row at the bottom.
        // Card heights vary a lot between tabs (launchers get one tall row, trophies get
        // three short ones), so anything that doesn't fit is dropped rather than overlapped.
        let statusRowHeight: CGFloat = 20
        let usable = size.height - statusRowHeight - 12
        var cursor = size.height / 2 - 8

        let iconBox = min(size.width * 0.34, usable * 0.34)
        let icon = Art.sprite(spec.artKey)
        let natural = max(icon.calculateAccumulatedFrame().width,
                          icon.calculateAccumulatedFrame().height, 1)
        icon.setScale(min(1.6, iconBox / natural))
        cursor -= iconBox / 2
        icon.position = CGPoint(x: 0, y: cursor)
        addChild(icon)
        cursor -= iconBox / 2 + 10

        let titleSize = min(16, max(11, size.width * 0.105))
        let titleLabel = SKLabelNode.make(spec.title, size: titleSize, font: Tuning.fontHeavy)
        cursor -= titleSize / 2
        titleLabel.position = CGPoint(x: 0, y: cursor)
        addChild(titleLabel)
        cursor -= titleSize / 2 + 5

        let subtitleLabel = SKLabelNode.make(spec.subtitle, size: 10.5, font: Tuning.fontMedium,
                                             color: UIColor.white.withAlphaComponent(0.6))
        cursor -= 6
        subtitleLabel.position = CGPoint(x: 0, y: cursor)
        addChild(subtitleLabel)
        cursor -= 12

        // Named `bottomLimit`, not `floor`: a local constant called `floor` shadows the
        // stdlib function of the same name.
        let bottomLimit = -size.height / 2 + statusRowHeight + 8
        let charWidth = size.width / 6.0     // ≈ the width of one 11.5pt character

        func addLines(_ text: String, size fontSize: CGFloat, colour: UIColor, maxLines: Int) {
            for line in LockerCard.wrap(text, width: Int(charWidth), maxLines: maxLines) {
                guard cursor - fontSize >= bottomLimit else { return }
                cursor -= fontSize
                let l = SKLabelNode.make(line, size: fontSize, font: Tuning.fontMedium, color: colour)
                l.position = CGPoint(x: 0, y: cursor)
                addChild(l)
                cursor -= 2
            }
        }

        addLines(spec.detail, size: 11.5, colour: UIColor(red: 0.8, green: 0.95, blue: 1, alpha: 1), maxLines: 3)
        if let footnote = spec.footnote {
            cursor -= 3
            addLines(footnote, size: 10, colour: UIColor.white.withAlphaComponent(0.5), maxLines: 2)
        }

        let status = SKLabelNode.make(spec.status, size: 14, font: Tuning.fontHeavy, color: spec.statusColor)
        status.position = CGPoint(x: 0, y: -size.height / 2 + 13)
        addChild(status)

        alpha = spec.dimmed ? 0.5 : 1
        isUserInteractionEnabled = action != nil
        zPosition = 5
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Greedy word wrap — SKLabelNode's own multi-line support needs a preferred width in
    /// points and still won't hyphenate, and these strings are short enough that this is
    /// simpler to reason about.
    private static func wrap(_ text: String, width: Int, maxLines: Int = 3) -> [String] {
        guard width > 4 else { return [text] }
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty {
                current = String(word)
            } else if current.count + 1 + word.count <= width {
                current += " " + word
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return Array(lines.prefix(maxLines))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        tracking = true
        run(.scale(to: 0.96, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking, let t = touches.first else { return }
        tracking = false
        run(.scale(to: 1, duration: 0.08))
        let p = t.location(in: self)
        if abs(p.x) <= cardSize.width / 2 && abs(p.y) <= cardSize.height / 2 { action?() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        tracking = false
        run(.scale(to: 1, duration: 0.08))
    }
}
