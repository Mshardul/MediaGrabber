import CryptoKit
import Foundation

public enum YtDlpUpdateResult: Sendable, Equatable {
    case success(newVersion: String)
    case failure(reason: String)
}

public protocol YtDlpUpdating: Sendable {
    func updateToLatest() async -> YtDlpUpdateResult
}

enum YtDlpUpdateCopy {
    static let offline = "Couldn't download the update. Check your connection and try again."
    static let damaged = "The update didn't download properly, so nothing was changed. Try again later."

    static func saveFailed(_ error: Error) -> String {
        switch SaveFailureNotice.cause(of: error as NSError) {
        case .diskFull:
            "The update couldn't be saved because the disk is full. Free some space, then try again."
        case .notPermitted:
            "The update couldn't be saved because the app data folder isn't writable. "
                + "Make the folder writable, then try again."
        case .unavailable:
            "The update couldn't be saved on this Mac. Try again."
        }
    }
}

public struct YtDlpFetchError: Error, Equatable, Sendable {
    public let message: String
}

public struct YtDlpBinary: Sendable, Equatable {
    public let version: String
    public let bytes: Data
    public let sha256Hex: String

    public init(version: String, bytes: Data, sha256Hex: String) {
        self.version = version
        self.bytes = bytes
        self.sha256Hex = sha256Hex
    }
}

public protocol YtDlpReleaseFetching: Sendable {
    func latestVersion() async -> Result<String, YtDlpFetchError>
    func latest() async -> Result<YtDlpBinary, YtDlpFetchError>
}

public struct YtDlpUpdater: YtDlpUpdating {
    private let fetcher: YtDlpReleaseFetching
    private let binDirectory: URL
    private let minimumVersion: String
    private let canary: @Sendable (URL) async -> Bool
    private let installedVersion: @Sendable () async -> String?
    private let onInstalled: @Sendable () async -> Void

    public init(
        fetcher: YtDlpReleaseFetching,
        binDirectory: URL,
        minimumVersion: String = EngineTuning.default.minimumYtDlpVersion,
        installedVersion: @escaping @Sendable () async -> String? = { nil },
        onInstalled: @escaping @Sendable () async -> Void = {},
        canary: @escaping @Sendable (URL) async -> Bool = { url in
            if case .success = await CanaryProbe.run(ytDlpPath: url, runner: ProcessRunner()) {
                return true
            }
            return false
        }
    ) {
        self.fetcher = fetcher
        self.binDirectory = binDirectory
        self.minimumVersion = minimumVersion
        self.canary = canary
        self.installedVersion = installedVersion
        self.onInstalled = onInstalled
    }

    public init(tools: ManagedTools, locator: YtDlpLocator) {
        self.init(
            fetcher: GitHubYtDlpReleaseFetcher(),
            binDirectory: tools.supportRoot.appendingPathComponent("bin"),
            installedVersion: { await locator.installedVersion() },
            onInstalled: { await locator.refresh() }
        )
    }

    public func updateToLatest() async -> YtDlpUpdateResult {
        let latestVersion: String
        switch await fetcher.latestVersion() {
        case let .success(version):
            latestVersion = version
        case let .failure(error):
            return .failure(reason: error.message)
        }
        if let installed = await installedVersion(), isCurrent(installed: installed, latest: latestVersion) {
            return .success(newVersion: installed)
        }
        let fetched: YtDlpBinary
        switch await fetcher.latest() {
        case let .success(binary):
            fetched = binary
        case let .failure(error):
            return .failure(reason: error.message)
        }
        if let rejection = rejection(for: fetched) {
            return .failure(reason: rejection)
        }
        let outcome = await install(fetched)
        if case .success = outcome {
            await onInstalled()
        }
        return outcome
    }

    private func rejection(for fetched: YtDlpBinary) -> String? {
        guard let downloaded = DottedVersion(parsing: fetched.version),
              let minimum = DottedVersion(parsing: minimumVersion),
              downloaded >= minimum
        else {
            return "The newest downloader is older than this app allows."
        }
        let digest = SHA256.hash(data: fetched.bytes).map { String(format: "%02x", $0) }.joined()
        return digest == fetched.sha256Hex.lowercased() ? nil : YtDlpUpdateCopy.damaged
    }

    private func install(_ fetched: YtDlpBinary) async -> YtDlpUpdateResult {
        let fileManager = FileManager.default
        let incoming = binDirectory.appendingPathComponent("yt-dlp.incoming")
        let destination = binDirectory.appendingPathComponent("yt-dlp")
        let receipt = binDirectory.appendingPathComponent("yt-dlp.sha256")
        do {
            try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
            try fetched.bytes.write(to: incoming, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: incoming.path)
        } catch {
            try? fileManager.removeItem(at: incoming)
            return .failure(reason: YtDlpUpdateCopy.saveFailed(error))
        }
        guard await canary(incoming) else {
            try? fileManager.removeItem(at: incoming)
            return .failure(reason: "The new downloader didn't pass a check, so the included copy stays in use.")
        }
        let previousReceipt = try? Data(contentsOf: receipt)
        do {
            // Written before the move, so a new copy is never in place without its checksum.
            try fetched.sha256Hex.lowercased().write(to: receipt, atomically: true, encoding: .utf8)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: incoming)
            } else {
                try fileManager.moveItem(at: incoming, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: incoming)
            restore(previousReceipt, at: receipt)
            return .failure(reason: YtDlpUpdateCopy.saveFailed(error))
        }
        return .success(newVersion: fetched.version)
    }

    private func restore(_ previous: Data?, at receipt: URL) {
        guard let previous else {
            try? FileManager.default.removeItem(at: receipt)
            return
        }
        try? previous.write(to: receipt, options: .atomic)
    }

    private func isCurrent(installed: String, latest: String) -> Bool {
        guard let have = DottedVersion(parsing: installed), let want = DottedVersion(parsing: latest) else {
            return false
        }
        return have >= want
    }
}

struct GitHubYtDlpReleaseFetcher: YtDlpReleaseFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestVersion() async -> Result<String, YtDlpFetchError> {
        do {
            return try await .success(Self.version(fromTag: releaseTag()))
        } catch {
            return .failure(YtDlpFetchError(message: YtDlpUpdateCopy.offline))
        }
    }

    private static func version(fromTag tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    func latest() async -> Result<YtDlpBinary, YtDlpFetchError> {
        do {
            let tag = try await releaseTag()
            let binaryURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/\(tag)/yt-dlp_macos")!
            let sumsURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/\(tag)/SHA2-256SUMS")!
            let (bytes, _) = try await session.data(from: binaryURL)
            let (sumsData, _) = try await session.data(from: sumsURL)
            let sums = String(data: sumsData, encoding: .utf8) ?? ""
            guard let checksum = Self.checksum(in: sums, filename: "yt-dlp_macos") else {
                return .failure(YtDlpFetchError(message: YtDlpUpdateCopy.offline))
            }
            let version = Self.version(fromTag: tag)
            return .success(YtDlpBinary(version: version, bytes: bytes, sha256Hex: checksum))
        } catch {
            return .failure(YtDlpFetchError(message: YtDlpUpdateCopy.offline))
        }
    }

    private func releaseTag() async throws -> String {
        let url = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let tag = object?["tag_name"] as? String, !tag.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return tag
    }

    static func checksum(in sums: String, filename: String) -> String? {
        for line in sums.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "*" || $0 == "\t" })
            guard parts.count >= 2, parts.last == Substring(filename) else { continue }
            return String(parts[0]).lowercased()
        }
        return nil
    }
}
