import Foundation

enum UsageFormatting {
    static func full(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func abbreviated(_ value: Int) -> String {
        switch value {
        case 1_000_000_000...:
            return decimal(Double(value) / 1_000_000_000) + "B"
        case 1_000_000...:
            return decimal(Double(value) / 1_000_000) + "M"
        case 1_000...:
            return decimal(Double(value) / 1_000) + "K"
        default:
            return String(value)
        }
    }

    static func electricity(_ kWh: Double) -> String {
        if kWh < 0.001 {
            return (kWh * 1_000).formatted(.number.precision(.fractionLength(2))) + " Wh"
        }
        if kWh < 1 {
            return (kWh * 1_000).formatted(.number.precision(.fractionLength(1))) + " Wh"
        }
        return kWh.formatted(.number.precision(.fractionLength(2))) + " kWh"
    }

    static func water(_ liters: Double) -> String {
        if liters < 1 {
            return (liters * 1_000).formatted(.number.precision(.fractionLength(0))) + " mL"
        }
        return liters.formatted(.number.precision(.fractionLength(2))) + " L"
    }

    static func axisValue(_ value: Double, metric: UsageMetric) -> String {
        switch metric {
        case .tokens: abbreviated(Int(value.rounded()))
        case .electricity: electricity(value)
        case .water: water(value)
        }
    }

    static func periodTitle(_ report: UsageReport) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        switch report.period {
        case .today:
            return report.interval.start.formatted(date: .complete, time: .omitted)
        case .lifetime:
            return "Since " + report.interval.start.formatted(date: .abbreviated, time: .omitted)
        default:
            return formatter.string(from: report.interval.start, to: min(report.interval.end, Date()))
        }
    }

    private static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value >= 100 ? 0 : 1)))
    }
}
