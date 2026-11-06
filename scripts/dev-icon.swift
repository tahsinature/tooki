import AppKit

// Adds a development badge while preserving the original icon used by releases.
guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: swift scripts/dev-icon.swift <source.png> <output.iconset>")
}
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func writeIcon(points: Int, scale: Int) throws {
    let pixels = points * scale
    let size = CGFloat(pixels)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Cannot create development icon")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    source.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

    let badge = NSRect(x: size * 0.44, y: size * 0.08, width: size * 0.51, height: size * 0.23)
    let pill = NSBezierPath(roundedRect: badge, xRadius: badge.height / 2, yRadius: badge.height / 2)
    NSColor(calibratedRed: 1, green: 0.62, blue: 0.16, alpha: 1).setFill()
    pill.fill()
    NSColor(calibratedWhite: 0.07, alpha: 1).setStroke()
    pill.lineWidth = size * 0.018
    pill.stroke()

    let title = NSAttributedString(string: "DEV", attributes: [
        .font: NSFont.systemFont(ofSize: size * 0.135, weight: .black),
        .foregroundColor: NSColor(calibratedWhite: 0.07, alpha: 1),
        .kern: size * 0.006,
    ])
    let textSize = title.size()
    title.draw(at: NSPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode development icon")
    }
    let suffix = scale == 2 ? "@2x" : ""
    try png.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}

for points in [16, 32, 128, 256, 512] {
    try writeIcon(points: points, scale: 1)
    try writeIcon(points: points, scale: 2)
}
