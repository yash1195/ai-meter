import Foundation
import SQLite3

struct CursorUsageResult {
    var daily: [Date: UsageTimeBucket] = [:]
    var hourly: [Date: UsageTimeBucket] = [:]
    var sessionActivity: [String: Date] = [:]
    var messageCount = 0
}

enum CursorUsageReader {
    private struct Bubble {
        let rowID: Int64
        let composerID: String
        let createdAt: Date
        let lastUpdatedAt: Date
        let counts: UsageCounts
    }

    static func read(databaseURL: URL, calendar: Calendar) throws -> CursorUsageResult {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            defer { if database != nil { sqlite3_close(database) } }
            throw CursorReaderError.cannotOpen
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 1_000)

        // Cursor documents that chat history is stored locally in SQLite. Its
        // token-count fields are not a public schema, so select metadata only
        // and fail closed if the expected shape changes. Prompt/response text,
        // tool output, source code, and Cursor authentication are never read.
        let sql = """
        SELECT
          b.rowid,
          substr(b.key, 10, 36),
          CAST(json_extract(c.value, '$.createdAt') AS INTEGER),
          CAST(json_extract(c.value, '$.lastUpdatedAt') AS INTEGER),
          CAST(json_extract(b.value, '$.tokenCount.inputTokens') AS INTEGER),
          CAST(json_extract(b.value, '$.tokenCount.outputTokens') AS INTEGER)
        FROM cursorDiskKV AS b
        JOIN cursorDiskKV AS c
          ON c.key = 'composerData:' || substr(b.key, 10, 36)
        WHERE b.key LIKE 'bubbleId:%'
          AND json_valid(b.value)
          AND json_valid(c.value)
          AND CAST(json_extract(b.value, '$.type') AS INTEGER) = 2
          AND (
            CAST(json_extract(b.value, '$.tokenCount.inputTokens') AS INTEGER) > 0
            OR CAST(json_extract(b.value, '$.tokenCount.outputTokens') AS INTEGER) > 0
          )
        ORDER BY substr(b.key, 10, 36), b.rowid
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw CursorReaderError.unsupportedSchema
        }
        defer { sqlite3_finalize(statement) }

        var bubblesByComposer: [String: [Bubble]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let composerID = text(statement, column: 1) else { continue }
            let createdMilliseconds = sqlite3_column_int64(statement, 2)
            let updatedMilliseconds = sqlite3_column_int64(statement, 3)
            guard createdMilliseconds > 0, updatedMilliseconds > 0 else { continue }

            let input = max(0, Int(sqlite3_column_int64(statement, 4)))
            let output = max(0, Int(sqlite3_column_int64(statement, 5)))
            let counts = UsageCounts(
                uncachedInputTokens: input,
                outputTokens: output,
                requests: 1
            )
            guard counts.totalTokens > 0 else { continue }

            bubblesByComposer[composerID, default: []].append(
                Bubble(
                    rowID: sqlite3_column_int64(statement, 0),
                    composerID: composerID,
                    createdAt: Date(timeIntervalSince1970: Double(createdMilliseconds) / 1_000),
                    lastUpdatedAt: Date(timeIntervalSince1970: Double(updatedMilliseconds) / 1_000),
                    counts: counts
                )
            )
        }

        var result = CursorUsageResult()
        let dimension = UsageDimension(provider: .cursor, model: UsageProvider.cursor.unknownModelName)
        for (composerID, bubbles) in bubblesByComposer {
            let ordered = bubbles.sorted { $0.rowID < $1.rowID }
            guard let first = ordered.first else { continue }
            let duration = max(0, first.lastUpdatedAt.timeIntervalSince(first.createdAt))

            for (index, bubble) in ordered.enumerated() {
                // Cursor exposes exact per-response token counts but not a
                // durable wall-clock timestamp for every bubble. Preserve the
                // exact totals and place bubbles in order across the
                // conversation's documented created/updated interval.
                let progress = ordered.count == 1
                    ? 1.0
                    : Double(index) / Double(ordered.count - 1)
                let timestamp = first.createdAt.addingTimeInterval(duration * progress)
                add(
                    bubble.counts,
                    at: timestamp,
                    dimension: dimension,
                    calendar: calendar,
                    result: &result
                )
                result.messageCount += 1
            }
            result.sessionActivity[composerID] = first.lastUpdatedAt
        }

        return result
    }

    private static func add(
        _ counts: UsageCounts,
        at timestamp: Date,
        dimension: UsageDimension,
        calendar: Calendar,
        result: inout CursorUsageResult
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
}

private enum CursorReaderError: Error {
    case cannotOpen
    case unsupportedSchema
}
