import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

@MainActor
final class ScreenshotScenesTests: XCTestCase {
    private var home: URL!
    private var domain: String!

    override func setUp() async throws {
        home = TestLocations.make().home
        domain = "mg.scenes.\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: domain)
        try FileManager.default.removeItem(at: home)
    }

    private func makeStage() async throws -> ScreenshotStage {
        let locations = AppLocations(home: home, settingsDomain: domain)
        let composition = try ScreenshotComposition.make(locations: locations)
        try await ScreenshotSettingsSeed.seedHome(locations)
        composition.model.startConsumerForTesting()
        return ScreenshotStage(composition: composition)
    }

    private func scene(_ name: String) throws -> SceneSpec {
        try XCTUnwrap(ScreenshotScenes.all.first { $0.name == name }, "no scene named \(name)")
    }

    func test_namesAreUnique() {
        let names = ScreenshotScenes.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func test_everyPreferencesPaneHasAScene() {
        let names = Set(ScreenshotScenes.all.map(\.name))
        for pane in PreferencesPane.allCases {
            XCTAssertTrue(names.contains("prefs-\(pane.rawValue)"), pane.rawValue)
        }
    }

    func test_everyAboutTabHasAScene() {
        let names = Set(ScreenshotScenes.all.map(\.name))
        for tab in AboutTab.allCases {
            XCTAssertTrue(names.contains(tab.rawValue), tab.rawValue)
        }
    }

    func test_everyDialogHasAScene() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/App/AppModelDialogs.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        let pattern = /static func (\w+)\([^)]*\) -> ConfirmationRequest/
        let builders = text.matches(of: pattern).map { String($0.1) }
        XCTAssertFalse(builders.isEmpty, "no dialog builders found in the source")

        let names = Set(ScreenshotScenes.all.map(\.name))
        for builder in builders {
            let scenes = OverlayScenes.dialogScenes[builder] ?? []
            XCTAssertFalse(scenes.isEmpty, "\(builder) has no scene")
            for name in scenes {
                XCTAssertTrue(names.contains(name), "\(builder) names a missing scene \(name)")
            }
        }
    }

    func test_banners_comeFromQueueState() async throws {
        let stage = try await makeStage()
        let expected: [(String, BannerReason)] = [
            ("banner-network", .networkDown),
            ("banner-circuit", .circuitOpen),
            ("banner-shield", .potProviderDown)
        ]
        for (name, reason) in expected {
            await stage.reset()
            try await scene(name).prepare(stage)
            let hosts = reason == .circuitOpen ? ["YouTube"] : []
            XCTAssertEqual(
                stage.model.bannerContent?.text,
                bannerCopy(for: reason, circuitHosts: hosts) {}?.text,
                name
            )
        }
    }

    func test_preparedStatesSatisfyExpect() async throws {
        let stage = try await makeStage()
        for scene in ScreenshotScenes.all where scene.hooks.isEmpty {
            await stage.reset()
            await scene.prepare(stage)
            await scene.interact(stage)
            XCTAssertTrue(scene.expect(stage.model), scene.name)
        }
    }

    func test_everyFlowHasScenesAndEverySceneAFlow() {
        for flow in ScreenshotFlow.allCases {
            XCTAssertTrue(ScreenshotScenes.all.contains { $0.flow == flow }, flow.rawValue)
        }
        XCTAssertTrue(ScreenshotScenes.all.allSatisfy { $0.flow != nil })
    }

    func test_popoverAndSheetScenesRequireTheirWindow() {
        for scene in ScreenshotScenes.all {
            let hasOwnWindow = scene.flow == .popovers
                || scene.name.hasPrefix("sheet-")
                || scene.name.hasPrefix("picker-")
            XCTAssertEqual(scene.overlays, hasOwnWindow ? 1 : 0, scene.name)
        }
    }

    func test_selectedByFlow() {
        let onboarding = ScreenshotOptions(
            outputDir: URL(fileURLWithPath: "/tmp"), scene: nil, theme: nil, flow: .onboarding
        )
        XCTAssertEqual(
            ScreenshotScenes.selected(onboarding).map(\.name),
            [
                "onboarding-ready", "onboarding-shield-pending", "onboarding-shield-failed",
                "onboarding-test-failed", "onboarding-not-ready"
            ]
        )

        let elsewhere = ScreenshotOptions(
            outputDir: URL(fileURLWithPath: "/tmp"), scene: "about", theme: nil, flow: .onboarding
        )
        XCTAssertTrue(ScreenshotScenes.selected(elsewhere).isEmpty)
    }

    func test_selectedByName() {
        let one = ScreenshotOptions(outputDir: URL(fileURLWithPath: "/tmp"), scene: "about", theme: nil)
        XCTAssertEqual(ScreenshotScenes.selected(one).map(\.name), ["about"])

        let unknown = ScreenshotOptions(outputDir: URL(fileURLWithPath: "/tmp"), scene: "nonexistent", theme: nil)
        XCTAssertTrue(ScreenshotScenes.selected(unknown).isEmpty)
    }
}
