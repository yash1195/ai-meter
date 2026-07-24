import Foundation

enum UsageProvider: String, CaseIterable, Hashable, Sendable, Identifiable {
    case codex = "Codex"
    case claude = "Claude Code"
    case openCode = "OpenCode"
    case geminiCLI = "Gemini CLI"

    var id: String { rawValue }

    var unknownModelName: String {
        switch self {
        case .codex: "Unknown Codex model"
        case .claude: "Unknown Claude model"
        case .openCode: "Unknown OpenCode model"
        case .geminiCLI: "Unknown Gemini model"
        }
    }
}

enum ProviderFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case codex = "Codex"
    case claude = "Claude"
    case openCode = "OpenCode"
    case geminiCLI = "Gemini"

    var id: String { rawValue }

    func includes(_ provider: UsageProvider) -> Bool {
        switch self {
        case .all: true
        case .codex: provider == .codex
        case .claude: provider == .claude
        case .openCode: provider == .openCode
        case .geminiCLI: provider == .geminiCLI
        }
    }
}

enum UsagePeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case yearToDate = "YTD"
    case lifetime = "Lifetime"

    var id: String { rawValue }
}

enum UsageMetric: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case electricity = "Electricity"
    case water = "Water"

    var id: String { rawValue }
}

struct UsageCounts: Equatable, Sendable {
    var uncachedInputTokens = 0
    var cachedInputTokens = 0
    var cacheWriteTokens = 0
    var outputTokens = 0
    var reasoningTokens = 0
    var requests = 0

    var inputTokens: Int {
        uncachedInputTokens + cachedInputTokens + cacheWriteTokens
    }

    var totalTokens: Int {
        inputTokens + outputTokens
    }

    static let zero = UsageCounts()

    static func + (lhs: UsageCounts, rhs: UsageCounts) -> UsageCounts {
        UsageCounts(
            uncachedInputTokens: lhs.uncachedInputTokens + rhs.uncachedInputTokens,
            cachedInputTokens: lhs.cachedInputTokens + rhs.cachedInputTokens,
            cacheWriteTokens: lhs.cacheWriteTokens + rhs.cacheWriteTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            reasoningTokens: lhs.reasoningTokens + rhs.reasoningTokens,
            requests: lhs.requests + rhs.requests
        )
    }

    static func += (lhs: inout UsageCounts, rhs: UsageCounts) {
        lhs = lhs + rhs
    }

    func delta(from previous: UsageCounts?) -> UsageCounts {
        guard let previous else {
            var initial = self
            initial.requests = totalTokens > 0 ? 1 : 0
            return initial
        }

        if totalTokens < previous.totalTokens {
            var reset = self
            reset.requests = totalTokens > 0 ? 1 : 0
            return reset
        }

        let result = UsageCounts(
            uncachedInputTokens: max(0, uncachedInputTokens - previous.uncachedInputTokens),
            cachedInputTokens: max(0, cachedInputTokens - previous.cachedInputTokens),
            cacheWriteTokens: max(0, cacheWriteTokens - previous.cacheWriteTokens),
            outputTokens: max(0, outputTokens - previous.outputTokens),
            reasoningTokens: max(0, reasoningTokens - previous.reasoningTokens),
            requests: 0
        )
        var counted = result
        counted.requests = result.totalTokens > 0 ? 1 : 0
        return counted
    }
}

struct UsageDimension: Hashable, Sendable {
    let provider: UsageProvider
    let model: String
}

struct UsageTimeBucket: Equatable, Sendable {
    let start: Date
    var dimensions: [UsageDimension: UsageCounts] = [:]

    var total: UsageCounts {
        dimensions.values.reduce(.zero, +)
    }

    mutating func add(_ counts: UsageCounts, dimension: UsageDimension) {
        dimensions[dimension, default: .zero] += counts
    }
}

struct UsageSnapshot: Equatable, Sendable {
    var generatedAt = Date()
    var daily: [Date: UsageTimeBucket] = [:]
    var hourly: [Date: UsageTimeBucket] = [:]
    var activeSessionsByProvider: [UsageProvider: Int] = [:]
    var sourceWarnings: [String] = []
    var indexedFileCount = 0

    static let empty = UsageSnapshot()

    var activeSessions: Int {
        activeSessionsByProvider.values.reduce(0, +)
    }

    var earliestDate: Date? {
        daily.keys.min()
    }
}

struct ResourceAssumptions: Equatable, Sendable {
    // Consumer-side operational estimate aligned to the SCI for AI per-token
    // functional unit. These are scenarios, not provider telemetry.
    static let defaultElectricityKWhPerMillionTokens = 0.39
    static let electricityInterquartileRange = 0.20...0.75
    static let defaultPowerUsageEffectiveness = 1.20
    static let defaultOperationalWaterLitersPerITKWh = 0.45

    var electricityKWhPerMillionTokens = Self.defaultElectricityKWhPerMillionTokens
    var powerUsageEffectiveness = Self.defaultPowerUsageEffectiveness
    var operationalWaterLitersPerKWh = Self.defaultOperationalWaterLitersPerITKWh

    func electricity(for tokens: Int) -> Double {
        Double(tokens) / 1_000_000 * electricityKWhPerMillionTokens
    }

    func itElectricity(for tokens: Int) -> Double {
        electricity(for: tokens) / max(1, powerUsageEffectiveness)
    }

    func water(for tokens: Int) -> Double {
        itElectricity(for: tokens) * operationalWaterLitersPerKWh
    }
}

struct UsageSeriesBin: Identifiable, Equatable {
    let start: Date
    let providers: [UsageProvider: UsageCounts]

    var id: Date { start }
    var total: UsageCounts { providers.values.reduce(.zero, +) }

    func counts(for filter: ProviderFilter) -> UsageCounts {
        providers.reduce(into: .zero) { result, entry in
            if filter.includes(entry.key) { result += entry.value }
        }
    }

    func counts(for provider: UsageProvider) -> UsageCounts {
        providers[provider] ?? .zero
    }
}

struct ModelUsageRow: Identifiable, Equatable {
    let dimension: UsageDimension
    let counts: UsageCounts

    var id: String { "\(dimension.provider.rawValue):\(dimension.model)" }
}

struct UsageReport: Equatable {
    let period: UsagePeriod
    let interval: DateInterval
    let calendarComponent: Calendar.Component
    let filter: ProviderFilter
    let total: UsageCounts
    let providerTotals: [UsageProvider: UsageCounts]
    let models: [ModelUsageRow]
    let bins: [UsageSeriesBin]
}

enum ParsedUsageEvent: Equatable {
    case codexContext(timestamp: Date, model: String)
    case codexCumulative(timestamp: Date, counts: UsageCounts)
    case message(
        provider: UsageProvider,
        timestamp: Date,
        messageID: String,
        sessionID: String,
        model: String,
        counts: UsageCounts
    )
}
