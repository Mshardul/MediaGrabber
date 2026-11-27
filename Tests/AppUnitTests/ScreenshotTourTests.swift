import AppKit
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

private struct CaptureFailed: Error, CustomStringConvertible {
    var description: String {
        "no picture"
    }
}

@MainActor
final class ScreenshotTourTests: XCTestCase {
    private final class FakeWindow: ScreenshotWindow {
        private(set) var saved: [URL] = []
        var failsToSave = false
        var onSave: (URL) -> Void = { _ in }
        var overlayCount = 0
        var failsToPrepare = false
        private(set) var prepared = 0

        func place(contentSize _: CGSize) {}
        func settle() async {}

        func prepare() throws {
            if failsToPrepare {
                throw CaptureFailed()
            }
            prepared += 1
        }

        func saveImage(to url: URL) async throws {
            if failsToSave {
                throw CaptureFailed()
            }
            saved.append(url)
            onSave(url)
        }

        // "theme/scene" for each picture, in the order taken.
        var pictures: [String] {
            saved.map { "\($0.deletingLastPathComponent().lastPathComponent)/\($0.lastPathComponent)" }
        }
    }

    private var home: URL!
    private var output: URL!
    private var domain: String!
    private var composition: ScreenshotComposition!
    private var window: FakeWindow!
    private var lines: [String] = []

    override func setUp() async throws {
        home = TestLocations.make().home
        output = home.appendingPathComponent("out", isDirectory: true)
        domain = "mg.tour.\(UUID().uuidString)"
        composition = try ScreenshotComposition.make(locations: AppLocations(home: home, settingsDomain: domain))
        composition.model.startConsumerForTesting()
        window = FakeWindow()
        lines = []
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: domain)
        try FileManager.default.removeItem(at: home)
    }

    private func tour(
        scene: String? = nil,
        theme: ThemeKind? = nil,
        scenes: [SceneSpec] = ScreenshotScenes.all
    ) -> ScreenshotTour {
        ScreenshotTour(
            composition: composition,
            options: ScreenshotOptions(outputDir: output, scene: scene, theme: theme),
            window: window,
            scenes: scenes,
            hookTimeout: .milliseconds(200),
            say: { self.lines.append($0) }
        )
    }

    private var failureLine: String {
        lines.first { $0.hasPrefix("tour-fail ") || $0.hasPrefix("tour-abort ") } ?? ""
    }

    private var saidFinished: Bool {
        lines.contains("tour-finished")
    }

    func test_runsEachSceneOncePerTheme() async throws {
        let code = await tour(scene: "about").run()

        XCTAssertEqual(code, 0)
        XCTAssertEqual(window.pictures, ["aurora/about.png", "tapeDeck/about.png"])
        XCTAssertEqual(lines, [
            "tour-plan 2",
            "tour-start 1 aurora/about.png", "tour-pass 1",
            "tour-start 2 tapeDeck/about.png", "tour-pass 2",
            "tour-finished"
        ])
        let written = try String(contentsOf: output.appendingPathComponent("settings.domain"), encoding: .utf8)
        XCTAssertEqual(written, domain)
    }

    func test_oneFailureDoesNotStopTheRunOrShiftNumbers() async {
        let scenes = [
            SceneSpec(name: "first", expect: { _ in true }),
            SceneSpec(name: "second", expect: { _ in false }),
            SceneSpec(name: "third", expect: { _ in true })
        ]

        let code = await tour(theme: .aurora, scenes: scenes).run()

        XCTAssertEqual(code, 1, "a run with a failed screen must not report success")
        XCTAssertEqual(window.pictures, ["aurora/first.png", "aurora/third.png"])
        XCTAssertEqual(lines, [
            "tour-plan 3",
            "tour-start 1 aurora/first.png", "tour-pass 1",
            "tour-start 2 aurora/second.png", "tour-fail 2 the expected state was not reached",
            "tour-start 3 aurora/third.png", "tour-pass 3",
            "tour-finished"
        ])
    }

    func test_themeOptionRunsOneTheme() async {
        _ = await tour(scene: "about", theme: .tapeDeck).run()

        XCTAssertEqual(window.pictures, ["tapeDeck/about.png"])
        XCTAssertEqual(composition.model.prefs.palette, .tapeDeckA)
    }

    func test_missingHookFailsAndNamesIt() async {
        let scene = SceneSpec(name: "broken", hooks: ["nope"], expect: { _ in true })

        let code = await tour(theme: .aurora, scenes: [scene]).run()

        XCTAssertEqual(code, 1)
        XCTAssertTrue(window.saved.isEmpty)
        XCTAssertTrue(failureLine.hasPrefix("tour-fail 1 "), failureLine)
        XCTAssertTrue(failureLine.contains("nope"), failureLine)
    }

    func test_failedExpectationFails() async {
        let scene = SceneSpec(name: "wrong", expect: { _ in false })

        let code = await tour(theme: .aurora, scenes: [scene]).run()

        XCTAssertEqual(code, 1)
        XCTAssertTrue(window.saved.isEmpty)
        XCTAssertTrue(failureLine.hasPrefix("tour-fail 1 "), failureLine)
    }

    func test_captureFailureFailsAndSaysWhy() async {
        window.failsToSave = true

        let code = await tour(scene: "about", theme: .aurora).run()

        XCTAssertEqual(code, 1)
        XCTAssertEqual(failureLine, "tour-fail 1 no picture")
    }

    func test_missingPopoverFails() async {
        let scene = SceneSpec(name: "popover", overlays: 1, expect: { _ in true })

        let code = await tour(theme: .aurora, scenes: [scene]).run()

        XCTAssertEqual(code, 1)
        XCTAssertTrue(window.saved.isEmpty, "a picture without its popover must not be saved")
        XCTAssertTrue(failureLine.contains("popover or sheet"), failureLine)
    }

    func test_popoverOnScreenIsCaptured() async {
        window.overlayCount = 1
        let scene = SceneSpec(name: "popover", overlays: 1, expect: { _ in true })

        let code = await tour(theme: .aurora, scenes: [scene]).run()

        XCTAssertEqual(code, 0)
        XCTAssertEqual(window.pictures, ["aurora/popover.png"])
    }

    func test_failedWindowSetupStopsBeforeAnyPicture() async {
        window.failsToPrepare = true

        let code = await tour(scene: "about").run()

        XCTAssertEqual(code, 1)
        XCTAssertTrue(window.saved.isEmpty)
        XCTAssertEqual(lines, ["tour-abort no picture"])
        XCTAssertFalse(saidFinished)
    }

    // A macOS update that drops a method must fail the run rather than save grey controls.
    func test_missingAppearanceMethodIsNamed() {
        XCTAssertThrowsError(try ForcedActiveAppearance.apply(["_noSuchAppearanceMethod"])) { error in
            XCTAssertTrue("\(error)".contains("_noSuchAppearanceMethod"), "\(error)")
        }
    }

    func test_thisSystemHasTheAppearanceMethods() {
        for name in ForcedActiveAppearance.methods {
            XCTAssertNotNil(class_getInstanceMethod(NSWindow.self, NSSelectorFromString(name)), name)
        }
    }

    func test_unknownSceneFails() async {
        let code = await tour(scene: "zzz").run()

        XCTAssertEqual(code, 1)
        XCTAssertTrue(failureLine.hasPrefix("tour-abort "), failureLine)
        XCTAssertTrue(failureLine.contains("zzz"), failureLine)
    }

    func test_sceneStateDoesNotLeak() async throws {
        let scenes = try ["dialog-remove", "about"].map { name in
            try XCTUnwrap(ScreenshotScenes.all.first { $0.name == name })
        }
        var dialogs: [String?] = []
        let model = composition.model
        window.onSave = { _ in dialogs.append(model.pendingConfirmation?.title) }

        let code = await tour(theme: .aurora, scenes: scenes).run()

        XCTAssertEqual(code, 0)
        XCTAssertEqual(dialogs, ["Remove this download?", nil])
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
