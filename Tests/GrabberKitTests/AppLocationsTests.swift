@testable import GrabberKit
import XCTest

final class AppLocationsTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/h")

    func testDerivedPathsUnderHome() {
        let locations = AppLocations(home: home)
        XCTAssertEqual(locations.logs.path, "/tmp/h/Library/Logs/MediaGrabber")
        XCTAssertEqual(locations.jobLogs.path, "/tmp/h/Library/Logs/MediaGrabber/jobs")
        XCTAssertEqual(locations.applicationSupport.path, "/tmp/h/Library/Application Support/MediaGrabber")
        XCTAssertEqual(locations.queueStore, locations.applicationSupport)
        XCTAssertEqual(locations.playerClients.path, "/tmp/h/Library/Application Support/MediaGrabber/player-clients")
        XCTAssertEqual(locations.pluginStore.path, "/tmp/h/Library/Application Support/MediaGrabber/yt-dlp-plugins")
        XCTAssertEqual(locations.userApplications.path, "/tmp/h/Applications")
        XCTAssertEqual(locations.downloads.path, "/tmp/h/Downloads")
    }

    func testBrowserLocations() {
        let browsers = AppLocations(home: home).browsers
        XCTAssertEqual(browsers.applicationSupport.path, "/tmp/h/Library/Application Support")
        XCTAssertTrue(
            browsers.safariCookies.path
                .hasSuffix("Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies")
        )
    }

    func testFootprintListsEveryWrittenFolder() {
        let locations = AppLocations(home: home)
        XCTAssertEqual(locations.footprintDirectories.map(\.path), [
            "/tmp/h/Library/Application Support/MediaGrabber",
            "/tmp/h/Library/Logs/MediaGrabber",
            "/tmp/h/Library/Caches/app.mediagrabber.mac",
            "/tmp/h/Library/Saved Application State/app.mediagrabber.mac.savedState"
        ])
        XCTAssertEqual(locations.preferenceFile.lastPathComponent, "app.mediagrabber.mac.plist")
    }

    func testUnsetMatchesToday() throws {
        let locations = AppLocations.live(environment: [:])
        let files = FileManager.default
        let library = try XCTUnwrap(files.urls(for: .libraryDirectory, in: .userDomainMask).first)
        let downloads = try XCTUnwrap(files.urls(for: .downloadsDirectory, in: .userDomainMask).first)
        XCTAssertEqual(locations.logs, library.appendingPathComponent("Logs/MediaGrabber", isDirectory: true))
        XCTAssertEqual(locations.downloads, downloads)
        XCTAssertNil(locations.settingsDomain)
    }

    func testEmptyMGHomeIsUnset() {
        XCTAssertNil(AppLocations.live(environment: ["MG_HOME": ""]).settingsDomain)
    }

    func testMGHomeOverrides() {
        let locations = AppLocations.live(environment: ["MG_HOME": "/tmp/a b/é"])
        XCTAssertEqual(locations.home.path, "/tmp/a b/é")
        XCTAssertTrue(locations.logs.path.hasPrefix("/tmp/a b/é/"))
        XCTAssertEqual(locations.downloads.path, "/tmp/a b/é/Downloads")
        XCTAssertTrue(locations.settingsDomain?.hasPrefix("app.mediagrabber.mac.home.") == true)
    }

    func testSettingsDomainDiffersPerHome() {
        let one = AppLocations.live(environment: ["MG_HOME": "/tmp/one"]).settingsDomain
        let two = AppLocations.live(environment: ["MG_HOME": "/tmp/two"]).settingsDomain
        XCTAssertNotEqual(one, two)
        XCTAssertEqual(one, AppLocations.live(environment: ["MG_HOME": "/tmp/one"]).settingsDomain)
        XCTAssertEqual(one?.count, "app.mediagrabber.mac.home.".count + 12)
    }

    func testMakeSettingsIsolated() {
        let key = "mg-test-\(UUID().uuidString)"
        let isolated = AppLocations.live(environment: ["MG_HOME": "/tmp/isolated-\(UUID().uuidString)"]).makeSettings()
        XCTAssertFalse(isolated === UserDefaults.standard)
        isolated.set("x", forKey: key)
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
        XCTAssertTrue(AppLocations.live(environment: [:]).makeSettings() === UserDefaults.standard)
    }
}
