import Foundation

// yt-dlp gives either a single "thumbnail" or a "thumbnails" list; the first usable URL wins.
enum ThumbnailURL {
    static func from(_ object: [String: Any]) -> String? {
        if let direct = object["thumbnail"] as? String, !direct.isEmpty {
            return direct
        }
        guard let list = object["thumbnails"] as? [[String: Any]] else { return nil }
        for item in list {
            if let url = item["url"] as? String, !url.isEmpty {
                return url
            }
        }
        return nil
    }
}
