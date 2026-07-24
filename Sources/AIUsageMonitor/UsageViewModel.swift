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
    @Published private(set) var isLoadingInitialSnapshot = true
    @Published private(set) var liveActivityLevel = 0.0
    @Published private(set) var screenshotConfirmation: String?

    private static let energyKey = "methodologyV2.electricityKWhPerMillionTokens"
    private static let pueKey = "methodologyV2.powerUsageEffectiveness"
    private static let waterKey = "methodologyV2.waterLitersPerKWh"
    private let collector: UsageCollector
    private let cacheWriter: UsageSnapshotCacheWriter
    private var liveUsageActivity = LiveUsageActivity()
    private var refreshTask: Task<Void, Never>?
    private var lastCachedSnapshot: UsageSnapshot?

    init(
        collector: UsageCollector = UsageCollector(),
        snapshotCache: UsageSnapshotCache = .standard
    ) {
        self.collector = collector
        self.cacheWriter = UsageSnapshotCacheWriter(cache: snapshotCache)
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

        if let cachedSnapshot = snapshotCache.load() {
            snapshot = cachedSnapshot.restoringForStartup
            lastCachedSnapshot = cachedSnapshot
            isLoadingInitialSnapshot = false
        }
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
                self.apply(snapshot)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func refreshNow() {
        Task { [weak self, collector] in
            let snapshot = await collector.refresh()
            self?.apply(snapshot)
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

    private func apply(_ snapshot: UsageSnapshot) {
        liveActivityLevel = liveUsageActivity.sample(
            totalTokens: snapshot.totalTokens,
            at: snapshot.generatedAt
        )
        isLoadingInitialSnapshot = false
        self.snapshot = snapshot
        persistIfNeeded(snapshot)
    }

    private func persistIfNeeded(_ snapshot: UsageSnapshot) {
        let refreshInterval: TimeInterval = 30
        if let lastCachedSnapshot,
           snapshot.hasSameCachedContent(as: lastCachedSnapshot),
           snapshot.generatedAt.timeIntervalSince(lastCachedSnapshot.generatedAt) < refreshInterval {
            return
        }

        lastCachedSnapshot = snapshot
        Task { [cacheWriter] in
            await cacheWriter.save(snapshot)
        }
    }

    deinit {
        refreshTask?.cancel()
    }
}
