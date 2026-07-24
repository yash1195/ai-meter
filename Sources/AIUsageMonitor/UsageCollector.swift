import Foundation

actor UsageCollector {
    private struct FileState {
        let provider: UsageProvider
        var offset: UInt64 = 0
        var buffer = Data()
        var daily: [Date: UsageTimeBucket] = [:]
        var hourly: [Date: UsageTimeBucket] = [:]
        var codexPrevious: UsageCounts?
        var currentModel: String
        var sessionID: String
        var exists = true
    }

    private let fileManager = FileManager.default
    private let calendar: Calendar
    private let jsonlRoots: [UsageProvider: [URL]]
    private let openCodeDataRoot: URL
    private let cursorDatabaseURL: URL
    private var states: [URL: FileState] = [:]
    private var observedMessageCounts: [String: UsageCounts] = [:]
    private var openCodeResults: [URL: OpenCodeUsageResult] = [:]
    private var cursorResult: CursorUsageResult?
    private var sessionActivity: [String: Date] = [:]
    private var lastDiscovery = Date.distantPast

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        let defaultHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let environment = homeDirectory.standardizedFileURL == defaultHome
            ? ProcessInfo.processInfo.environment
            : [:]
        let codexHome = environment["CODEX_HOME"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        let claudeHome = environment["CLAUDE_CONFIG_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        let geminiHome = environment["GEMINI_CLI_HOME"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? homeDirectory
        let xdgData = environment["XDG_DATA_HOME"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? homeDirectory.appendingPathComponent(".local/share", isDirectory: true)
        self.jsonlRoots = [
            .codex: [codexHome.appendingPathComponent("sessions", isDirectory: true)],
            .claude: [claudeHome.appendingPathComponent("projects", isDirectory: true)],
            .geminiCLI: [geminiHome.appendingPathComponent(".gemini/tmp", isDirectory: true)]
        ]
        self.openCodeDataRoot = xdgData.appendingPathComponent("opencode", isDirectory: true)
        self.cursorDatabaseURL = homeDirectory
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage", isDirectory: true)
            .appendingPathComponent("state.vscdb")
    }

    func refresh(now: Date = Date()) -> UsageSnapshot {
        if now.timeIntervalSince(lastDiscovery) >= 3 {
            discoverFiles()
            refreshOpenCode()
            refreshCursor()
            lastDiscovery = now
        }

        var requiresRebuild = false
        for url in Array(states.keys) {
            do {
                try consumeNewData(at: url)
            } catch CollectorError.fileWasTruncated {
                requiresRebuild = true
                break
            } catch {
                states[url]?.exists = false
            }
        }

        if requiresRebuild {
            rebuildAll()
        }

        return makeSnapshot(now: now)
    }

    private func rebuildAll() {
        states.removeAll(keepingCapacity: true)
        observedMessageCounts.removeAll(keepingCapacity: true)
        openCodeResults.removeAll(keepingCapacity: true)
        cursorResult = nil
        sessionActivity.removeAll(keepingCapacity: true)
        lastDiscovery = .distantPast
        discoverFiles()
        refreshOpenCode()
        refreshCursor()
        for url in Array(states.keys) {
            try? consumeNewData(at: url)
        }
    }

    private func discoverFiles() {
        for (provider, roots) in jsonlRoots {
            for root in roots {
                discoverJSONLFiles(for: provider, under: root)
            }
        }
    }

    private func discoverJSONLFiles(for provider: UsageProvider, under root: URL) {
        guard fileManager.fileExists(atPath: root.path) else { return }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard
                states[url] == nil,
                let values = try? url.resourceValues(forKeys: Set(keys)),
                values.isRegularFile == true
            else {
                continue
            }

            states[url] = FileState(
                provider: provider,
                currentModel: provider.unknownModelName,
                sessionID: url.deletingPathExtension().lastPathComponent
            )
        }
    }

    private func refreshOpenCode() {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: openCodeDataRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }

        let databases = files.filter {
            $0.pathExtension == "db" && $0.lastPathComponent.hasPrefix("opencode")
        }
        var refreshed: [URL: OpenCodeUsageResult] = [:]
        for database in databases {
            if let result = try? OpenCodeUsageReader.read(databaseURL: database, calendar: calendar) {
                refreshed[database] = result
            }
        }
        openCodeResults = refreshed
    }

    private func refreshCursor() {
        guard fileManager.fileExists(atPath: cursorDatabaseURL.path) else {
            cursorResult = nil
            return
        }
        cursorResult = try? CursorUsageReader.read(
            databaseURL: cursorDatabaseURL,
            calendar: calendar
        )
    }

    private func consumeNewData(at url: URL) throws {
        guard var state = states[url] else { return }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0

        guard fileSize >= state.offset else {
            throw CollectorError.fileWasTruncated
        }
        guard fileSize > state.offset else {
            state.exists = true
            states[url] = state
            return
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: state.offset)
        let newData = try handle.readToEnd() ?? Data()
        state.offset += UInt64(newData.count)
        state.buffer.append(newData)
        state.exists = true

        while let newlineIndex = state.buffer.firstIndex(of: 0x0A) {
            let line = Data(state.buffer[..<newlineIndex])
            state.buffer.removeSubrange(...newlineIndex)
            consume(line: line, state: &state)
        }

        states[url] = state
    }

    private func consume(line: Data, state: inout FileState) {
        guard let event = UsageLogParser.parse(lineData: line, provider: state.provider) else {
            return
        }

        switch event {
        case let .codexContext(_, model):
            state.currentModel = model

        case let .codexCumulative(timestamp, counts):
            let delta = counts.delta(from: state.codexPrevious)
            state.codexPrevious = counts
            guard delta.totalTokens > 0 else { return }
            add(
                delta,
                at: timestamp,
                dimension: UsageDimension(provider: .codex, model: state.currentModel),
                to: &state
            )
            recordActivity(provider: .codex, sessionID: state.sessionID, at: timestamp)

        case let .message(provider, timestamp, messageID, sessionID, model, counts):
            let uniqueID = "\(provider.rawValue):\(messageID)"
            let delta = counts.delta(from: observedMessageCounts[uniqueID])
            observedMessageCounts[uniqueID] = counts
            guard delta.totalTokens > 0 else { return }
            if sessionID != "unknown" {
                state.sessionID = sessionID
            }
            add(
                delta,
                at: timestamp,
                dimension: UsageDimension(provider: provider, model: model),
                to: &state
            )
            recordActivity(provider: provider, sessionID: state.sessionID, at: timestamp)
        }
    }

    private func add(
        _ counts: UsageCounts,
        at timestamp: Date,
        dimension: UsageDimension,
        to state: inout FileState
    ) {
        let day = calendar.startOfDay(for: timestamp)
        var dayBucket = state.daily[day] ?? UsageTimeBucket(start: day)
        dayBucket.add(counts, dimension: dimension)
        state.daily[day] = dayBucket

        guard let hour = calendar.dateInterval(of: .hour, for: timestamp)?.start else { return }
        var hourBucket = state.hourly[hour] ?? UsageTimeBucket(start: hour)
        hourBucket.add(counts, dimension: dimension)
        state.hourly[hour] = hourBucket
    }

    private func recordActivity(provider: UsageProvider, sessionID: String, at timestamp: Date) {
        let key = "\(provider.rawValue):\(sessionID)"
        sessionActivity[key] = max(sessionActivity[key] ?? .distantPast, timestamp)
    }

    private func makeSnapshot(now: Date) -> UsageSnapshot {
        var snapshot = UsageSnapshot(generatedAt: now)

        let hasJSONLRoot = jsonlRoots.values
            .flatMap { $0 }
            .contains { fileManager.fileExists(atPath: $0.path) }
        if !hasJSONLRoot
            && !fileManager.fileExists(atPath: openCodeDataRoot.path)
            && !fileManager.fileExists(atPath: cursorDatabaseURL.path) {
            snapshot.sourceWarnings.append("No supported local AI usage folders were found")
        }

        for state in states.values {
            for (date, bucket) in state.daily {
                var combined = snapshot.daily[date] ?? UsageTimeBucket(start: date)
                for (dimension, counts) in bucket.dimensions {
                    combined.add(counts, dimension: dimension)
                }
                snapshot.daily[date] = combined
            }
            for (date, bucket) in state.hourly {
                var combined = snapshot.hourly[date] ?? UsageTimeBucket(start: date)
                for (dimension, counts) in bucket.dimensions {
                    combined.add(counts, dimension: dimension)
                }
                snapshot.hourly[date] = combined
            }
        }

        for result in openCodeResults.values {
            merge(result.daily, into: &snapshot.daily)
            merge(result.hourly, into: &snapshot.hourly)
            for (sessionID, timestamp) in result.sessionActivity {
                recordActivity(provider: .openCode, sessionID: sessionID, at: timestamp)
            }
        }

        if let cursorResult {
            merge(cursorResult.daily, into: &snapshot.daily)
            merge(cursorResult.hourly, into: &snapshot.hourly)
            for (sessionID, timestamp) in cursorResult.sessionActivity {
                recordActivity(provider: .cursor, sessionID: sessionID, at: timestamp)
            }
        }

        let activeCutoff = now.addingTimeInterval(-5 * 60)
        for (key, activity) in sessionActivity where activity >= activeCutoff {
            for provider in UsageProvider.allCases where key.hasPrefix("\(provider.rawValue):") {
                snapshot.activeSessionsByProvider[provider, default: 0] += 1
                break
            }
        }

        snapshot.indexedFileCount = states.count + openCodeResults.count + (cursorResult == nil ? 0 : 1)
        return snapshot
    }

    private func merge(
        _ source: [Date: UsageTimeBucket],
        into destination: inout [Date: UsageTimeBucket]
    ) {
        for (date, bucket) in source {
            var combined = destination[date] ?? UsageTimeBucket(start: date)
            for (dimension, counts) in bucket.dimensions {
                combined.add(counts, dimension: dimension)
            }
            destination[date] = combined
        }
    }
}

private enum CollectorError: Error {
    case fileWasTruncated
}
