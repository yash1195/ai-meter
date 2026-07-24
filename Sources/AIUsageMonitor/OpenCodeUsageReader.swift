import Foundation
import SQLite3

struct OpenCodeUsageResult {
    var daily: [Date: UsageTimeBucket] = [:]
    var hourly: [Date: UsageTimeBucket] = [:]
    var sessionActivity: [String: Date] = [:]
    var messageCount = 0
}

enum OpenCodeUsageReader {
    static func read(databaseURL: URL, calendar: Calendar) throws -> OpenCodeUsageResult {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            defer { if database != nil { sqlite3_close(database) } }
            throw OpenCodeReaderError.cannotOpen
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 1_000)

        let sql = "SELECT id, session_id, time_created, data FROM message"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw OpenCodeReaderError.unsupportedSchema
        }
        defer { sqlite3_finalize(statement) }

        var result = OpenCodeUsageResult()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let messageID = text(statement, column: 0),
                let sessionID = text(statement, column: 1),
                let jsonText = text(statement, column: 3),
                let jsonData = jsonText.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: jsonData),
                let json = object as? [String: Any],
                json["role"] as? String == "assistant",
                let tokens = json["tokens"] as? [String: Any]
            else {
                continue
            }

            let input = integer(tokens["input"])
            let cache = tokens["cache"] as? [String: Any]
            let cacheRead = integer(cache?["read"])
            let cacheWrite = integer(cache?["write"])
            let reasoning = integer(tokens["reasoning"])
            let output = integer(tokens["output"]) + reasoning
            let counts = UsageCounts(
                uncachedInputTokens: input,
                cachedInputTokens: cacheRead,
                cacheWriteTokens: cacheWrite,
                outputTokens: output,
                reasoningTokens: reasoning,
                requests: 1
            )
            guard counts.totalTokens > 0 else { continue }

            let milliseconds = sqlite3_column_int64(statement, 2)
            let timestamp = Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
            let modelObject = json["model"] as? [String: Any]
            let modelID = json["modelID"] as? String ?? modelObject?["modelID"] as? String
            let providerID = json["providerID"] as? String ?? modelObject?["providerID"] as? String
            let model = normalizedModel(modelID, providerID: providerID)
            let dimension = UsageDimension(provider: .openCode, model: model)
            add(counts, at: timestamp, dimension: dimension, calendar: calendar, result: &result)
            result.sessionActivity[sessionID] = max(result.sessionActivity[sessionID] ?? .distantPast, timestamp)
            result.messageCount += 1

            _ = messageID // Selecting the ID documents the row-level deduplication boundary.
        }
        return result
    }

    private static func add(
        _ counts: UsageCounts,
        at timestamp: Date,
        dimension: UsageDimension,
        calendar: Calendar,
        result: inout OpenCodeUsageResult
    ) {
        let day = calendar.startOfDay(for: timestamp)
        var dayBucket = result.daily[day] ?? UsageTimeBucket(start: day)
        dayBucket.add(counts, dimension: dimension)
        result.daily[day] = dayBucket

        guard let hour = calendar.dateInterval(of: .hour, for: timestamp)?.start else { return }
        var hourBucket = result.hourly[hour] ?? UsageTimeBucket(start: hour)
        hourBucket.add(counts, dimension: dimension)
        result.hourly[hour] = hourBucket
    }

    private static func text(_ statement: OpaquePointer, column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: pointer)
    }

    private static func integer(_ value: Any?) -> Int {
        if let value = value as? Int { return max(0, value) }
        if let value = value as? NSNumber { return max(0, value.intValue) }
        return 0
    }

    private static func normalizedModel(_ model: String?, providerID: String?) -> String {
        guard let model, !model.isEmpty else { return UsageProvider.openCode.unknownModelName }
        if let providerID, !providerID.isEmpty, !model.hasPrefix("\(providerID)/") {
            return "\(providerID)/\(model)"
        }
        return model
    }
}

private enum OpenCodeReaderError: Error {
    case cannotOpen
    case unsupportedSchema
}
