@testable import GrabberKit
import TestSupport
import XCTest

final class LocationsWiringTests: XCTestCase {
    func testLiveDependenciesUseLocations() {
        let locations = TestLocations.make()
        let deps = EngineDependencies.live(ytDlp: .fixed(URL(fileURLWithPath: "/bin/echo")), locations: locations)
        XCTAssertEqual(deps.jobLogDir, locations.jobLogs)
        XCTAssertEqual(deps.cookieBrowsers, locations.browsers)
    }

    func testCookieResolverReadsFirefoxUnderBrowsers() throws {
        let locations = TestLocations.make()
        let firefox = locations.browsers.applicationSupport.appendingPathComponent("Firefox", isDirectory: true)
        try FileManager.default.createDirectory(at: firefox, withIntermediateDirectories: true)
        let ini = "[Profile0]\nName=work\nIsRelative=1\nPath=Profiles/abc.work\n"
        try ini.write(to: firefox.appendingPathComponent("profiles.ini"), atomically: true, encoding: .utf8)
        let profiles = CookieResolver(browsers: locations.browsers).firefoxProfiles()
        XCTAssertEqual(profiles.map(\.name), ["work"])
    }

    func testDefaultDownloadFolderComesFromInjectedFolder() {
        let prefs = Preferences(defaults: TestLocations.settings(), downloadsFolder: URL(fileURLWithPath: "/tmp/dl"))
        XCTAssertEqual(prefs.defaultDownloadFolder.path, "/tmp/dl")
    }
}
