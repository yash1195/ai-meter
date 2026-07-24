import AppKit

@MainActor
enum WidgetScreenshotService {
    static func copyVisibleWidgetToClipboard() -> Bool {
        guard
            let window = targetWindow(),
            let view = window.contentView,
            let png = pngData(for: view)
        else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        return true
    }

    static func pngData(for view: NSView) -> Data? {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func targetWindow() -> NSWindow? {
        if let keyWindow = NSApplication.shared.keyWindow, keyWindow.isVisible {
            return keyWindow
        }
        return NSApplication.shared.orderedWindows.first { window in
            window.isVisible && window.contentView?.bounds.isEmpty == false
        }
    }
}
