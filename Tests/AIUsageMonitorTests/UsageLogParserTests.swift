import AppKit
import XCTest
@testable import AIUsageMonitor

final class UsageLogParserTests: XCTestCase {
    func testCodexContextProvidesModelName() throws {
        let line = #"{"timestamp":"2026-07-22T18:40:00.000Z","type":"turn_context","payload":{"model":"gpt-5.6-sol"}}"#

        let event = UsageLogParser.parse(lineData: Data(line.utf8), provider: .codex)
        guard case let .codexContext(_, model) = event else {
            return XCTFail("Expected a Codex context event")
        }
        XCTAssertEqual(model, "gpt-5.6-sol")
    }

    func testCodexCumulativeUsageNormalizesCachedInput() throws {
        let line = #"{"timestamp":"2026-07-22T18:42:10.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":700,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":1200}}}}"#

        let event = UsageLogParser.parse(lineData: Data(line.utf8), provider: .codex)
        guard case let .codexCumulative(_, counts) = event else {
            return XCTFail("Expected a Codex cumulative event")
        }

        XCTAssertEqual(counts.uncachedInputTokens, 300)
        XCTAssertEqual(counts.cachedInputTokens, 700)
        XCTAssertEqual(counts.outputTokens, 200)
        XCTAssertEqual(counts.reasoningTokens, 50)
        XCTAssertEqual(counts.totalTokens, 1200)
    }

    func testClaudeMessageAddsSeparateCacheCategories() throws {
        let line = #"{"type":"assistant","timestamp":"2026-07-22T18:42:10.000Z","sessionId":"session-1","uuid":"entry-1","message":{"id":"msg_1","usage":{"input_tokens":100,"cache_creation_input_tokens":300,"cache_read_input_tokens":700,"output_tokens":200}}}"#

        let event = UsageLogParser.parse(lineData: Data(line.utf8), provider: .claude)
        guard case let .claudeMessage(_, messageID, sessionID, model, counts) = event else {
            return XCTFail("Expected a Claude message event")
        }

        XCTAssertEqual(messageID, "msg_1")
        XCTAssertEqual(sessionID, "session-1")
        XCTAssertEqual(model, "Unknown Claude model")
        XCTAssertEqual(counts.uncachedInputTokens, 100)
        XCTAssertEqual(counts.cacheWriteTokens, 300)
        XCTAssertEqual(counts.cachedInputTokens, 700)
        XCTAssertEqual(counts.outputTokens, 200)
        XCTAssertEqual(counts.totalTokens, 1300)
    }

    func testCodexDeltaDoesNotDoubleCountCumulativeTotals() {
        let previous = UsageCounts(
            uncachedInputTokens: 100,
            cachedInputTokens: 500,
            outputTokens: 100
        )
        let current = UsageCounts(
            uncachedInputTokens: 150,
            cachedInputTokens: 900,
            outputTokens: 180
        )

        XCTAssertEqual(
            current.delta(from: previous),
            UsageCounts(
                uncachedInputTokens: 50,
                cachedInputTokens: 400,
                outputTokens: 80,
                requests: 1
            )
        )
    }

    func testCollectorCombinesConcurrentFilesAndConsumesAppends() async throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory
            .appendingPathComponent("AIUsageMonitorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: home) }

        let codexDirectory = home.appendingPathComponent(".codex/sessions/2026/07/22", isDirectory: true)
        let claudeDirectory = home.appendingPathComponent(".claude/projects/test-project", isDirectory: true)
        try fileManager.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        let codexURL = codexDirectory.appendingPathComponent("rollout-session-a.jsonl")
        let claudeURL = claudeDirectory.appendingPathComponent("session-b.jsonl")

        let codexLines = [
            codexLine(timestamp: timestamp, input: 100, cached: 40, output: 20),
            codexLine(timestamp: timestamp, input: 150, cached: 60, output: 30)
        ].joined(separator: "\n") + "\n"
        try Data(codexLines.utf8).write(to: codexURL)

        let claude = claudeLine(
            timestamp: timestamp,
            messageID: "msg-one",
            input: 20,
            cacheWrite: 30,
            cacheRead: 100,
            output: 30
        )
        try Data("\(claude)\n\(claude)\n".utf8).write(to: claudeURL)

        let collector = UsageCollector(homeDirectory: home)
        let initial = await collector.refresh()
        let initialReport = UsageReportBuilder.make(snapshot: initial, period: .today, filter: .all)
        XCTAssertEqual(initialReport.providerTotals[.codex]?.totalTokens, 180)
        XCTAssertEqual(initialReport.providerTotals[.claude]?.totalTokens, 180)
        XCTAssertEqual(initialReport.total.totalTokens, 360)
        XCTAssertEqual(initial.activeSessions, 2)

        try append(
            codexLine(timestamp: timestamp, input: 200, cached: 80, output: 40) + "\n",
            to: codexURL
        )
        try append(
            claudeLine(
                timestamp: timestamp,
                messageID: "msg-two",
                input: 10,
                cacheWrite: 0,
                cacheRead: 0,
                output: 10
            ) + "\n",
            to: claudeURL
        )

        let updated = await collector.refresh()
        let updatedReport = UsageReportBuilder.make(snapshot: updated, period: .today, filter: .all)
        XCTAssertEqual(updatedReport.providerTotals[.codex]?.totalTokens, 240)
        XCTAssertEqual(updatedReport.providerTotals[.claude]?.totalTokens, 200)
        XCTAssertEqual(updatedReport.total.totalTokens, 440)
    }

    func testReportBuilderFiltersMonthProviderAndModel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        let february = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 10)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 12)))
        let codex = UsageDimension(provider: .codex, model: "gpt-test")
        let claude = UsageDimension(provider: .claude, model: "claude-test")

        var januaryBucket = UsageTimeBucket(start: january)
        januaryBucket.add(UsageCounts(uncachedInputTokens: 100), dimension: codex)
        var februaryBucket = UsageTimeBucket(start: february)
        februaryBucket.add(UsageCounts(uncachedInputTokens: 200), dimension: codex)
        februaryBucket.add(UsageCounts(uncachedInputTokens: 300), dimension: claude)
        let snapshot = UsageSnapshot(daily: [january: januaryBucket, february: februaryBucket])

        let month = UsageReportBuilder.make(
            snapshot: snapshot,
            period: .month,
            filter: .codex,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(month.total.totalTokens, 200)
        XCTAssertEqual(month.models.map(\.dimension.model), ["gpt-test"])

        let lifetime = UsageReportBuilder.make(
            snapshot: snapshot,
            period: .lifetime,
            filter: .all,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(lifetime.total.totalTokens, 600)
        XCTAssertEqual(lifetime.bins.count, 2)
    }

    func testResourceAssumptionsAreDeterministicAndAdjustable() {
        let assumptions = ResourceAssumptions(
            electricityKWhPerMillionTokens: 0.5,
            powerUsageEffectiveness: 2.0,
            operationalWaterLitersPerKWh: 0.8
        )
        XCTAssertEqual(assumptions.electricity(for: 2_000_000), 1.0, accuracy: 0.0001)
        XCTAssertEqual(assumptions.itElectricity(for: 2_000_000), 0.5, accuracy: 0.0001)
        XCTAssertEqual(assumptions.water(for: 2_000_000), 0.4, accuracy: 0.0001)
    }

    func testUpdateCheckerComparesMonotonicBuildNumbers() {
        XCTAssertTrue(UpdateChecker.isNewer(build: 2, than: 1))
        XCTAssertFalse(UpdateChecker.isNewer(build: 1, than: 1))
        XCTAssertFalse(UpdateChecker.isNewer(build: 1, than: 2))
    }

    func testUpdateManifestDecodesReleaseMetadata() throws {
        let data = Data(
            #"{"version":"0.2.0","build":2,"releaseURL":"https://github.com/yash1195/ai-meter/releases/tag/v0.2.0"}"#.utf8
        )
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
        XCTAssertEqual(manifest.version, "0.2.0")
        XCTAssertEqual(manifest.build, 2)
        XCTAssertEqual(manifest.releaseURL.host, "github.com")
    }

    @MainActor
    func testWidgetScreenshotRendersViewPixelsAsPNG() throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemBlue.cgColor
        let png = try XCTUnwrap(WidgetScreenshotService.pngData(for: view))
        XCTAssertGreaterThan(png.count, 1_000)
        XCTAssertEqual(Array(png.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }

    private func codexLine(
        timestamp: String,
        input: Int,
        cached: Int,
        output: Int
    ) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cached),"output_tokens":\(output),"reasoning_output_tokens":0,"total_tokens":\(input + output)}}}}
        """
    }

    private func claudeLine(
        timestamp: String,
        messageID: String,
        input: Int,
        cacheWrite: Int,
        cacheRead: Int,
        output: Int
    ) -> String {
        """
        {"type":"assistant","timestamp":"\(timestamp)","sessionId":"session-b","uuid":"entry-\(messageID)","message":{"id":"\(messageID)","usage":{"input_tokens":\(input),"cache_creation_input_tokens":\(cacheWrite),"cache_read_input_tokens":\(cacheRead),"output_tokens":\(output)}}}
        """
    }

    private func append(_ string: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(string.utf8))
    }
}
