import AppKit
import Foundation

struct UpdateManifest: Codable, Equatable, Sendable {
    let version: String
    let build: Int
    let releaseURL: URL
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case current
    case available(UpdateManifest)
    case failed
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var status: UpdateStatus = .idle

    private let manifestURL: URL?
    private let session: URLSession
    private let currentBuild: Int
    private var refreshTask: Task<Void, Never>?

    init() {
        self.manifestURL = Self.configuredManifestURL
        self.session = .shared
        self.currentBuild = Self.bundleBuild
    }

    init(
        manifestURL: URL?,
        session: URLSession = .shared,
        currentBuild: Int
    ) {
        self.manifestURL = manifestURL
        self.session = session
        self.currentBuild = currentBuild
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.check(showFailure: false)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 21_600_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.check(showFailure: false)
            }
        }
    }

    func checkNow() {
        Task { [weak self] in
            await self?.check(showFailure: true)
        }
    }

    func openAvailableUpdate() {
        guard case let .available(manifest) = status else { return }
        NSWorkspace.shared.open(manifest.releaseURL)
    }

    nonisolated static func isNewer(build: Int, than currentBuild: Int) -> Bool {
        build > currentBuild
    }

    private func check(showFailure: Bool) async {
        guard let manifestURL else {
            if showFailure { status = .failed }
            return
        }

        status = .checking
        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode)
            else {
                throw URLError(.badServerResponse)
            }

            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
            guard manifest.releaseURL.scheme == "https" else {
                throw URLError(.appTransportSecurityRequiresSecureConnection)
            }
            status = Self.isNewer(build: manifest.build, than: currentBuild)
                ? .available(manifest)
                : .current
        } catch {
            status = showFailure ? .failed : .idle
        }
    }

    private static var configuredManifestURL: URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "AIUpdateManifestURL") as? String
        else {
            return nil
        }
        return URL(string: value)
    }

    private static var bundleBuild: Int {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            let build = Int(value)
        else {
            return 0
        }
        return build
    }

    deinit {
        refreshTask?.cancel()
    }
}
