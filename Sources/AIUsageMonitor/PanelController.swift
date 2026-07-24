import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel

    init(model: UsageViewModel, updateChecker: UpdateChecker) {
        let rootView = UsagePanelView(toggleFloatingPanel: nil)
            .environmentObject(model)
            .environmentObject(updateChecker)
        let hostingController = NSHostingController(rootView: rootView)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 720),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.title = "AI Meter"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.setFrameAutosaveName("AIUsageFloatingPanel")
        super.init()
        panel.delegate = self
    }

    func show() {
        if !UserDefaults.standard.bool(forKey: "didPlaceAIUsagePanelV2") {
            moveToCurrentScreen()
            UserDefaults.standard.set(true, forKey: "didPlaceAIUsagePanelV2")
        } else {
            ensureVisible()
        }
        panel.orderFrontRegardless()
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func moveToCurrentScreen() {
        guard let screen = preferredScreen() else { return }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    private func ensureVisible() {
        let isVisibleOnCurrentScreen = NSScreen.screens.contains { screen in
            let intersection = panel.frame.intersection(screen.visibleFrame)
            return intersection.width >= 120 && intersection.height >= 120
        }
        if !isVisibleOnCurrentScreen {
            moveToCurrentScreen()
        }
    }

    private func preferredScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}
