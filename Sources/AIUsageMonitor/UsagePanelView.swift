import Charts
import SwiftUI

struct UsagePanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var model: UsageViewModel
    @EnvironmentObject private var updateChecker: UpdateChecker

    private let brandAccent = Color(red: 0.72, green: 0.96, blue: 0.34)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                periodPicker
                summaryCards
                metricPicker
                InteractiveUsageChart(
                    report: model.report,
                    assumptions: model.assumptions,
                    metric: model.selectedMetric
                )
                assumptions
                providerModelBreakdown
                footer
            }
            .padding(18)
        }
        .frame(width: 540, height: 720)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.12),
                        Color.clear,
                        Color.cyan.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.035)
                        : Color.black.opacity(0.025)
                )

            HStack(spacing: 10) {
                MeterGlyph()

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI METER")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .tracking(-0.7)

                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(brandAccent)
                            .frame(width: 5, height: 5)

                        Text("\(model.snapshot.activeSessions) LIVE")
                            .foregroundStyle(.primary.opacity(0.82))

                        Text("/")
                            .foregroundStyle(.tertiary)

                        Text("LOCAL TELEMETRY")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    if case .available = updateChecker.status {
                        Button(action: updateChecker.openAvailableUpdate) {
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(brandAccent)
                                    .frame(width: 4, height: 4)
                                Text("UPDATE TO LATEST")
                            }
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.85))
                            .padding(.horizontal, 7)
                            .frame(height: 27)
                            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(.primary.opacity(0.13), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Open the latest AI Meter release")
                    } else if model.screenshotConfirmation != nil {
                        Text("COPIED")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(brandAccent)
                    }

                    HeaderActionButton(
                        systemImage: model.screenshotConfirmation == nil ? "camera" : "checkmark",
                        help: "Copy a screenshot of this widget",
                        action: model.takeScreenshot
                    )
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)

            HStack {
                Rectangle()
                    .fill(brandAccent)
                    .frame(width: 28, height: 1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $model.selectedPeriod) {
            ForEach(UsagePeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var summaryCards: some View {
        let total = model.report.total.totalTokens
        let energy = model.assumptions.electricity(for: total)
        let water = model.assumptions.water(for: total)
        return HStack(spacing: 10) {
            SummaryMetric(
                label: "TOKENS",
                value: UsageFormatting.abbreviated(total),
                detail: "provider reported",
                systemImage: "number",
                tint: .accentColor,
                prominent: true
            )
            SummaryMetric(
                label: "ELECTRICITY",
                value: UsageFormatting.electricity(energy),
                detail: "estimated",
                systemImage: "bolt.fill",
                tint: .yellow,
                prominent: false
            )
            SummaryMetric(
                label: "WATER",
                value: UsageFormatting.water(water),
                detail: "estimated",
                systemImage: "drop.fill",
                tint: .cyan,
                prominent: false
            )
        }
    }

    private var metricPicker: some View {
        HStack {
            Picker("Chart metric", selection: $model.selectedMetric) {
                ForEach(UsageMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            Picker("Provider", selection: $model.providerFilter) {
                ForEach(ProviderFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .frame(width: 120)
        }
        .controlSize(.small)
    }

    private var providerBreakdown: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Providers")
                .font(.headline)
            providerRow(.codex, color: .accentColor)
            providerRow(.claude, color: .orange)
        }
    }

    private var providerModelBreakdown: some View {
        let activeProviders = model.report.providerTotals.values.filter { $0.totalTokens > 0 }.count
        let modelCount = model.report.models.count
        let providerLabel = activeProviders == 1 ? "provider" : "providers"
        let modelLabel = modelCount == 1 ? "model" : "models"
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                providerBreakdown

                Divider()

                modelBreakdown
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label("Provider & model breakdown", systemImage: "square.stack.3d.up")
                Spacer()
                Text("\(activeProviders) \(providerLabel) · \(modelCount) \(modelLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func providerRow(_ provider: UsageProvider, color: Color) -> some View {
        let counts = model.report.providerTotals[provider] ?? .zero
        let allTokens = model.report.providerTotals.values.reduce(0) { $0 + $1.totalTokens }
        let share = allTokens == 0 ? 0 : Double(counts.totalTokens) / Double(allTokens)
        let sessions = model.snapshot.activeSessionsByProvider[provider, default: 0]
        return VStack(spacing: 5) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(provider.rawValue)
                Text("\(sessions) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(UsageFormatting.full(counts.totalTokens))
                    .monospacedDigit()
                Text(share, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: max(2, geometry.size.width * share))
                    }
            }
            .frame(height: 5)
        }
    }

    private var modelBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.headline)
            if model.report.models.isEmpty {
                Text("No model usage in this period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.report.models.prefix(6))) { row in
                    HStack {
                        Circle()
                            .fill(row.dimension.provider == .codex ? Color.accentColor : .orange)
                            .frame(width: 7, height: 7)
                        Text(row.dimension.model)
                            .lineLimit(1)
                        Spacer()
                        Text(UsageFormatting.abbreviated(row.counts.totalTokens))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var assumptions: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Consumer-side operational estimate", systemImage: "scope")
                        .font(.caption.weight(.semibold))

                    Text("AI Meter follows the SCI for AI consumer boundary and uses tokens as the functional unit. Provider infrastructure is not exposed, so this is a calibrated scenario—not a measured footprint or a complete SCI score.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Facility energy = reported tokens ÷ 1M × energy intensity")
                        Text("Direct water = facility energy ÷ PUE × site WUE")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Facility electricity intensity")
                        Spacer()
                        Text("\(model.electricityKWhPerMillionTokens, format: .number.precision(.fractionLength(2))) kWh / 1M tokens")
                            .monospacedDigit()
                    }
                        .font(.caption)
                    Slider(value: $model.electricityKWhPerMillionTokens, in: 0.10...1.20, step: 0.01)
                    Text("Research-calibrated midpoint 0.39; approximate IQR 0.20–0.75.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Data-center PUE")
                        Spacer()
                        Text(model.powerUsageEffectiveness, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }
                        .font(.caption)
                    Slider(value: $model.powerUsageEffectiveness, in: 1.05...1.60, step: 0.01)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Site WUE")
                        Spacer()
                        Text("\(model.waterLitersPerKWh, format: .number.precision(.fractionLength(2))) L / IT kWh")
                            .monospacedDigit()
                    }
                        .font(.caption)
                    Slider(value: $model.waterLitersPerKWh, in: 0...1.20, step: 0.01)
                    Text("Direct cooling water only. The 0.45 default is the LBNL U.S. data-center scenario midpoint.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("Excluded: model training, embodied hardware, electricity-generation water, and tool or network activity absent from local token logs. Cached context and proprietary model efficiency add further uncertainty.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Link("SCI for AI", destination: URL(string: "https://greensoftware.foundation/standards/sci-ai/")!)
                    Link("Inference study", destination: URL(string: "https://arxiv.org/abs/2509.20241")!)
                    Link("ISO WUE", destination: URL(string: "https://www.iso.org/standard/77692.html")!)
                    Link("LBNL baseline", destination: URL(string: "https://doi.org/10.71468/P1WC7Q")!)
                    Spacer()
                    Button("Reset", action: model.resetEnvironmentalAssumptions)
                }
                .font(.caption2)
                .buttonStyle(.link)
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label("Energy & water methodology", systemImage: "function")
                Spacer()
                Text("SCI / AI")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(brandAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(brandAccent.opacity(0.10), in: Capsule())
            }
        }
        .font(.caption)
    }

    private var footer: some View {
        HStack {
            if let warning = model.snapshot.sourceWarnings.first {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .lineLimit(1)
            } else {
                Text("\(model.snapshot.indexedFileCount) local files · updated \(model.snapshot.generatedAt, style: .relative) ago")
            }
            Spacer()
            updateControl
            Button("Refresh", action: model.refreshNow)
            Button("Quit", action: model.quit)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var updateControl: some View {
        switch updateChecker.status {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking")
            }
        case .current:
            Button("Up to date", action: updateChecker.checkNow)
        case .available:
            Button("Update to latest", action: updateChecker.openAvailableUpdate)
                .foregroundStyle(Color.accentColor)
        case .failed:
            Button("Retry update", action: updateChecker.checkNow)
        case .idle:
            Button("Check for updates", action: updateChecker.checkNow)
        }
    }
}

private struct MeterGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.primary.opacity(0.045))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.primary.opacity(0.14), lineWidth: 1)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
        }
        .frame(width: 34, height: 34)
    }
}

private struct HeaderActionButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(width: 27, height: 27)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.primary.opacity(0.13), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct SummaryMetric: View {
    let label: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(prominent ? .title2.weight(.semibold) : .headline)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 13)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(prominent ? 0.18 : 0.10), tint.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct InteractiveUsageChart: View {
    let report: UsageReport
    let assumptions: ResourceAssumptions
    let metric: UsageMetric
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(selectedBin.map { label(for: $0.start) } ?? "Usage over time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let selectedBin {
                    Text(UsageFormatting.axisValue(value(for: selectedBin.counts(for: report.filter)), metric: metric))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                }
            }

            Chart {
                ForEach(report.bins) { bin in
                    if report.filter.includes(.codex) {
                        AreaMark(
                            x: .value("Time", bin.start, unit: report.calendarComponent),
                            yStart: .value("Baseline", 0),
                            yEnd: .value(metric.rawValue, value(for: bin.codex))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.26), Color.accentColor.opacity(0.015)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Time", bin.start, unit: report.calendarComponent),
                            y: .value(metric.rawValue, value(for: bin.codex)),
                            series: .value("Provider series", UsageProvider.codex.rawValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(by: .value("Provider", UsageProvider.codex.rawValue))
                    }
                    if report.filter.includes(.claude) {
                        AreaMark(
                            x: .value("Time", bin.start, unit: report.calendarComponent),
                            yStart: .value("Baseline", 0),
                            yEnd: .value(metric.rawValue, value(for: bin.claude))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.23), Color.orange.opacity(0.012)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Time", bin.start, unit: report.calendarComponent),
                            y: .value(metric.rawValue, value(for: bin.claude)),
                            series: .value("Provider series", UsageProvider.claude.rawValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(by: .value("Provider", UsageProvider.claude.rawValue))
                    }
                }
                if let selectedDate {
                    RuleMark(x: .value("Selection", selectedDate))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                    if let selectedBin {
                        if report.filter.includes(.codex) {
                            PointMark(
                                x: .value("Selection", selectedDate),
                                y: .value(metric.rawValue, value(for: selectedBin.codex))
                            )
                            .symbolSize(54)
                            .foregroundStyle(Color.accentColor)
                        }
                        if report.filter.includes(.claude) {
                            PointMark(
                                x: .value("Selection", selectedDate),
                                y: .value(metric.rawValue, value(for: selectedBin.claude))
                            )
                            .symbolSize(54)
                            .foregroundStyle(Color.orange)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                UsageProvider.codex.rawValue: Color.accentColor,
                UsageProvider.claude.rawValue: Color.orange
            ])
            .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(UsageFormatting.axisValue(number, metric: metric))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case let .active(location):
                                updateSelection(at: location, proxy: proxy, geometry: geometry)
                            case .ended:
                                selectedDate = nil
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    updateSelection(at: gesture.location, proxy: proxy, geometry: geometry)
                                }
                                .onEnded { _ in }
                        )
                }
            }
            .frame(height: 210)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .animation(.easeInOut(duration: 0.24), value: report.bins)
        }
        .onChange(of: report.period) { _ in selectedDate = nil }
        .onChange(of: report.filter) { _ in selectedDate = nil }
    }

    private var selectedBin: UsageSeriesBin? {
        guard let selectedDate else { return nil }
        return report.bins.first(where: { $0.start == selectedDate })
    }

    private func value(for counts: UsageCounts) -> Double {
        switch metric {
        case .tokens: Double(counts.totalTokens)
        case .electricity: assumptions.electricity(for: counts.totalTokens)
        case .water: assumptions.water(for: counts.totalTokens)
        }
    }

    private func updateSelection(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        guard plotFrame.contains(location) else {
            selectedDate = nil
            return
        }
        let x = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        selectedDate = report.bins.min {
            abs($0.start.timeIntervalSince(date)) < abs($1.start.timeIntervalSince(date))
        }?.start
    }

    private func label(for date: Date) -> String {
        switch report.calendarComponent {
        case .hour: date.formatted(date: .omitted, time: .shortened)
        case .day: date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        default: date.formatted(.dateTime.month(.abbreviated).year())
        }
    }
}
