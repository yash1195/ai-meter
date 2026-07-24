import Foundation

enum UsageReportBuilder {
    static func make(
        snapshot: UsageSnapshot,
        period: UsagePeriod,
        filter: ProviderFilter,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageReport {
        let interval = interval(
            for: period,
            now: now,
            earliest: snapshot.earliestDate,
            calendar: calendar
        )
        let component = aggregationComponent(for: period)
        var providerTotals: [UsageProvider: UsageCounts] = [:]
        var modelTotals: [UsageDimension: UsageCounts] = [:]

        for (date, bucket) in snapshot.daily where interval.contains(date) {
            for (dimension, counts) in bucket.dimensions {
                providerTotals[dimension.provider, default: .zero] += counts
                if filter.includes(dimension.provider) {
                    modelTotals[dimension, default: .zero] += counts
                }
            }
        }

        let source = component == .hour ? snapshot.hourly : snapshot.daily
        var aggregated: [Date: [UsageProvider: UsageCounts]] = [:]
        for (date, bucket) in source where interval.contains(date) {
            let binStart = floor(date, to: component, calendar: calendar)
            for (dimension, counts) in bucket.dimensions {
                aggregated[binStart, default: [:]][dimension.provider, default: .zero] += counts
            }
        }

        var bins: [UsageSeriesBin] = []
        var cursor = floor(interval.start, to: component, calendar: calendar)
        let finalBin = floor(min(now, interval.end), to: component, calendar: calendar)
        while cursor <= finalBin {
            let values = aggregated[cursor] ?? [:]
            bins.append(
                UsageSeriesBin(
                    start: cursor,
                    codex: values[.codex] ?? .zero,
                    claude: values[.claude] ?? .zero
                )
            )
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else {
                break
            }
            cursor = next
        }

        let total = providerTotals.reduce(into: UsageCounts.zero) { result, entry in
            if filter.includes(entry.key) { result += entry.value }
        }
        let models = modelTotals
            .map { ModelUsageRow(dimension: $0.key, counts: $0.value) }
            .sorted { $0.counts.totalTokens > $1.counts.totalTokens }

        return UsageReport(
            period: period,
            interval: interval,
            calendarComponent: component,
            filter: filter,
            total: total,
            providerTotals: providerTotals,
            models: models,
            bins: bins
        )
    }

    private static func interval(
        for period: UsagePeriod,
        now: Date,
        earliest: Date?,
        calendar: Calendar
    ) -> DateInterval {
        switch period {
        case .today:
            return calendar.dateInterval(of: .day, for: now)
                ?? DateInterval(start: calendar.startOfDay(for: now), end: now)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)
                ?? DateInterval(start: calendar.startOfDay(for: now), end: now)
        case .month:
            return calendar.dateInterval(of: .month, for: now)
                ?? DateInterval(start: calendar.startOfDay(for: now), end: now)
        case .yearToDate:
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
                ?? calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)
        case .lifetime:
            return DateInterval(start: earliest ?? calendar.startOfDay(for: now), end: now)
        }
    }

    private static func aggregationComponent(for period: UsagePeriod) -> Calendar.Component {
        switch period {
        case .today: .hour
        case .week, .month: .day
        case .yearToDate, .lifetime: .month
        }
    }

    private static func floor(
        _ date: Date,
        to component: Calendar.Component,
        calendar: Calendar
    ) -> Date {
        switch component {
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        default:
            return date
        }
    }
}
