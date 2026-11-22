import Foundation

public enum ShieldInstallOutcome: Sendable, Equatable {
    case installed
    case failed(detail: String)
}

public struct ShieldInstaller: Sendable {
    // The bundled helper is GPL-3.0; future-ideas.md tracks a permissively licensed replacement.
    public static let version = "2.0.2"

    private let tools: ManagedTools
    private let fileExists: @Sendable (String) -> Bool

    public init(
        tools: ManagedTools,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.tools = tools
        self.fileExists = fileExists
    }

    public func install() async -> ShieldInstallOutcome {
        if fileExists(tools.shieldServer.path), fileExists(tools.shieldPlugin.path) {
            return .installed
        }
        return .failed(detail: "This copy of the app doesn't include the YouTube check.")
    }
}
