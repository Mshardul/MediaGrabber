import Foundation
@testable import MediaGrabber
import XCTest

@MainActor
final class ScreenshotOptionsTests: XCTestCase {
    func test_noFlag_returnsNil() {
        let result = ScreenshotOptions.parse(["MediaGrabber"])
        XCTAssertNil(result)
    }

    func test_outputDirOnly() {
        let result = ScreenshotOptions.parse(["x", "-MGScreenshots", "/tmp/out"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.outputDir, URL(fileURLWithPath: "/tmp/out"))
        XCTAssertNil(result?.scene)
        XCTAssertNil(result?.theme)
    }

    func test_sceneAndTheme() {
        let result = ScreenshotOptions.parse([
            "x",
            "-MGScreenshots",
            "/tmp/out",
            "-MGScreenshotScene",
            "about",
            "-MGScreenshotTheme",
            "tapeDeck"
        ])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.outputDir, URL(fileURLWithPath: "/tmp/out"))
        XCTAssertEqual(result?.scene, "about")
        XCTAssertEqual(result?.theme, .tapeDeck)
    }

    func test_flow() {
        let result = ScreenshotOptions.parse(["x", "-MGScreenshots", "/tmp/out", "-MGScreenshotFlow", "onboarding"])
        XCTAssertEqual(result?.flow, .onboarding)
    }

    func test_unknownFlow_returnsNil() {
        XCTAssertNil(ScreenshotOptions.parse(["x", "-MGScreenshots", "/tmp/out", "-MGScreenshotFlow", "nowhere"]))
    }

    func test_unknownTheme_returnsNil() {
        let result = ScreenshotOptions.parse(["x", "-MGScreenshots", "/tmp/out", "-MGScreenshotTheme", "neon"])
        XCTAssertNil(result)
    }

    func test_flagWithoutValue_returnsNil() {
        let result = ScreenshotOptions.parse(["x", "-MGScreenshots"])
        XCTAssertNil(result)
    }
}
