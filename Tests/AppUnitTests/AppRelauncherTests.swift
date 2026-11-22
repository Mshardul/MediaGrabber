@testable import MediaGrabber
import XCTest

@MainActor
final class AppRelauncherTests: XCTestCase {
    func test_relaunch_startsAWaiterBeforeTerminating() {
        var events: [String] = []
        let spy = SpyProcessLauncher { events.append("launch") }
        let relauncher = AppRelauncher(launcher: spy, processID: 4242) { events.append("terminate") }

        relauncher.relaunch(bundlePath: "/Applications/MediaGrabber.app", extraArguments: ["-MGForceOnboarding"])

        XCTAssertEqual(events, ["launch", "terminate"])
        XCTAssertEqual(spy.pid, 4242)
        XCTAssertEqual(spy.bundlePath, "/Applications/MediaGrabber.app")
        XCTAssertEqual(spy.arguments, ["-MGForceOnboarding"])
    }
}

final class SpyProcessLauncher: RelaunchProcessLaunching {
    private let onLaunch: () -> Void
    private(set) var pid: Int32 = 0
    private(set) var bundlePath = ""
    private(set) var arguments: [String] = []

    init(onLaunch: @escaping () -> Void) {
        self.onLaunch = onLaunch
    }

    func launchAfterExit(of pid: Int32, bundlePath: String, arguments: [String]) {
        self.pid = pid
        self.bundlePath = bundlePath
        self.arguments = arguments
        onLaunch()
    }
}
