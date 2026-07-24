import Foundation

enum ImpactEquivalence {
    // EIA reports 865 kWh per month for the average U.S. residential
    // electricity customer in 2024.
    static let averageUSHomeKWhPerDay = 865.0 * 12.0 / 365.0

    // EPA WaterSense showerheads are rated at no more than 7.6 L/min.
    static let waterSenseShowerLitersPerMinute = 7.6

    static func electricity(_ kWh: Double) -> String {
        let homeHours = max(0, kWh) / averageUSHomeKWhPerDay * 24
        if homeHours < 1 {
            let minutes = homeHours * 60
            return "About \(quantity(minutes, singular: "minute", plural: "minutes")) of electricity for an average U.S. home"
        }
        if homeHours < 24 {
            return "About \(quantity(homeHours, singular: "hour", plural: "hours")) of electricity for an average U.S. home"
        }
        let homeDays = homeHours / 24
        return "About \(quantity(homeDays, singular: "day", plural: "days")) of electricity for an average U.S. home"
    }

    static func water(_ liters: Double) -> String {
        let showerMinutes = max(0, liters) / waterSenseShowerLitersPerMinute
        if showerMinutes < 1 {
            return "About \(quantity(showerMinutes * 60, singular: "second", plural: "seconds")) of a WaterSense shower"
        }
        if showerMinutes < 15 {
            return "About \(quantity(showerMinutes, singular: "minute", plural: "minutes")) of a WaterSense shower"
        }
        let showers = showerMinutes / 15
        return "About \(quantity(showers, singular: "fifteen-minute WaterSense shower", plural: "fifteen-minute WaterSense showers"))"
    }

    private static func number(_ value: Double) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(value >= 10 ? 0 : 1)
            )
        )
    }

    private static func approximatelyOne(_ value: Double) -> Bool {
        abs(value - 1) < 0.05
    }

    private static func quantity(_ value: Double, singular: String, plural: String) -> String {
        "\(number(value)) \(approximatelyOne(value) ? singular : plural)"
    }
}
