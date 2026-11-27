@testable import GrabberKit
import TestSupport
import XCTest

@MainActor
final class OnboardingInstallerTests: XCTestCase {
    func test_toolsMissing_blocksWithoutInstallingAnything() async {
        let runner = FakeProcessRunner()
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with()),
            runner: runner,
            isShieldInstalled: { false }
        )
        await installer.check()
        XCTAssertFalse(installer.canProceedToHome)
        XCTAssertTrue(runner.launches.isEmpty)
    }

    func test_canaryFailure_marksTheCheckFailed() async {
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            runner: FakeProcessRunner(),
            metadataProbe: FakeMetadataProbe(default: .failure(.network))
        )
        await installer.check()
        guard case .failed = installer.steps[.testRun] else {
            return XCTFail("expected the check to fail")
        }
    }

    func test_check_readyTools_marksTheCheckDoneWithoutInstalling() async {
        let runner = FakeProcessRunner()
        let probe = FakeMetadataProbe(default: FakeMetadataProbe.success(title: "ok"))
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            runner: runner,
            metadataProbe: probe,
            isShieldInstalled: { true }
        )
        await installer.check()
        XCTAssertEqual(installer.steps[.botCheckShield], .skipped)
        XCTAssertEqual(installer.steps[.testRun], .done)
        XCTAssertTrue(installer.canProceedToHome)
        XCTAssertTrue(runner.launches.isEmpty)
        XCTAssertEqual(probe.probedURLs.last, CanaryProbe.url)
    }

    func test_check_shieldMissing_isOfferedNotInstalled() async {
        let runner = FakeProcessRunner()
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            runner: runner,
            metadataProbe: FakeMetadataProbe(default: FakeMetadataProbe.success(title: "ok")),
            isShieldInstalled: { false }
        )
        await installer.check()
        XCTAssertEqual(installer.steps[.botCheckShield], .pending)
        XCTAssertTrue(installer.canProceedToHome)
        XCTAssertTrue(runner.launches.isEmpty)
    }

    func test_installShieldOnly_bundledHelper_marksTheStepDone() async {
        let installer = OnboardingInstaller(
            locations: TestLocations.make(),
            probe: FakeEnvironmentProbe(.with(ytDlp: true, ffmpeg: true)),
            runner: FakeProcessRunner(),
            shieldInstaller: ShieldInstaller(
                tools: ManagedTools.live(locations: TestLocations.make()),
                fileExists: { _ in true }
            )
        )
        await installer.installShieldOnly()
        XCTAssertEqual(installer.steps[.botCheckShield], .done)
    }
}
