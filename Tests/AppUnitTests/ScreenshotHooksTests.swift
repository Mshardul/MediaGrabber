import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import XCTest

@MainActor
final class ScreenshotHooksTests: XCTestCase {
    private let hooks = ScreenshotHooks()

    override func tearDown() async throws {
        ScreenshotMode.isActive = false
    }

    func test_fireRunsRegisteredAction() async {
        var runs = 0
        hooks.register("a") { runs += 1 }

        let fired = await hooks.fire("a")

        XCTAssertTrue(fired)
        XCTAssertEqual(runs, 1)
    }

    func test_fireUnknownReturnsFalse() async {
        let fired = await hooks.fire("nope")
        XCTAssertFalse(fired)
    }

    func test_unregisterRemoves() async {
        hooks.register("a") {}
        hooks.unregister("a")

        let fired = await hooks.fire("a")

        XCTAssertFalse(fired)
        XCTAssertTrue(hooks.registeredIDs.isEmpty)
    }

    func test_latestRegistrationWins() async {
        var ran: [String] = []
        let first = hooks.register("a") { ran.append("first") }
        hooks.register("a") { ran.append("second") }
        hooks.unregister("a", token: first)

        let fired = await hooks.fire("a")

        XCTAssertTrue(fired, "a replaced view going away must not remove its successor")
        XCTAssertEqual(ran, ["second"])
    }

    func test_motionIsFrozenInScreenshotMode() {
        let motif = MotifView(isActive: true, size: 10)
        let strip = HealthStrip(chips: [])
        XCTAssertTrue(motif.isSpinning(reduceMotion: false))

        ScreenshotMode.isActive = true

        XCTAssertFalse(motif.isSpinning(reduceMotion: false))
        XCTAssertFalse(strip.isPulsing(.busy, reduceMotion: false))
        XCTAssertFalse(strip.isSpinning(true, reduceMotion: false))
    }
}
