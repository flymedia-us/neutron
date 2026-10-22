import AppKit

// Adapted from Fly Media AppleTree's AppKit DMG background renderer (GPLv3).
// Window points and icon centers match settings.py. Output is temporary build data.
let size = NSSize(width: 660, height: 400)
guard CommandLine.arguments.count == 2 else { fatalError("Pass an output directory") }
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

func text(_ value: String, y: CGFloat, font: NSFont, color: NSColor) {
    let string = value as NSString
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    string.draw(at: NSPoint(x: (size.width - string.size(withAttributes: attributes).width) / 2, y: y),
                withAttributes: attributes)
}

func draw() {
    let bounds = NSRect(origin: .zero, size: size)
    NSGradient(starting: NSColor(srgbRed: 0.075, green: 0.10, blue: 0.16, alpha: 1),
               ending: NSColor(srgbRed: 0.035, green: 0.045, blue: 0.075, alpha: 1))!
        .draw(in: bounds, angle: -90)
    // Quiet orbital contours carry Neutron's icon motif into the window edges.
    for angle: CGFloat in [-28, 28] {
        let orbit = NSBezierPath(ovalIn: NSRect(x: -210, y: -78, width: 420, height: 156))
        let transform = AffineTransform(translationByX: 620, byY: 16)
        var rotation = AffineTransform()
        rotation.rotate(byDegrees: angle)
        orbit.transform(using: rotation)
        orbit.transform(using: transform)
        orbit.lineWidth = 1.5
        NSColor(srgbRed: 0.38, green: 0.69, blue: 1, alpha: 0.12).setStroke()
        orbit.stroke()
    }
    text("Neutron", y: 344, font: .systemFont(ofSize: 30, weight: .semibold), color: .white)
    text("Your Steam games. Now on Mac.", y: 320, font: .systemFont(ofSize: 13),
         color: NSColor(calibratedWhite: 0.70, alpha: 1))
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 314, y: 230))
    arrow.line(to: NSPoint(x: 336, y: 210))
    arrow.line(to: NSPoint(x: 314, y: 190))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(srgbRed: 0.48, green: 0.75, blue: 1, alpha: 0.8).setStroke()
    arrow.stroke()
    text("Drag Neutron to Applications", y: 80, font: .systemFont(ofSize: 15, weight: .medium),
         color: NSColor(calibratedWhite: 0.93, alpha: 1))
    text("Then open Neutron from Applications to get started.", y: 56, font: .systemFont(ofSize: 12),
         color: NSColor(calibratedWhite: 0.62, alpha: 1))
    text("Apple silicon  ·  macOS 15 or later", y: 22, font: .systemFont(ofSize: 11),
         color: NSColor(calibratedWhite: 0.42, alpha: 1))
}

for scale: CGFloat in [1, 2] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let url = output.appendingPathComponent("background\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    if scale == 2 {
        let sips = Process()
        sips.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        sips.arguments = ["-s", "dpiWidth", "144", "-s", "dpiHeight", "144", url.path]
        try sips.run()
        sips.waitUntilExit()
        guard sips.terminationStatus == 0 else { fatalError("Could not set Retina image density") }
    }
}
