#if DEBUG
    import Foundation
    import GrabberKit

    enum ScreenshotSettingsSeed {
        private static let longFolder = "/Users/example/Movies/Archive/Field Recording and Restoration Projects/"
            + "2026/Reference Downloads"

        static let firefoxProfiles = ["personal", "work"]

        // No pane shows a default by accident; the run sets theme and palette itself.
        static func apply(to prefs: Preferences) {
            prefs.defaultDownloadFolder = URL(fileURLWithPath: longFolder, isDirectory: true)
            prefs.lastUsedDownloadFolder = URL(fileURLWithPath: "/Users/example/Movies/Talks", isDirectory: true)
            prefs.defaultMediaType = .audio
            prefs.defaultVideoHeight = 1440
            prefs.defaultAudioFormat = .mp3
            prefs.filenameTemplate = "%(title)s - %(uploader)s.%(ext)s"
            prefs.maxAutoRetries = 3
            prefs.maxConcurrentDownloads = 5
            prefs.verboseLogging = true
            prefs.detectClipboardLinks = false
            prefs.autoCheckAppUpdates = false
            prefs.autoCheckYtDlpUpdates = false
            prefs.proxyURL = "http://proxy.example.com:8080"
            prefs.forceIPv4 = true
            prefs.speedLimitKBps = 2500
            prefs.cookiesFromBrowser = .firefox(profile: "work")
            prefs.signInScope = .listedSites
            prefs.signInSites = ["youtube", "vimeo.com", "soundcloud", "courses.example.com", "members.example.com"]
            prefs.lastVideoHeight = 1080
            prefs.lastMediaType = .video
            prefs.lastAudioFormat = .mp3
            prefs.defaultAudioLanguagePolicy = .original
            prefs.lastAudioLanguage = .code("es")
        }

        // Logs and browser folders the panes read, written only under the temporary home.
        static func seedHome(_ locations: AppLocations) async throws {
            try seedBrowsers(locations.browsers)
            await seedAppLog(locations.logs)
        }

        private static func seedBrowsers(_ browsers: BrowserLocations) throws {
            let files = FileManager.default
            let firefox = browsers.applicationSupport.appendingPathComponent("Firefox", isDirectory: true)
            try files.createDirectory(at: firefox, withIntermediateDirectories: true)
            let sections = firefoxProfiles.enumerated().map { offset, name in
                """
                [Profile\(offset)]
                Name=\(name)
                IsRelative=1
                Path=Profiles/\(name)
                Default=\(offset == 0 ? 1 : 0)
                """
            }
            try sections.joined(separator: "\n\n").write(
                to: firefox.appendingPathComponent("profiles.ini"),
                atomically: true,
                encoding: .utf8
            )
            try files.createDirectory(
                at: browsers.safariCookies.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: browsers.safariCookies)
        }

        private static func seedAppLog(_ directory: URL) async {
            let log = LogWriter(directory: directory, clock: { ScreenshotJob.addedAnchor })
            await log.log(.appLaunched)
            await log.log(.probeCompleted(url: ScreenshotLinks.videoURL, title: nil, ok: false), level: .warn)
            await log.log(.persistenceWriteFailed(file: "queue.json", error: "disk full"), level: .error)
        }
    }
#endif
