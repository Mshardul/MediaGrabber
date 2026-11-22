import Foundation

public struct PotPluginInstaller: Sendable {
    private let pluginDestination: URL
    private let tools: ManagedTools
    private let isExecutable: @Sendable (URL) -> Bool
    private let fileExists: @Sendable (URL) -> Bool
    private let pluginStore: any PluginStoring

    public init(
        pluginDestination: URL,
        tools: ManagedTools,
        isExecutable: @escaping @Sendable (URL) -> Bool,
        fileExists: @escaping @Sendable (URL) -> Bool,
        pluginStore: any PluginStoring
    ) {
        self.pluginDestination = pluginDestination
        self.tools = tools
        self.isExecutable = isExecutable
        self.fileExists = fileExists
        self.pluginStore = pluginStore
    }

    public static func live(locations: AppLocations) -> PotPluginInstaller {
        PotPluginInstaller(
            pluginDestination: locations.pluginStore,
            tools: .live(locations: locations),
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0.path) },
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            pluginStore: FoundationPluginStore()
        )
    }

    public func pluginDirs() -> [URL] {
        guard let source = pluginSource() else {
            return []
        }
        let dest = pluginDestination
        try? pluginStore.createDirectory(at: dest)
        let target = dest.appendingPathComponent(source.lastPathComponent)
        if !pluginStore.fileExists(atPath: target.path) {
            try? pluginStore.copyItem(at: source, to: target)
        }
        guard pluginStore.fileExists(atPath: target.path) else {
            return []
        }
        return [dest]
    }

    public func resolveServerLaunch(port: Int, host: String = "127.0.0.1") -> ProcessLaunch? {
        let node = tools.nodeURL
        guard isExecutable(node), let mainJS = nodeEntry() else { return nil }
        return ProcessLaunch(
            executableURL: node,
            arguments: [mainJS.path, "--host", host, "--port", "\(port)"]
        )
    }

    private func nodeEntry() -> URL? {
        existing(tools.shieldServer)
    }

    private func pluginSource() -> URL? {
        existing(tools.shieldPlugin)
    }

    private func existing(_ url: URL) -> URL? {
        fileExists(url) ? url : nil
    }
}
