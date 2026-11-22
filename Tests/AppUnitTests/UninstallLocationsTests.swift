import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

@MainActor
final class UninstallLocationsTests: XCTestCase {
    func testUninstallUnderMGHomeClearsOnlyNamedStore() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("mg-uninstall-\(UUID().uuidString)", isDirectory: true)
        let locations = AppLocations.live(environment: ["MG_HOME": home.path])
        let domain = try XCTUnwrap(locations.settingsDomain)
        let settings = try XCTUnwrap(UserDefaults(suiteName: domain))
        settings.set("x", forKey: "mg.probe")
        let realKey = "mg.uninstall-test-\(UUID().uuidString)"
        UserDefaults.standard.set("keep", forKey: realKey)
        defer { UserDefaults.standard.removeObject(forKey: realKey) }

        let effects = LiveUninstallEffects(
            engine: FakeEngine(),
            persistence: nil,
            locations: locations,
            bundleURL: home.appendingPathComponent("MediaGrabber.app"),
            defaults: settings
        )
        effects.clearPreferences()

        XCTAssertNil(settings.object(forKey: "mg.probe"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: realKey), "keep")
    }
}
