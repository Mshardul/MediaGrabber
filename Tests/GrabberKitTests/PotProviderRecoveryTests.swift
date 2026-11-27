@testable import GrabberKit
import TestSupport
import XCTest

final class PotProviderRecoveryTests: XCTestCase {
    func testCrashedChildIsRecoveredAndEndsUpRunning() async throws {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .milliseconds(50)
        var tuning = EngineTuning.default
        tuning.potRestartBackoffSeconds = 0
        tuning.potStartupWaitSeconds = 10
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: tuning,
            log: nil
        )
        await provider.ensure()
        guard case .running = await provider.status else { return XCTFail("expected first run to be running") }
        // The child exits on its own after 50ms; the provider must restart it and recover.
        try await waitUntil(timeout: .seconds(5)) {
            guard runner.launches.count >= 2, case .running = await provider.status else { return false }
            return true
        }
        await provider.stop()
    }

    func testConcurrentEnsureDoesNotOverlapChildren() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: .default,
            log: nil
        )
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await provider.ensure() }
            group.addTask { await provider.ensure() }
        }
        XCTAssertEqual(runner.launches.count, 1, "serialized ensure starts one child, the second sees it healthy")
        XCTAssertEqual(runner.maxConcurrent, 1, "two starts must never run a child at the same time")
        await provider.stop()
    }

    func testRestartDuringStartupDoesNotStrandStatus() async {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .seconds(60)
        var tuning = EngineTuning.default
        tuning.potStartupWaitSeconds = 10
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FlakyPinger(failuresBeforeSuccess: 3),
            tuning: tuning,
            log: nil
        )
        let first = Task { await provider.ensure() }
        let second = Task { await provider.restart() }
        await first.value
        await second.value
        let finalStatus = await provider.status
        guard case .running = finalStatus
        else { return XCTFail("expected running after overlap, got \(finalStatus)") }
        await provider.stop()
    }

    func testStopDuringCrashBackoff_leavesStatusDown() async throws {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .milliseconds(100)
        var tuning = EngineTuning.default
        tuning.potRestartBackoffSeconds = 30
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: FakePinger(true),
            tuning: tuning,
            log: nil
        )
        await provider.ensure()
        try await waitUntil(timeout: .seconds(5)) { await provider.status == .restarting }
        await provider.stop()
        let status = await provider.status
        XCTAssertEqual(status, .down)
        XCTAssertEqual(runner.launches.count, 1)
    }

    func testStopQueuedBeforeCrashRecovery_neverRelaunches() async throws {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .milliseconds(300)
        var tuning = EngineTuning.default
        tuning.potRestartBackoffSeconds = 0
        let pinger = GatedPinger()
        let provider = PotProviderProcess(
            installer: PotInstallerFixtures.bgutil(),
            runner: runner,
            pinger: pinger,
            tuning: tuning,
            log: nil
        )
        await provider.ensure()
        pinger.close()
        // A health check holds the lifecycle queue while stop waits behind it and the child exits.
        let check = Task { await provider.ensure() }
        try await Task.sleep(for: .milliseconds(50))
        let stop = Task { await provider.stop() }
        try await Task.sleep(for: .milliseconds(600))
        pinger.open()
        await check.value
        await stop.value
        try await Task.sleep(for: .milliseconds(300))
        let status = await provider.status
        XCTAssertEqual(status, .down)
        XCTAssertEqual(runner.launches.count, 1, "nothing may start after stop")
    }

    private func waitUntil(
        timeout: Duration,
        _ condition: @escaping () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        if await condition() {
            return
        }
        throw TimeoutError()
    }

    private struct TimeoutError: Error {}
}

private final class GatedPinger: ShieldPinging, Sendable {
    private let isOpen = LockedBox(true)

    func open() {
        isOpen.mutate { $0 = true }
    }

    func close() {
        isOpen.mutate { $0 = false }
    }

    func ping(_: URL, timeout _: TimeInterval, maxUptime _: TimeInterval) async -> Bool {
        while !isOpen.read({ $0 }) {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }
}
