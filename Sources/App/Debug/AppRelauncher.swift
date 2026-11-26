import AppKit
import Foundation

protocol RelaunchProcessLaunching {
    func launchAfterExit(of pid: Int32, bundlePath: String, arguments: [String])
}

struct SystemProcessLauncher: RelaunchProcessLaunching {
    private static let waiter = """
    pid=$1; bundle=$2; shift 2
    while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
    exec /usr/bin/open -n "$bundle" --args "$@"
    """

    func launchAfterExit(of pid: Int32, bundlePath: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", Self.waiter, "sh", String(pid), bundlePath] + arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

@MainActor
struct AppRelauncher {
    private let launcher: RelaunchProcessLaunching
    private let terminate: () -> Void
    private let processID: Int32

    init(
        launcher: RelaunchProcessLaunching = SystemProcessLauncher(),
        processID: Int32 = ProcessInfo.processInfo.processIdentifier,
        terminate: @escaping () -> Void = { AppTermination.request() }
    ) {
        self.launcher = launcher
        self.processID = processID
        self.terminate = terminate
    }

    func relaunch(withExtraArguments extraArguments: [String]) {
        relaunch(bundlePath: Bundle.main.bundlePath, extraArguments: extraArguments)
    }

    func relaunch(bundlePath: String, extraArguments: [String] = []) {
        launcher.launchAfterExit(of: processID, bundlePath: bundlePath, arguments: extraArguments)
        terminate()
    }
}
