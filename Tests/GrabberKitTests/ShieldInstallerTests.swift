@testable import GrabberKit
import XCTest

final class ShieldInstallerTests: XCTestCase {
    private let resources = URL(fileURLWithPath: "/bundle/Resources")
    private let support = URL(fileURLWithPath: "/tmp/mg-shield-support")

    private var tools: ManagedTools {
        ManagedTools(resourceRoot: resources, supportRoot: support, isExecutable: { _ in false })
    }

    func testInstallSucceedsWhenServerAndPluginExist() async {
        let present: Set<String> = [tools.shieldServer.path, tools.shieldPlugin.path]
        let installer = ShieldInstaller(tools: tools, fileExists: { present.contains($0) })
        let outcome = await installer.install()
        XCTAssertEqual(outcome, .installed)
    }

    func testInstallFailsWhenPluginMissing() async {
        let present: Set<String> = [tools.shieldServer.path]
        let installer = ShieldInstaller(tools: tools, fileExists: { present.contains($0) })
        let outcome = await installer.install()
        XCTAssertEqual(outcome, .failed(detail: "This copy of the app doesn't include the YouTube check."))
    }

    func testLeftoverSupportFilesDoNotCountAsInstalled() async {
        let leftovers: Set<String> = [
            support.appendingPathComponent("bgutil-server/server/build/main.js").path,
            support.appendingPathComponent("bgutil-plugin.zip").path
        ]
        let installer = ShieldInstaller(tools: tools, fileExists: { leftovers.contains($0) })
        let outcome = await installer.install()
        XCTAssertEqual(outcome, .failed(detail: "This copy of the app doesn't include the YouTube check."))
    }
}
