import AppKit
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot.empty
    @Published var selectedPeriod: UsagePeriod = .today
    @Published var providerFilter: ProviderFilter = .all
    @Published var selectedMetric: UsageMetric = .tokens
    @Published var electricityKWhPerMillionTokens: Double {
        didSet { UserDefaults.standard.set(electricityKWhPerMillionTokens, forKey: Self.energyKey) }
    }
    @Published var powerUsageEffectiveness: Double {
        didSet { UserDefaults.standard.set(powerUsageEffectiveness, forKey: Self.pueKey) }
    }
    @Published var waterLitersPerKWh: Double {
        didSet { UserDefaults.standard.set(waterLitersPerKWh, forKey: Self.waterKey) }
    }
    @Published private(set) var screenshotConfirmation: String?

    private static let energyKey = "methodologyV2.electricityKWhPerMillionTokens"
    private static let pueKey = "methodologyV2.powerUsageEffectiveness"
    private static let waterKey = "methodologyV2.waterLitersPerKWh"
    private let collector: UsageCollector
    private var refreshTask: Task<Void, Never>?

    init(collector: UsageCollector = UsageCollector()) {
        self.collector = collector
        let defaults = UserDefaults.standard
        self.electricityKWhPerMillionTokens = defaults.object(forKey: Self.energyKey) == nil
            ? ResourceAssumptions.defaultElectricityKWhPerMillionTokens
            : defaults.double(forKey: Self.energyKey)
        self.powerUsageEffectiveness = defaults.object(forKey: Self.pueKey) == nil
            ? ResourceAssumptions.defaultPowerUsageEffectiveness
            : defaults.double(forKey: Self.pueKey)
        self.waterLitersPerKWh = defaults.object(forKey: Self.waterKey) == nil
            ? ResourceAssumptions.defaultOperationalWaterLitersPerITKWh
            : defaults.double(forKey: Self.waterKey)
    }

    var assumptions: ResourceAssumptions {
        ResourceAssumptions(
            electricityKWhPerMillionTokens: electricityKWhPerMillionTokens,
            powerUsageEffectiveness: powerUsageEffectiveness,
            operationalWaterLitersPerKWh: waterLitersPerKWh
        )
    }

    var report: UsageReport {
        UsageReportBuilder.make(
            snapshot: snapshot,
            period: selectedPeriod,
            filter: providerFilter
        )
    }

    var todayTokens: Int {
        UsageReportBuilder.make(snapshot: snapshot, period: .today, filter: .all).total.totalTokens
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self, collector] in
            while !Task.isCancelled {
                let snapshot = await collector.refresh()
                guard let self else { return }
                self.snapshot = snapshot
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func refreshNow() {
        Task { [weak self, collector] in
            let snapshot = await collector.refresh()
            self?.snapshot = snapshot
        }
    }

    func takeScreenshot() {
        guard WidgetScreenshotService.copyVisibleWidgetToClipboard() else {
            screenshotConfirmation = "Failed"
            return
        }
        screenshotConfirmation = "Copied"
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.screenshotConfirmation = nil
        }
    }

    func resetEnvironmentalAssumptions() {
        electricityKWhPerMillionTokens = ResourceAssumptions.defaultElectricityKWhPerMillionTokens
        powerUsageEffectiveness = ResourceAssumptions.defaultPowerUsageEffectiveness
        waterLitersPerKWh = ResourceAssumptions.defaultOperationalWaterLitersPerITKWh
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        refreshTask?.cancel()
    }
}
