import SpriteKit

/// Parallax sky / shoreline / clouds / water. The sky, sun, moon and stars are camera children
/// (screen-fixed); clouds, shoreline and water live in the world and are re-positioned around
/// the camera every frame with parallax factors.
final class Background {

    // Implicitly unwrapped so the initializer can build the scene graph in one pass.
    private var daySky: SKSpriteNode!
    private var duskSky: SKSpriteNode!
    private var nightSky: SKSpriteNode!
    private let sun = SKShapeNode(circleOfRadius: 26)
    private let moon = SKShapeNode(circleOfRadius: 20)
    private let stars = SKNode()

    private let cloudLayer = SKNode()
    private var clouds: [SKNode] = []
    private var cloudInfo: [(baseX: CGFloat, baseY: CGFloat, drift: CGFloat)] = []
    private let cloudTileWidth: CGFloat = 2400
    private let cloudAltitude: CGFloat = 520

    private let shoreLayer = SKNode()
    private var shoreTileWidth: CGFloat = 1800     // replaced by the generated tile's real width
    private var shoreTint: SKSpriteNode!

    private let waterLayer = SKNode()
    private var waterSurface: SKSpriteNode!
    private var waterDeep: SKSpriteNode!
    private var waterNight: SKSpriteNode!
    private var wavePhase: CGFloat = 0
    private var waveStripes: [SKSpriteNode] = []

    private var sceneSize: CGSize

    init(scene: SKScene, camera: SKCameraNode) {
        sceneSize = scene.size
        let big = CGSize(width: 4000, height: 3000)

        daySky = SKSpriteNode(texture: Art.gradientTexture(top: UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1),
                                                           bottom: UIColor(red: 0.8, green: 0.92, blue: 1, alpha: 1), key: "__skyDay"), size: big)
        duskSky = SKSpriteNode(texture: Art.gradientTexture(top: UIColor(red: 0.3, green: 0.25, blue: 0.55, alpha: 1),
                                                            bottom: UIColor(red: 1, green: 0.6, blue: 0.45, alpha: 1), key: "__skyDusk"), size: big)
        nightSky = SKSpriteNode(texture: Art.gradientTexture(top: UIColor(red: 0.03, green: 0.04, blue: 0.12, alpha: 1),
                                                             bottom: UIColor(red: 0.12, green: 0.15, blue: 0.35, alpha: 1), key: "__skyNight"), size: big)
        for (i, sky) in [daySky!, duskSky!, nightSky!].enumerated() {
            sky.zPosition = -1000 + CGFloat(i)
            camera.addChild(sky)
        }
        duskSky.alpha = 0
        nightSky.alpha = 0

        sun.fillColor = UIColor(red: 1, green: 0.93, blue: 0.55, alpha: 1)
        sun.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.6)
        sun.lineWidth = 6
        sun.zPosition = -990
        camera.addChild(sun)

        moon.fillColor = UIColor(red: 0.95, green: 0.95, blue: 0.85, alpha: 1)
        moon.strokeColor = .clear
        moon.zPosition = -990
        moon.alpha = 0
        camera.addChild(moon)

        stars.zPosition = -995
        stars.alpha = 0
        for _ in 0..<70 {
            let s = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.2))
            s.fillColor = .white
            s.strokeColor = .clear
            s.position = CGPoint(x: CGFloat.random(in: -1200...1200), y: CGFloat.random(in: -100...800))
            s.alpha = CGFloat.random(in: 0.4...1)
            s.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: Double.random(in: 0.6...1.6)), .fadeAlpha(to: 1, duration: Double.random(in: 0.6...1.6))])))
            stars.addChild(s)
        }
        camera.addChild(stars)

        // Clouds (world space, parallax 0.25)
        cloudLayer.zPosition = -900
        scene.addChild(cloudLayer)
        for i in 0..<7 {
            let c = Art.sprite("cloud")
            let scale = CGFloat.random(in: 0.7...1.5)
            c.setScale(scale)
            c.alpha = CGFloat.random(in: 0.7...0.95)
            cloudInfo.append((baseX: CGFloat(i) * (cloudTileWidth / 7) + CGFloat.random(in: -120...120),
                              baseY: CGFloat.random(in: -80...260),
                              drift: CGFloat.random(in: 6...20)))
            cloudLayer.addChild(c)
            clouds.append(c)
        }

        // Distant shoreline (world space, parallax 0.55)
        shoreLayer.zPosition = -800
        scene.addChild(shoreLayer)
        let shoreColor = UIColor(red: 0.45, green: 0.62, blue: 0.55, alpha: 1)
        // One deterministic tile of rolling hills, repeated three times.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        var tileW: CGFloat = 0
        var seed: UInt32 = 12345
        while tileW < 1800 {
            seed = seed &* 1103515245 &+ 12345
            let h = 30 + CGFloat(seed % 90)
            let w = 140 + CGFloat((seed >> 8) % 160)
            path.addQuadCurve(to: CGPoint(x: tileW + w, y: 0), control: CGPoint(x: tileW + w / 2, y: h * 2))
            tileW += w
        }
        path.addLine(to: CGPoint(x: tileW, y: -200))
        path.addLine(to: CGPoint(x: 0, y: -200))
        path.closeSubpath()
        shoreTileWidth = tileW
        for tile in 0..<3 {
            let hills = SKShapeNode(path: path)
            hills.fillColor = shoreColor
            hills.strokeColor = .clear
            hills.position = CGPoint(x: CGFloat(tile) * tileW, y: 0)
            shoreLayer.addChild(hills)
            // little houses on each tile
            for j in 0..<5 {
                let house = SKShapeNode(rectOf: CGSize(width: 14, height: 12))
                house.fillColor = UIColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1)
                house.strokeColor = .clear
                house.position = CGPoint(x: CGFloat(tile) * tileW + 200 + CGFloat(j) * 300, y: 8)
                shoreLayer.addChild(house)
                let roof = SKShapeNode(path: Placeholders.polygon([CGPoint(x: -9, y: 6), CGPoint(x: 0, y: 15), CGPoint(x: 9, y: 6)]))
                roof.fillColor = UIColor(red: 0.75, green: 0.3, blue: 0.25, alpha: 1)
                roof.strokeColor = .clear
                roof.position = house.position
                shoreLayer.addChild(roof)
            }
        }
        shoreTint = SKSpriteNode(color: UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1), size: CGSize(width: shoreTileWidth * 3, height: 400))
        shoreTint.anchorPoint = CGPoint(x: 0, y: 0)
        shoreTint.position = CGPoint(x: 0, y: -200)
        shoreTint.alpha = 0
        shoreTint.zPosition = 1
        shoreLayer.addChild(shoreTint)

        // Water (world space, follows camera x)
        waterLayer.zPosition = 10
        scene.addChild(waterLayer)
        waterDeep = SKSpriteNode(color: UIColor(red: 0.1, green: 0.4, blue: 0.75, alpha: 1), size: CGSize(width: 12000, height: 3000))
        waterDeep.anchorPoint = CGPoint(x: 0.5, y: 1)
        waterDeep.position = CGPoint(x: 0, y: Tuning.waterY)
        waterLayer.addChild(waterDeep)
        waterNight = SKSpriteNode(color: UIColor(red: 0.02, green: 0.06, blue: 0.2, alpha: 1), size: CGSize(width: 12000, height: 3000))
        waterNight.anchorPoint = CGPoint(x: 0.5, y: 1)
        waterNight.position = CGPoint(x: 0, y: Tuning.waterY)
        waterNight.alpha = 0
        waterNight.zPosition = 1
        waterLayer.addChild(waterNight)
        waterSurface = SKSpriteNode(color: UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 0.9), size: CGSize(width: 12000, height: 6))
        waterSurface.anchorPoint = CGPoint(x: 0.5, y: 1)
        waterSurface.position = CGPoint(x: 0, y: Tuning.waterY + 3)
        waterSurface.zPosition = 2
        waterLayer.addChild(waterSurface)
        for i in 0..<40 {
            let stripe = SKSpriteNode(color: UIColor.white.withAlphaComponent(0.25), size: CGSize(width: CGFloat.random(in: 30...90), height: 3))
            stripe.position = CGPoint(x: CGFloat(i) * 300 - 6000, y: Tuning.waterY - CGFloat.random(in: 12...60))
            stripe.zPosition = 2
            waterLayer.addChild(stripe)
            waveStripes.append(stripe)
        }
    }

    func layout(sceneSize: CGSize) {
        self.sceneSize = sceneSize
    }

    func update(camera: GameCamera, distanceMetres: CGFloat, dt: CGFloat) {
        let camX = camera.position.x
        let camY = camera.position.y
        let night = clamp(distanceMetres / Tuning.dayNightMeters, 0, 1)

        // Sky blend: day → dusk (0…0.5) → night (0.5…1)
        duskSky.alpha = night < 0.5 ? night * 2 : 1
        nightSky.alpha = max(0, (night - 0.5) * 2)
        stars.alpha = max(0, (night - 0.6) * 2.5)
        shoreTint.alpha = night * 0.7
        waterNight.alpha = night * 0.85

        // Sun sets, moon rises (screen-fixed)
        let w = sceneSize.width, h = sceneSize.height
        sun.position = CGPoint(x: w * 0.3, y: lerp(h * 0.32, -h * 0.6, night))
        sun.alpha = 1 - max(0, (night - 0.4) * 2)
        moon.position = CGPoint(x: w * 0.34, y: lerp(-h * 0.6, h * 0.3, night))
        moon.alpha = max(0, (night - 0.35) * 2)

        // Clouds: parallax 0.25 with slow drift, wrap around a tile
        wavePhase += dt
        cloudLayer.position = CGPoint(x: camX, y: Tuning.waterY + cloudAltitude - (camY - Tuning.waterY) * 0.25)
        for (c, info) in zip(clouds, cloudInfo) {
            var lx = (info.baseX - camX * 0.25 - wavePhase * info.drift).truncatingRemainder(dividingBy: cloudTileWidth)
            if lx < 0 { lx += cloudTileWidth }
            c.position = CGPoint(x: lx - cloudTileWidth / 2, y: info.baseY)
            c.alpha = lerp(0.9, 0.35, night)
        }

        // Shoreline: parallax 0.55, sits on the horizon just above the water line
        var sx = (-camX * 0.55).truncatingRemainder(dividingBy: shoreTileWidth)
        if sx > 0 { sx -= shoreTileWidth }
        shoreLayer.position = CGPoint(x: camX + sx - shoreTileWidth, y: Tuning.waterY + 6 - (camY - Tuning.waterY) * 0.15)

        // Water follows the camera horizontally; stripes wobble
        waterLayer.position = CGPoint(x: camX, y: 0)
        for (i, s) in waveStripes.enumerated() {
            s.position.x = CGFloat(i) * 300 - 6000 + sin(wavePhase * 1.5 + CGFloat(i)) * 12 - camX.truncatingRemainder(dividingBy: 300)
        }
    }
}
