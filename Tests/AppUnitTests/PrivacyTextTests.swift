@testable import MediaGrabber
import XCTest

final class PrivacyTextTests: XCTestCase {
    func test_loadReturnsBundleContents() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mg-privacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("private and personal\n".utf8).write(to: folder.appendingPathComponent("Privacy.txt"))

        let bundle = try XCTUnwrap(Bundle(url: folder))
        XCTAssertEqual(PrivacyText.load(from: bundle), "private and personal\n")
    }

    func test_loadReturnsNilWhenAbsent() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mg-privacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let bundle = try XCTUnwrap(Bundle(url: folder))
        XCTAssertNil(PrivacyText.load(from: bundle))
    }
}
