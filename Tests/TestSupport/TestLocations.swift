import Foundation
import GrabberKit

public enum TestLocations {
    public static func make() -> AppLocations {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("mg-home-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return AppLocations(home: home)
    }

    public static func settings() -> UserDefaults {
        UserDefaults(suiteName: "mg-test-settings-\(UUID().uuidString)") ?? UserDefaults()
    }
}
