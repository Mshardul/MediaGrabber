import Foundation

actor PotProviderProcess: PotProviding {
    private let installer: PotPluginInstaller
    private let runner: ProcessRunning
    private let pinger: any ShieldPinging
    private let tuning: EngineTuning
    private let log: LogWriter?
    private let portChecker: any LoopbackPortChecking

    private var statusValue: ShieldStatus = .missing
    private var childTask: Task<Void, Never>?
    private var childStartedAt = ContinuousClock.now
    private var generation = 0
    private var exitCount = 0

    // Actors are reentrant across `await`, so start, restart, stop and crash recovery are chained through this.
    private var tail: Task<Void, Never> = Task {}

    init(
        installer: PotPluginInstaller,
        runner: ProcessRunning,
        pinger: any ShieldPinging,
        tuning: EngineTuning,
        log: LogWriter?,
        portChecker: any LoopbackPortChecking = AlwaysFreePortChecker()
    ) {
        self.installer = installer
        self.runner = runner
        self.pinger = pinger
        self.tuning = tuning
        self.log = log
        self.portChecker = portChecker
    }

    var status: ShieldStatus {
        statusValue
    }

    var baseURL: URL? {
        guard case let .running(port) = statusValue else {
            return nil
        }
        return URL(string: "http://127.0.0.1:\(port)")
    }

    var pluginDirs: [URL] {
        installer.pluginDirs()
    }

    func ensure() async {
        await enqueue { await self.ensureSerialized() }
    }

    func restart() async {
        await enqueue { await self.restartSerialized() }
    }

    func stop() async {
        await enqueue { await self.stopSerialized() }
    }

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) async {
        let predecessor = tail
        let work = Task {
            await predecessor.value
            await operation()
        }
        tail = Task { _ = await work.value }
        await work.value
    }

    private func ensureSerialized() async {
        if await isHealthyRunning() {
            return
        }
        await startChild()
    }

    private func restartSerialized() async {
        stopSerialized()
        statusValue = .restarting
        await logEvent(.shieldRestarted(reason: "user"))
        await startChild()
    }

    private func stopSerialized() {
        abandonChild()
        switch statusValue {
        case .running, .restarting: statusValue = .down
        case .down, .missing: break
        }
    }

    private func isHealthyRunning() async -> Bool {
        guard case let .running(port) = statusValue, let url = pingURL(port: port) else {
            return false
        }
        return await pingChild(url)
    }

    private func pingChild(_ url: URL) async -> Bool {
        let age = childStartedAt.duration(to: .now).components
        // One second of slack covers the two clocks rounding differently.
        let maxUptime = TimeInterval(age.seconds) + TimeInterval(age.attoseconds) / 1e18 + 1
        return await pinger.ping(url, timeout: TimeInterval(tuning.potHealthTimeoutSeconds), maxUptime: maxUptime)
    }

    private func startChild() async {
        abandonChild()
        guard let port = firstFreePort() else {
            statusValue = .down
            await logEvent(.shieldNoFreePort)
            return
        }
        guard let launch = installer.resolveServerLaunch(port: port, host: "127.0.0.1") else {
            statusValue = .missing
            await logEvent(.shieldMissing)
            return
        }
        childStartedAt = .now
        watch(runner.run(launch))
        await applyHealth(port: port)
    }

    private func watch(_ execution: ProcessExecution) {
        generation += 1
        let token = generation
        childTask = Task { [weak self] in
            let result = await execution.result()
            await self?.recover(from: result, token: token)
        }
    }

    private func applyHealth(port: Int) async {
        guard let url = pingURL(port: port) else {
            statusValue = .down
            return
        }
        // The server needs a moment to start, so keep asking until it answers, exits, or the wait runs out.
        let exitsBefore = exitCount
        let deadline = Date().addingTimeInterval(TimeInterval(max(tuning.potStartupWaitSeconds, 0)))
        while true {
            if await pingChild(url) {
                statusValue = .running(port: port)
                await logEvent(.shieldStarted(port: port))
                return
            }
            if exitCount != exitsBefore || Date() >= deadline {
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        abandonChild()
        statusValue = .down
    }

    private func recover(from result: ProcessResult, token: Int) async {
        guard token == generation, !result.wasCancelled else {
            return
        }
        exitCount += 1
        // Set before suspending, so a later verdict from startup or stop is never overwritten.
        statusValue = .restarting
        await logEvent(.shieldExited(code: result.exitCode))
        let delay = min(max(tuning.potRestartBackoffSeconds, 0), 30)
        try? await Task.sleep(for: .seconds(delay))
        await enqueue { await self.recoverSerialized(token: token) }
    }

    // Checked inside the queue: a stop or restart waiting ahead of this retires the crashed child.
    private func recoverSerialized(token: Int) async {
        guard token == generation else {
            return
        }
        await ensureSerialized()
    }

    private func abandonChild() {
        generation += 1
        childTask?.cancel()
        childTask = nil
    }

    private func firstFreePort() -> Int? {
        var port = 4416
        while port <= 4426 {
            if portChecker.isFree(port) {
                return port
            }
            port += 1
        }
        return nil
    }

    private func pingURL(port: Int) -> URL? {
        URL(string: "http://127.0.0.1:\(port)/ping")
    }

    private func logEvent(_ event: LogEvent) async {
        await log?.log(event)
    }
}
