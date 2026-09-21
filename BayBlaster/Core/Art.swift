import SpriteKit
import UIKit

// =====================================================================================
//  Art.swift — placeholder art factory.
//
//  Every drawable thing in the game is requested by key, e.g. `Art.sprite("boat")`.
//  Resolution order:
//    1. An image asset named `key` in Assets.xcassets  → SKSpriteNode(imageNamed:)
//    2. A cached texture rendered from the placeholder drawing
//    3. The placeholder SKShapeNode drawing itself (only before the first SKView exists)
//
//  SWAPPING IN REAL ART: drop a PNG (or an atlas image) named exactly `key` into the
//  asset catalog. Nothing else changes. Keep the artwork centred and roughly the same
//  size as the placeholder so physics radii still fit.
// =====================================================================================

enum Art {
    /// Set by each scene in didMove(to:). Needed to bake shape drawings into textures.
    static weak var view: SKView?

    private static var textureCache: [String: SKTexture] = [:]
    private static var assetExists: [String: Bool] = [:]

    /// Returns a node drawn for `key`. The returned node is positioned so that the drawing's
    /// origin (0,0) is exactly where the placeholder placed it.
    static func sprite(_ key: String) -> SKNode {
        if assetExists[key] == nil { assetExists[key] = UIImage(named: key) != nil }
        if assetExists[key] == true {
            return SKSpriteNode(imageNamed: key)
        }
        let drawing = Placeholders.build(key)
        if let tex = textureCache[key] {
            return wrap(texture: tex, frame: drawing.calculateAccumulatedFrame())
        }
        if let view = view, let tex = view.texture(from: drawing) {
            tex.filteringMode = .linear
            textureCache[key] = tex
            return wrap(texture: tex, frame: drawing.calculateAccumulatedFrame())
        }
        return drawing
    }

    private static func wrap(texture: SKTexture, frame: CGRect) -> SKNode {
        let container = SKNode()
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = frame.size
        sprite.position = CGPoint(x: frame.midX, y: frame.midY)
        container.addChild(sprite)
        return container
    }

    /// Soft round particle used by every emitter (splash, rocket trail, sparkles).
    static var particleTexture: SKTexture {
        if let t = textureCache["__particle"] { return t }
        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(gradient,
                                                 startCenter: CGPoint(x: 12, y: 12), startRadius: 0,
                                                 endCenter: CGPoint(x: 12, y: 12), endRadius: 12,
                                                 options: [])
            }
        }
        let t = SKTexture(image: img)
        textureCache["__particle"] = t
        return t
    }

    /// Vertical gradient texture (top colour → bottom colour) used for skies.
    static func gradientTexture(top: UIColor, bottom: UIColor, key: String) -> SKTexture {
        if let t = textureCache[key] { return t }
        let size = CGSize(width: 4, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        let t = SKTexture(image: img)
        textureCache[key] = t
        return t
    }
}

// MARK: - Placeholder drawings (cartoony vector shapes)

enum Placeholders {

    static func build(_ key: String) -> SKNode {
        switch key {
        case "boat":        return boat()
        case "fish":        return fish()
        case "buoy":        return buoy()
        case "whaleSpout":  return whaleSpout()
        case "motor":       return motor()
        case "birdFlock":   return birdFlock()
        case "coinBag":     return coinBag()
        case "fuelCan":     return fuelCan()
        case "rock":        return rock()
        case "net":         return net()
        case "shark":       return shark()
        case "stormCloud":  return stormCloud()
        case "lighthouse":  return lighthouse()
        case "cannon":      return cannon()
        case "cloud":       return cloud()
        case "coinIcon":    return coinIcon()
        case "rocketIcon":  return rocketIcon()
        case "coin":        return coin()
        case "dolphin":     return dolphin()
        case "balloon":     return balloon()
        case "mine":        return mine()
        case "jellyfish":   return jellyfish()
        case "whirlpool":   return whirlpool()
        case "flag":        return flag(best: false)
        case "bestFlag":    return flag(best: true)
        // Unlockable riders (Marlow keeps the original "fish" key)
        case "crewBristle": return crewBristle()
        case "crewNixie":   return crewNixie()
        case "crewGilly":   return crewGilly()
        case "crewBruno":   return crewBruno()
        case "crewTock":    return crewTock()
        case "crewPip":     return crewPip()
        case "crewChum":    return crewChum()
        // Gear
        case "gearWheels":         return gearWheels()
        case "gearPontoons":       return gearPontoons()
        case "gearSpringKeel":     return gearSpringKeel()
        case "gearStormSail":      return gearStormSail()
        case "gearBoxKite":        return gearBoxKite()
        case "gearJetVent":        return gearJetVent()
        case "gearCoinMagnet":     return gearCoinMagnet()
        case "gearLuckyHorseshoe": return gearLuckyHorseshoe()
        case "gearBarnaclePlate":  return gearBarnaclePlate()
        // Unlockable launchers
        case "rodStand":    return rodStand()
        case "rodReel":     return rodReel()
        case "slingPost":   return slingPost()
        case "slingshot":   return slingshot()
        case "torpedoRig":  return torpedoRig()
        case "torpedoTube": return torpedoTube()
        case "trophyIcon":  return trophyIcon()
        // Smashables and the high air
        case "barrierWood":  return barrierWood()
        case "barrierStone": return barrierStone()
        case "barrierIron":  return barrierIron()
        case "crate":        return crate()
        case "blimp":        return blimp()
        case "boostRing":    return boostRing()
        case "jetStream":    return jetStream()
        case "cirrus":       return cirrus()
        default:            return missing()
        }
    }

    // MARK: helpers

    @discardableResult
    static func shape(_ path: CGPath, fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 2, in parent: SKNode) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = fill
        n.strokeColor = stroke ?? fill.darker(0.25)
        n.lineWidth = lineWidth
        n.lineJoin = .round
        n.isAntialiased = true
        parent.addChild(n)
        return n
    }

    @discardableResult
    static func circle(_ r: CGFloat, at p: CGPoint = .zero, fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 2, in parent: SKNode) -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: r)
        n.position = p
        n.fillColor = fill
        n.strokeColor = stroke ?? fill.darker(0.25)
        n.lineWidth = lineWidth
        n.isAntialiased = true
        parent.addChild(n)
        return n
    }

    @discardableResult
    static func rect(_ size: CGSize, at p: CGPoint = .zero, corner: CGFloat = 3, fill: UIColor, stroke: UIColor? = nil, lineWidth: CGFloat = 2, in parent: SKNode) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: corner)
        n.position = p
        n.fillColor = fill
        n.strokeColor = stroke ?? fill.darker(0.25)
        n.lineWidth = lineWidth
        n.isAntialiased = true
        parent.addChild(n)
        return n
    }

    static func polygon(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }

    // MARK: drawings

    /// Hero boat, ~72×26, origin at the waterline centre of the hull.
    static func boat() -> SKNode {
        let n = SKNode()
        let hull = CGMutablePath()
        hull.move(to: CGPoint(x: -36, y: 8))
        hull.addLine(to: CGPoint(x: 30, y: 8))
        hull.addQuadCurve(to: CGPoint(x: 40, y: 2), control: CGPoint(x: 40, y: 8))
        hull.addLine(to: CGPoint(x: 26, y: -12))
        hull.addLine(to: CGPoint(x: -26, y: -12))
        hull.addQuadCurve(to: CGPoint(x: -36, y: 8), control: CGPoint(x: -36, y: -8))
        hull.closeSubpath()
        shape(hull, fill: UIColor(red: 0.93, green: 0.36, blue: 0.24, alpha: 1), lineWidth: 2.5, in: n)
        // white stripe
        rect(CGSize(width: 62, height: 4), at: CGPoint(x: 0, y: 2), corner: 2, fill: .white, stroke: .clear, in: n)
        // gunwale / rim
        rect(CGSize(width: 74, height: 5), at: CGPoint(x: 1, y: 9), corner: 2.5, fill: UIColor(red: 0.55, green: 0.33, blue: 0.18, alpha: 1), in: n)
        // seat plank
        rect(CGSize(width: 22, height: 4), at: CGPoint(x: -8, y: 6), corner: 1, fill: UIColor(red: 0.72, green: 0.5, blue: 0.3, alpha: 1), in: n)
        return n
    }

    /// Marlow the mackerel, ~34×18, origin at his belly.
    static func fish() -> SKNode {
        let n = SKNode()
        let bodyColor = UIColor(red: 0.35, green: 0.72, blue: 0.85, alpha: 1)
        // tail
        shape(polygon([CGPoint(x: -14, y: 0), CGPoint(x: -24, y: 8), CGPoint(x: -22, y: 0), CGPoint(x: -24, y: -8)]), fill: bodyColor.darker(0.1), in: n)
        // body
        let body = SKShapeNode(ellipseOf: CGSize(width: 30, height: 16))
        body.fillColor = bodyColor
        body.strokeColor = bodyColor.darker(0.3)
        body.lineWidth = 2
        n.addChild(body)
        // stripes
        for i in 0..<3 {
            let s = SKShapeNode(rectOf: CGSize(width: 2.5, height: 9), cornerRadius: 1)
            s.position = CGPoint(x: CGFloat(-6 + i * 5), y: 2)
            s.fillColor = bodyColor.darker(0.35)
            s.strokeColor = .clear
            n.addChild(s)
        }
        // dorsal fin
        shape(polygon([CGPoint(x: -4, y: 7), CGPoint(x: 4, y: 13), CGPoint(x: 8, y: 7)]), fill: bodyColor.darker(0.15), in: n)
        // eye
        circle(3.2, at: CGPoint(x: 9, y: 2), fill: .white, stroke: .clear, in: n)
        circle(1.6, at: CGPoint(x: 10, y: 2), fill: .black, stroke: .clear, in: n)
        // goggles strap (he's a pilot!)
        let strap = SKShapeNode(circleOfRadius: 4.5)
        strap.position = CGPoint(x: 9, y: 2)
        strap.strokeColor = UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1)
        strap.lineWidth = 1.5
        strap.fillColor = .clear
        n.addChild(strap)
        // smile
        let smile = CGMutablePath()
        smile.move(to: CGPoint(x: 10, y: -3))
        smile.addQuadCurve(to: CGPoint(x: 15, y: -1), control: CGPoint(x: 14, y: -4))
        let sm = SKShapeNode(path: smile)
        sm.strokeColor = bodyColor.darker(0.5)
        sm.lineWidth = 1.5
        n.addChild(sm)
        return n
    }

    /// Springy buoy, ~44 tall, origin at the waterline.
    static func buoy() -> SKNode {
        let n = SKNode()
        let red = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        circle(16, at: CGPoint(x: 0, y: 2), fill: red, in: n)
        rect(CGSize(width: 30, height: 7), at: CGPoint(x: 0, y: 4), corner: 1, fill: .white, stroke: .clear, in: n)
        rect(CGSize(width: 8, height: 14), at: CGPoint(x: 0, y: 22), corner: 2, fill: red.darker(0.2), in: n)
        circle(4, at: CGPoint(x: 0, y: 30), fill: UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1), in: n)
        // spring coil hint
        rect(CGSize(width: 12, height: 6), at: CGPoint(x: 0, y: -12), corner: 2, fill: UIColor.darkGray, in: n)
        return n
    }

    /// Whale back at the water with a spout column above. Origin at waterline.
    static func whaleSpout() -> SKNode {
        let n = SKNode()
        let whale = UIColor(red: 0.2, green: 0.32, blue: 0.55, alpha: 1)
        let back = CGMutablePath()
        back.move(to: CGPoint(x: -48, y: -6))
        back.addQuadCurve(to: CGPoint(x: 48, y: -6), control: CGPoint(x: 0, y: 34))
        back.closeSubpath()
        shape(back, fill: whale, in: n)
        circle(3, at: CGPoint(x: 28, y: 4), fill: .white, in: n)
        circle(1.5, at: CGPoint(x: 29, y: 4), fill: .black, stroke: .clear, in: n)
        // spout
        let spray = UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 0.9)
        rect(CGSize(width: 8, height: 46), at: CGPoint(x: 0, y: 40), corner: 4, fill: spray, stroke: .clear, in: n)
        for (i, dx) in [-14, 0, 14].enumerated() {
            circle(CGFloat(9 - abs(i - 1) * 2), at: CGPoint(x: CGFloat(dx), y: 66), fill: spray, stroke: .clear, in: n)
        }
        return n
    }

    /// Outboard motor pickup, ~30×34.
    static func motor() -> SKNode {
        let n = SKNode()
        rect(CGSize(width: 24, height: 18), at: CGPoint(x: 0, y: 10), corner: 4, fill: UIColor(red: 0.3, green: 0.3, blue: 0.34, alpha: 1), in: n)
        rect(CGSize(width: 14, height: 5), at: CGPoint(x: 0, y: 14), corner: 2, fill: UIColor(red: 0.95, green: 0.8, blue: 0.2, alpha: 1), stroke: .clear, in: n)
        rect(CGSize(width: 6, height: 16), at: CGPoint(x: 0, y: -4), corner: 2, fill: UIColor.darkGray, in: n)
        // propeller
        shape(polygon([CGPoint(x: 0, y: -12), CGPoint(x: 10, y: -8), CGPoint(x: 0, y: -13), CGPoint(x: -10, y: -8)]), fill: UIColor.lightGray, in: n)
        // glow ring so it reads as a pickup
        let ring = SKShapeNode(circleOfRadius: 24)
        ring.strokeColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.6)
        ring.lineWidth = 2
        ring.fillColor = .clear
        n.addChild(ring)
        return n
    }

    /// Four gulls in a loose V. Zone entity (~220 wide).
    static func birdFlock() -> SKNode {
        let n = SKNode()
        let positions = [CGPoint(x: -80, y: 20), CGPoint(x: -30, y: 0), CGPoint(x: 30, y: -6), CGPoint(x: 85, y: 14), CGPoint(x: 0, y: 40)]
        for p in positions {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -14, y: -2))
            path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: -7, y: 8))
            path.addQuadCurve(to: CGPoint(x: 14, y: -2), control: CGPoint(x: 7, y: 8))
            let g = SKShapeNode(path: path)
            g.position = p
            g.strokeColor = .white
            g.lineWidth = 3
            g.lineCap = .round
            g.fillColor = .clear
            n.addChild(g)
        }
        // faint up-draft arrows
        for dx in [-60, 0, 60] {
            let a = SKShapeNode(path: polygon([CGPoint(x: -6, y: -26), CGPoint(x: 0, y: -16), CGPoint(x: 6, y: -26)]))
            a.position = CGPoint(x: CGFloat(dx), y: 0)
            a.fillColor = UIColor.white.withAlphaComponent(0.35)
            a.strokeColor = .clear
            n.addChild(a)
        }
        return n
    }

    /// Coin bag, ~26×30.
    static func coinBag() -> SKNode {
        let n = SKNode()
        let bag = CGMutablePath()
        bag.move(to: CGPoint(x: -6, y: 12))
        bag.addQuadCurve(to: CGPoint(x: -14, y: -10), control: CGPoint(x: -18, y: 6))
        bag.addQuadCurve(to: CGPoint(x: 14, y: -10), control: CGPoint(x: 0, y: -18))
        bag.addQuadCurve(to: CGPoint(x: 6, y: 12), control: CGPoint(x: 18, y: 6))
        bag.closeSubpath()
        shape(bag, fill: UIColor(red: 0.65, green: 0.45, blue: 0.25, alpha: 1), in: n)
        rect(CGSize(width: 14, height: 5), at: CGPoint(x: 0, y: 12), corner: 2, fill: UIColor(red: 0.5, green: 0.32, blue: 0.16, alpha: 1), in: n)
        circle(6, at: CGPoint(x: 0, y: -2), fill: UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1), in: n)
        return n
    }

    /// Fuel jerry-can, ~22×28.
    static func fuelCan() -> SKNode {
        let n = SKNode()
        rect(CGSize(width: 22, height: 26), at: .zero, corner: 4, fill: UIColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1), in: n)
        rect(CGSize(width: 10, height: 5), at: CGPoint(x: 0, y: 15), corner: 2, fill: UIColor.darkGray, in: n)
        rect(CGSize(width: 12, height: 3), at: CGPoint(x: 0, y: 2), corner: 1, fill: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), stroke: .clear, in: n)
        return n
    }

    /// Single small coin, ~20 wide.
    static func coin() -> SKNode {
        let n = SKNode()
        circle(10, fill: UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), stroke: UIColor(red: 0.8, green: 0.55, blue: 0.1, alpha: 1), in: n)
        circle(5, fill: UIColor(red: 1, green: 0.92, blue: 0.5, alpha: 1), stroke: .clear, in: n)
        return n
    }

    /// Leaping dolphin at the waterline, ~76×40. Nose points forward (+x).
    static func dolphin() -> SKNode {
        let n = SKNode()
        let grey = UIColor(red: 0.55, green: 0.65, blue: 0.78, alpha: 1)
        let body = CGMutablePath()
        body.move(to: CGPoint(x: -36, y: 4))
        body.addQuadCurve(to: CGPoint(x: 36, y: 6), control: CGPoint(x: 0, y: 34))
        body.addQuadCurve(to: CGPoint(x: -36, y: 4), control: CGPoint(x: 0, y: -4))
        body.closeSubpath()
        shape(body, fill: grey, in: n)
        shape(polygon([CGPoint(x: -4, y: 18), CGPoint(x: 4, y: 34), CGPoint(x: 10, y: 18)]), fill: grey.darker(0.15), in: n)   // dorsal fin
        shape(polygon([CGPoint(x: -36, y: 4), CGPoint(x: -46, y: 16), CGPoint(x: -40, y: 0), CGPoint(x: -46, y: -6)]), fill: grey.darker(0.15), in: n) // tail
        circle(2.5, at: CGPoint(x: 24, y: 10), fill: .black, stroke: .clear, in: n)   // eye
        for dx in [-24, 30] { circle(5, at: CGPoint(x: CGFloat(dx), y: 0), fill: UIColor.white.withAlphaComponent(0.7), stroke: .clear, in: n) }
        return n
    }

    /// Bunch of three balloons with strings, ~56×70.
    static func balloon() -> SKNode {
        let n = SKNode()
        let colors = [UIColor(red: 1, green: 0.35, blue: 0.4, alpha: 1), UIColor(red: 0.4, green: 0.7, blue: 1, alpha: 1), UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)]
        for (i, (dx, dy)) in [(-16, 14), (16, 18), (0, 30)].enumerated() {
            let string = SKShapeNode(path: polygon([CGPoint(x: CGFloat(dx), y: CGFloat(dy) - 16), CGPoint(x: 0, y: -22)]))
            string.strokeColor = UIColor.white.withAlphaComponent(0.7)
            string.lineWidth = 1.5
            n.addChild(string)
            let b = SKShapeNode(ellipseOf: CGSize(width: 26, height: 32))
            b.position = CGPoint(x: CGFloat(dx), y: CGFloat(dy))
            b.fillColor = colors[i]
            b.strokeColor = colors[i].darker(0.2)
            b.lineWidth = 2
            n.addChild(b)
            circle(4, at: CGPoint(x: CGFloat(dx) - 6, y: CGFloat(dy) + 8), fill: UIColor.white.withAlphaComponent(0.6), stroke: .clear, in: n)
        }
        return n
    }

    /// Spiky sea mine bobbing at the waterline, ~56 wide.
    static func mine() -> SKNode {
        let n = SKNode()
        let dark = UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2
            let tip = CGPoint(x: cos(a) * 28, y: sin(a) * 28)
            let base1 = CGPoint(x: cos(a + 0.25) * 18, y: sin(a + 0.25) * 18)
            let base2 = CGPoint(x: cos(a - 0.25) * 18, y: sin(a - 0.25) * 18)
            shape(polygon([base1, tip, base2]), fill: dark, stroke: .clear, in: n)
        }
        circle(20, fill: dark, stroke: UIColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1), in: n)
        circle(5, at: CGPoint(x: 0, y: 4), fill: UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1), stroke: .clear, in: n) // blinking light
        circle(7, at: CGPoint(x: -8, y: 8), fill: UIColor.white.withAlphaComponent(0.18), stroke: .clear, in: n)
        return n
    }

    /// Jellyfish drifting just above the water, ~48×56.
    static func jellyfish() -> SKNode {
        let n = SKNode()
        let purple = UIColor(red: 0.8, green: 0.55, blue: 1, alpha: 0.9)
        let dome = CGMutablePath()
        dome.move(to: CGPoint(x: -22, y: 0))
        dome.addQuadCurve(to: CGPoint(x: 22, y: 0), control: CGPoint(x: 0, y: 44))
        dome.addLine(to: CGPoint(x: 16, y: -4))
        dome.addLine(to: CGPoint(x: 8, y: 0))
        dome.addLine(to: CGPoint(x: 0, y: -4))
        dome.addLine(to: CGPoint(x: -8, y: 0))
        dome.addLine(to: CGPoint(x: -16, y: -4))
        dome.closeSubpath()
        shape(dome, fill: purple, stroke: purple.darker(0.2), in: n)
        for dx in [-14, -5, 5, 14] {
            let t = SKShapeNode(path: polygon([CGPoint(x: CGFloat(dx), y: -2), CGPoint(x: CGFloat(dx) + 4, y: -14), CGPoint(x: CGFloat(dx) - 3, y: -28)]))
            t.strokeColor = purple.darker(0.1)
            t.lineWidth = 2.5
            n.addChild(t)
        }
        circle(3, at: CGPoint(x: -7, y: 14), fill: .white, stroke: .clear, in: n)
        circle(3, at: CGPoint(x: 7, y: 14), fill: .white, stroke: .clear, in: n)
        return n
    }

    /// Whirlpool on the water, ~180 wide (zone). Drawn flat so it reads as a surface feature.
    static func whirlpool() -> SKNode {
        let n = SKNode()
        for (i, w) in [170, 130, 92, 56, 24].enumerated() {
            let ring = SKShapeNode(ellipseOf: CGSize(width: CGFloat(w), height: CGFloat(w) * 0.34))
            ring.position = CGPoint(x: 0, y: -CGFloat(i) * 3)
            ring.fillColor = .clear
            ring.strokeColor = UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 0.55 + CGFloat(i) * 0.08)
            ring.lineWidth = 3
            ring.zRotation = CGFloat(i) * 0.15
            n.addChild(ring)
        }
        let eye = SKShapeNode(ellipseOf: CGSize(width: 20, height: 8))
        eye.position = CGPoint(x: 0, y: -12)
        eye.fillColor = UIColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 0.9)
        eye.strokeColor = .clear
        n.addChild(eye)
        return n
    }

    /// Distance flag on a pole. Origin at the waterline; the label is added by Milestones.
    static func flag(best: Bool) -> SKNode {
        let n = SKNode()
        rect(CGSize(width: 4, height: 84), at: CGPoint(x: 0, y: 42), corner: 1, fill: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), stroke: .clear, in: n)
        circle(10, at: CGPoint(x: 0, y: 2), fill: UIColor(red: 0.95, green: 0.4, blue: 0.3, alpha: 1), in: n)   // float
        let color = best ? UIColor(red: 1, green: 0.78, blue: 0.2, alpha: 1) : UIColor(red: 0.95, green: 0.95, blue: 1, alpha: 1)
        shape(polygon([CGPoint(x: 2, y: 84), CGPoint(x: 48, y: 72), CGPoint(x: 2, y: 58)]), fill: color, stroke: color.darker(0.2), in: n)
        if best {
            shape(polygon([CGPoint(x: 2, y: 84), CGPoint(x: 48, y: 72), CGPoint(x: 2, y: 58)]), fill: color, stroke: UIColor(red: 0.7, green: 0.45, blue: 0.05, alpha: 1), lineWidth: 3, in: n)
        }
        return n
    }

    /// Reef rock at the waterline, ~70×30.
    static func rock() -> SKNode {
        let n = SKNode()
        let dark = UIColor(red: 0.36, green: 0.36, blue: 0.4, alpha: 1)
        shape(polygon([CGPoint(x: -36, y: -8), CGPoint(x: -22, y: 12), CGPoint(x: -4, y: 22), CGPoint(x: 18, y: 16), CGPoint(x: 34, y: 2), CGPoint(x: 30, y: -8)]), fill: dark, in: n)
        shape(polygon([CGPoint(x: -10, y: 8), CGPoint(x: -4, y: 18), CGPoint(x: 14, y: 14), CGPoint(x: 8, y: 6)]), fill: dark.lighter(0.18), stroke: .clear, in: n)
        // foam
        for dx in [-30, 32] {
            circle(6, at: CGPoint(x: CGFloat(dx), y: 0), fill: UIColor.white.withAlphaComponent(0.8), stroke: .clear, in: n)
        }
        return n
    }

    /// Fishing net floating on the surface, ~80 wide.
    static func net() -> SKNode {
        let n = SKNode()
        let brown = UIColor(red: 0.55, green: 0.4, blue: 0.2, alpha: 1)
        for i in 0...6 {
            let x = CGFloat(-36 + i * 12)
            let line = SKShapeNode(path: polygon([CGPoint(x: x, y: -10), CGPoint(x: x + 6, y: 14)]))
            line.strokeColor = brown
            line.lineWidth = 2
            n.addChild(line)
            let line2 = SKShapeNode(path: polygon([CGPoint(x: x + 6, y: -10), CGPoint(x: x, y: 14)]))
            line2.strokeColor = brown
            line2.lineWidth = 2
            n.addChild(line2)
        }
        for dx in [-40, 0, 40] {
            circle(6, at: CGPoint(x: CGFloat(dx), y: 14), fill: UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1), in: n)
        }
        return n
    }

    /// Shark fin + shadow at the waterline, ~60×36.
    static func shark() -> SKNode {
        let n = SKNode()
        let gray = UIColor(red: 0.45, green: 0.5, blue: 0.58, alpha: 1)
        // body shadow under water
        let body = SKShapeNode(ellipseOf: CGSize(width: 64, height: 14))
        body.position = CGPoint(x: 0, y: -8)
        body.fillColor = gray.withAlphaComponent(0.45)
        body.strokeColor = .clear
        n.addChild(body)
        // fin
        shape(polygon([CGPoint(x: -14, y: 0), CGPoint(x: 6, y: 30), CGPoint(x: 16, y: 0)]), fill: gray, in: n)
        // tail tip
        shape(polygon([CGPoint(x: -34, y: 0), CGPoint(x: -28, y: 14), CGPoint(x: -22, y: 0)]), fill: gray, in: n)
        return n
    }

    /// Angry storm cloud with a bolt. Zone entity (~200 wide).
    static func stormCloud() -> SKNode {
        let n = SKNode()
        let c = UIColor(red: 0.3, green: 0.32, blue: 0.4, alpha: 1)
        for (dx, r) in [(-60, 34), (-20, 44), (25, 40), (65, 30)] {
            circle(CGFloat(r), at: CGPoint(x: CGFloat(dx), y: CGFloat(r) * 0.2), fill: c, stroke: .clear, in: n)
        }
        rect(CGSize(width: 150, height: 30), at: CGPoint(x: 0, y: -6), corner: 12, fill: c, stroke: .clear, in: n)
        shape(polygon([CGPoint(x: 4, y: -18), CGPoint(x: -8, y: -44), CGPoint(x: 2, y: -42), CGPoint(x: -6, y: -68), CGPoint(x: 14, y: -38), CGPoint(x: 4, y: -40), CGPoint(x: 12, y: -18)]),
              fill: UIColor(red: 1, green: 0.92, blue: 0.3, alpha: 1), in: n)
        // rain streaks
        for dx in [-50, -25, 30, 55] {
            let r = SKShapeNode(path: polygon([CGPoint(x: CGFloat(dx), y: -24), CGPoint(x: CGFloat(dx) - 4, y: -40)]))
            r.strokeColor = UIColor(red: 0.6, green: 0.75, blue: 1, alpha: 0.8)
            r.lineWidth = 2
            n.addChild(r)
        }
        return n
    }

    /// Lighthouse tower on a rocky base. Origin at the waterline under the tower centre.
    static func lighthouse() -> SKNode {
        let n = SKNode()
        // rock base
        shape(polygon([CGPoint(x: -80, y: -30), CGPoint(x: -60, y: 14), CGPoint(x: -20, y: 22), CGPoint(x: 30, y: 18), CGPoint(x: 60, y: 6), CGPoint(x: 70, y: -30)]),
              fill: UIColor(red: 0.42, green: 0.4, blue: 0.42, alpha: 1), in: n)
        // tower (tapered)
        shape(polygon([CGPoint(x: -26, y: 18), CGPoint(x: -18, y: 150), CGPoint(x: 18, y: 150), CGPoint(x: 26, y: 18)]),
              fill: UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1), in: n)
        for i in 0..<3 {
            let y = 40 + CGFloat(i) * 36
            let w = 50 - CGFloat(i) * 4.5
            rect(CGSize(width: w, height: 14), at: CGPoint(x: 0, y: y), corner: 0, fill: UIColor(red: 0.85, green: 0.2, blue: 0.22, alpha: 1), stroke: .clear, in: n)
        }
        // door
        rect(CGSize(width: 12, height: 20), at: CGPoint(x: 0, y: 28), corner: 5, fill: UIColor(red: 0.35, green: 0.22, blue: 0.14, alpha: 1), in: n)
        // gallery + lamp room
        rect(CGSize(width: 48, height: 6), at: CGPoint(x: 0, y: 152), corner: 2, fill: UIColor.darkGray, in: n)
        rect(CGSize(width: 26, height: 22), at: CGPoint(x: 0, y: 166), corner: 3, fill: UIColor(red: 1, green: 0.92, blue: 0.45, alpha: 1), stroke: UIColor.darkGray, in: n)
        shape(polygon([CGPoint(x: -18, y: 177), CGPoint(x: 0, y: 194), CGPoint(x: 18, y: 177)]), fill: UIColor(red: 0.85, green: 0.2, blue: 0.22, alpha: 1), in: n)
        // lamp glow
        let glow = SKShapeNode(circleOfRadius: 20)
        glow.position = CGPoint(x: 0, y: 166)
        glow.fillColor = UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 0.25)
        glow.strokeColor = .clear
        n.addChild(glow)
        return n
    }

    /// Cannon barrel. Origin at the pivot; barrel extends along +x.
    static func cannon() -> SKNode {
        let n = SKNode()
        let iron = UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        shape(polygon([CGPoint(x: -14, y: -12), CGPoint(x: -14, y: 12), CGPoint(x: Tuning.launcherBarrelLength, y: 9), CGPoint(x: Tuning.launcherBarrelLength, y: -9)]),
              fill: iron, in: n)
        rect(CGSize(width: 8, height: 24), at: CGPoint(x: Tuning.launcherBarrelLength - 4, y: 0), corner: 2, fill: iron.lighter(0.15), in: n)
        rect(CGSize(width: 8, height: 20), at: CGPoint(x: 20, y: 0), corner: 2, fill: UIColor(red: 0.8, green: 0.6, blue: 0.25, alpha: 1), stroke: .clear, in: n)
        circle(12, at: .zero, fill: iron.darker(0.1), in: n)
        circle(4, at: .zero, fill: UIColor(red: 0.8, green: 0.6, blue: 0.25, alpha: 1), stroke: .clear, in: n)
        return n
    }

    /// Background cloud, ~140 wide.
    static func cloud() -> SKNode {
        let n = SKNode()
        let c = UIColor.white
        for (dx, r) in [(-45, 22), (-15, 32), (20, 28), (50, 20)] {
            circle(CGFloat(r), at: CGPoint(x: CGFloat(dx), y: CGFloat(r) * 0.15), fill: c, stroke: .clear, in: n)
        }
        rect(CGSize(width: 120, height: 24), at: CGPoint(x: 0, y: -6), corner: 12, fill: c, stroke: .clear, in: n)
        return n
    }

    static func coinIcon() -> SKNode {
        let n = SKNode()
        circle(9, fill: UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1), stroke: UIColor(red: 0.75, green: 0.55, blue: 0.1, alpha: 1), in: n)
        circle(5, fill: .clear, stroke: UIColor(red: 0.85, green: 0.65, blue: 0.15, alpha: 1), lineWidth: 1.5, in: n)
        return n
    }

    static func rocketIcon() -> SKNode {
        let n = SKNode()
        shape(polygon([CGPoint(x: -8, y: -4), CGPoint(x: 6, y: -4), CGPoint(x: 12, y: 0), CGPoint(x: 6, y: 4), CGPoint(x: -8, y: 4)]), fill: UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1), in: n)
        shape(polygon([CGPoint(x: -8, y: 0), CGPoint(x: -14, y: 5), CGPoint(x: -6, y: 0), CGPoint(x: -14, y: -5)]), fill: UIColor(red: 1, green: 0.5, blue: 0.15, alpha: 1), stroke: .clear, in: n)
        return n
    }


    // MARK: - Unlockable riders (Core/Crew.swift)
    // Each is drawn to the same footprint as Marlow (~34×18, origin at the belly) so the
    // rider swap never moves the boat's centre of mass or the goggles-height bob.

    /// Bristle the pufferfish — round, spiky, unbothered.
    static func crewBristle() -> SKNode {
        let n = SKNode()
        let body = UIColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        for i in 0..<10 {                               // spikes around the sphere
            let a = CGFloat(i) / 10 * .pi * 2
            shape(polygon([CGPoint(x: cos(a) * 10, y: sin(a) * 10 + 2),
                           CGPoint(x: cos(a + 0.3) * 10, y: sin(a + 0.3) * 10 + 2),
                           CGPoint(x: cos(a + 0.15) * 16, y: sin(a + 0.15) * 16 + 2)]),
                  fill: body.darker(0.18), stroke: .clear, in: n)
        }
        circle(11, at: CGPoint(x: 0, y: 2), fill: body, in: n)
        circle(3.2, at: CGPoint(x: 7, y: 4), fill: .white, stroke: .clear, in: n)
        circle(1.6, at: CGPoint(x: 8, y: 4), fill: .black, stroke: .clear, in: n)
        shape(polygon([CGPoint(x: -11, y: 2), CGPoint(x: -18, y: 8), CGPoint(x: -18, y: -4)]),
              fill: body.darker(0.1), in: n)
        return n
    }

    /// Nixie the flying fish — long wing-fins held out wide.
    static func crewNixie() -> SKNode {
        let n = SKNode()
        let body = UIColor(red: 0.55, green: 0.85, blue: 0.7, alpha: 1)
        shape(polygon([CGPoint(x: -12, y: 0), CGPoint(x: -22, y: 7), CGPoint(x: -20, y: 0), CGPoint(x: -22, y: -7)]),
              fill: body.darker(0.12), in: n)
        // wings, above and below
        shape(polygon([CGPoint(x: -2, y: 4), CGPoint(x: -14, y: 16), CGPoint(x: 8, y: 6)]),
              fill: UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 0.9), in: n)
        shape(polygon([CGPoint(x: -2, y: -3), CGPoint(x: -13, y: -13), CGPoint(x: 7, y: -5)]),
              fill: UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 0.75), in: n)
        let e = SKShapeNode(ellipseOf: CGSize(width: 28, height: 13))
        e.fillColor = body; e.strokeColor = body.darker(0.3); e.lineWidth = 2
        e.position = CGPoint(x: 0, y: 1)
        n.addChild(e)
        circle(3, at: CGPoint(x: 9, y: 2), fill: .white, stroke: .clear, in: n)
        circle(1.5, at: CGPoint(x: 10, y: 2), fill: .black, stroke: .clear, in: n)
        return n
    }

    /// Gilly the squid — mantle up front, tentacles trailing behind.
    static func crewGilly() -> SKNode {
        let n = SKNode()
        let body = UIColor(red: 0.85, green: 0.5, blue: 0.85, alpha: 1)
        for i in 0..<5 {                                // tentacles
            let y = CGFloat(i - 2) * 3.4
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -6, y: y + 2))
            p.addQuadCurve(to: CGPoint(x: -22, y: y - 2), control: CGPoint(x: -14, y: y + 6))
            let t = SKShapeNode(path: p)
            t.strokeColor = body.darker(0.15); t.lineWidth = 2.6; t.lineCap = .round
            n.addChild(t)
        }
        let mantle = SKShapeNode(ellipseOf: CGSize(width: 26, height: 15))
        mantle.fillColor = body; mantle.strokeColor = body.darker(0.3); mantle.lineWidth = 2
        mantle.position = CGPoint(x: 3, y: 2)
        n.addChild(mantle)
        shape(polygon([CGPoint(x: 12, y: 8), CGPoint(x: 20, y: 12), CGPoint(x: 15, y: 3)]), fill: body.lighter(0.05), in: n)
        circle(3.4, at: CGPoint(x: 8, y: 3), fill: .white, stroke: .clear, in: n)
        circle(1.7, at: CGPoint(x: 9, y: 3), fill: .black, stroke: .clear, in: n)
        return n
    }

    /// Bruno the sea otter — broad chest, little paws up.
    static func crewBruno() -> SKNode {
        let n = SKNode()
        let fur = UIColor(red: 0.55, green: 0.38, blue: 0.24, alpha: 1)
        shape(polygon([CGPoint(x: -12, y: -2), CGPoint(x: -24, y: 2), CGPoint(x: -12, y: 4)]), fill: fur.darker(0.1), in: n)
        let body = SKShapeNode(ellipseOf: CGSize(width: 26, height: 17))
        body.fillColor = fur; body.strokeColor = fur.darker(0.25); body.lineWidth = 2
        n.addChild(body)
        circle(8, at: CGPoint(x: 9, y: 5), fill: fur.lighter(0.08), in: n)          // head
        circle(2.6, at: CGPoint(x: 5, y: 11), fill: fur.darker(0.15), in: n)        // ears
        circle(2.6, at: CGPoint(x: 13, y: 11), fill: fur.darker(0.15), in: n)
        circle(3.4, at: CGPoint(x: 11, y: 3), fill: UIColor(red: 0.95, green: 0.88, blue: 0.78, alpha: 1), stroke: .clear, in: n)
        circle(1.3, at: CGPoint(x: 12, y: 3.5), fill: .black, stroke: .clear, in: n)
        circle(1.4, at: CGPoint(x: 7, y: 6), fill: .black, stroke: .clear, in: n)
        circle(4, at: CGPoint(x: 0, y: -5), fill: fur.lighter(0.1), in: n)          // paws
        return n
    }

    /// Tock the hermit crab — a shell with a crab leaning out of it.
    static func crewTock() -> SKNode {
        let n = SKNode()
        let shell = UIColor(red: 0.85, green: 0.66, blue: 0.45, alpha: 1)
        let crab = UIColor(red: 0.9, green: 0.35, blue: 0.3, alpha: 1)
        circle(11, at: CGPoint(x: -4, y: 3), fill: shell, in: n)
        let spiral = SKShapeNode(circleOfRadius: 6.5)
        spiral.position = CGPoint(x: -4, y: 3)
        spiral.fillColor = .clear; spiral.strokeColor = shell.darker(0.25); spiral.lineWidth = 2
        n.addChild(spiral)
        circle(2.5, at: CGPoint(x: -4, y: 3), fill: shell.darker(0.2), stroke: .clear, in: n)
        circle(6, at: CGPoint(x: 9, y: 0), fill: crab, in: n)                        // body
        for dy in [-4, 0, 4] {                                                        // legs
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 12, y: CGFloat(dy)))
            p.addLine(to: CGPoint(x: 18, y: CGFloat(dy) - 4))
            let l = SKShapeNode(path: p)
            l.strokeColor = crab.darker(0.15); l.lineWidth = 2; l.lineCap = .round
            n.addChild(l)
        }
        circle(2.2, at: CGPoint(x: 8, y: 6), fill: .white, stroke: .clear, in: n)     // eyestalks
        circle(2.2, at: CGPoint(x: 13, y: 5), fill: .white, stroke: .clear, in: n)
        circle(1.1, at: CGPoint(x: 8, y: 6), fill: .black, stroke: .clear, in: n)
        circle(1.1, at: CGPoint(x: 13, y: 5), fill: .black, stroke: .clear, in: n)
        return n
    }

    /// Pip the seagull — white, wings half-folded, very smug.
    static func crewPip() -> SKNode {
        let n = SKNode()
        let feather = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
        shape(polygon([CGPoint(x: -10, y: 1), CGPoint(x: -22, y: 6), CGPoint(x: -20, y: -3)]),
              fill: feather.darker(0.12), in: n)
        let body = SKShapeNode(ellipseOf: CGSize(width: 26, height: 15))
        body.fillColor = feather; body.strokeColor = feather.darker(0.25); body.lineWidth = 2
        n.addChild(body)
        shape(polygon([CGPoint(x: 2, y: 4), CGPoint(x: -10, y: 13), CGPoint(x: 6, y: 5)]),
              fill: UIColor(red: 0.7, green: 0.72, blue: 0.78, alpha: 1), in: n)      // wing
        circle(6, at: CGPoint(x: 10, y: 6), fill: feather, in: n)                     // head
        shape(polygon([CGPoint(x: 14, y: 6), CGPoint(x: 23, y: 4), CGPoint(x: 14, y: 2)]),
              fill: UIColor(red: 1, green: 0.72, blue: 0.2, alpha: 1), in: n)         // beak
        circle(1.6, at: CGPoint(x: 11, y: 8), fill: .black, stroke: .clear, in: n)
        return n
    }

    /// Chum the baby shark — small, grey, all teeth.
    static func crewChum() -> SKNode {
        let n = SKNode()
        let grey = UIColor(red: 0.52, green: 0.58, blue: 0.66, alpha: 1)
        shape(polygon([CGPoint(x: -12, y: 0), CGPoint(x: -23, y: 9), CGPoint(x: -19, y: 0), CGPoint(x: -23, y: -7)]),
              fill: grey.darker(0.12), in: n)
        let body = SKShapeNode(ellipseOf: CGSize(width: 30, height: 15))
        body.fillColor = grey; body.strokeColor = grey.darker(0.3); body.lineWidth = 2
        n.addChild(body)
        shape(polygon([CGPoint(x: -3, y: 6), CGPoint(x: 2, y: 15), CGPoint(x: 7, y: 6)]), fill: grey.darker(0.15), in: n)
        rect(CGSize(width: 22, height: 6), at: CGPoint(x: -1, y: -4), corner: 3,
             fill: UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1), stroke: .clear, in: n) // pale belly
        // grin
        for i in 0..<5 {
            shape(polygon([CGPoint(x: CGFloat(4 + i * 3), y: -2), CGPoint(x: CGFloat(i * 3) + 5.5, y: -5.5), CGPoint(x: CGFloat(7 + i * 3), y: -2)]),
                  fill: .white, stroke: .clear, in: n)
        }
        circle(2.6, at: CGPoint(x: 9, y: 3), fill: .white, stroke: .clear, in: n)
        circle(1.3, at: CGPoint(x: 10, y: 3), fill: .black, stroke: .clear, in: n)
        return n
    }

    // MARK: - Gear (Core/Gear.swift)
    // Hull parts are drawn to hang under the hull, rigs to stand above it, trinkets small
    // enough to sit on the gunwale. Player.addGearArt places them.

    static func gearWheels() -> SKNode {
        let n = SKNode()
        let tyre = UIColor(red: 0.18, green: 0.18, blue: 0.2, alpha: 1)
        for dx in [-18, 18] {
            circle(9, at: CGPoint(x: CGFloat(dx), y: 0), fill: tyre, stroke: tyre.lighter(0.1), in: n)
            circle(3.5, at: CGPoint(x: CGFloat(dx), y: 0), fill: UIColor(red: 0.8, green: 0.8, blue: 0.85, alpha: 1), stroke: .clear, in: n)
        }
        rect(CGSize(width: 40, height: 4), at: CGPoint(x: 0, y: 4), corner: 2,
             fill: UIColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1), in: n)
        return n
    }

    static func gearPontoons() -> SKNode {
        let n = SKNode()
        let hull = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1)
        for dx in [-20, 20] {
            let p = SKShapeNode(ellipseOf: CGSize(width: 30, height: 12))
            p.position = CGPoint(x: CGFloat(dx), y: 0)
            p.fillColor = hull; p.strokeColor = UIColor(red: 0.3, green: 0.55, blue: 0.85, alpha: 1); p.lineWidth = 2
            n.addChild(p)
        }
        return n
    }

    static func gearSpringKeel() -> SKNode {
        let n = SKNode()
        let steel = UIColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1)
        let coil = CGMutablePath()
        coil.move(to: CGPoint(x: -10, y: 6))
        for i in 0..<6 {                                  // zig-zag spring
            let x = CGFloat(-10 + i * 4)
            coil.addLine(to: CGPoint(x: x + 2, y: i % 2 == 0 ? -6 : 6))
        }
        let c = SKShapeNode(path: coil)
        c.strokeColor = steel; c.lineWidth = 3; c.fillColor = .clear; c.lineJoin = .round
        n.addChild(c)
        rect(CGSize(width: 34, height: 4), at: CGPoint(x: 0, y: -9), corner: 2, fill: steel.darker(0.2), in: n)
        return n
    }

    static func gearStormSail() -> SKNode {
        let n = SKNode()
        rect(CGSize(width: 3, height: 40), at: CGPoint(x: -8, y: 0), corner: 1.5,
             fill: UIColor(red: 0.6, green: 0.42, blue: 0.25, alpha: 1), in: n)
        let sail = CGMutablePath()
        sail.move(to: CGPoint(x: -7, y: 20))
        sail.addQuadCurve(to: CGPoint(x: -7, y: -14), control: CGPoint(x: 22, y: 2))
        sail.closeSubpath()
        shape(sail, fill: UIColor(red: 0.98, green: 0.93, blue: 0.85, alpha: 1),
              stroke: UIColor(red: 0.85, green: 0.35, blue: 0.3, alpha: 1), in: n)
        return n
    }

    static func gearBoxKite() -> SKNode {
        let n = SKNode()
        let cloth = UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1)
        rect(CGSize(width: 24, height: 14), at: CGPoint(x: 0, y: 26), corner: 2, fill: cloth, in: n)
        rect(CGSize(width: 24, height: 14), at: CGPoint(x: 0, y: 6), corner: 2, fill: cloth.darker(0.12), in: n)
        for dx in [-11, 11] {
            rect(CGSize(width: 2, height: 36), at: CGPoint(x: CGFloat(dx), y: 16), corner: 1,
                 fill: UIColor(red: 0.6, green: 0.45, blue: 0.3, alpha: 1), stroke: .clear, in: n)
        }
        let line = CGMutablePath()
        line.move(to: CGPoint(x: 0, y: 0))
        line.addLine(to: CGPoint(x: -6, y: -14))
        let l = SKShapeNode(path: line)
        l.strokeColor = UIColor.white.withAlphaComponent(0.7); l.lineWidth = 1.5
        n.addChild(l)
        return n
    }

    static func gearJetVent() -> SKNode {
        let n = SKNode()
        let metal = UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        shape(polygon([CGPoint(x: 8, y: 6), CGPoint(x: -10, y: 8), CGPoint(x: -14, y: 0), CGPoint(x: -10, y: -8), CGPoint(x: 8, y: -6)]),
              fill: metal, in: n)
        circle(5, at: CGPoint(x: -12, y: 0), fill: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1),
               stroke: UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), in: n)
        rect(CGSize(width: 6, height: 16), at: CGPoint(x: 8, y: 0), corner: 2, fill: metal.darker(0.2), in: n)
        return n
    }

    static func gearCoinMagnet() -> SKNode {
        let n = SKNode()
        let horseshoe = CGMutablePath()
        horseshoe.addArc(center: .zero, radius: 8, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
        let h = SKShapeNode(path: horseshoe)
        h.strokeColor = UIColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)
        h.lineWidth = 5; h.lineCap = .butt; h.fillColor = .clear
        n.addChild(h)
        rect(CGSize(width: 5, height: 5), at: CGPoint(x: -7.2, y: 0.5), fill: UIColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1), stroke: .clear, in: n)
        rect(CGSize(width: 5, height: 5), at: CGPoint(x: 7.2, y: 0.5), fill: UIColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1), stroke: .clear, in: n)
        return n
    }

    static func gearLuckyHorseshoe() -> SKNode {
        let n = SKNode()
        let gold = UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1)
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: 8, startAngle: -.pi * 0.9, endAngle: .pi * 0.9, clockwise: false)
        let h = SKShapeNode(path: p)
        h.strokeColor = gold; h.lineWidth = 4.5; h.fillColor = .clear; h.lineCap = .round
        n.addChild(h)
        for a in [-0.9, 0.9] {                                     // nail holes
            circle(1.2, at: CGPoint(x: cos(CGFloat(a) * .pi) * 8, y: sin(CGFloat(a) * .pi) * 8),
                   fill: gold.darker(0.35), stroke: .clear, in: n)
        }
        return n
    }

    static func gearBarnaclePlate() -> SKNode {
        let n = SKNode()
        let plate = UIColor(red: 0.55, green: 0.6, blue: 0.62, alpha: 1)
        rect(CGSize(width: 22, height: 14), at: .zero, corner: 3, fill: plate, in: n)
        for (dx, dy, r) in [(-6.0, 3.0, 3.5), (2.0, -2.0, 4.0), (7.0, 4.0, 2.8)] {
            circle(CGFloat(r), at: CGPoint(x: CGFloat(dx), y: CGFloat(dy)),
                   fill: UIColor(red: 0.9, green: 0.89, blue: 0.85, alpha: 1), in: n)
            circle(CGFloat(r) * 0.4, at: CGPoint(x: CGFloat(dx), y: CGFloat(dy)),
                   fill: plate.darker(0.25), stroke: .clear, in: n)
        }
        return n
    }

    // MARK: - Unlockable launchers (Core/Launchers.swift)
    // Each pairs a "tower" (drawn at the water line) with a "barrel" (rotated to the aim
    // angle, origin at the pivot) exactly like the lighthouse + cannon.

    /// Rod holder wedged in the sand.
    static func rodStand() -> SKNode {
        let n = SKNode()
        let wood = UIColor(red: 0.55, green: 0.4, blue: 0.26, alpha: 1)
        shape(polygon([CGPoint(x: 18, y: 0), CGPoint(x: 62, y: 0), CGPoint(x: 56, y: 96), CGPoint(x: 30, y: 96)]),
              fill: wood, in: n)
        rect(CGSize(width: 52, height: 10), at: CGPoint(x: 42, y: 92), corner: 4, fill: wood.darker(0.15), in: n)
        rect(CGSize(width: 58, height: 14), at: CGPoint(x: 40, y: 6), corner: 6, fill: wood.darker(0.25), in: n)
        // a bucket of bait, because why not
        rect(CGSize(width: 26, height: 22), at: CGPoint(x: 92, y: 11), corner: 4,
             fill: UIColor(red: 0.3, green: 0.6, blue: 0.85, alpha: 1), in: n)
        return n
    }

    /// The rod itself: a long tapering blank with a reel at the butt.
    static func rodReel() -> SKNode {
        let n = SKNode()
        let blank = CGMutablePath()
        blank.move(to: CGPoint(x: 0, y: -3))
        blank.addLine(to: CGPoint(x: 96, y: -1))
        blank.addLine(to: CGPoint(x: 96, y: 1))
        blank.addLine(to: CGPoint(x: 0, y: 3))
        blank.closeSubpath()
        shape(blank, fill: UIColor(red: 0.2, green: 0.24, blue: 0.3, alpha: 1), lineWidth: 1.5, in: n)
        for x in [34, 58, 82] {                              // line guides
            circle(3.5, at: CGPoint(x: CGFloat(x), y: 4), fill: .clear,
                   stroke: UIColor(red: 0.8, green: 0.82, blue: 0.9, alpha: 1), lineWidth: 1.5, in: n)
        }
        circle(11, at: CGPoint(x: 6, y: -9), fill: UIColor(red: 0.75, green: 0.2, blue: 0.2, alpha: 1), in: n)
        circle(4, at: CGPoint(x: 6, y: -9), fill: UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1), stroke: .clear, in: n)
        circle(5, at: CGPoint(x: 98, y: 0), fill: UIColor(red: 0.95, green: 0.85, blue: 0.3, alpha: 1), in: n)  // the lure
        return n
    }

    /// Two posts sunk into the shallows.
    static func slingPost() -> SKNode {
        let n = SKNode()
        let wood = UIColor(red: 0.48, green: 0.35, blue: 0.24, alpha: 1)
        for dx in [22, 74] {
            rect(CGSize(width: 16, height: 84), at: CGPoint(x: CGFloat(dx), y: 42), corner: 5, fill: wood, in: n)
            circle(9, at: CGPoint(x: CGFloat(dx), y: 84), fill: wood.darker(0.18), in: n)
        }
        rect(CGSize(width: 74, height: 10), at: CGPoint(x: 48, y: 8), corner: 4, fill: wood.darker(0.28), in: n)
        return n
    }

    /// The pouch and band, drawn along +x so the barrel rotation points it at the aim angle.
    static func slingshot() -> SKNode {
        let n = SKNode()
        let band = UIColor(red: 0.25, green: 0.2, blue: 0.2, alpha: 1)
        for dy in [16, -16] {                                 // the two rubber bands
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -14, y: CGFloat(dy)))
            p.addLine(to: CGPoint(x: 58, y: 0))
            let b = SKShapeNode(path: p)
            b.strokeColor = band; b.lineWidth = 4; b.lineCap = .round
            n.addChild(b)
        }
        rect(CGSize(width: 20, height: 26), at: CGPoint(x: 62, y: 0), corner: 6,
             fill: UIColor(red: 0.6, green: 0.42, blue: 0.3, alpha: 1), in: n)   // pouch
        return n
    }

    /// A rusted launch cradle sitting right on the water.
    static func torpedoRig() -> SKNode {
        let n = SKNode()
        let rust = UIColor(red: 0.45, green: 0.35, blue: 0.3, alpha: 1)
        shape(polygon([CGPoint(x: 6, y: 0), CGPoint(x: 96, y: 0), CGPoint(x: 86, y: 40), CGPoint(x: 18, y: 40)]),
              fill: rust, in: n)
        rect(CGSize(width: 90, height: 10), at: CGPoint(x: 51, y: 5), corner: 3, fill: rust.darker(0.2), in: n)
        for dx in [30, 52, 74] {
            circle(4, at: CGPoint(x: CGFloat(dx), y: 26), fill: UIColor(red: 0.8, green: 0.75, blue: 0.5, alpha: 1), stroke: .clear, in: n)
        }
        return n
    }

    /// The tube: wide, blunt and low.
    static func torpedoTube() -> SKNode {
        let n = SKNode()
        let metal = UIColor(red: 0.42, green: 0.48, blue: 0.54, alpha: 1)
        rect(CGSize(width: 86, height: 30), at: CGPoint(x: 42, y: 0), corner: 12, fill: metal, in: n)
        circle(15, at: CGPoint(x: 84, y: 0), fill: UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1),
               stroke: metal.lighter(0.15), lineWidth: 3, in: n)
        for x in [22, 44, 66] {                               // banding
            rect(CGSize(width: 4, height: 32), at: CGPoint(x: CGFloat(x), y: 0), corner: 2,
                 fill: metal.darker(0.2), stroke: .clear, in: n)
        }
        rect(CGSize(width: 18, height: 12), at: CGPoint(x: 6, y: 18), corner: 4,
             fill: UIColor(red: 0.85, green: 0.6, blue: 0.2, alpha: 1), in: n)   // valve wheel housing
        return n
    }

    /// Small trophy used on the achievements board.
    static func trophyIcon() -> SKNode {
        let n = SKNode()
        let gold = UIColor(red: 1, green: 0.82, blue: 0.28, alpha: 1)
        shape(polygon([CGPoint(x: -7, y: 8), CGPoint(x: 7, y: 8), CGPoint(x: 4, y: -3), CGPoint(x: -4, y: -3)]), fill: gold, in: n)
        rect(CGSize(width: 12, height: 3), at: CGPoint(x: 0, y: -6), corner: 1.5, fill: gold.darker(0.2), in: n)
        rect(CGSize(width: 4, height: 4), at: CGPoint(x: 0, y: -3), corner: 1, fill: gold.darker(0.1), stroke: .clear, in: n)
        for dx in [-9, 9] {
            circle(3.5, at: CGPoint(x: CGFloat(dx), y: 6), fill: .clear, stroke: gold, lineWidth: 2, in: n)
        }
        return n
    }


    // MARK: - Smashables and the high air

    /// One brick of a breakable wall. Three tiers, chosen by toughness in `WorldEntity`, so a
    /// wall's difficulty reads at a glance from across the bay. All drawn 64x64, origin centred.
    private static func brick(face: UIColor, mortar: UIColor, studs: Bool) -> SKNode {
        let n = SKNode()
        let s = Tuning.barrierBlockSize
        rect(CGSize(width: s, height: s), corner: 4, fill: face, stroke: mortar, lineWidth: 3, in: n)
        // two courses of masonry, offset
        rect(CGSize(width: s - 10, height: 2.5), at: CGPoint(x: 0, y: 0), corner: 1,
             fill: mortar.withAlphaComponent(0.8), stroke: .clear, in: n)
        rect(CGSize(width: 2.5, height: s / 2 - 6), at: CGPoint(x: 0, y: s / 4 + 1), corner: 1,
             fill: mortar.withAlphaComponent(0.8), stroke: .clear, in: n)
        rect(CGSize(width: 2.5, height: s / 2 - 6), at: CGPoint(x: -s / 4, y: -s / 4 - 1), corner: 1,
             fill: mortar.withAlphaComponent(0.8), stroke: .clear, in: n)
        rect(CGSize(width: 2.5, height: s / 2 - 6), at: CGPoint(x: s / 4, y: -s / 4 - 1), corner: 1,
             fill: mortar.withAlphaComponent(0.8), stroke: .clear, in: n)
        if studs {
            for p in [CGPoint(x: -s / 2 + 8, y: s / 2 - 8), CGPoint(x: s / 2 - 8, y: s / 2 - 8),
                      CGPoint(x: -s / 2 + 8, y: -s / 2 + 8), CGPoint(x: s / 2 - 8, y: -s / 2 + 8)] {
                circle(3.2, at: p, fill: face.lighter(0.18), stroke: mortar, lineWidth: 1, in: n)
            }
        }
        return n
    }

    static func barrierWood() -> SKNode {
        brick(face: UIColor(red: 0.62, green: 0.44, blue: 0.27, alpha: 1),
              mortar: UIColor(red: 0.38, green: 0.26, blue: 0.15, alpha: 1), studs: false)
    }

    static func barrierStone() -> SKNode {
        brick(face: UIColor(red: 0.62, green: 0.63, blue: 0.66, alpha: 1),
              mortar: UIColor(red: 0.38, green: 0.39, blue: 0.43, alpha: 1), studs: false)
    }

    static func barrierIron() -> SKNode {
        brick(face: UIColor(red: 0.40, green: 0.44, blue: 0.52, alpha: 1),
              mortar: UIColor(red: 0.20, green: 0.23, blue: 0.29, alpha: 1), studs: true)
    }

    /// Floating supply crate, ~44 square. Always breakable — it teaches the smash before the
    /// first real wall shows up.
    static func crate() -> SKNode {
        let n = SKNode()
        let wood = UIColor(red: 0.78, green: 0.58, blue: 0.33, alpha: 1)
        rect(CGSize(width: 44, height: 40), corner: 3, fill: wood, in: n)
        for pts in [[CGPoint(x: -20, y: -17), CGPoint(x: 20, y: 17)],
                    [CGPoint(x: -20, y: 17), CGPoint(x: 20, y: -17)]] {
            let p = CGMutablePath()
            p.move(to: pts[0]); p.addLine(to: pts[1])
            let brace = SKShapeNode(path: p)
            brace.strokeColor = wood.darker(0.22); brace.lineWidth = 4
            n.addChild(brace)
        }
        rect(CGSize(width: 46, height: 5), at: CGPoint(x: 0, y: 17), corner: 2, fill: wood.darker(0.15), in: n)
        rect(CGSize(width: 46, height: 5), at: CGPoint(x: 0, y: -17), corner: 2, fill: wood.darker(0.15), in: n)
        return n
    }

    /// Blimp, ~150 wide. A trampoline you only meet if you get up there.
    static func blimp() -> SKNode {
        let n = SKNode()
        let skin = UIColor(red: 0.95, green: 0.55, blue: 0.35, alpha: 1)
        let hull = SKShapeNode(ellipseOf: CGSize(width: 150, height: 66))
        hull.fillColor = skin
        hull.strokeColor = skin.darker(0.25)
        hull.lineWidth = 3
        n.addChild(hull)
        rect(CGSize(width: 150, height: 9), at: .zero, corner: 4, fill: UIColor(red: 0.98, green: 0.85, blue: 0.4, alpha: 1), stroke: .clear, in: n)
        // tail fins
        shape(polygon([CGPoint(x: -66, y: 0), CGPoint(x: -88, y: 24), CGPoint(x: -84, y: 0)]), fill: skin.darker(0.12), in: n)
        shape(polygon([CGPoint(x: -66, y: 0), CGPoint(x: -88, y: -24), CGPoint(x: -84, y: 0)]), fill: skin.darker(0.12), in: n)
        // gondola
        rect(CGSize(width: 44, height: 18), at: CGPoint(x: 4, y: -40), corner: 6,
             fill: UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1), in: n)
        for dx in [-14, 14] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: CGFloat(dx) + 4, y: -31))
            p.addLine(to: CGPoint(x: CGFloat(dx) + 4, y: -26))
            let line = SKShapeNode(path: p)
            line.strokeColor = UIColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1); line.lineWidth = 2
            n.addChild(line)
        }
        for dx in [-12, 12] {
            circle(4, at: CGPoint(x: CGFloat(dx) + 4, y: -40), fill: UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 1), stroke: .clear, in: n)
        }
        return n
    }

    /// Boost ring, ~92 across. Drawn as a torus seen slightly side-on so flying "through" reads.
    static func boostRing() -> SKNode {
        let n = SKNode()
        let outer = SKShapeNode(ellipseOf: CGSize(width: 62, height: 92))
        outer.fillColor = .clear
        outer.strokeColor = UIColor(red: 0.3, green: 0.95, blue: 0.75, alpha: 1)
        outer.lineWidth = 9
        n.addChild(outer)
        let inner = SKShapeNode(ellipseOf: CGSize(width: 62, height: 92))
        inner.fillColor = .clear
        inner.strokeColor = UIColor(red: 0.85, green: 1, blue: 0.95, alpha: 0.9)
        inner.lineWidth = 3
        n.addChild(inner)
        for dy in [-46, 46] {
            shape(polygon([CGPoint(x: -14, y: CGFloat(dy)), CGPoint(x: 0, y: CGFloat(dy) + (dy > 0 ? 14 : -14)), CGPoint(x: 14, y: CGFloat(dy))]),
                  fill: UIColor(red: 0.98, green: 1, blue: 0.6, alpha: 1), stroke: .clear, in: n)
        }
        return n
    }

    /// Jet stream: a wide band of streaked wind, ~340 across.
    static func jetStream() -> SKNode {
        let n = SKNode()
        let band = SKShapeNode(ellipseOf: CGSize(width: 340, height: 150))
        band.fillColor = UIColor(red: 0.75, green: 0.92, blue: 1, alpha: 0.16)
        band.strokeColor = UIColor(red: 0.8, green: 0.96, blue: 1, alpha: 0.35)
        band.lineWidth = 2
        n.addChild(band)
        var seed: UInt32 = 8081
        for i in 0..<9 {
            seed = seed &* 1103515245 &+ 12345
            let y = CGFloat(Int(seed % 110)) - 55
            let w = 70 + CGFloat((seed >> 9) % 120)
            let streak = SKShapeNode(rectOf: CGSize(width: w, height: 3), cornerRadius: 1.5)
            streak.fillColor = UIColor.white.withAlphaComponent(0.55)
            streak.strokeColor = .clear
            streak.position = CGPoint(x: CGFloat(i - 4) * 34, y: y)
            n.addChild(streak)
            // an arrowhead on the longer streaks, so the direction is unmistakable
            if w > 140 {
                shape(polygon([CGPoint(x: w / 2, y: y + 6), CGPoint(x: w / 2 + 12, y: y), CGPoint(x: w / 2, y: y - 6)]),
                      fill: UIColor.white.withAlphaComponent(0.6), stroke: .clear, in: n)
            }
        }
        return n
    }

    /// Wispy cirrus for the high cloud deck, ~260 wide.
    static func cirrus() -> SKNode {
        let n = SKNode()
        var seed: UInt32 = 4242
        for i in 0..<5 {
            seed = seed &* 1103515245 &+ 12345
            let w = 90 + CGFloat(seed % 150)
            let y = CGFloat(Int((seed >> 7) % 40)) - 20
            let streak = SKShapeNode(rectOf: CGSize(width: w, height: 6 + CGFloat((seed >> 12) % 6)), cornerRadius: 4)
            streak.fillColor = UIColor.white.withAlphaComponent(0.5)
            streak.strokeColor = .clear
            streak.position = CGPoint(x: CGFloat(i - 2) * 46, y: y)
            n.addChild(streak)
        }
        return n
    }

    static func missing() -> SKNode {
        let n = SKNode()
        rect(CGSize(width: 24, height: 24), fill: .magenta, in: n)
        return n
    }
}

// MARK: - UIColor helpers

extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor { adjusted(by: -amount) }
    func lighter(_ amount: CGFloat) -> UIColor { adjusted(by: amount) }

    private func adjusted(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        return UIColor(red: clamp(r + amount, 0, 1), green: clamp(g + amount, 0, 1), blue: clamp(b + amount, 0, 1), alpha: a)
    }

    func mixed(with other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: lerp(r1, r2, t), green: lerp(g1, g2, t), blue: lerp(b1, b2, t), alpha: lerp(a1, a2, t))
    }
}
