import Foundation

struct LiveUsageActivity: Equatable, Sendable {
    static let decayHalfLife: TimeInterval = 6
    static let tokensForFullBurst = 100_000

    private(set) var level = 0.0
    private var previousTotalTokens: Int?
    private var previousSampleAt: Date?

    mutating func sample(totalTokens: Int, at date: Date) -> Double {
        guard
            let previousTotalTokens,
            let previousSampleAt
        else {
            self.previousTotalTokens = totalTokens
            self.previousSampleAt = date
            level = 0
            return level
        }

        let elapsed = max(0, date.timeIntervalSince(previousSampleAt))
        if elapsed > 0 {
            level *= pow(0.5, elapsed / Self.decayHalfLife)
        }

        let addedTokens = max(0, totalTokens - previousTotalTokens)
        if addedTokens > 0 {
            let burst = log1p(Double(addedTokens))
                / log1p(Double(Self.tokensForFullBurst))
            level = max(level, min(1, burst))
        }

        self.previousTotalTokens = totalTokens
        self.previousSampleAt = date
        return level
    }
}
