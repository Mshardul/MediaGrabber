@testable import GrabberKit
import XCTest

final class QueueLoadNoticeTests: XCTestCase {
    private let file = URL(fileURLWithPath: "/tmp/queue.json.corrupt")

    private func notice(_ cause: QueueLoadNotice.Cause, copied: Bool) -> QueueLoadNotice {
        QueueLoadNotice(cause: cause, copied: copied, fileURL: file)
    }

    func test_copiedSentenceNamesTheRealCause() {
        let ending = ", so MediaGrabber started with an empty list. A copy of the old list was saved."
        XCTAssertEqual(notice(.damaged, copied: true).sentence, "Your download list was damaged" + ending)
        XCTAssertEqual(
            notice(.newerVersion, copied: true).sentence,
            "Your download list was made by a newer version of MediaGrabber" + ending
        )
        XCTAssertEqual(notice(.unopenable, copied: true).sentence, "Your download list couldn't be opened" + ending)
        XCTAssertEqual(notice(.damaged, copied: true).actionTitle, "Show copy")
    }

    func test_uncopiedSentenceNeverClaimsACopy() {
        XCTAssertEqual(
            notice(.unopenable, copied: false).sentence,
            "Your download list couldn't be opened and no copy could be made. The old file is left as it is, "
                + "so changes to the list won't be saved. Move that file somewhere safe, then reopen MediaGrabber."
        )
        XCTAssertEqual(notice(.unopenable, copied: false).actionTitle, "Show file")
    }
}
