#if DEBUG
    import Foundation
    import GrabberKit
    import os

    struct DummyEnvironmentProbe: EnvironmentProbing {
        let world: DummyWorld

        func probe() async -> EnvironmentReport {
            world.environment
        }
    }

    struct DummyYtDlpUpdater: YtDlpUpdating {
        func updateToLatest() async -> YtDlpUpdateResult {
            .success(newVersion: "2026.11.20")
        }
    }

    // Serves both checks: only the sign-in test sends a browser's cookies.
    struct DummyMetadataProbe: MetadataProbing {
        let world: DummyWorld

        func probe(
            _: String,
            context: ExtractorContext,
            onWait _: (@Sendable (Date?) -> Void)?
        ) async -> Result<MediaMetadata, MetadataError> {
            guard context.cookieArgument == nil else { return world.signInResult }
            return world.testRunPasses ? .success(DummyWorld.testRunMetadata) : .failure(.unavailable)
        }

        func probePlaylist(_: String, context _: ExtractorContext) async -> Result<PlaylistDump, MetadataError> {
            .failure(.unsupported)
        }
    }

    struct DummyVPNDetector: VPNDetecting {
        var isVPNActive: Bool {
            false
        }
    }

    struct DummyNotificationRouter: NotificationRouting {
        func notifyJobFailed(title _: String, reason _: String) async {}
    }

    struct DummyRevealSink: RevealSink {
        func reveal(_: [URL]) {}
    }

    struct DummyOpenURLSink: OpenURLSink {
        func open(_: URL) {}
    }

    struct DummySettingsLink: SettingsLinkOpening {
        func open(_: URL) {}
    }

    struct DummySharePresenter: SharePresenting {
        func share(data _: Data, filename _: String) {}
    }

    // Stands where the real clipboard would, so a run never reads what the developer copied.
    final class DummyPasteboard: PasteboardReading, PasteboardWriting {
        private let reads = OSAllocatedUnfairLock(initialState: 0)

        var readCount: Int {
            reads.withLock { $0 }
        }

        var changeCount: Int {
            0
        }

        func readString() -> String? {
            reads.withLock { $0 += 1 }
            return nil
        }

        func writeString(_: String) {}
    }
#endif
