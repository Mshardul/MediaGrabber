@testable import GrabberKit
import TestSupport
import XCTest

final class PotPluginInstallerTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/mg-pot-home")

    private func installer(
        executable: Set<String> = [],
        existing: Set<String> = [],
        store: FakePluginStore = FakePluginStore()
    ) -> PotPluginInstaller {
        PotPluginInstaller(
            home: home,
            tools: ManagedTools(
                resourceRoot: URL(fileURLWithPath: "/bundle/Resources"),
                supportRoot: home.appendingPathComponent("Library/Application Support/MediaGrabber"),
                isExecutable: { _ in false }
            ),
            isExecutable: { executable.contains($0.path) },
            fileExists: { existing.contains($0.path) },
            pluginStore: store
        )
    }

    func testResolveNilWhenNothingFound() {
        let sut = installer()
        XCTAssertNil(sut.resolveServerLaunch(port: 4416))
        XCTAssertEqual(sut.pluginDirs(), [])
    }

    func testUsesBundledNodeAndServer() {
        let node = URL(fileURLWithPath: "/bundle/Resources/Tools/node")
        let mainJS = URL(fileURLWithPath: "/bundle/Resources/Shield/server/build/main.js")
        let sut = installer(executable: [node.path], existing: [node.path, mainJS.path])
        let launch = sut.resolveServerLaunch(port: 4416)
        XCTAssertEqual(launch?.executableURL, node)
        XCTAssertEqual(launch?.arguments, [mainJS.path, "--host", "127.0.0.1", "--port", "4416"])
    }

    func testIgnoresALeftoverAppSupportServer() {
        let node = URL(fileURLWithPath: "/bundle/Resources/Tools/node")
        let mainJS = home.appendingPathComponent(
            "Library/Application Support/MediaGrabber/bgutil-server/server/build/main.js"
        )
        let sut = installer(executable: [node.path], existing: [node.path, mainJS.path])
        let launch = sut.resolveServerLaunch(port: 4420)
        XCTAssertNil(launch)
    }

    func testPluginDirsUsesBundledZip() {
        let zip = URL(fileURLWithPath: "/bundle/Resources/Shield/plugin.zip")
        let store = FakePluginStore()
        store.files = [zip.path]
        let sut = installer(existing: [zip.path], store: store)
        let dirs = sut.pluginDirs()
        let dest = home.appendingPathComponent(
            "Library/Application Support/MediaGrabber/yt-dlp-plugins"
        )
        XCTAssertEqual(dirs, [dest])
    }
}
