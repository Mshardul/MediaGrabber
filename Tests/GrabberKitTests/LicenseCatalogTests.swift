@testable import GrabberKit
import XCTest

final class LicenseCatalogTests: XCTestCase {
    private let expectedIDs = ["yt-dlp", "ffmpeg", "lame", "node", "shield", "sparkle"]

    func test_idsAreUniqueAndExactlyTheBundledComponents() {
        let ids = LicenseCatalog.entries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(ids), Set(expectedIDs))
    }

    func test_textFileMatchesID() {
        for entry in LicenseCatalog.entries {
            XCTAssertEqual(entry.textFile, "\(entry.id).txt")
        }
    }

    func test_summariesAndLicenseNamesArePlain() {
        for entry in LicenseCatalog.entries {
            XCTAssertFalse(entry.summary.isEmpty)
            XCTAssertFalse(entry.licenseName.isEmpty)
            for banned in ["configure", "--", "./"] {
                XCTAssertFalse(entry.summary.contains(banned), "\(entry.id) summary contains \(banned)")
                XCTAssertFalse(entry.licenseName.contains(banned), "\(entry.id) license name contains \(banned)")
            }
        }
    }

    func test_everyLockComponentMapsToACatalogueEntry() throws {
        let ids = Set(LicenseCatalog.entries.map(\.id))
        for name in try lockNames() {
            let id = try XCTUnwrap(LicenseCatalog.componentID(forLockName: name), "no catalogue entry for \(name)")
            XCTAssertTrue(ids.contains(id), "\(name) maps to unknown id \(id)")
        }
    }

    func test_shieldAndLicenseEntriesMapToTheirComponent() {
        XCTAssertEqual(LicenseCatalog.componentID(forLockName: "shield-plugin"), "shield")
        XCTAssertEqual(LicenseCatalog.componentID(forLockName: "shield-source"), "shield")
        XCTAssertEqual(LicenseCatalog.componentID(forLockName: "yt-dlp-license"), "yt-dlp")
        XCTAssertEqual(LicenseCatalog.componentID(forLockName: "sparkle-license"), "sparkle")
    }

    private func lockNames() throws -> [String] {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 {
            root.deleteLastPathComponent()
        }
        let lock = root.appendingPathComponent("scripts/tools.lock")
        let text = try String(contentsOf: lock, encoding: .utf8)
        return text
            .split(separator: "\n")
            .compactMap { $0.split(separator: " ").first.map(String.init) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}
