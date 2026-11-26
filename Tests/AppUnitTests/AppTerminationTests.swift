@testable import MediaGrabber
import XCTest

@MainActor
final class AppTerminationTests: XCTestCase {
    // AppKit waits for the quit reply in a nested run loop inside terminate, and the reply comes from a Task.
    func test_quitReplyCanRunWhileTerminateWaits() async {
        let finished = expectation(description: "terminate returned")
        var replied = false

        AppTermination.request {
            Task { @MainActor in replied = true }
            let deadline = Date(timeIntervalSinceNow: 2)
            while !replied, Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            }
            XCTAssertTrue(replied, "the quit reply never ran, so the app would hang")
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 5)
    }
}
