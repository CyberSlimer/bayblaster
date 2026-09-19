import SpriteKit

/// Title screen: Launch, Shop, best distance, stats, mute toggle. Reuses the game's camera and
/// background so the transition into a run feels continuous.
final class TitleScene: SKScene {

    private let cam = GameCamera()
    private var background: Background!
    private var launcher: Launcher!
    private var boat: SKNode!
    private var didBuild = false
    private var lastUpdateTime: TimeInterval = 0
    private var bob: CGFloat = 0

    private let ui = SKNode()
    private let titleLabel = SKLabelNode.make("BAY BLASTER", size: 56, font: Tuning.fontHeavy)
    private let subtitleLabel = SKLabelNode.make("Marlow the Mackerel & the Old Lighthouse Cannon", size: 16, font: Tuning.fontMedium, color: UIColor.white.withAlphaComponent(0.85))
    private let bestLabel = SKLabelNode.make("", size: 20, align: .left)
    private let coinsLabel = SKLabelNode.make("", size: 20, color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), align: .left)
    private let statsLabel = SKLabelNode.make("", size: 13, font: Tuning.fontMedium, color: UIColor.white.withAlphaComponent(0.75))
    private var launchButton: ButtonNode!
    private var shopButton: ButtonNode!
    private var muteButton: ButtonNode!
    private let missionsHeader = SKLabelNode.make("MISSIONS", size: 13, font: Tuning.fontHeavy,
                                                  color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), align: .left)
    private var missionLabels: [SKLabelNode] = []

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        Art.view = view
        AudioManager.shared.warmUp()
        Haptics.prepare()
        backgroundColor = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1)
        if !didBuild { build() }
        refreshLabels()
        layout()
    }

    private func build() {
        didBuild = true
        camera = cam
        addChild(cam)
        cam.configure(sceneSize: size)
        background = Background(scene: self, camera: cam)

        launcher = Launcher()
        addChild(launcher)

        boat = SKNode()
        let hull = Art.sprite("boat")
        let fish = Art.sprite("fish")
        fish.position = CGPoint(x: -4, y: 18)
        boat.addChild(hull)
        boat.addChild(fish)
        boat.position = CGPoint(x: 140, y: Tuning.waterY + 4)
        boat.zPosition = 50
        addChild(boat)

        ui.zPosition = 1000
        cam.addChild(ui)

        titleLabel.fontColor = UIColor(red: 1, green: 0.93, blue: 0.5, alpha: 1)
        ui.addChild(titleLabel)
        ui.addChild(subtitleLabel)
        ui.addChild(bestLabel)
        ui.addChild(coinsLabel)
        ui.addChild(statsLabel)

        ui.addChild(missionsHeader)
        for _ in 0..<Missions.activeCount {
            let l = SKLabelNode.make("", size: 14, font: Tuning.fontMedium, color: UIColor.white.withAlphaComponent(0.9), align: .left)
            missionLabels.append(l)
            ui.addChild(l)
        }

        launchButton = ButtonNode(text: "LAUNCH!", size: CGSize(width: 240, height: 66), color: UIColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 1), fontSize: 30)
        launchButton.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(GameScene(size: self.size), from: self)
        }
        ui.addChild(launchButton)

        shopButton = ButtonNode(text: "SHOP", size: CGSize(width: 170, height: 50), color: UIColor(red: 0.25, green: 0.6, blue: 0.95, alpha: 1))
        shopButton.action = { [weak self] in
            guard let self = self else { return }
            SceneRouter.present(ShopScene(size: self.size), from: self, reveal: true)
        }
        ui.addChild(shopButton)

        muteButton = ButtonNode(text: "", size: CGSize(width: 56, height: 44), color: UIColor(red: 0.2, green: 0.25, blue: 0.4, alpha: 0.9), fontSize: 20)
        muteButton.action = { [weak self] in
            SaveManager.shared.toggleMute()
            self?.refreshLabels()
            AudioManager.shared.play(.tick)
        }
        ui.addChild(muteButton)

        cam.snap(to: CGPoint(x: 60, y: Tuning.waterY + 40))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard didBuild else { return }
        cam.configure(sceneSize: size)
        cam.snap(to: CGPoint(x: 60, y: Tuning.waterY + 40))
        background.layout(sceneSize: size)
        layout()
    }

    private func layout() {
        let insets = view?.safeAreaInsets ?? .zero
        let w = size.width, h = size.height
        let left = -w / 2 + insets.left + 18
        let right = w / 2 - insets.right - 18
        let top = h / 2 - insets.top - 16
        let bottom = -h / 2 + insets.bottom + 14

        let compact = h < 420
        titleLabel.fontSize = compact ? 44 : 60
        titleLabel.position = CGPoint(x: 0, y: top - (compact ? 26 : 40))
        subtitleLabel.position = CGPoint(x: 0, y: titleLabel.position.y - (compact ? 30 : 42))

        bestLabel.position = CGPoint(x: left, y: top - 12)
        coinsLabel.position = CGPoint(x: left, y: top - 38)
        missionsHeader.position = CGPoint(x: left, y: top - 76)
        for (i, l) in missionLabels.enumerated() {
            l.position = CGPoint(x: left, y: top - 96 - CGFloat(i) * 20)
        }
        muteButton.position = CGPoint(x: right - 28, y: top - 22)

        launchButton.position = CGPoint(x: 0, y: compact ? -8 : 0)
        shopButton.position = CGPoint(x: 0, y: launchButton.position.y - (compact ? 60 : 70))
        statsLabel.position = CGPoint(x: 0, y: bottom + 4)
    }

    private func refreshLabels() {
        Missions.refill()
        let d = SaveManager.shared.data
        for (i, l) in missionLabels.enumerated() {
            guard i < d.missions.count else { l.text = ""; continue }
            let m = d.missions[i]
            l.text = "\(m.completed ? "✓" : "•")  \(m.title)   +\(m.reward)"
            l.fontColor = m.completed ? UIColor(red: 0.6, green: 1, blue: 0.6, alpha: 1) : UIColor.white.withAlphaComponent(0.9)
        }
        bestLabel.text = "Best: \(Int(d.bestDistance)) m"
        coinsLabel.text = "Coins: \(d.coins)"
        muteButton.text = d.muted ? "MUTED" : "SOUND"
        let s = d.stats
        statsLabel.text = "Runs \(s.totalRuns)   ·   Total \(Int(s.totalDistance)) m   ·   Longest hop \(String(format: "%.1f", s.longestFlightTime)) s   ·   Best haul \(s.bestRunCoins) coins"
    }

    override func update(_ currentTime: TimeInterval) {
        var dt = CGFloat(currentTime - lastUpdateTime)
        if lastUpdateTime == 0 || dt > Tuning.maxDeltaTime { dt = Tuning.maxDeltaTime }
        lastUpdateTime = currentTime
        bob += dt
        boat.position.y = Tuning.waterY + 4 + sin(bob * 2.2) * 4
        boat.zRotation = sin(bob * 2.2 + 0.8) * 0.06
        background.update(camera: cam, distanceMetres: 0, dt: dt)
    }
}
