@testable import GrabberKit
import Observation
import TestSupport
import XCTest

final class PreferencesObservationTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "mg.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private struct Setting {
        let name: String
        let read: (Preferences) -> Void
        let write: (Preferences) -> Void

        init<Value>(
            _ name: String,
            _ keyPath: ReferenceWritableKeyPath<Preferences, Value>,
            _ value: Value
        ) {
            self.name = name
            read = { _ = $0[keyPath: keyPath] }
            write = { $0[keyPath: keyPath] = value }
        }
    }

    private var settings: [Setting] {
        let folder = TestLocations.make().downloads
        return [
            Setting("defaultDownloadFolder", \.defaultDownloadFolder, folder),
            Setting("lastUsedDownloadFolder", \.lastUsedDownloadFolder, folder),
            Setting("defaultMediaType", \.defaultMediaType, .audio),
            Setting("defaultVideoHeight", \.defaultVideoHeight, 480),
            Setting("defaultAudioFormat", \.defaultAudioFormat, .mp3),
            Setting("filenameTemplate", \.filenameTemplate, "%(id)s.%(ext)s"),
            Setting("maxAutoRetries", \.maxAutoRetries, 2),
            Setting("maxConcurrentDownloads", \.maxConcurrentDownloads, 6),
            Setting("verboseLogging", \.verboseLogging, true),
            Setting("detectClipboardLinks", \.detectClipboardLinks, false),
            Setting("autoCheckAppUpdates", \.autoCheckAppUpdates, false),
            Setting("autoCheckYtDlpUpdates", \.autoCheckYtDlpUpdates, false),
            Setting("proxyURL", \.proxyURL, "http://h:1"),
            Setting("forceIPv4", \.forceIPv4, true),
            Setting("speedLimitKBps", \.speedLimitKBps, 500),
            Setting("cookiesFromBrowser", \.cookiesFromBrowser, .safari),
            Setting("signInScope", \.signInScope, .listedSites),
            Setting("signInSites", \.signInSites, ["example.com"]),
            Setting("lastVideoHeight", \.lastVideoHeight, 720),
            Setting("lastMediaType", \.lastMediaType, .audio),
            Setting("lastAudioFormat", \.lastAudioFormat, .mp3),
            Setting("defaultAudioLanguagePolicy", \.defaultAudioLanguagePolicy, .original),
            Setting("lastAudioLanguage", \.lastAudioLanguage, .code("es")),
            Setting("theme", \.theme, .tapeDeck),
            Setting("palette", \.palette, .tapeDeckC)
        ]
    }

    private func notifies(
        _ prefs: Preferences,
        reading: (Preferences) -> Void,
        after change: (Preferences) -> Void
    ) -> Bool {
        let notified = LockedBox(false)
        withObservationTracking {
            reading(prefs)
        } onChange: {
            notified.mutate { $0 = true }
        }
        change(prefs)
        return notified.read { $0 }
    }

    func test_changingASettingTellsItsReaders() {
        let prefs = Preferences(defaults: defaults, downloadsFolder: TestLocations.make().downloads)
        for setting in settings {
            XCTAssertTrue(notifies(prefs, reading: setting.read, after: setting.write), setting.name)
        }
    }

    func test_resetToDefaultsTellsReadersOfEverySetting() {
        let prefs = Preferences(defaults: defaults, downloadsFolder: TestLocations.make().downloads)
        for setting in settings {
            setting.write(prefs)
            let notified = notifies(prefs, reading: setting.read) { $0.resetToDefaults() }
            XCTAssertTrue(notified, setting.name)
        }
    }
}
