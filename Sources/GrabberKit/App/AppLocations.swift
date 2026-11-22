import CryptoKit
import Foundation

public struct BrowserLocations: Sendable, Equatable {
    public let applicationSupport: URL
    public let safariCookies: URL

    public init(applicationSupport: URL, safariCookies: URL) {
        self.applicationSupport = applicationSupport
        self.safariCookies = safariCookies
    }
}

public struct AppLocations: Sendable, Equatable {
    public static let preferenceDomain = "app.mediagrabber.mac"
    private static let homeVariable = "MG_HOME"
    private static let homeDomainPrefix = "app.mediagrabber.mac.home."

    public let home: URL
    public let library: URL
    public let downloads: URL
    public let settingsDomain: String?

    public init(home: URL, downloads: URL? = nil, settingsDomain: String? = nil) {
        self.init(
            home: home,
            library: home.appendingPathComponent("Library", isDirectory: true),
            downloads: downloads ?? home.appendingPathComponent("Downloads", isDirectory: true),
            settingsDomain: settingsDomain
        )
    }

    private init(home: URL, library: URL, downloads: URL, settingsDomain: String?) {
        self.home = home
        self.library = library
        self.downloads = downloads
        self.settingsDomain = settingsDomain
    }

    public static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppLocations {
        guard let override = environment[homeVariable], !override.isEmpty else {
            return systemLocations()
        }
        guard override.hasPrefix("/") else {
            preconditionFailure("MG_HOME must be an absolute path")
        }
        let home = URL(fileURLWithPath: override, isDirectory: true)
        return AppLocations(home: home, settingsDomain: homeDomainPrefix + pathDigest(home.path))
    }

    private static func systemLocations() -> AppLocations {
        let files = FileManager.default
        let home = files.homeDirectoryForCurrentUser
        let library = files.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Library", isDirectory: true)
        let downloads = files.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Downloads", isDirectory: true)
        return AppLocations(home: home, library: library, downloads: downloads, settingsDomain: nil)
    }

    private static func pathDigest(_ path: String) -> String {
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    public var logs: URL {
        library.appendingPathComponent("Logs/MediaGrabber", isDirectory: true)
    }

    public var jobLogs: URL {
        logs.appendingPathComponent("jobs", isDirectory: true)
    }

    public var applicationSupport: URL {
        library.appendingPathComponent("Application Support/MediaGrabber", isDirectory: true)
    }

    public var queueStore: URL {
        applicationSupport
    }

    public var playerClients: URL {
        applicationSupport.appendingPathComponent("player-clients", isDirectory: true)
    }

    public var pluginStore: URL {
        applicationSupport.appendingPathComponent("yt-dlp-plugins", isDirectory: true)
    }

    public var userApplications: URL {
        home.appendingPathComponent("Applications", isDirectory: true)
    }

    public var browsers: BrowserLocations {
        BrowserLocations(
            applicationSupport: library.appendingPathComponent("Application Support", isDirectory: true),
            safariCookies: library.appendingPathComponent(
                "Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
            )
        )
    }

    public var footprintDirectories: [URL] {
        [
            applicationSupport,
            logs,
            library.appendingPathComponent("Caches/\(Self.preferenceDomain)", isDirectory: true),
            library.appendingPathComponent(
                "Saved Application State/\(Self.preferenceDomain).savedState",
                isDirectory: true
            )
        ]
    }

    public var preferenceFile: URL {
        library
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(Self.preferenceDomain).plist")
    }

    public func makeSettings() -> UserDefaults {
        guard let settingsDomain, let defaults = UserDefaults(suiteName: settingsDomain) else {
            return .standard
        }
        return defaults
    }
}
