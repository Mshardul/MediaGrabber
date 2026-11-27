#if DEBUG
    import Foundation
    import GrabberKit
    import os

    enum DummyLinkResult: Sendable {
        case video(MediaMetadata)
        case playlist(PlaylistDump)
        case failure(MetadataError)
        case pending
    }

    // Lock-backed because the dummy services answer off the main actor.
    final class DummyWorld: Sendable {
        struct Values: Sendable {
            var environment = DummyWorld.readyEnvironment
            var linkResult = DummyLinkResult.failure(.unavailable)
            var shieldInstalled = true
            var testRunPasses = true
            var signInResult: Result<MediaMetadata, MetadataError> = .success(DummyWorld.testRunMetadata)
        }

        private let values = OSAllocatedUnfairLock(initialState: Values())

        var environment: EnvironmentReport {
            get { values.withLock { $0.environment } }
            set { values.withLock { $0.environment = newValue } }
        }

        var linkResult: DummyLinkResult {
            get { values.withLock { $0.linkResult } }
            set { values.withLock { $0.linkResult = newValue } }
        }

        var shieldInstalled: Bool {
            get { values.withLock { $0.shieldInstalled } }
            set { values.withLock { $0.shieldInstalled = newValue } }
        }

        var testRunPasses: Bool {
            get { values.withLock { $0.testRunPasses } }
            set { values.withLock { $0.testRunPasses = newValue } }
        }

        var signInResult: Result<MediaMetadata, MetadataError> {
            get { values.withLock { $0.signInResult } }
            set { values.withLock { $0.signInResult = newValue } }
        }

        func reset() {
            values.withLock { $0 = Values() }
        }

        static let readyEnvironment = EnvironmentReport(
            ytDlp: tool("yt-dlp", version: "2026.11.12"),
            ffmpeg: tool("ffmpeg", version: "8.0.1"),
            ffprobe: tool("ffprobe", version: "8.0.1")
        )

        // Older than the version the app expects, so it offers an update.
        static let outdatedEnvironment = EnvironmentReport(
            ytDlp: tool("yt-dlp", version: "2024.01.01"),
            ffmpeg: tool("ffmpeg", version: "8.0.1"),
            ffprobe: tool("ffprobe", version: "8.0.1")
        )

        static let degradedEnvironment = EnvironmentReport(
            ytDlp: tool("yt-dlp", version: "2024.01.01"),
            ffmpeg: nil
        )

        static let testRunMetadata = MediaMetadata(
            title: "Test clip",
            durationSeconds: 10,
            isPlaylist: false,
            sourceURL: "https://example.com/test-clip"
        )

        private static func tool(_ name: String, version: String) -> ToolInfo {
            ToolInfo(path: URL(fileURLWithPath: "/Users/example/MediaGrabber/Tools/\(name)"), version: version)
        }
    }
#endif
