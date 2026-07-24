import Foundation

struct UsageSnapshotCache: Sendable {
    private struct Envelope: Codable {
        let version: Int
        let snapshot: UsageSnapshot
    }

    static let currentVersion = 1
    static let standard = UsageSnapshotCache(fileURL: defaultFileURL())

    let fileURL: URL

    func load() -> UsageSnapshot? {
        guard
            let data = try? Data(contentsOf: fileURL),
            let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
            envelope.version == Self.currentVersion
        else {
            return nil
        }
        return envelope.snapshot
    }

    func save(_ snapshot: UsageSnapshot) throws {
        let envelope = Envelope(version: Self.currentVersion, snapshot: snapshot)
        let data = try JSONEncoder().encode(envelope)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return cachesDirectory
            .appendingPathComponent("com.zeko.aimeter", isDirectory: true)
            .appendingPathComponent("usage-snapshot-v1.json")
    }
}

actor UsageSnapshotCacheWriter {
    let cache: UsageSnapshotCache

    init(cache: UsageSnapshotCache) {
        self.cache = cache
    }

    func save(_ snapshot: UsageSnapshot) {
        try? cache.save(snapshot)
    }
}
