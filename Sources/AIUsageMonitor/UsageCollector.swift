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
    private let roots: [UsageProvider: URL]
    private var states: [URL: FileState] = [:]
    private var seenClaudeMessageIDs = Set<String>()
    private var sessionActivity: [String: Date] = [:]
    private var lastDiscovery = Date.distantPast

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.roots = [
            .codex: homeDirectory.appendingPathComponent(".codex/sessions", isDirectory: true),
            .claude: homeDirectory.appendingPathComponent(".claude/projects", isDirectory: true)
        ]
    }

    func refresh(now: Date = Date()) -> UsageSnapshot {
        if now.timeIntervalSince(lastDiscovery) >= 3 {
            discoverFiles()
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
        seenClaudeMessageIDs.removeAll(keepingCapacity: true)
        sessionActivity.removeAll(keepingCapacity: true)
        lastDiscovery = .distantPast
        discoverFiles()
        for url in Array(states.keys) {
            try? consumeNewData(at: url)
        }
    }

    private func discoverFiles() {
        for (provider, root) in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }

            let keys: [URLResourceKey] = [.isRegularFileKey]
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            ) else {
                continue
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
                    currentModel: provider == .codex ? "Unknown Codex model" : "Unknown Claude model",
                    sessionID: url.deletingPathExtension().lastPathComponent
                )
            }
        }
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

        case let .claudeMessage(timestamp, messageID, sessionID, model, counts):
            let uniqueID = "claude:\(messageID)"
            guard seenClaudeMessageIDs.insert(uniqueID).inserted else { return }
            state.sessionID = sessionID
            add(
                counts,
                at: timestamp,
                dimension: UsageDimension(provider: .claude, model: model),
                to: &state
            )
            recordActivity(provider: .claude, sessionID: sessionID, at: timestamp)
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

        for provider in UsageProvider.allCases {
            if let root = roots[provider], !fileManager.fileExists(atPath: root.path) {
                snapshot.sourceWarnings.append("\(provider.rawValue) data folder was not found")
            }
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

        let activeCutoff = now.addingTimeInterval(-5 * 60)
        for (key, activity) in sessionActivity where activity >= activeCutoff {
            if key.hasPrefix("\(UsageProvider.codex.rawValue):") {
                snapshot.activeSessionsByProvider[.codex, default: 0] += 1
            } else if key.hasPrefix("\(UsageProvider.claude.rawValue):") {
                snapshot.activeSessionsByProvider[.claude, default: 0] += 1
            }
        }

        snapshot.indexedFileCount = states.count
        return snapshot
    }
}

private enum CollectorError: Error {
    case fileWasTruncated
}
