@testable import MediaGrabber
import XCTest

final class DeveloperLinksTests: XCTestCase {
    func test_linksPointAtMediaGrabberRepository() {
        XCTAssertEqual(
            DeveloperLinks.sourceCode,
            URL(string: "https://github.com/Mshardul/MediaGrabber")!
        )
        XCTAssertEqual(
            DeveloperLinks.issues,
            URL(string: "https://github.com/Mshardul/MediaGrabber/issues")!
        )
        XCTAssertEqual(
            DeveloperLinks.license,
            URL(string: "https://github.com/Mshardul/MediaGrabber/blob/main/LICENSE")!
        )
    }
}
