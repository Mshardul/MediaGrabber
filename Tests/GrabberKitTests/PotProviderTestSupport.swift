@testable import GrabberKit
import TestSupport
import XCTest

enum PotInstallerFixtures {
    private static let home = URL(fileURLWithPath: "/tmp/mg-pot-proc-home")

    static func bgutil() -> PotPluginInstaller {
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

    static func empty() -> PotPluginInstaller {
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
}

final class FlakyPinger: ShieldPinging, @unchecked Sendable {
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
