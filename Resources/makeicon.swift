import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

/// The Sweep mark: three diagonal strokes, longest to shortest — the trail a sweep leaves.
/// Black tile, white glyph, hairline border. Straight lines only so it survives 16pt.
func draw(size: Int) -> Data? {
    let d = CGFloat(size)
    let image = NSImage(size: NSSize(width: d, height: d))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return nil }

    let inset = d * 0.085
    let rect = CGRect(x: inset, y: inset, width: d - inset * 2, height: d - inset * 2)
    let tile = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225,
                      cornerHeight: rect.width * 0.225, transform: nil)

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()

    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(rect)

    // Fractions are top-down; flip into AppKit's bottom-up space.
    func point(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * fx, y: rect.maxY - rect.height * fy)
    }

    ctx.setLineCap(.round)
    ctx.setLineWidth(rect.width * 0.085)

    let strokes: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.22, 0.76, 0.48, 0.24, 1.00),
        (0.47, 0.76, 0.67, 0.36, 0.66),
        (0.69, 0.76, 0.83, 0.48, 0.42)
    ]
    for (x1, y1, x2, y2, alpha) in strokes {
        ctx.setStrokeColor(NSColor(white: 0.93, alpha: alpha).cgColor)
        ctx.move(to: point(x1, y1))
        ctx.addLine(to: point(x2, y2))
        ctx.strokePath()
    }

    ctx.restoreGState()

    // Hairline edge keeps a black tile visible against a dark dock or wallpaper.
    ctx.addPath(tile)
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.22).cgColor)
    ctx.setLineWidth(max(1, d * 0.006))
    ctx.strokePath()

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    rep.size = NSSize(width: d, height: d)
    return rep.representation(using: .png, properties: [:])
}

for size in sizes {
    guard let data = draw(size: size) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    if size > 16 {
        try? data.write(to: URL(fileURLWithPath: "\(out)/icon_\(size / 2)x\(size / 2)@2x.png"))
    }
}
print("icons written to \(out)")
