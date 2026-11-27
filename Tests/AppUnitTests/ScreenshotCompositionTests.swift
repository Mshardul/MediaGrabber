import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

@MainActor
final class ScreenshotCompositionTests: XCTestCase {
    private var home: URL!
    private var domain: String!

    override func setUp() async throws {
        home = TestLocations.make().home
        domain = "mg.composition.\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: domain)
        try FileManager.default.removeItem(at: home)
    }

    private func compose() throws -> ScreenshotComposition {
        try ScreenshotComposition.make(locations: AppLocations(home: home, settingsDomain: domain))
    }

    func test_makeRefusesRealHome() {
        XCTAssertThrowsError(try ScreenshotComposition.make(locations: AppLocations(home: home))) { error in
            XCTAssertEqual(error as? ScreenshotCompositionError, .homeNotIsolated)
        }
    }

    func test_clipboardIsNeverRead() async throws {
        let composition = try compose()

        await composition.incomingLinks.applicationDidBecomeActive()
        await composition.incomingLinks.pollPasteboard()

        XCTAssertEqual(composition.pasteboard.readCount, 2, "the link checks must reach the dummy clipboard")
        XCTAssertEqual(composition.model.homeFieldText, "")
        XCTAssertNil(composition.model.pendingConfirmation)
    }

    func test_noMoveOffer() throws {
        XCTAssertTrue(try compose().model.canReplaceItself)
    }
}
