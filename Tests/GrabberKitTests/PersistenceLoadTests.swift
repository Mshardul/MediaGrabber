@testable import GrabberKit
import TestSupport
import XCTest

final class PersistenceLoadTests: PersistenceTestCase {
    // MARK: - Load table

    func test_corruptJSON_startsEmpty_logsCorrupt_noThrow() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: dir.appendingPathComponent("queue.json"))
        XCTAssertEqual(makePersistence().loadQueue().count, 0)
    }

    func test_schemaAhead_startsEmpty_doesNotParse() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ahead = QueueFile(schemaVersion: 99, jobs: [job(1)])
        try JSONEncoder().encode(ahead).write(to: dir.appendingPathComponent("queue.json"))
        XCTAssertEqual(makePersistence().loadQueue().count, 0)
    }

    func test_corruptQueue_writesSingleCorruptBackup_notBak() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: dir.appendingPathComponent("queue.json"))
        XCTAssertEqual(makePersistence().loadQueue().count, 0)
        let corrupt = dir.appendingPathComponent("queue.json.corrupt")
        let bak = dir.appendingPathComponent("queue.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bak.path))
    }

    func test_schemaAheadQueue_writesSingleCorruptBackup_notBak() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ahead = QueueFile(schemaVersion: 99, jobs: [job(1)])
        try JSONEncoder().encode(ahead).write(to: dir.appendingPathComponent("queue.json"))
        XCTAssertEqual(makePersistence().loadQueue().count, 0)
        let corrupt = dir.appendingPathComponent("queue.json.corrupt")
        let bak = dir.appendingPathComponent("queue.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bak.path))
    }

    func test_unopenableQueue_isNeverOverwritten() async throws {
        let url = try writeQueueFile("original")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
        let persistence = makePersistence()
        XCTAssertEqual(persistence.loadQueue().count, 0)
        persistence.saveQueue([job(1)])
        await persistence.flushNow()
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
    }

    func test_secondDamagedQueue_keepsTheFirstBackup() throws {
        _ = try writeQueueFile("first damage")
        _ = makePersistence().loadQueue()
        _ = try writeQueueFile("second damage")
        _ = makePersistence().loadQueue()
        let first = dir.appendingPathComponent("queue.json.corrupt")
        let second = dir.appendingPathComponent("queue.json.corrupt-2")
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "first damage")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "second damage")
    }

    func test_damagedQueueReadTwice_tellsTheUserOnce() throws {
        _ = try writeQueueFile("{ not json")
        let persistence = makePersistence()
        let told = LockedBox(0)
        persistence.reportLoadFailure { _ in told.mutate { $0 += 1 } }
        _ = persistence.loadQueue()
        _ = persistence.loadPlaylistGroups()
        XCTAssertEqual(told.read { $0 }, 1)
    }

    private func writeQueueFile(_ text: String) throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("queue.json")
        try Data(text.utf8).write(to: url)
        return url
    }

    func test_fileAbsent_startsEmpty() {
        XCTAssertEqual(makePersistence().loadQueue().count, 0)
        XCTAssertNil(makePersistence().loadColumns())
    }

    func test_debugResetState_noLoads() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(QueueFile(schemaVersion: 1, jobs: [job(1)]))
            .write(to: dir.appendingPathComponent("queue.json"))
        XCTAssertEqual(makePersistence(reset: true).loadQueue().count, 0)
    }
}
