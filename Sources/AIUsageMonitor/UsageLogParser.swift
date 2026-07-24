import Foundation

enum UsageLogParser {
    static func parse(lineData: Data, provider: UsageProvider) -> ParsedUsageEvent? {
        let isRelevant: Bool
        switch provider {
        case .codex:
            isRelevant = lineData.range(of: Data("\"token_count\"".utf8)) != nil
                || lineData.range(of: Data("\"turn_context\"".utf8)) != nil
        case .claude:
            isRelevant = lineData.range(of: Data("\"assistant\"".utf8)) != nil
                && lineData.range(of: Data("\"usage\"".utf8)) != nil
        case .geminiCLI:
            isRelevant = lineData.range(of: Data("\"gemini\"".utf8)) != nil
                && lineData.range(of: Data("\"tokens\"".utf8)) != nil
        case .openCode:
            return nil
        }
        guard isRelevant else { return nil }

        guard
            !lineData.isEmpty,
            let object = try? JSONSerialization.jsonObject(with: lineData),
            let json = object as? [String: Any]
        else {
            return nil
        }

        switch provider {
        case .codex:
            return parseCodex(json)
        case .claude:
            return parseClaude(json)
        case .geminiCLI:
            return parseGemini(json)
        case .openCode:
            return nil
        }
    }

    private static func parseCodex(_ json: [String: Any]) -> ParsedUsageEvent? {
        if json["type"] as? String == "turn_context",
           let payload = json["payload"] as? [String: Any],
           let model = payload["model"] as? String,
           let timestamp = parseTimestamp(json["timestamp"]) {
            return .codexContext(timestamp: timestamp, model: normalizedModel(model, provider: .codex))
        }

        guard
            json["type"] as? String == "event_msg",
            let payload = json["payload"] as? [String: Any],
            payload["type"] as? String == "token_count",
            let info = payload["info"] as? [String: Any],
            let total = info["total_token_usage"] as? [String: Any],
            let timestamp = parseTimestamp(json["timestamp"])
        else {
            return nil
        }

        let rawInput = integer(total["input_tokens"])
        let cachedInput = integer(total["cached_input_tokens"])
        let counts = UsageCounts(
            uncachedInputTokens: max(0, rawInput - cachedInput),
            cachedInputTokens: cachedInput,
            cacheWriteTokens: 0,
            outputTokens: integer(total["output_tokens"]),
            reasoningTokens: integer(total["reasoning_output_tokens"]),
            requests: 0
        )

        return .codexCumulative(timestamp: timestamp, counts: counts)
    }

    private static func parseClaude(_ json: [String: Any]) -> ParsedUsageEvent? {
        guard
            json["type"] as? String == "assistant",
            let message = json["message"] as? [String: Any],
            let usage = message["usage"] as? [String: Any],
            let timestamp = parseTimestamp(json["timestamp"])
        else {
            return nil
        }

        let messageID = (message["id"] as? String)
            ?? (json["uuid"] as? String)
            ?? UUID().uuidString
        let sessionID = (json["sessionId"] as? String) ?? "unknown"
        let model = normalizedModel(message["model"] as? String, provider: .claude)
        let counts = UsageCounts(
            uncachedInputTokens: integer(usage["input_tokens"]),
            cachedInputTokens: integer(usage["cache_read_input_tokens"]),
            cacheWriteTokens: integer(usage["cache_creation_input_tokens"]),
            outputTokens: integer(usage["output_tokens"]),
            reasoningTokens: 0,
            requests: 1
        )

        guard counts.totalTokens > 0 else { return nil }
        return .message(
            provider: .claude,
            timestamp: timestamp,
            messageID: messageID,
            sessionID: sessionID,
            model: model,
            counts: counts
        )
    }

    private static func parseGemini(_ json: [String: Any]) -> ParsedUsageEvent? {
        guard
            json["type"] as? String == "gemini",
            let tokens = json["tokens"] as? [String: Any],
            let timestamp = parseTimestamp(json["timestamp"])
        else {
            return nil
        }

        let input = integer(tokens["input"])
        let cached = min(input, integer(tokens["cached"]))
        let total = integer(tokens["total"])
        let reportedOutput = integer(tokens["output"]) + integer(tokens["thoughts"])
        let output = max(reportedOutput, total - input)
        let counts = UsageCounts(
            uncachedInputTokens: max(0, input - cached),
            cachedInputTokens: cached,
            cacheWriteTokens: 0,
            outputTokens: max(0, output),
            reasoningTokens: integer(tokens["thoughts"]),
            requests: 1
        )
        guard counts.totalTokens > 0 else { return nil }

        return .message(
            provider: .geminiCLI,
            timestamp: timestamp,
            messageID: (json["id"] as? String) ?? UUID().uuidString,
            sessionID: (json["sessionId"] as? String) ?? "unknown",
            model: normalizedModel(json["model"] as? String, provider: .geminiCLI),
            counts: counts
        )
    }

    private static func integer(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func normalizedModel(_ value: String?, provider: UsageProvider) -> String {
        guard let value, !value.isEmpty, value != "<synthetic>" else {
            return provider.unknownModelName
        }
        return value
    }
}
