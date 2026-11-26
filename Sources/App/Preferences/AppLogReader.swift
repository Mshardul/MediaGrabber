import Foundation
import GrabberKit

// Behind a protocol so tests can inject a fake instead of reading the real logs folder.
protocol LogReading: Sendable {
    func appLogTail() -> String
    func mostRecentJobLog() -> String?
}

struct AppLogReader: LogReading {
    private let appLogDirectory: URL
    private let jobLogDirectory: URL
    private let tailLineCount: Int

    init(
        locations: AppLocations,
        tailLineCount: Int = 200
    ) {
        appLogDirectory = locations.logs
        jobLogDirectory = locations.jobLogs
        self.tailLineCount = tailLineCount
    }

    func appLogTail() -> String {
        let fileURL = appLogDirectory.appendingPathComponent("app.log")
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return "" }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(tailLineCount).joined(separator: "\n")
    }

    func mostRecentJobLog() -> String? {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: jobLogDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return nil
        }
        let newest = entries
            .filter { $0.pathExtension == "log" }
            .max { lhs, rhs in
                modificationDate(lhs, fileManager: fileManager) < modificationDate(rhs, fileManager: fileManager)
            }
        guard let newest else { return nil }
        return try? String(contentsOf: newest, encoding: .utf8)
    }

    private func modificationDate(_ url: URL, fileManager: FileManager) -> Date {
        (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
    }
}
