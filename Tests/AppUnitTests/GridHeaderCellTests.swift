import AppKit
@testable import MediaGrabber
import XCTest

@MainActor
final class GridHeaderCellTests: XCTestCase {
    // AppKit copies cells without retaining Swift reference fields, so freeing the copies must not over-release.
    func test_copiedHeaderCells_canBeFreedRepeatedlyWithoutCrashing() {
        for _ in 0 ..< 50 {
            let original = GridHeaderCell(textCell: "Title")
            original.showsSort = true
            original.showsFilter = true
            autoreleasepool {
                for _ in 0 ..< 5 {
                    let copy = original.copy() as? GridHeaderCell
                    XCTAssertEqual(copy?.showsSort, true)
                    XCTAssertEqual(copy?.tokens.hairlineWidth, original.tokens.hairlineWidth)
                }
            }
        }
    }
}
