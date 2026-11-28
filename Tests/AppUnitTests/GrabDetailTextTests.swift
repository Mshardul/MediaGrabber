@testable import MediaGrabber
import XCTest

final class GrabDetailTextTests: XCTestCase {
    func test_summaryJoinsSizeAndLength() {
        let summary = GrabDetailText.summary(sizeBytes: 1_500_000_000, durationSeconds: 754)
        XCTAssertEqual(summary, "≈ 1.5 GB · 12:34")
    }

    func test_summaryShowsLengthAloneWhenSizeUnknown() {
        let summary = GrabDetailText.summary(sizeBytes: nil, durationSeconds: 754)
        XCTAssertEqual(summary, "12:34")
    }

    func test_summaryShowsSizeAloneWhenLengthUnknown() {
        let summary = GrabDetailText.summary(sizeBytes: 1_500_000_000, durationSeconds: nil)
        XCTAssertEqual(summary, "≈ 1.5 GB")
    }

    func test_summaryIsNilWhenNeitherKnown() {
        XCTAssertNil(GrabDetailText.summary(sizeBytes: nil, durationSeconds: nil))
    }

    func test_lengthFormatsHoursAndMinutes() {
        XCTAssertEqual(GrabDetailText.length(59), "0:59")
        XCTAssertEqual(GrabDetailText.length(754), "12:34")
        XCTAssertEqual(GrabDetailText.length(3661), "1:01:01")
    }
}
