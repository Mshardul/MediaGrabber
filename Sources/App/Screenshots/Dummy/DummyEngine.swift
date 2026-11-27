#if DEBUG
    import Foundation
    import GrabberKit
    import os

    struct DummyQueueState: Sendable, Equatable {
        var jobs: [JobSnapshot] = []
        var queueHalt: QueueHaltReason?
        var hostRateSummary: [RateHost: HostRateDisplayState] = [:]
        var isOnline = true
        var shieldStatus = ShieldStatus.running(port: 4416)
        var playlistGroups: [PersistedPlaylistGroup] = []

        static let empty = DummyQueueState()
    }

    // Publishes the state a scene asks for and does no work of its own, so nothing moves before a capture.
    final class DummyEngine: DownloadEngineProtocol {
        let events: AsyncStream<QueueEvent>
        private let continuation: AsyncStream<QueueEvent>.Continuation
        private let world: DummyWorld
        private let latest = OSAllocatedUnfairLock(initialState: DummyEngine.snapshot(of: .empty, revision: 0))

        init(world: DummyWorld) {
            self.world = world
            (events, continuation) = AsyncStream<QueueEvent>.makeStream()
        }

        @discardableResult
        func publish(_ state: DummyQueueState) -> UInt64 {
            let next = latest.withLock { current in
                current = Self.snapshot(of: state, revision: current.revision + 1)
                return current
            }
            continuation.yield(.snapshot(next))
            return next.revision
        }

        private static func snapshot(of state: DummyQueueState, revision: UInt64) -> QueueSnapshot {
            QueueSnapshot(
                jobs: state.jobs,
                revision: revision,
                queueHalt: state.queueHalt,
                hostRateSummary: state.hostRateSummary,
                isOnline: state.isOnline,
                shieldStatus: state.shieldStatus,
                playlistGroups: state.playlistGroups.map {
                    PlaylistGroupSnapshot.rollup(from: state.jobs, registry: $0)
                }
            )
        }

        func currentSnapshot() async -> QueueSnapshot {
            latest.withLock { $0 }
        }

        func hasActiveJobs() async -> Bool {
            false
        }

        func preview(_: String) async -> Result<MediaMetadata, MetadataError> {
            switch world.linkResult {
            case let .video(metadata): .success(metadata)
            case let .failure(error): .failure(error)
            case .playlist: .failure(.unsupported)
            case .pending: await .failure(Self.neverAnswer())
            }
        }

        func previewPlaylist(_: String) async -> Result<PlaylistDump, MetadataError> {
            switch world.linkResult {
            case let .playlist(dump): .success(dump)
            case let .failure(error): .failure(error)
            case .video: .failure(.unsupported)
            case .pending: await .failure(Self.neverAnswer())
            }
        }

        // Returns only once the caller's task is cancelled.
        private static func neverAnswer() async -> MetadataError {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
            }
            return .network
        }

        func submit(_: DownloadRequest, force _: Bool, prefetchedMetadata _: MediaMetadata?) async -> SubmitResult {
            .queued(UUID())
        }

        func submitPlaylistItems(_: [PlaylistSubmitItem]) async -> [UUID] {
            []
        }

        func restore(active _: [PersistedJob], history _: [PersistedJob]) async {}
        func revalidate() async {}
        func pause(_: UUID) async {}
        func resume(_: UUID) async {}
        func retry(_: UUID) async {}
        func retryWithCookies(_: UUID) async {}
        func setPasscode(_: String, for _: String) async {}
        func retryWithPasscode(_: UUID, passcode _: String) async {}
        func cancel(_: UUID) async {}
        func remove(_: UUID) async {}
        func forceStart(_: UUID) async {}
        func willForceStartEvict(_: UUID) async -> Bool {
            false
        }

        func resetCircuit(_: RateHost) async {}
        func resetAllCircuits() async {}
        func upsertPlaylistGroup(_: PersistedPlaylistGroup) async {}
        func setPlaylistGroupCollapsed(id _: UUID, _: Bool) async {}
        func loadPlaylistGroupsFromPersistence() async {}
        func ensureShield() async {}
        func restartShield() async -> Bool {
            true
        }

        func shutdown() async {}
    }
#endif
