// Renders a placeholder 1024×1024 app icon (sky, bay, lighthouse, Marlow's dinghy).
// Run: swift Tools/make_icon.swift   → writes BayBlaster/Assets.xcassets/AppIcon.appiconset/AppIcon.png
// Replace with real art whenever; keep the filename or update Contents.json.
import AppKit

let size = 1024.0
// Plain CGContext at exactly 1024 px, opaque (App Store icons must be 1024×1024 with no alpha).
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }

// Sky gradient
let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                     colors: [rgb(0.42, 0.72, 0.98), rgb(0.70, 0.88, 1.0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 380), options: [])

// Sun
ctx.setFillColor(rgb(1.0, 0.92, 0.45))
ctx.fillEllipse(in: CGRect(x: 700, y: 700, width: 180, height: 180))

// Far hills
ctx.setFillColor(rgb(0.45, 0.66, 0.55))
for (x, w, h) in [(-100.0, 500.0, 260.0), (350.0, 520.0, 300.0), (760.0, 480.0, 240.0)] {
    ctx.fillEllipse(in: CGRect(x: x, y: 300, width: w, height: h))
}

// Water
ctx.setFillColor(rgb(0.13, 0.42, 0.78))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: 400))
ctx.setFillColor(rgb(0.55, 0.80, 0.98))
ctx.fill(CGRect(x: 0, y: 392, width: size, height: 14))
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
ctx.setLineWidth(8)
for (x, y, w) in [(80.0, 300.0, 120.0), (420.0, 240.0, 160.0), (760.0, 320.0, 110.0), (250.0, 120.0, 140.0), (640.0, 150.0, 120.0)] {
    ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + w, y: y)); ctx.strokePath()
}

// Lighthouse (left)
ctx.setFillColor(rgb(0.45, 0.45, 0.5))
ctx.fillEllipse(in: CGRect(x: 60, y: 330, width: 300, height: 140))
let towerX = 150.0, towerW = 120.0, towerBottom = 400.0, towerTop = 780.0
let tower = CGMutablePath()
tower.move(to: CGPoint(x: towerX, y: towerBottom))
tower.addLine(to: CGPoint(x: towerX + towerW, y: towerBottom))
tower.addLine(to: CGPoint(x: towerX + towerW - 25, y: towerTop))
tower.addLine(to: CGPoint(x: towerX + 25, y: towerTop))
tower.closeSubpath()
ctx.setFillColor(rgb(0.97, 0.96, 0.92)); ctx.addPath(tower); ctx.fillPath()
ctx.saveGState(); ctx.addPath(tower); ctx.clip()
ctx.setFillColor(rgb(0.85, 0.2, 0.22))
for y in stride(from: 440.0, to: towerTop, by: 130) { ctx.fill(CGRect(x: towerX - 10, y: y, width: towerW + 20, height: 60)) }
ctx.restoreGState()
ctx.setFillColor(rgb(0.2, 0.2, 0.25)); ctx.fill(CGRect(x: towerX + 10, y: towerTop, width: towerW - 20, height: 50))
ctx.setFillColor(rgb(1.0, 0.95, 0.5)); ctx.fill(CGRect(x: towerX + 25, y: towerTop + 50, width: towerW - 50, height: 55))
ctx.setFillColor(rgb(0.85, 0.2, 0.22))
let roof = CGMutablePath()
roof.move(to: CGPoint(x: towerX + 5, y: towerTop + 105)); roof.addLine(to: CGPoint(x: towerX + towerW - 5, y: towerTop + 105))
roof.addLine(to: CGPoint(x: towerX + towerW / 2, y: towerTop + 175)); roof.closeSubpath()
ctx.addPath(roof); ctx.fillPath()

// Dinghy (centre-right), tilted as if mid-skip
ctx.saveGState()
ctx.translateBy(x: 620, y: 470)
ctx.rotate(by: 0.28)
let hull = CGMutablePath()
hull.move(to: CGPoint(x: -190, y: 40))
hull.addLine(to: CGPoint(x: 210, y: 40))
hull.addLine(to: CGPoint(x: 150, y: -70))
hull.addLine(to: CGPoint(x: -140, y: -70))
hull.closeSubpath()
ctx.setFillColor(rgb(0.92, 0.28, 0.2)); ctx.addPath(hull); ctx.fillPath()
ctx.setFillColor(rgb(0.6, 0.4, 0.25)); ctx.fill(CGRect(x: -150, y: 40, width: 320, height: 22))
ctx.setFillColor(rgb(1, 1, 1)); ctx.fill(CGRect(x: -120, y: -10, width: 200, height: 18))
// Marlow: fish body + eye
ctx.setFillColor(rgb(0.25, 0.68, 0.85))
ctx.fillEllipse(in: CGRect(x: -80, y: 60, width: 200, height: 110))
let tail = CGMutablePath()
tail.move(to: CGPoint(x: -70, y: 115)); tail.addLine(to: CGPoint(x: -140, y: 165)); tail.addLine(to: CGPoint(x: -140, y: 65)); tail.closeSubpath()
ctx.addPath(tail); ctx.fillPath()
ctx.setFillColor(rgb(1, 1, 1)); ctx.fillEllipse(in: CGRect(x: 55, y: 100, width: 40, height: 40))
ctx.setFillColor(rgb(0.05, 0.05, 0.1)); ctx.fillEllipse(in: CGRect(x: 68, y: 108, width: 20, height: 20))
ctx.restoreGState()

// Splash
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
for (x, y, r) in [(560.0, 400.0, 30.0), (610.0, 430.0, 22.0), (520.0, 420.0, 18.0), (660.0, 405.0, 16.0)] {
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

let cg = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: cg)
let png = rep.representation(using: .png, properties: [:])!
let out = URL(fileURLWithPath: "BayBlaster/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try! png.write(to: out)
print("wrote \(out.path) \(cg.width)x\(cg.height) alpha=\(cg.alphaInfo != .noneSkipLast && cg.alphaInfo != .none)")
