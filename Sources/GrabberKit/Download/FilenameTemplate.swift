import Foundation

public enum FilenameTemplate {
    public static func apply(
        _ template: String,
        metadata: MediaMetadata,
        kind: DownloadKind,
        audioLanguage: AudioLanguage
    ) -> String {
        var result = template

        result = result.replacingOccurrences(of: "%(title)s", with: sanitize(metadata.title))
        result = result.replacingOccurrences(of: "%(id)s", with: extractID(from: metadata.sourceURL))
        result = result.replacingOccurrences(of: "%(ext)s", with: extensionForKind(kind))
        result = result.replacingOccurrences(of: "%(extractor)s", with: metadata.extractor ?? "unknown")
        result = result.replacingOccurrences(of: "%(uploader)s", with: metadata.extractor ?? "unknown")
        result = result.replacingOccurrences(of: "%(upload_date)s", with: dateString())
        result = result.replacingOccurrences(of: "%(height)s", with: heightString(for: kind))
        result = result.replacingOccurrences(of: "%(format)s", with: formatString(for: kind))
        result = result.replacingOccurrences(of: "%(language)s", with: languageString(for: audioLanguage))

        return result
    }

    private static func sanitize(_ title: String) -> String {
        title.unicodeScalars.filter { scalar in
            scalar != "/" && !CharacterSet.controlCharacters.contains(scalar)
        }.map(String.init).joined()
    }

    private static func extractID(from url: String) -> String {
        if let regex =
            try? NSRegularExpression(
                pattern: "(?:youtu\\.be/|youtube\\.com/(?:watch\\?v=|embed/|v/|shorts/))([^&?/]+)"
            ),
            let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
            let range = Range(match.range(at: 1), in: url)
        {
            return String(url[range])
        }
        if let regex = try? NSRegularExpression(pattern: "([^/?#]+)(?:[?#]|$)"),
           let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
           let range = Range(match.range(at: 1), in: url)
        {
            return String(url[range])
        }
        return "unknown"
    }

    private static func extensionForKind(_ kind: DownloadKind) -> String {
        switch kind {
        case .video:
            "mp4"
        case let .audio(format):
            format.rawValue
        }
    }

    private static func heightString(for kind: DownloadKind) -> String {
        switch kind {
        case let .video(maxHeight):
            if maxHeight == Int.max {
                return "best"
            }
            return "\(maxHeight)"
        case .audio:
            return "audio"
        }
    }

    private static func formatString(for kind: DownloadKind) -> String {
        switch kind {
        case let .video(maxHeight):
            if maxHeight == Int.max {
                return "bestvideo"
            }
            return "\(maxHeight)p"
        case let .audio(format):
            return format.rawValue
        }
    }

    private static func languageString(for audioLanguage: AudioLanguage) -> String {
        switch audioLanguage {
        case .unspecified:
            "default"
        case .original:
            "original"
        case let .code(code):
            code
        }
    }

    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYYMMDD"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
