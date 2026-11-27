import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

@MainActor
final class ScreenshotDummyValuesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var mixed: [JobSnapshot] {
        ScreenshotJobs.mixed(now: now).jobs
    }

    private var allStates: [DummyQueueState] {
        [
            ScreenshotJobs.mixed(now: now),
            ScreenshotJobs.playlist(now: now, collapsed: false),
            ScreenshotJobs.halted(.networkDown, now: now),
            ScreenshotJobs.halted(.circuitOpen, now: now),
            ScreenshotJobs.rateLimited(now: now),
            ScreenshotJobs.shield(.down, now: now)
        ]
    }

    func test_mixedCoversEveryJobState() {
        XCTAssertEqual(Set(mixed.map { stateName($0.state) }), [
            "queued", "probing", "running", "paused", "waitingForNetwork", "cooldown", "completed",
            "cancelled", "failed"
        ])
    }

    func test_mixedCoversEveryErrorClassWithDistinctRowText() {
        let failed = mixed.compactMap { job -> (String, String)? in
            guard case let .failed(errorClass) = job.state else { return nil }
            let remark = RowModel.remark(for: job, queuePosition: nil, shieldStatus: .running(port: 1))
            return (errorName(errorClass), remark)
        }

        XCTAssertEqual(Set(failed.map(\.0)), [
            "rate_limited", "bot_check", "sabr_gated", "formats_missing", "cookie_read_failed", "geo_blocked",
            "private", "unavailable", "age_restricted", "network_down", "disk_full", "permission_denied",
            "incomplete", "dep_missing", "pot_provider_down", "passcode_required", "passcode_rejected", "unknown"
        ])
        XCTAssertEqual(Set(failed.map(\.1)).count, failed.count, "two failures read the same")
    }

    func test_mixedCoversIntegrityVerdicts() {
        let verdicts = mixed.compactMap(\.integrityVerdict).map { verdict in
            switch verdict {
            case .passed: "passed"
            case .failed: "failed"
            case .skipped: "skipped"
            }
        }
        XCTAssertEqual(Set(verdicts), ["passed", "failed", "skipped"])
    }

    func test_mixedVariety() {
        XCTAssertGreaterThanOrEqual(mixed.count, 25)
        XCTAssertTrue(mixed.contains { isAudio($0.kind) })
        XCTAssertTrue(mixed.contains { !isAudio($0.kind) })
        let heights = Set(mixed.compactMap { job -> Int? in
            if case let .video(height) = job.kind {
                return height
            }
            return nil
        })
        XCTAssertGreaterThanOrEqual(heights.count, 3)
        XCTAssertGreaterThanOrEqual(Set(mixed.compactMap(\.extractor)).count, 4)
        XCTAssertTrue(mixed.contains { $0.title == nil })
        XCTAssertTrue(mixed.contains { ($0.title?.count ?? 0) > 150 })
        XCTAssertTrue(mixed.contains { $0.title?.unicodeScalars.contains { $0.value > 0x3000 } == true })
        XCTAssertTrue(mixed.contains { $0.sizeBytes == nil })
        XCTAssertTrue(mixed.contains { ($0.sizeBytes ?? .max) < 1_000_000 })
        XCTAssertTrue(mixed.contains { ($0.sizeBytes ?? 0) > 20_000_000_000 })
        XCTAssertTrue(mixed.contains { ($0.durationSeconds ?? 0) > 36000 })
        let fractions = mixed.compactMap(\.progress?.fraction)
        XCTAssertTrue(fractions.contains { $0 < 0.05 })
        XCTAssertTrue(fractions.contains { $0 >= 0.4 && $0 <= 0.6 })
        XCTAssertTrue(fractions.contains { $0 > 0.95 })
        XCTAssertTrue(mixed.contains { $0.attempt > 1 })
        XCTAssertEqual(Set(mixed.map(\.id)).count, mixed.count)
    }

    func test_availableActionsMatchState() {
        for job in allStates.flatMap(\.jobs) {
            XCTAssertEqual(
                job.availableActions,
                DownloadEngine.availableActions(for: job.state, signInAdvice: job.signInAdvice),
                job.title ?? job.url
            )
        }
    }

    func test_playlistGroup() throws {
        let state = ScreenshotJobs.playlist(now: now, collapsed: true)
        XCTAssertEqual(state.playlistGroups.count, 1)
        let group = try XCTUnwrap(state.playlistGroups.first)
        XCTAssertTrue(group.isCollapsed)
        let children = state.jobs.filter { $0.playlistGroupID == group.id }
        XCTAssertGreaterThanOrEqual(children.count, 5)
        XCTAssertEqual(Set(children.compactMap(\.playlistIndex)).count, children.count)
        XCTAssertGreaterThanOrEqual(Set(children.map { stateName($0.state) }).count, 3)
    }

    func test_deterministic() {
        XCTAssertEqual(ScreenshotJobs.mixed(now: now), ScreenshotJobs.mixed(now: now))
        XCTAssertEqual(
            ScreenshotJobs.playlist(now: now, collapsed: false),
            ScreenshotJobs.playlist(now: now, collapsed: false)
        )
    }

    func test_dummyURLsAndPathsAreSafe() {
        // Real hosts are allowed only where the app's wording or link handling depends on them.
        let derivedHosts: Set = ["www.youtube.com"]
        let jobs = allStates.flatMap(\.jobs)
        let urls = jobs.map(\.url)
            + ScreenshotLinks.playlist.entries.map(\.watchURL)
            + [
                ScreenshotLinks.playlist.sourceURL, ScreenshotLinks.video.sourceURL,
                ScreenshotLinks.multiAudioVideo.sourceURL, ScreenshotLinks.videoURL, ScreenshotLinks.playlistURL
            ]
        for url in urls {
            let host = URL(string: url)?.host ?? ""
            XCTAssertTrue(
                host == "example.com" || host.hasSuffix(".example.com") || derivedHosts.contains(host),
                "\(url) could reach a real site"
            )
        }
        XCTAssertTrue(ScreenshotLinks.playlist.entries.allSatisfy { $0.thumbnailURL == nil })
        for path in jobs.flatMap({ [$0.destFolder.path] + $0.outputFiles.map(\.path) }) {
            XCTAssertTrue(path.hasPrefix("/Users/example"), path)
        }
    }

    func test_settingsSeedChangesEverySetting() {
        let seeded = Preferences(defaults: TestLocations.settings(), downloadsFolder: TestLocations.make().downloads)
        let fresh = Preferences(defaults: TestLocations.settings(), downloadsFolder: TestLocations.make().downloads)

        ScreenshotSettingsSeed.apply(to: seeded)

        XCTAssertEqual(Preferences.ownedKeys.count, 25)
        for key in Preferences.ownedKeys where key != "mg.theme" && key != "mg.palette" {
            let changed = value(of: key, in: seeded)
            XCTAssertNotNil(changed, "no reading for \(key)")
            XCTAssertNotEqual(changed, value(of: key, in: fresh), "\(key) keeps its default")
        }
        XCTAssertGreaterThanOrEqual(seeded.defaultDownloadFolder.path.count, 90)
        XCTAssertNotNil(seeded.proxyURL)
        XCTAssertGreaterThan(seeded.speedLimitKBps, 0)
        XCTAssertGreaterThanOrEqual(seeded.signInSites.count, 5)
    }

    func test_seedHomeWritesOnlyUnderHome() async throws {
        let locations = TestLocations.make()

        try await ScreenshotSettingsSeed.seedHome(locations)

        let log = try String(contentsOf: locations.logs.appendingPathComponent("app.log"), encoding: .utf8)
        for level in ["info", "warn", "error"] {
            XCTAssertTrue(log.contains("\"level\":\"\(level)\""), level)
        }
        let profiles = CookieResolver(browsers: locations.browsers).firefoxProfiles()
        XCTAssertGreaterThanOrEqual(profiles.count, 2)
        for url in [locations.logs, locations.browsers.applicationSupport, locations.browsers.safariCookies] {
            XCTAssertTrue(url.path.hasPrefix(locations.home.path), url.path)
        }
    }

    private func value(of key: String, in prefs: Preferences) -> String? {
        let readings: [String: () -> Any] = [
            "mg.defaultDownloadFolder": { prefs.defaultDownloadFolder.path },
            // Falls back to the default folder, so compare it against that folder rather than a second default.
            "mg.lastUsedDownloadFolder": { prefs.lastUsedDownloadFolder == prefs.defaultDownloadFolder },
            "mg.defaultMediaType": { prefs.defaultMediaType },
            "mg.defaultVideoHeight": { prefs.defaultVideoHeight },
            "mg.defaultAudioFormat": { prefs.defaultAudioFormat },
            "mg.filenameTemplate": { prefs.filenameTemplate },
            "mg.maxAutoRetries": { prefs.maxAutoRetries },
            "mg.maxConcurrentDownloads": { prefs.maxConcurrentDownloads },
            "mg.verboseLogging": { prefs.verboseLogging },
            "mg.detectClipboardLinks": { prefs.detectClipboardLinks },
            "mg.proxyURL": { prefs.proxyURL ?? "" },
            "mg.forceIPv4": { prefs.forceIPv4 },
            "mg.speedLimitKBps": { prefs.speedLimitKBps },
            "mg.lastVideoHeight": { prefs.lastVideoHeight ?? -1 },
            "mg.lastMediaType": { String(describing: prefs.lastMediaType) },
            "mg.lastAudioFormat": { String(describing: prefs.lastAudioFormat) },
            "mg.cookiesFromBrowser": { prefs.cookiesFromBrowser },
            "mg.signInScope": { prefs.signInScope },
            "mg.signInSites": { prefs.signInSites },
            "mg.defaultAudioLanguagePolicy": { prefs.defaultAudioLanguagePolicy },
            "mg.lastAudioLanguage": { String(describing: prefs.lastAudioLanguage) },
            "mg.autoCheckAppUpdates": { prefs.autoCheckAppUpdates },
            "mg.autoCheckYtDlpUpdates": { prefs.autoCheckYtDlpUpdates }
        ]
        return readings[key].map { String(describing: $0()) }
    }

    private func isAudio(_ kind: DownloadKind) -> Bool {
        if case .audio = kind {
            return true
        }
        return false
    }

    private func stateName(_ state: JobState) -> String {
        switch state {
        case .queued: "queued"
        case .probing: "probing"
        case .running: "running"
        case .paused: "paused"
        case .waitingForNetwork: "waitingForNetwork"
        case .cooldown: "cooldown"
        case .completed: "completed"
        case .cancelled: "cancelled"
        case .failed: "failed"
        }
    }

    // Every case is listed, so a new one does not compile until a dummy row covers it.
    private func errorName(_ errorClass: ErrorClass) -> String {
        switch errorClass {
        case .rateLimited, .botCheck, .sabrGated, .formatsMissing, .cookieReadFailed, .geoBlocked, .private,
             .unavailable, .ageRestricted, .networkDown, .diskFull, .permissionDenied, .incomplete, .depMissing,
             .potProviderDown, .passcodeRequired, .passcodeRejected, .unknown:
            errorClass.key
        }
    }
}
