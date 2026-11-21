import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import XCTest

@MainActor
final class ScreenshotTourTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var logDirectory: URL!

    override func setUp() async throws {
        suiteName = "mg.tour.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        logDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mg-tour-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: logDirectory)
    }

    private func makeModel() -> AppModel {
        AppModelTestHelpers.makeModel(
            defaults: defaults,
            logDirectory: logDirectory,
            engine: FakeEngine(),
            envReady: true
        )
    }

    func test_runScene_navigatesAndReturnsModel() async throws {
        let model = makeModel()
        let scene = try XCTUnwrap(ScreenshotScenes.all.first { $0.name == "prefs-downloads" })

        await ScreenshotTour.runScene(scene, model: model)

        XCTAssertEqual(model.page, .preferences(.downloads))
    }

    func test_runScene_withUnknownScene_doesNothing() async {
        let model = makeModel()
        let unknownScene = SceneSpec(name: "nonexistent") { _ in }

        await ScreenshotTour.runScene(unknownScene, model: model)

        XCTAssertEqual(model.page, .home)
    }

    func test_outputURLForScene_createsCorrectPath() {
        let outputDir = URL(fileURLWithPath: "/screenshots")
        let url = ScreenshotTour.outputURLForScene(
            scene: "prefs-downloads",
            theme: .tapeDeck,
            outputDir: outputDir
        )

        XCTAssertEqual(url.lastPathComponent, "prefs-downloads.png")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "tapeDeck")
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "screenshots")
    }

    func test_outputURLForScene_sanitizesSceneName() {
        let outputDir = URL(fileURLWithPath: "/screenshots")
        let url = ScreenshotTour.outputURLForScene(
            scene: "prefs/advanced",
            theme: .aurora,
            outputDir: outputDir
        )

        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("prefs"))
    }
}
