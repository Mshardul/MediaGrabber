import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

@MainActor
final class AppModelSeamTests: XCTestCase {
    func test_signInTestProbeComesFromTheFactory() throws {
        let marker = FakeMetadataProbe()
        var requested: [URL] = []
        let model = AppModel(
            engine: FakeEngine(),
            prefs: Preferences(defaults: TestLocations.settings(), downloadsFolder: TestLocations.make().downloads),
            log: LogWriter(directory: TestLocations.make().logs),
            locations: TestLocations.make(),
            defaults: TestLocations.settings(),
            suppression: UserDefaultsSuppressionStore(defaults: TestLocations.settings()),
            envProbe: FakeEnvironmentProbe(ready: true),
            makeCanaryProbe: { url in
                requested.append(url)
                return marker
            }
        )
        let path = URL(fileURLWithPath: "/tmp/x")
        model.setLatestEnvironmentReport(EnvironmentReport(
            ytDlp: ToolInfo(path: path, version: "0"),
            ffmpeg: nil,
            ffprobe: nil
        ))

        let probe = try XCTUnwrap(model.makeSignInTestProbe())

        XCTAssertTrue(probe as AnyObject === marker)
        XCTAssertEqual(requested, [path])
    }
}
