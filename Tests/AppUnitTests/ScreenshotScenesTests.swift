import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import XCTest

@MainActor
final class ScreenshotScenesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var logDirectory: URL!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "mg.screenshots.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        logDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mg-screenshots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: logDirectory)
    }

    private func makeModel(onboardingCompleted: Bool = true) -> AppModel {
        AppModelTestHelpers.makeModel(
            defaults: defaults,
            logDirectory: logDirectory,
            engine: FakeEngine(),
            envReady: true,
            onboardingCompleted: onboardingCompleted
        )
    }

    func test_namesAreUnique() {
        let names = ScreenshotScenes.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func test_everyPreferencesPaneHasAScene() {
        let prefsScenes = ScreenshotScenes.all.filter { $0.name.hasPrefix("prefs-") }
        let expectedCount = PreferencesPane.allCases.count
        XCTAssertEqual(prefsScenes.count, expectedCount)
        for pane in PreferencesPane.allCases {
            XCTAssertTrue(ScreenshotScenes.all.contains { $0.name == "prefs-\(pane.rawValue)" })
        }
    }

    func test_everyAboutTabHasAScene() {
        XCTAssertTrue(ScreenshotScenes.all.contains { $0.name == "about" })
        XCTAssertTrue(ScreenshotScenes.all.contains { $0.name == "developer" })
    }

    func test_selectedByName() {
        let options = ScreenshotOptions(
            outputDir: URL(fileURLWithPath: "/tmp"),
            scene: "about",
            theme: nil
        )
        let selected = ScreenshotScenes.selected(options)
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected[0].name, "about")

        let unknownOptions = ScreenshotOptions(
            outputDir: URL(fileURLWithPath: "/tmp"),
            scene: "nonexistent",
            theme: nil
        )
        XCTAssertTrue(ScreenshotScenes.selected(unknownOptions).isEmpty)
    }

    func test_navigatePreferencesCookies() async throws {
        let model = makeModel()
        let scene = try XCTUnwrap(ScreenshotScenes.all.first { $0.name == "prefs-cookies" })
        await scene.navigate(model)
        XCTAssertEqual(model.page, .preferences(.cookies))
    }

    func test_navigateConfirmDialog() async throws {
        let model = makeModel()
        let scene = try XCTUnwrap(ScreenshotScenes.all.first { $0.name == "dialog-confirm" })
        await scene.navigate(model)
        XCTAssertEqual(model.pendingConfirmation?.title, AppModelDialogs.removeConfirmation().title)
    }

    func test_navigateBanner() async throws {
        let model = makeModel()
        let scene = try XCTUnwrap(ScreenshotScenes.all.first { $0.name == "banner-warning" })
        await scene.navigate(model)
        XCTAssertNotNil(model.bannerContent)
    }

    func test_navigatePlaylistPicker() async throws {
        let model = makeModel()
        let scene = try XCTUnwrap(ScreenshotScenes.all.first { $0.name == "picker-playlist" })
        await scene.navigate(model)
        XCTAssertTrue(model.isPlaylistPickerPresented)
        XCTAssertEqual(model.resolved, .playlist(ScreenshotFixtures.playlistDump))
    }

    func test_navigateOnboarding() async throws {
        let model = makeModel(onboardingCompleted: false)
        let scene = try XCTUnwrap(ScreenshotScenes.all.first { $0.name == "onboarding" })
        await scene.navigate(model)
        XCTAssertTrue(model.needsOnboarding)
    }
}
