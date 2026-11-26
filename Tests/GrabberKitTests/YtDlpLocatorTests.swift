import CryptoKit
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
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            verifyChecksum: { _ in true }
        )
        await locator.refresh()
        XCTAssertEqual(locator.url, updated)
    }

    func testRefreshKeepsBundledWhenUpdatedChecksumDoesNotMatch() async {
        let runner = runner(bundled: "2025.01.01", updated: "2025.06.01")
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            verifyChecksum: { _ in false }
        )
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
        XCTAssertFalse(runner.launches.contains { $0.executableURL == updated }, "an unverified copy must never run")
    }

    func testRefreshKeepsBundledWhenBundledIsMissingAndChecksumDoesNotMatch() async {
        let runner = runner(bundled: nil, updated: "2025.06.01")
        let locator = YtDlpLocator(
            tools: tools(executable: [updated]),
            runner: runner,
            verifyChecksum: { _ in false }
        )
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
        XCTAssertTrue(runner.launches.isEmpty)
    }

    func testRefreshKeepsBundledWhenUpdatedIsOlder() async {
        let runner = runner(bundled: "2025.06.01", updated: "2025.01.01")
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            verifyChecksum: { _ in true }
        )
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
    }

    func testRefreshKeepsBundledWhenVersionsAreEqual() async {
        let runner = runner(bundled: "2025.06.01", updated: "2025.06.01")
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            verifyChecksum: { _ in true }
        )
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
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            verifyChecksum: { _ in true }
        )
        await locator.refresh()
        XCTAssertEqual(locator.url, bundled)
    }

    func testRefreshUsesUpdatedWhenBundledIsMissing() async {
        let runner = runner(bundled: nil, updated: "2025.06.01")
        let locator = YtDlpLocator(
            tools: tools(executable: [updated]),
            runner: runner,
            verifyChecksum: { _ in true }
        )
        await locator.refresh()
        XCTAssertEqual(locator.url, updated)
    }

    func testRefreshGivesUpAfterTimeout() async {
        let runner = runner(bundled: "2025.01.01", updated: "2025.06.01")
        runner.perRunDelay = .seconds(30)
        let locator = YtDlpLocator(
            tools: tools(executable: [bundled, updated]),
            runner: runner,
            timeout: .milliseconds(50),
            verifyChecksum: { _ in true }
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

    func testRealChecksumGate_rejectsASwappedUpdatedCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let tools = ManagedTools(
            resourceRoot: root,
            supportRoot: root,
            isExecutable: { _ in true }
        )
        let bundledURL = tools.bundledYtDlp
        let updatedURL = tools.updatedYtDlp
        for folder in [bundledURL, updatedURL].map({ $0.deletingLastPathComponent() }) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try Data("bundled".utf8).write(to: bundledURL)
        try Data("updated".utf8).write(to: updatedURL)
        let runner = FakeProcessRunner()
        runner.script(.stdout("2025.01.01"), forExactPath: bundledURL.path)
        runner.script(.stdout("2025.06.01"), forExactPath: updatedURL.path)
        let locator = YtDlpLocator(tools: tools, runner: runner)

        // No recorded checksum yet: the updated copy is refused.
        await locator.refresh()
        XCTAssertEqual(locator.url, bundledURL)

        // Record the checksum of different bytes: still refused.
        try Data("something else".utf8).write(to: tools.updatedYtDlpChecksum)
        await locator.refresh()
        XCTAssertEqual(locator.url, bundledURL)

        // Record the real checksum: the updated copy is used.
        let digest = SHA256.hash(data: Data("updated".utf8)).map { String(format: "%02x", $0) }.joined()
        try digest.write(to: tools.updatedYtDlpChecksum, atomically: true, encoding: .utf8)
        await locator.refresh()
        XCTAssertEqual(locator.url, updatedURL)
    }
}
