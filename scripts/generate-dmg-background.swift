import AppKit

let outputURL = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dmg-background.png"
)
let width = 640
let height = 420

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width * 2,
    pixelsHigh: height * 2,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create DMG background bitmap")
}
bitmap.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.12, green: 0.135, blue: 0.16, alpha: 1),
    NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.05, alpha: 1),
])
gradient?.draw(in: canvas, angle: -55)

let accent = NSColor(calibratedRed: 0.72, green: 0.96, blue: 0.34, alpha: 1)
accent.setFill()
NSBezierPath(
    roundedRect: NSRect(x: 40, y: 376, width: 92, height: 5),
    xRadius: 2.5,
    yRadius: 2.5
).fill()

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
("INSTALL AI METER" as NSString).draw(
    in: NSRect(x: 40, y: 334, width: 560, height: 32),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1),
        .paragraphStyle: titleStyle,
        .kern: -0.6,
    ]
)

("Drag AI Meter into Applications" as NSString).draw(
    in: NSRect(x: 40, y: 306, width: 560, height: 24),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.68, alpha: 1),
        .paragraphStyle: titleStyle,
    ]
)

for cardX in [76.0, 364.0] {
    let cardRect = NSRect(x: cardX, y: 86, width: 200, height: 194)
    let card = NSBezierPath(roundedRect: cardRect, xRadius: 24, yRadius: 24)
    NSColor(calibratedWhite: 0.94, alpha: 0.96).setFill()
    card.fill()
    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    card.lineWidth = 2
    card.stroke()
}

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 268, y: 196))
arrow.line(to: NSPoint(x: 372, y: 196))
arrow.move(to: NSPoint(x: 350, y: 218))
arrow.line(to: NSPoint(x: 372, y: 196))
arrow.line(to: NSPoint(x: 350, y: 174))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
accent.setStroke()
arrow.stroke()

("LOCAL · PRIVATE · NOTARIZED" as NSString).draw(
    in: NSRect(x: 40, y: 33, width: 560, height: 18),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1),
        .paragraphStyle: titleStyle,
        .kern: 1.1,
    ]
)

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render DMG background")
}
try png.write(to: outputURL)
