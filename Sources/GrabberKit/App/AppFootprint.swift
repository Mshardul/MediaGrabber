import Foundation

public enum AppFootprint {
    public static func remove(in locations: AppLocations, fileManager: FileManager = .default) throws {
        for url in locations.footprintDirectories where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        let preferences = locations.preferenceFile
        if fileManager.fileExists(atPath: preferences.path) {
            try fileManager.removeItem(at: preferences)
        }
    }
}
