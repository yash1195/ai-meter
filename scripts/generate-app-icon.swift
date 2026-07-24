import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png")
let size = NSSize(width: 1024, height: 1024)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create app icon bitmap")
}
bitmap.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let iconRect = NSRect(x: 62, y: 62, width: 900, height: 900)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 202, yRadius: 202)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.055, green: 0.06, blue: 0.075, alpha: 1),
])
background?.draw(in: iconPath, angle: -52)

NSColor(calibratedWhite: 1, alpha: 0.13).setStroke()
iconPath.lineWidth = 7
iconPath.stroke()

let accent = NSColor(calibratedRed: 0.72, green: 0.96, blue: 0.34, alpha: 1)
let accentPath = NSBezierPath()
accentPath.move(to: NSPoint(x: 166, y: 854))
accentPath.line(to: NSPoint(x: 352, y: 854))
accentPath.lineWidth = 14
accentPath.lineCapStyle = .round
accentPath.setLineDash([1, 0], count: 2, phase: 0)
accent.setStroke()
accentPath.stroke()

let waveform = NSBezierPath()
waveform.move(to: NSPoint(x: 202, y: 500))
waveform.line(to: NSPoint(x: 310, y: 500))
waveform.line(to: NSPoint(x: 372, y: 334))
waveform.line(to: NSPoint(x: 442, y: 688))
waveform.line(to: NSPoint(x: 510, y: 424))
waveform.line(to: NSPoint(x: 576, y: 574))
waveform.line(to: NSPoint(x: 640, y: 500))
waveform.line(to: NSPoint(x: 820, y: 500))
waveform.lineWidth = 42
waveform.lineCapStyle = .round
waveform.lineJoinStyle = .round
NSColor(calibratedWhite: 0.95, alpha: 1).setStroke()
waveform.stroke()

let statusDot = NSBezierPath(
    roundedRect: NSRect(x: 760, y: 744, width: 64, height: 64),
    xRadius: 15,
    yRadius: 15
)
accent.setFill()
statusDot.fill()

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render app icon")
}

try png.write(to: outputURL)
