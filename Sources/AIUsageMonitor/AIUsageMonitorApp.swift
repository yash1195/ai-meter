import AppKit
import SwiftUI

@main
struct AIUsageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            UsagePanelView(toggleFloatingPanel: appDelegate.togglePanel)
                .environmentObject(appDelegate.model)
                .environmentObject(appDelegate.updateChecker)
        } label: {
            MenuBarLabelView()
                .environmentObject(appDelegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    let model = UsageViewModel()
    let updateChecker = UpdateChecker()
    private lazy var panelController = PanelController(model: model, updateChecker: updateChecker)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
        updateChecker.start()
    }

    func togglePanel() {
        panelController.toggle()
    }

    func resetPanelPosition() {
        panelController.moveToCurrentScreen()
    }
}

private struct MenuBarLabelView: View {
    @EnvironmentObject private var model: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
            Text(UsageFormatting.abbreviated(model.todayTokens))
                .monospacedDigit()
        }
    }
}
