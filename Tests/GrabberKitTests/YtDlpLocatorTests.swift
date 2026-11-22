@testable import GrabberKit
import TestSupport
import XCTest

final class YtDlpLocatorTests: XCTestCase {
    private let bundled = URL(fileURLWithPath: "/bundle/Tools/yt-dlp")
    private let updated = URL(fileURLWithPath: "/support/bin/yt-dlp")

    private func tools(executable: Set<URL>) -> ManagedTools {
        ManagedTools(
            resourceRoot: URL(fileURLWithPath: "/bundle"),
            supportRoot: URL(fileURLWithPath: "/support"),
            isExecutable: { executable.contains($0) }
        )
    }

    private func runner(bundled bundledVersion: String?, updated updatedVersion: String?) -> FakeProcessRunner {
        let runner = FakeProcessRunner()
        if let bundledVersion {
            runner.script(.stdout(bundledVersion), forExactPath: bundled.path)
        }
        if let updatedVersion {
            runner.script(.stdout(updatedVersion), forExactPath: updated.path)
        }
        return runner
    }

    func testStartsAtBundledWithoutRunningAnything() {
        let runner = runner(bundled: "2025.01.01", updated: "2025.06.01")
        let locator = YtDlpLocator(tools: tools(executable: [bundled, updated]), runner: runner)
        XCTAssertEqual(locator.url, bundled)
        XCTAssertTrue(runner.launches.isEmpty)
    }

    func testRefreshSwitchesToNewerUpdatedCopy() async {
        let runner = runner(bundled: "2025.01.01", updated: "2025.06.01")
        let locator = YtDlpLocator(tools: tools(executable: [bundled, updated]), runner: runner)
        await locator.refresh()
        XCTAssertEqual(locator.url, updated)
    }

    func testRefreshKeepsBundledWhenUpdatedIsOlder() async {
        let runner = runner(bundled: "2025.06.01", updated: "2025.01.01")
        let locator = YtDlpLocator(tools: tools(executable: [bundled, updated]), runner: runner)
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
    }

    func testRefreshKeepsBundledWhenVersionsAreEqual() async {
        let runner = runner(bundled: "2025.06.01", updated: "2025.06.01")
        let locator = YtDlpLocator(tools: tools(executable: [bundled, updated]), runner: runner)
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
    }

    func testRefreshKeepsBundledWhenUpdatedIsNotExecutable() async {
        let runner = runner(bundled: "2025.01.01", updated: "2025.06.01")
        let locator = YtDlpLocator(tools: tools(executable: [bundled]), runner: runner)
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
        XCTAssertTrue(runner.launches.isEmpty)
    }

    func testRefreshKeepsBundledWhenUpdatedVersionIsUnreadable() async {
        let runner = runner(bundled: "2025.01.01", updated: nil)
        let locator = YtDlpLocator(tools: tools(executable: [bundled, updated]), runner: runner)
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
    }

    func testRefreshUsesUpdatedWhenBundledIsMissing() async {
        let runner = runner(bundled: nil, updated: "2025.06.01")
        let locator = YtDlpLocator(tools: tools(executable: [updated]), runner: runner)
        await locator.refresh()
        XCTAssertEqual(locator.url, updated)
    }

    func testRefreshGivesUpAfterTimeout() async {
        let runner = runner(bundled: "2025.01.01", updated: "2025.06.01")
        runner.perRunDelay = .seconds(30)
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            timeout: .milliseconds(50)
        )
        let started = Date()
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testFixedLocatorNeverChanges() async {
        let locator = YtDlpLocator.fixed(bundled)
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
    }
}
