@testable import GrabberKit
import TestSupport
import XCTest

final class SmokeTests: XCTestCase {
    func test_engineProtocolIsReachable() {
        let deps = EngineDependencies.live(
            ytDlp: .fixed(URL(fileURLWithPath: "/bin/echo")),
            locations: TestLocations.make()
        )
        XCTAssertEqual(deps.ytDlpURL.lastPathComponent, "echo")
    }
}
