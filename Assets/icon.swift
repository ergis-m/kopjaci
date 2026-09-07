// Placeholder app icon: indigo squircle with the clipboard symbol. Run via `make icon`.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = out.appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: CGFloat) -> Data {
    let img = NSImage(size: NSSize(width: px, height: px), flipped: false) { _ in
        let inset = px * 0.1                                    // macOS icons leave ~10% margin
        let rect = NSRect(x: inset, y: inset, width: px - 2 * inset, height: px - 2 * inset)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
        NSShadow().apply { $0.shadowBlurRadius = px * 0.02; $0.shadowOffset = NSSize(width: 0, height: -px * 0.01); $0.shadowColor = .black.withAlphaComponent(0.35) }
        NSGradient(starting: NSColor(red: 0.42, green: 0.36, blue: 0.95, alpha: 1), ending: NSColor(red: 0.22, green: 0.16, blue: 0.62, alpha: 1))!
            .draw(in: path, angle: -60)
        let cfg = NSImage.SymbolConfiguration(pointSize: rect.width * 0.5, weight: .medium).applying(.init(paletteColors: [.white]))
        let sym = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
        let s = sym.size, k = rect.width * 0.55 / max(s.width, s.height)
        let sz = NSSize(width: s.width * k, height: s.height * k)
        sym.draw(in: NSRect(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2, width: sz.width, height: sz.height),
                 from: .zero, operation: .sourceOver, fraction: 1)
        return true
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

extension NSShadow { func apply(_ f: (NSShadow) -> Void) { f(self); set() } }

for base in [16, 32, 128, 256, 512] {
    try! render(CGFloat(base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(CGFloat(base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
