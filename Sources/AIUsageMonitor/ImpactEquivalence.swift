import Foundation

enum ImpactEquivalence {
    // Tesla publishes a Model 3 comparison consumption rating of
    // 25.4 kWh per 100 miles.
    static let teslaModel3KWhPerMile = 25.4 / 100.0

    // EPA WaterSense showerheads are rated at no more than 7.6 L/min.
    static let waterSenseShowerLitersPerMinute = 7.6

    static func electricity(_ kWh: Double) -> String {
        let miles = max(0, kWh) / teslaModel3KWhPerMile
        return "Enough to drive a Tesla Model 3 about \(quantity(miles, singular: "mile", plural: "miles"))"
    }

    static func water(_ liters: Double) -> String {
        let showerMinutes = max(0, liters) / waterSenseShowerLitersPerMinute
        if showerMinutes < 1 {
            return "About \(quantity(showerMinutes * 60, singular: "second", plural: "seconds")) of a water-efficient shower"
        }
        if showerMinutes < 15 {
            return "About \(quantity(showerMinutes, singular: "minute", plural: "minutes")) of a water-efficient shower"
        }
        let showers = showerMinutes / 15
        return "About \(quantity(showers, singular: "fifteen-minute shower", plural: "fifteen-minute showers"))"
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
