import Foundation

public enum ShieldInstallOutcome: Sendable, Equatable {
    case installed
    case failed(detail: String)
}

public struct ShieldInstaller: Sendable {
    // The bundled helper is GPL-3.0; future-ideas.md tracks a permissively licensed replacement.
    public static let version = "2.0.2"

    private let fileExists: @Sendable (String) -> Bool
    private let bundledServer: URL
    private let bundledPlugin: URL

    public init(
        runner _: ProcessRunning = ProcessRunner(),
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        isExecutable _: @escaping @Sendable (String) -> Bool = { _ in false },
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        prepareDirectory _: @escaping @Sendable (URL) -> Void = { _ in },
        removeItem _: @escaping @Sendable (URL) -> Void = { _ in },
        bundledServer: URL? = nil,
        bundledPlugin: URL? = nil
    ) {
        self.fileExists = fileExists
        let tools = ManagedTools.live(home: home)
        self.bundledServer = bundledServer ?? tools.shieldServer
        self.bundledPlugin = bundledPlugin ?? tools.shieldPlugin
    }

    public func install(onProgress _: @escaping @Sendable (String) -> Void = { _ in }) async -> ShieldInstallOutcome {
        let serverReady = fileExists(bundledServer.path)
        let pluginReady = fileExists(bundledPlugin.path)
        if serverReady, pluginReady {
            return .installed
        }
        return .failed(detail: "This copy of the app doesn't include the YouTube check.")
    }
}
