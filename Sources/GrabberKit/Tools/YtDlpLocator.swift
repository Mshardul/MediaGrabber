import Foundation

public final class YtDlpLocator: Sendable {
    private let current: Locked<URL>
    private let resolve: (@Sendable () async -> URL)?
    private let readVersion: @Sendable (URL) async -> String?

    public var url: URL {
        current.read { $0 }
    }

    public init(tools: ManagedTools, runner: ProcessRunning, timeout: Duration = .seconds(5)) {
        current = Locked(tools.bundledYtDlp)
        let reader: @Sendable (URL) async -> String? = { url in
            await Self.version(of: url, runner: runner, timeout: timeout)
        }
        readVersion = reader
        resolve = { await Self.pick(tools: tools, readVersion: reader) }
    }

    private init(fixed url: URL) {
        current = Locked(url)
        resolve = nil
        readVersion = { _ in nil }
    }

    public static func fixed(_ url: URL) -> YtDlpLocator {
        YtDlpLocator(fixed: url)
    }

    public func refresh() async {
        guard let resolve else { return }
        let chosen = await resolve()
        current.mutate { $0 = chosen }
    }

    public func installedVersion() async -> String? {
        await readVersion(url)
    }

    private static func pick(
        tools: ManagedTools,
        readVersion: @Sendable (URL) async -> String?
    ) async -> URL {
        let bundled = tools.bundledYtDlp
        let updated = tools.updatedYtDlp
        guard tools.isExecutable(updated) else { return bundled }
        guard tools.isExecutable(bundled) else { return updated }
        async let bundledVersion = readVersion(bundled)
        async let updatedVersion = readVersion(updated)
        guard let have = await bundledVersion.flatMap({ DottedVersion(parsing: $0) }),
              let candidate = await updatedVersion.flatMap({ DottedVersion(parsing: $0) }),
              candidate > have
        else { return bundled }
        return updated
    }

    private static func version(of url: URL, runner: ProcessRunning, timeout: Duration) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await runVersion(url, runner: runner) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func runVersion(_ url: URL, runner: ProcessRunning) async -> String? {
        let execution = runner.run(ProcessLaunch(executableURL: url, arguments: ["--version"]))
        let collector = Task { () -> String in
            var output = ""
            for await line in execution.lines {
                switch line {
                case let .stdout(text), let .stderr(text):
                    output += text + "\n"
                }
            }
            return output
        }
        let result = await execution.result()
        let output = await collector.value
        guard result.exitCode == 0, !result.wasCancelled else { return nil }
        return EnvironmentProbe.parseYtDlp(output)
    }
}
