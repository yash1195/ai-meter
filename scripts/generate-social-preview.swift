import AppKit

let arguments = CommandLine.arguments.dropFirst()
let iconURL = URL(fileURLWithPath: arguments.first ?? "Resources/AppIcon-1024.png")
let outputURL = URL(fileURLWithPath: arguments.dropFirst().first ?? "website/public/og-image.png")
let width = 1200
let height = 630

guard
    let icon = NSImage(contentsOf: iconURL),
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    fatalError("Unable to create social preview")
}
bitmap.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(colors: [
    NSColor(calibratedRed: 0.13, green: 0.145, blue: 0.175, alpha: 1),
    NSColor(calibratedRed: 0.025, green: 0.03, blue: 0.038, alpha: 1),
])?.draw(in: canvas, angle: -35)

let accent = NSColor(calibratedRed: 0.72, green: 0.96, blue: 0.34, alpha: 1)
accent.setFill()
NSBezierPath(
    roundedRect: NSRect(x: 72, y: 552, width: 128, height: 7),
    xRadius: 3.5,
    yRadius: 3.5
).fill()

icon.draw(
    in: NSRect(x: 76, y: 115, width: 400, height: 400),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)

let left = 540.0
("AI METER" as NSString).draw(
    in: NSRect(x: left, y: 372, width: 590, height: 100),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 72, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1),
        .kern: -3.2,
    ]
)

("Measure your AI. Locally." as NSString).draw(
    in: NSRect(x: left, y: 300, width: 590, height: 52),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.76, alpha: 1),
        .kern: -0.8,
    ]
)

("Codex + Claude Code usage, electricity, and water estimates—all on your Mac." as NSString).draw(
    with: NSRect(x: left, y: 205, width: 555, height: 74),
    options: [.usesLineFragmentOrigin, .usesFontLeading],
    attributes: [
        .font: NSFont.systemFont(ofSize: 21, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.54, alpha: 1),
    ]
)

("LOCAL  ·  PRIVATE  ·  macOS" as NSString).draw(
    in: NSRect(x: left, y: 112, width: 555, height: 28),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
        .foregroundColor: accent,
        .kern: 1.2,
    ]
)

("ai-meter.app" as NSString).draw(
    in: NSRect(x: left, y: 66, width: 555, height: 26),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.48, alpha: 1),
    ]
)

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode social preview")
}
try png.write(to: outputURL)
