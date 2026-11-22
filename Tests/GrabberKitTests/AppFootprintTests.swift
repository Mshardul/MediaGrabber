@testable import GrabberKit
import TestSupport
import XCTest

final class AppFootprintTests: XCTestCase {
    func testRemoveDeletesEveryFootprintDirectoryUnderFakeHome() throws {
        let locations = TestLocations.make()
        let files = FileManager.default
        for directory in locations.footprintDirectories {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try files.createDirectory(
            at: locations.preferenceFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("p".utf8).write(to: locations.preferenceFile)
        let sibling = locations.home.appendingPathComponent("keep.txt")
        try Data("k".utf8).write(to: sibling)

        try AppFootprint.remove(in: locations)

        for directory in locations.footprintDirectories {
            XCTAssertFalse(files.fileExists(atPath: directory.path))
        }
        XCTAssertFalse(files.fileExists(atPath: locations.preferenceFile.path))
        XCTAssertTrue(files.fileExists(atPath: sibling.path))
    }
}
