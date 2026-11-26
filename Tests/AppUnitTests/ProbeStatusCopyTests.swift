@testable import MediaGrabber
import XCTest

final class ProbeStatusCopyTests: XCTestCase {
    func test_onlyZoomLinksWarnThatTheCheckIsSlow() {
        for link in ["https://zoom.us/rec/share/a", " https://school.zoom.us/rec/share/a\n"] {
            XCTAssertEqual(ProbeStatusCopy.message(for: link), ProbeStatusCopy.checkingZoom, link)
        }
        for link in ["https://youtube.com/watch?v=a", "https://notzoom.us.example.com/a", ""] {
            XCTAssertEqual(ProbeStatusCopy.message(for: link), ProbeStatusCopy.checking, link)
        }
    }
}
