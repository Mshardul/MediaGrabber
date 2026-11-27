import Foundation

public protocol PluginStoring: Sendable {
    func fileExists(atPath: String) -> Bool
    func copyItem(at: URL, to: URL) throws
    func createDirectory(at: URL) throws
}

struct FoundationPluginStore: PluginStoring {
    func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func copyItem(at source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
