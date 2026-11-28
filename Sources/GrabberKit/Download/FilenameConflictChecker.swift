import Foundation

struct FilenameConflictResult {
    let filename: String
    let exists: Bool
    let conflictingURL: URL?
}

public enum FilenameConflictChecker {
    public static func checkConflict(
        filename: String,
        in folder: URL
    ) -> (exists: Bool, conflictingURL: URL?) {
        let fileURL = folder.appendingPathComponent(filename)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        return (exists, exists ? fileURL : nil)
    }

    static func checkConflicts(
        filenames: [String],
        in folder: URL
    ) -> [FilenameConflictResult] {
        filenames.map { filename in
            let (exists, url) = checkConflict(filename: filename, in: folder)
            return FilenameConflictResult(filename: filename, exists: exists, conflictingURL: url)
        }
    }
}
