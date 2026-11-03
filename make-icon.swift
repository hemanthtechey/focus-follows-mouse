// Renders AppIcon.icns: a window frame with a pointer resting on it, on a teal squircle.
// Usage: swift make-icon.swift <out-dir>   (build.sh calls this)
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconset = "\(out)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// Classic pointer in a 0...1 box, y pointing down.
let arrow: [CGPoint] = [(0, 0), (0, 0.74), (0.18, 0.58), (0.31, 0.88), (0.44, 0.82), (0.31, 0.53), (0.54, 0.53)].map { CGPoint(x: $0.0, y: $0.1) }

func draw(_ s: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.translateBy(x: 0, y: s); ctx.scaleBy(x: 1, y: -1)  // y down, like the arrow coordinates
    // squircle background on the macOS icon grid (824/1024 with 100 px margin)
    let inset = s * 100 / 1024, side = s - inset * 2
    let bg = CGPath(roundedRect: CGRect(x: inset, y: inset, width: side, height: side), cornerWidth: side * 0.225, cornerHeight: side * 0.225, transform: nil)
    ctx.saveGState(); ctx.addPath(bg); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 0.05, green: 0.46, blue: 0.43, alpha: 1), CGColor(red: 0.02, green: 0.20, blue: 0.22, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: inset, y: inset), end: CGPoint(x: inset + side, y: inset + side), options: [])
    ctx.restoreGState()
    // window frame with title-bar dots
    let u = side / 100
    let win = CGRect(x: inset + 16 * u, y: inset + 20 * u, width: 60 * u, height: 46 * u)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.9)); ctx.setLineWidth(3.2 * u)
    ctx.addPath(CGPath(roundedRect: win, cornerWidth: 6 * u, cornerHeight: 6 * u, transform: nil)); ctx.strokePath()
    ctx.move(to: CGPoint(x: win.minX, y: win.minY + 11 * u)); ctx.addLine(to: CGPoint(x: win.maxX, y: win.minY + 11 * u)); ctx.strokePath()
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
    for i in 0..<3 { ctx.fillEllipse(in: CGRect(x: win.minX + (5 + CGFloat(i) * 6) * u, y: win.minY + 3.5 * u, width: 4 * u, height: 4 * u)) }
    // text caret inside the window: "keyboard goes here"
    ctx.setFillColor(CGColor(red: 0.55, green: 0.95, blue: 0.85, alpha: 1))
    ctx.fill(CGRect(x: win.minX + 10 * u, y: win.minY + 19 * u, width: 3 * u, height: 16 * u))
    // pointer, with a soft shadow, resting on the window's lower-right corner
    let a = CGMutablePath(), origin = CGPoint(x: inset + 52 * u, y: inset + 44 * u), size = 44 * u
    a.addLines(between: arrow.map { CGPoint(x: origin.x + $0.x * size, y: origin.y + $0.y * size) }); a.closeSubpath()
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: 2 * u), blur: 6 * u, color: CGColor(gray: 0, alpha: 0.45))
    ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.addPath(a); ctx.fillPath(); ctx.restoreGState()
    ctx.setStrokeColor(CGColor(gray: 0.08, alpha: 1)); ctx.setLineWidth(2.2 * u); ctx.setLineJoin(.round); ctx.addPath(a); ctx.strokePath()
}

for (pt, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = pt * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}
let p = Process(); p.launchPath = "/usr/bin/iconutil"; p.arguments = ["-c", "icns", iconset, "-o", "\(out)/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconset)
