import Foundation
import XCTest

final class HomeAccessGuardTests: XCTestCase {
    private let forbidden = [
        "homeDirectoryForCurrentUser",
        "NSHomeDirectory(",
        "urls(for: .libraryDirectory",
        "urls(for: .applicationSupportDirectory",
        "urls(for: .downloadsDirectory",
        "urls(for: .userDirectory"
    ]

    func testNoSourceOutsideAppLocationsReadsTheHome() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        let allowed = sources.appendingPathComponent("GrabberKit/App/AppLocations.swift").path
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var hits: [String] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" && file.path != allowed {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where forbidden.contains(where: line.contains) {
                hits.append("\(file.path):\(index + 1)")
            }
        }
        XCTAssertEqual(hits, [], "Only AppLocations may read the real home")
    }
}
