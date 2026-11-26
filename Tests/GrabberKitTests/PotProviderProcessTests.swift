@testable import GrabberKit
import TestSupport
import XCTest

final class PotProviderProcessTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/mg-pot-proc-home")

    private func bgutilInstaller() -> PotPluginInstaller {
        let node = URL(fileURLWithPath: "/bundle/Resources/Tools/node")
        let mainJS = URL(fileURLWithPath: "/bundle/Resources/Shield/server/build/main.js")
        return PotPluginInstaller(
            pluginDestination: home.appendingPathComponent("Library/Application Support/MediaGrabber/yt-dlp-plugins"),
            tools: ManagedTools(
                resourceRoot: URL(fileURLWithPath: "/bundle/Resources"),
                supportRoot: home.appendingPathComponent("Library/Application Support/MediaGrabber"),
                isExecutable: { _ in false }
            ),
            isExecutable: { $0 == node },
            fileExists: { $0 == node || $0 == mainJS },
            pluginStore: FakePluginStore()
        )
    }

    private func emptyInstaller() -> PotPluginInstaller {
        PotPluginInstaller(
            pluginDestination: home.appendingPathComponent("Library/Application Support/MediaGrabber/yt-dlp-plugins"),
            tools: ManagedTools(
                resourceRoot: URL(fileURLWithPath: "/bundle/Resources"),
                supportRoot: home.appendingPathComponent("Library/Application Support/MediaGrabber"),
                isExecutable: { _ in false }
            ),
            isExecutable: { _ in false },
            fileExists: { _ in false },
            pluginStore: FakePluginStore()
        )
    }

    func testEnsureMissingWhenInstallerFindsNothing() async {
        let runner = FakeProcessRunner()
        let provider = PotProviderProcess(
            installer: emptyInstaller(),
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
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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

    func testShieldReplyValidation() {
        let ok = Data("{\"server_uptime\": 1.5, \"version\": \"2.0.2\"}".utf8)
        XCTAssertTrue(isOwnReply(200, ok))
        XCTAssertFalse(isOwnReply(404, ok))
        XCTAssertFalse(isOwnReply(200, Data("not json".utf8)))
        XCTAssertFalse(isOwnReply(200, Data("{\"server_uptime\": 1}".utf8)))
        XCTAssertFalse(isOwnReply(200, Data("{\"version\": \"2.0.2\"}".utf8)))
    }

    func testReplyFromAServerOlderThanTheChildIsRejected() {
        let older = Data("{\"server_uptime\": 3600, \"version\": \"2.0.2\"}".utf8)
        XCTAssertFalse(isOwnReply(200, older))
    }

    func testPortCheckSeesALoopbackListener() throws {
        let listener = try TestListener(address: "127.0.0.1")
        XCTAssertFalse(LoopbackPortChecker().isFree(listener.port))
    }

    func testPortCheckSeesAnAllInterfacesListener() throws {
        let listener = try TestListener(address: "0.0.0.0")
        XCTAssertFalse(LoopbackPortChecker().isFree(listener.port))
    }

    func testPortCheckReportsAClosedPortFree() throws {
        let port = try TestListener(address: "127.0.0.1").port
        XCTAssertTrue(LoopbackPortChecker().isFree(port))
    }

    private func isOwnReply(_ status: Int, _ body: Data) -> Bool {
        URLSessionShieldPinger.isOwnChildReply(statusCode: status, body: body, maxUptime: 5)
    }

    func testCrashedChildIsRecoveredAndEndsUpRunning() async throws {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .milliseconds(50)
        var tuning = EngineTuning.default
        tuning.potRestartBackoffSeconds = 0
        tuning.potStartupWaitSeconds = 10
        let provider = PotProviderProcess(
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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
        else { return await XCTFail("expected running after overlap, got \(finalStatus)") }
        await provider.stop()
    }

    func testStopDuringCrashBackoff_leavesStatusDown() async throws {
        let runner = FakeProcessRunner()
        runner.perRunDelay = .milliseconds(100)
        var tuning = EngineTuning.default
        tuning.potRestartBackoffSeconds = 30
        let provider = PotProviderProcess(
            installer: bgutilInstaller(),
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
            installer: bgutilInstaller(),
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

private final class TestListener {
    let port: Int
    private let descriptor: Int32

    init(address host: String) throws {
        descriptor = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr(host)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let descriptor = descriptor
        let ready = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { raw in
                bind(descriptor, raw, length) == 0 && listen(descriptor, 1) == 0
                    && getsockname(descriptor, raw, &length) == 0
            }
        }
        guard ready else { throw POSIXError(.EADDRNOTAVAIL) }
        port = Int(in_port_t(bigEndian: address.sin_port))
    }

    deinit {
        close(descriptor)
    }
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

private struct FixedPortChecker: LoopbackPortChecking {
    let free: Set<Int>

    func isFree(_ port: Int) -> Bool {
        free.contains(port)
    }
}

private final class FlakyPinger: ShieldPinging, @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: Int

    init(failuresBeforeSuccess: Int) {
        remaining = failuresBeforeSuccess
    }

    func ping(_: URL, timeout _: TimeInterval, maxUptime _: TimeInterval) async -> Bool {
        lock.withLock {
            guard remaining > 0 else { return true }
            remaining -= 1
            return false
        }
    }
}
