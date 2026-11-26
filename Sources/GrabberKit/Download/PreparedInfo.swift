import Foundation

// Spares rate-sensitive sites a repeat check; it holds session cookies, so it is owner-only and used once.
public struct PreparedInfo: Sendable, Equatable {
    static let reusableExtractors: Set<String> = ["zoom"]
    // How long a signed video link stays valid is unknown, so reuse stays well short of a long pause.
    static let maxAge: TimeInterval = 10 * 60

    let json: String
    let capturedAt: Date

    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(capturedAt) < Self.maxAge
    }

    func write(jobID: UUID) throws -> URL {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("mg-prepared-\(jobID.uuidString).info.json")
        try? FileManager.default.removeItem(at: file)
        let created = FileManager.default.createFile(
            atPath: file.path,
            contents: Data(json.utf8),
            attributes: [.posixPermissions: 0o600]
        )
        guard created else { throw CocoaError(.fileWriteUnknown) }
        return file
    }
}
