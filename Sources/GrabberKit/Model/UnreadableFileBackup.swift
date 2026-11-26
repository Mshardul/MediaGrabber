import Foundation

enum UnreadableFileBackup {
    private static let limit = 100

    // Returns the copy holding this file's bytes, or nil when none could be made. Earlier copies are never replaced.
    static func preserve(_ url: URL) -> URL? {
        let fileManager = FileManager.default
        for number in 1 ... limit {
            let suffix = number == 1 ? "corrupt" : "corrupt-\(number)"
            let candidate = url.appendingPathExtension(suffix)
            if fileManager.fileExists(atPath: candidate.path) {
                if fileManager.contentsEqual(atPath: url.path, andPath: candidate.path) {
                    return candidate
                }
                continue
            }
            guard let data = try? Data(contentsOf: url),
                  (try? data.write(to: candidate, options: .atomic)) != nil
            else { return nil }
            return candidate
        }
        return nil
    }
}
