import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport

@MainActor
enum AppModelTestHelpers {
    static func makeModel(
        defaults: UserDefaults,
        logDirectory: URL,
        engine: FakeEngine = FakeEngine(),
        envReady: Bool = true,
        debugFlags: DebugFlags = DebugFlags(),
        revealSink: FakeRevealSink = FakeRevealSink(),
        openURLSink: FakeOpenURLSink = FakeOpenURLSink(),
        persistence: FakeQueuePersisting? = nil,
        notificationRouter: (any NotificationRouting)? = nil,
        ytDlpUpdater: YtDlpUpdating? = nil,
        appUpdating: (any AppUpdating)? = nil,
        appVersion: String = "0.0.0",
        onboardingCompleted: Bool = true,
        bundleURL: URL = Bundle.main.bundleURL,
        locations: AppLocations = TestLocations.make()
    ) -> AppModel {
        defaults.set(onboardingCompleted, forKey: "mg.hasCompletedOnboarding")
        if let persistence {
            engine.attachPersistence(persistence)
        }
        return AppModel(
            engine: engine,
            installer: OnboardingInstaller(
                locations: TestLocations.make(),
                probe: FakeEnvironmentProbe(ready: envReady),
                runner: NullRunner()
            ),
            prefs: Preferences(defaults: defaults, downloadsFolder: TestLocations.make().downloads),
            log: LogWriter(directory: logDirectory),
            locations: locations,
            defaults: defaults,
            suppression: UserDefaultsSuppressionStore(defaults: defaults),
            envProbe: FakeEnvironmentProbe(ready: envReady),
            ytDlpUpdater: ytDlpUpdater ?? FakeYtDlpUpdater(),
            debugFlags: debugFlags,
            notificationRouter: notificationRouter ?? FakeNotificationRouter(),
            revealSink: revealSink,
            openURLSink: openURLSink,
            appUpdating: appUpdating ?? IdleAppUpdating(),
            appVersion: appVersion,
            bundleURL: bundleURL,
            persistence: persistence
        )
    }

    static func meta(title: String = "Clip", url: String = "https://x/y") -> MediaMetadata {
        MediaMetadata(title: title, durationSeconds: 10, isPlaylist: false, sourceURL: url)
    }

    static func jobSnapshot(
        id: UUID = UUID(),
        url: String = "https://example.com/v",
        outputFiles: [URL] = [],
        state: JobState = .completed,
        playlistGroupID: UUID? = nil
    ) -> JobSnapshot {
        JobSnapshot(
            id: id,
            url: url,
            rateHost: RateHost(urlString: "https://example.com/v"),
            title: "Clip",
            state: state,
            progress: nil,
            kind: .video(maxHeight: 1080),
            durationSeconds: 10,
            extractor: "youtube",
            addedAt: Date(),
            finishedAt: Date(),
            destFolder: URL(fileURLWithPath: "/tmp"),
            outputFiles: outputFiles,
            sizeBytes: 100,
            actualQuality: "1080p",
            attempt: 1,
            cooldownUntil: nil,
            playerClientUsed: nil,
            playlistGroupID: playlistGroupID,
            integrityVerdict: .passed,
            availableActions: [.reveal]
        )
    }

    static func logContainsEvent(_ event: String, in directory: URL) throws -> Bool {
        let logFile = directory.appendingPathComponent("app.log")
        guard FileManager.default.fileExists(atPath: logFile.path) else { return false }
        let text = try String(contentsOf: logFile, encoding: .utf8)
        return text.contains("\"event\":\"\(event)\"")
    }
}

@MainActor
final class FakeNotificationRouter: NotificationRouting {
    private(set) var notifiedFailures: [(title: String, reason: String)] = []

    func notifyJobFailed(title: String, reason: String) async {
        notifiedFailures.append((title, reason))
    }
}

struct NullRunner: ProcessRunning {
    func run(_: ProcessLaunch) -> ProcessExecution {
        let (stream, continuation) = AsyncStream<ProcessLine>.makeStream()
        continuation.finish()
        return ProcessExecution(lines: stream) { ProcessResult(exitCode: 0, wasCancelled: false) }
    }
}
