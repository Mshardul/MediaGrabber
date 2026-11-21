import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import XCTest

@MainActor
final class ScreenshotHandoffTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mg-handoff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func test_announceReady_writesOneIDPerLine() throws {
        let handoff = ScreenshotHandoff(dir: dir)
        try handoff.announceReady(key: "aurora-about", windowIDs: [12, 34])

        let readyURL = dir.appendingPathComponent("aurora-about.ready")
        let content = try String(contentsOf: readyURL, encoding: .utf8)
        XCTAssertEqual(content, "12\n34\n")
    }

    func test_waitForDone_returnsWhenDoneFileAppears() async throws {
        let handoff = ScreenshotHandoff(dir: dir, timeout: 5, pollInterval: 0.05)

        Task.detached {
            try await Task.sleep(for: .milliseconds(100))
            let doneURL = self.dir.appendingPathComponent("aurora-about.done")
            try "".write(to: doneURL, atomically: true, encoding: .utf8)
        }

        try await handoff.waitForDone(key: "aurora-about")
    }

    func test_waitForDone_timesOut() async {
        let handoff = ScreenshotHandoff(dir: dir, timeout: 0.2, pollInterval: 0.05)

        do {
            try await handoff.waitForDone(key: "aurora-about")
            XCTFail("Expected timeout")
        } catch ScreenshotHandoffError.timedOut(let key) {
            XCTAssertEqual(key, "aurora-about")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_finish_writesFinishedMarker() throws {
        let handoff = ScreenshotHandoff(dir: dir)
        try handoff.finish()

        let finishedURL = dir.appendingPathComponent("tour.finished")
        XCTAssertTrue(FileManager.default.fileExists(atPath: finishedURL.path))
    }

    func test_fail_writesKeyThenReason() throws {
        let handoff = ScreenshotHandoff(dir: dir)
        try handoff.fail(key: "aurora-about", reason: "never settled")

        let failedURL = dir.appendingPathComponent("tour.failed")
        let content = try String(contentsOf: failedURL, encoding: .utf8)
        XCTAssertEqual(content, "aurora-about\nnever settled\n")
    }
}