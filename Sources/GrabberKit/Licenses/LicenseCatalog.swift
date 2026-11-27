import Foundation

/// One third-party component bundled inside the app.
public struct LicenseEntry: Sendable, Equatable {
    public let id: String
    public let name: String
    public let licenseName: String
    public let summary: String
    public let textFile: String

    public init(id: String, name: String, licenseName: String, summary: String) {
        self.id = id
        self.name = name
        self.licenseName = licenseName
        self.summary = summary
        textFile = "\(id).txt"
    }
}

/// Every name in `scripts/tools.lock` maps through `componentID(forLockName:)`, or a unit test fails.
public enum LicenseCatalog {
    public static let appLicenseLine = "MediaGrabber is MIT-licensed. Each bundled tool keeps "
        + "its own license; FFmpeg build steps are in the public repository."

    public static let entries: [LicenseEntry] = [
        LicenseEntry(
            id: "yt-dlp",
            name: "yt-dlp",
            licenseName: "Unlicense",
            summary: "Downloads the video or audio you asked for, directly from the site."
        ),
        LicenseEntry(
            id: "ffmpeg",
            name: "FFmpeg",
            licenseName: "LGPL 2.1 or later",
            summary: "Converts a download into the format you chose."
        ),
        LicenseEntry(
            id: "lame",
            name: "LAME",
            licenseName: "LGPL 2.1 or later",
            summary: "Encodes mp3 audio inside FFmpeg."
        ),
        LicenseEntry(
            id: "node",
            name: "Node",
            licenseName: "MIT",
            summary: "Runs the YouTube check helper that ships inside the app."
        ),
        LicenseEntry(
            id: "shield",
            name: "YouTube check helper",
            licenseName: "GPL 3.0 only",
            summary: "Answers a site's bot check on your Mac."
        ),
        LicenseEntry(
            id: "sparkle",
            name: "Sparkle",
            licenseName: "MIT",
            summary: "Checks for and installs app updates."
        )
    ]

    /// The catalogue id for a component named in `scripts/tools.lock`.
    public static func componentID(forLockName name: String) -> String? {
        switch name {
        case "yt-dlp", "yt-dlp-license": "yt-dlp"
        case "ffmpeg": "ffmpeg"
        case "lame": "lame"
        case "node": "node"
        case "shield-plugin", "shield-source": "shield"
        case "sparkle-license": "sparkle"
        default: nil
        }
    }
}
