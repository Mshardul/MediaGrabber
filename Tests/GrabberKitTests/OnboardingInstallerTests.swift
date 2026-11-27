@testable import GrabberKit
import TestSupport
import XCTest

@MainActor
final class OnboardingInstallerTests: XCTestCase {
    func test_toolsMissing_blocksWithoutRunningTheTest() async {
        let probed = LockedBox<[URL]>([])
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with()),
            makeCanaryProbe: { url in
                probed.mutate { $0.append(url) }
                return FakeMetadataProbe()
            },
            isShieldInstalled: { false }
        )
        await installer.check()
        XCTAssertFalse(installer.canProceedToHome)
        XCTAssertEqual(installer.steps[.testRun], .pending)
        XCTAssertTrue(probed.read { $0 }.isEmpty)
    }

    func test_canaryFailure_marksTheCheckFailed() async {
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            makeCanaryProbe: { _ in FakeMetadataProbe(default: .failure(.network)) }
        )
        await installer.check()
        guard case .failed = installer.steps[.testRun] else {
            return XCTFail("expected the check to fail")
        }
    }

    func test_check_readyTools_marksTheCheckDoneWithoutInstalling() async {
        let probed = LockedBox<[URL]>([])
        let probe = FakeMetadataProbe(default: FakeMetadataProbe.success(title: "ok"))
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            makeCanaryProbe: { url in
                probed.mutate { $0.append(url) }
                return probe
            },
            isShieldInstalled: { true }
        )
        await installer.check()
        XCTAssertEqual(installer.steps[.botCheckShield], .skipped)
        XCTAssertEqual(installer.steps[.testRun], .done)
        XCTAssertTrue(installer.canProceedToHome)
        XCTAssertEqual(probed.read { $0.map(\.lastPathComponent) }, ["yt-dlp"])
        XCTAssertEqual(probe.probedURLs.last, CanaryProbe.url)
    }

    func test_check_shieldMissing_isOfferedNotInstalled() async {
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            makeCanaryProbe: { _ in FakeMetadataProbe(default: FakeMetadataProbe.success(title: "ok")) },
            isShieldInstalled: { false }
        )
        await installer.check()
        XCTAssertEqual(installer.steps[.botCheckShield], .pending)
        XCTAssertTrue(installer.canProceedToHome)
    }

    func test_installShieldOnly_bundledHelper_marksTheStepDone() async {
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            shieldInstaller: ShieldInstaller(
                tools: ManagedTools.live(locations: TestLocations.make()),
                fileExists: { _ in true }
            )
        )
        await installer.installShieldOnly()
        XCTAssertEqual(installer.steps[.botCheckShield], .done)
    }
}
