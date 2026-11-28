import Foundation
import Observation

// String-raw identity only; the Color/Font-bearing Theme lives in the App target.
public enum ThemeKind: String, Codable, Sendable, CaseIterable {
    case tapeDeck
    case aurora
}

public enum PaletteKind: String, Codable, Sendable, CaseIterable {
    case auroraMintIris
    case auroraLimeForest
    case auroraMagentaViolet
    case tapeDeckA
    case tapeDeckB
    case tapeDeckC
}

@Observable
public final class Preferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private let downloadsFolder: URL

    // Every setting shares one observed key, so a new setting or a reset cannot be left out.
    private var _observationToken = 0

    public init(defaults: UserDefaults, downloadsFolder: URL) {
        self.defaults = defaults
        self.downloadsFolder = downloadsFolder
    }

    // MARK: - Destination

    public var defaultDownloadFolder: URL {
        get { url(forKey: "defaultDownloadFolder", default: downloadsFolder) }
        set { setURL(newValue, forKey: "defaultDownloadFolder") }
    }

    public var lastUsedDownloadFolder: URL {
        get { url(forKey: "lastUsedDownloadFolder", default: defaultDownloadFolder) }
        set { setURL(newValue, forKey: "lastUsedDownloadFolder") }
    }

    // MARK: - Format

    public var defaultKind: DownloadKind {
        switch defaultMediaType {
        case .video: .video(maxHeight: defaultVideoHeight)
        case .audio: .audio(format: defaultAudioFormat)
        }
    }

    public var defaultMediaType: MediaType {
        get {
            (saved.string(forKey: "mg.defaultMediaType"))
                .flatMap(MediaType.init) ?? .video
        }
        set { store(newValue.rawValue, forKey: "mg.defaultMediaType") }
    }

    public var defaultVideoHeight: Int {
        get { intValue(forKey: "defaultVideoHeight", default: .max) }
        set { store(newValue, forKey: "mg.defaultVideoHeight") }
    }

    public var defaultAudioFormat: AudioFormat {
        get {
            (saved.string(forKey: "mg.defaultAudioFormat"))
                .flatMap(AudioFormat.init) ?? .m4a
        }
        set { store(newValue.rawValue, forKey: "mg.defaultAudioFormat") }
    }

    public var filenameTemplate: String {
        get { saved.string(forKey: "mg.filenameTemplate") ?? "%(title)s.%(ext)s" }
        set { store(newValue, forKey: "mg.filenameTemplate") }
    }

    // MARK: - Behavior

    public var maxAutoRetries: Int {
        get { intValue(forKey: "maxAutoRetries", default: 5) }
        set { store(min(5, max(1, newValue)), forKey: "mg.maxAutoRetries") }
    }

    // Gates concurrent downloads only, not probes. DebugFlags.concurrencyCapOverride wins.
    public var maxConcurrentDownloads: Int {
        get { intValue(forKey: "maxConcurrentDownloads", default: 3) }
        set { store(min(6, max(1, newValue)), forKey: "mg.maxConcurrentDownloads") }
    }

    public var verboseLogging: Bool {
        get { saved.bool(forKey: "mg.verboseLogging") }
        set { store(newValue, forKey: "mg.verboseLogging") }
    }

    // MARK: - Clipboard

    public var detectClipboardLinks: Bool {
        get {
            saved.object(forKey: "mg.detectClipboardLinks") == nil
                ? true
                : saved.bool(forKey: "mg.detectClipboardLinks")
        }
        set { store(newValue, forKey: "mg.detectClipboardLinks") }
    }

    // MARK: - Updates

    public var autoCheckAppUpdates: Bool {
        get {
            saved.object(forKey: "mg.autoCheckAppUpdates") == nil
                ? true
                : saved.bool(forKey: "mg.autoCheckAppUpdates")
        }
        set { store(newValue, forKey: "mg.autoCheckAppUpdates") }
    }

    public var autoCheckYtDlpUpdates: Bool {
        get {
            saved.object(forKey: "mg.autoCheckYtDlpUpdates") == nil
                ? true
                : saved.bool(forKey: "mg.autoCheckYtDlpUpdates")
        }
        set { store(newValue, forKey: "mg.autoCheckYtDlpUpdates") }
    }

    // MARK: - Network

    public var proxyURL: String? {
        get { saved.string(forKey: "mg.proxyURL") }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                store(nil, forKey: "mg.proxyURL")
            } else {
                store(trimmed, forKey: "mg.proxyURL")
            }
        }
    }

    public var forceIPv4: Bool {
        get { saved.bool(forKey: "mg.forceIPv4") }
        set { store(newValue, forKey: "mg.forceIPv4") }
    }

    public var speedLimitKBps: Int {
        get { intValue(forKey: "speedLimitKBps", default: 0) }
        set { store(min(100_000, max(0, newValue)), forKey: "mg.speedLimitKBps") }
    }

    // MARK: - Cookies

    public var cookiesFromBrowser: CookieSource {
        get {
            guard let data = saved.data(forKey: "mg.cookiesFromBrowser"),
                  let decoded = try? JSONDecoder().decode(CookieSource.self, from: data)
            else {
                return .none
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                store(nil, forKey: "mg.cookiesFromBrowser")
                return
            }
            store(data, forKey: "mg.cookiesFromBrowser")
        }
    }

    public var signInScope: SignInScope {
        get {
            guard let raw = saved.string(forKey: "mg.signInScope"),
                  let scope = SignInScope(rawValue: raw)
            else {
                return .allSites
            }
            return scope
        }
        set { store(newValue.rawValue, forKey: "mg.signInScope") }
    }

    public var signInSites: [String] {
        get {
            guard let data = saved.data(forKey: "mg.signInSites"),
                  let sites = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            return sites
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store(data, forKey: "mg.signInSites")
        }
    }

    // MARK: - Runway last-selected

    public var lastVideoHeight: Int? {
        get {
            saved.object(forKey: "mg.lastVideoHeight") == nil
                ? nil
                : saved.integer(forKey: "mg.lastVideoHeight")
        }
        set {
            guard let value = newValue else {
                store(nil, forKey: "mg.lastVideoHeight")
                return
            }
            store(value, forKey: "mg.lastVideoHeight")
        }
    }

    public var lastMediaType: MediaType? {
        get { saved.string(forKey: "mg.lastMediaType").flatMap(MediaType.init) }
        set {
            guard let value = newValue else {
                store(nil, forKey: "mg.lastMediaType")
                return
            }
            store(value.rawValue, forKey: "mg.lastMediaType")
        }
    }

    public var lastAudioFormat: AudioFormat? {
        get { saved.string(forKey: "mg.lastAudioFormat").flatMap(AudioFormat.init) }
        set {
            guard let value = newValue else {
                store(nil, forKey: "mg.lastAudioFormat")
                return
            }
            store(value.rawValue, forKey: "mg.lastAudioFormat")
        }
    }

    public var defaultAudioLanguagePolicy: AudioLanguagePolicy {
        get {
            (saved.string(forKey: "mg.defaultAudioLanguagePolicy"))
                .flatMap(AudioLanguagePolicy.init) ?? .youtubeDefault
        }
        set { store(newValue.rawValue, forKey: "mg.defaultAudioLanguagePolicy") }
    }

    public var lastAudioLanguage: LastAudioLanguage? {
        get {
            guard let data = saved.data(forKey: "mg.lastAudioLanguage"),
                  let decoded = try? JSONDecoder().decode(LastAudioLanguage.self, from: data)
            else {
                return nil
            }
            return decoded
        }
        set {
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value)
            else {
                store(nil, forKey: "mg.lastAudioLanguage")
                return
            }
            store(data, forKey: "mg.lastAudioLanguage")
        }
    }

    // MARK: - Theme

    public var theme: ThemeKind {
        get {
            (saved.string(forKey: "mg.theme")).flatMap(ThemeKind.init) ?? .aurora
        }
        set { store(newValue.rawValue, forKey: "mg.theme") }
    }

    public var palette: PaletteKind {
        get {
            (saved.string(forKey: "mg.palette"))
                .flatMap(PaletteKind.init) ?? .auroraMintIris
        }
        set { store(newValue.rawValue, forKey: "mg.palette") }
    }

    // MARK: - Reset

    public func resetToDefaults() {
        for key in Self.ownedKeys {
            store(nil, forKey: key)
        }
    }

    static let ownedKeys = [
        "mg.defaultDownloadFolder", "mg.lastUsedDownloadFolder", "mg.defaultMediaType",
        "mg.defaultVideoHeight", "mg.defaultAudioFormat", "mg.filenameTemplate",
        "mg.maxAutoRetries", "mg.maxConcurrentDownloads", "mg.verboseLogging",
        "mg.theme", "mg.palette", "mg.detectClipboardLinks", "mg.proxyURL",
        "mg.forceIPv4", "mg.speedLimitKBps", "mg.lastVideoHeight",
        "mg.lastMediaType", "mg.lastAudioFormat", "mg.cookiesFromBrowser",
        "mg.signInScope", "mg.signInSites",
        "mg.defaultAudioLanguagePolicy", "mg.lastAudioLanguage",
        "mg.autoCheckAppUpdates", "mg.autoCheckYtDlpUpdates"
    ]
}

// MARK: - Storage

extension Preferences {
    private func intValue(forKey name: String, default fallback: Int) -> Int {
        saved.object(forKey: "mg.\(name)") == nil
            ? fallback
            : saved.integer(forKey: "mg.\(name)")
    }

    private func url(forKey name: String, default fallback: URL) -> URL {
        guard let path = saved.string(forKey: "mg.\(name)") else { return fallback }
        return URL(fileURLWithPath: path)
    }

    private func setURL(_ value: URL, forKey name: String) {
        store(value.path, forKey: "mg.\(name)")
    }

    private var saved: UserDefaults {
        access(keyPath: \._observationToken)
        return defaults
    }

    private func store(_ value: Any?, forKey key: String) {
        withMutation(keyPath: \._observationToken) {
            defaults.set(value, forKey: key)
            _observationToken &+= 1
        }
    }
}
