@testable import GrabberKit
import TestSupport
import XCTest

final class PotProviderProcessTests: XCTestCase {
    func testEnsureMissingWhenInstallerFindsNothing() async {
        let runner = FakeProcessRunner()
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.empty(),
            runner: runner,
            pinger: FakePinger(false),
            tuning: .default,
            log: nil
        )
        await provider.ensure()
        let status = await provider.status
        XCTAssertEqual(status, .missing)
        XCTAssertTrue(runner.launches.isEmpty)
    }

    func testEnsureRunningWhenPingSucceeds() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: .default,
            log: nil
        )
        await provider.ensure()
        let status = await provider.status
        XCTAssertEqual(status, .running(port: 4416))
        XCTAssertEqual(runner.launches.count, 1)
        await provider.stop()
    }

    private var noStartupWait: EngineTuning {
        var tuning = EngineTuning.default
        tuning.potStartupWaitSeconds = 0
        return tuning
    }

    func testEnsureDownWhenPingFails() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(false),
            tuning: noStartupWait,
            log: nil
        )
        await provider.ensure()
        let status = await provider.status
        XCTAssertEqual(status, .down)
        await provider.stop()
    }

    func testRestartIncrementsLaunches() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: .default,
            log: nil
        )
        await provider.ensure()
        await provider.restart()
        XCTAssertEqual(runner.launches.count, 2)
        await provider.stop()
    }

    func testSlowStartingServer_isWaitedForAndEndsUpRunning() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        var tuning = EngineTuning.default
        tuning.potStartupWaitSeconds = 10
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FlakyPinger(failuresBeforeSuccess: 2),
            tuning: tuning,
            log: nil
        )
        await provider.ensure()
        let status = await provider.status
        guard case .running = status else { return XCTFail("expected running, got \(status)") }
        await provider.stop()
    }

    func testNoFreePort_goesDownAndLogsWithoutLaunching() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let log = LogWriter(directory: root, clock: { Date(timeIntervalSince1970: 1_700_000_000) })
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: .default,
            log: log,
            portChecker: FixedPortChecker(free: [])
        )
        await provider.ensure()
        let status = await provider.status
        XCTAssertEqual(status, .down)
        XCTAssertTrue(runner.launches.isEmpty)
        let text = try String(contentsOf: root.appendingPathComponent("app.log"), encoding: .utf8)
        XCTAssertTrue(text.contains("shield.no_free_port"), text)
    }

    func testFirstFreePortIsUsedWhenLowerPortsAreTaken() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: .default,
            log: nil,
            portChecker: FixedPortChecker(free: [4417])
        )
        await provider.ensure()
        let status = await provider.status
        XCTAssertEqual(status, .running(port: 4417))
        await provider.stop()
    }
}

private struct FixedPortChecker: LoopbackPortChecking {
    let free: Set<Int>

    func isFree(_ port: Int) -> Bool {
        free.contains(port)
    }
}
