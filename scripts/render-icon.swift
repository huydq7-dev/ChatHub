import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func bubble(_ rect: NSRect, tailOnLeft: Bool) -> NSBezierPath {
    let path = NSBezierPath(roundedRect: rect, xRadius: 58, yRadius: 58)
    let tail = NSBezierPath()
    let x = tailOnLeft ? rect.minX + 32 : rect.maxX - 32
    tail.move(to: NSPoint(x: x, y: rect.minY + 32))
    tail.line(to: NSPoint(x: tailOnLeft ? x - 8 : x + 8, y: rect.minY - 48))
    tail.line(to: NSPoint(x: tailOnLeft ? x + 95 : x - 95, y: rect.minY + 5))
    tail.close()
    path.append(tail)
    return path
}

func render(pixels: Int, filename: String) throws {
    let image = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()
    let rect = NSRect(x: 90, y: 90, width: 844, height: 844)
    let background = NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190)
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.23)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(red: 0.40, green: 0.32, blue: 0.84, alpha: 1).setFill()
    background.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [
        NSColor(red: 0.34, green: 0.24, blue: 0.73, alpha: 1),
        NSColor(red: 0.56, green: 0.43, blue: 0.96, alpha: 1),
    ])!.draw(in: background, angle: 75)
    NSColor.white.withAlphaComponent(0.35).setFill()
    bubble(NSRect(x: 450, y: 330, width: 330, height: 270), tailOnLeft: false).fill()
    NSColor.white.setFill()
    bubble(NSRect(x: 246, y: 444, width: 370, height: 290), tailOnLeft: true).fill()
    NSGraphicsContext.restoreGraphicsState()
    try image.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
}

for pointSize in [16, 32, 128, 256, 512] {
    try render(pixels: pointSize, filename: "icon_\(pointSize)x\(pointSize).png")
    try render(pixels: pointSize * 2, filename: "icon_\(pointSize)x\(pointSize)@2x.png")
}
