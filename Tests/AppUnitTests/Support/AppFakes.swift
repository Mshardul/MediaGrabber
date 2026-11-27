import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport

final class FakeEngine: DownloadEngineProtocol, @unchecked Sendable {
    private let box = LockedBox(State())
    private let continuation: AsyncStream<QueueEvent>.Continuation

    let events: AsyncStream<QueueEvent>

    private struct State {
        var submitted: [(DownloadRequest, Bool)] = []
        var paused: [UUID] = []
        var cancelled: [UUID] = []
        var removed: [UUID] = []
        var retried: [UUID] = []
        var retriedWithCookies: [UUID] = []
        var forceStarted: [UUID] = []
        var submitResults: [SubmitResult] = []
        var snapshot = QueueSnapshot(
            jobs: [], revision: 0, queueHalt: nil,
            hostRateSummary: [:], isOnline: true
        )
        var restoreSnapshot: QueueSnapshot?
        var restoreCalled = false
        var restoreCount = 0
        var revalidateCalled = false
        var previewResult: Result<MediaMetadata, MetadataError> = .failure(.malformedOutput)
        var previewPlaylistResult: Result<PlaylistDump, MetadataError> = .failure(.malformedOutput)
        var previewed: [String] = []
        var previewedPlaylists: [String] = []
        var submittedPlaylistItems: [PlaylistSubmitItem] = []
        var stubPlaylistSubmitIDs: [UUID]?
        var ensureCount = 0
        var restartShieldResult = true
        var playlistGroups: [PersistedPlaylistGroup] = []
        var persistence: FakeQueuePersisting?
    }

    init() {
        let (stream, continuation) = AsyncStream<QueueEvent>.makeStream()
        events = stream
        self.continuation = continuation
    }

    var submittedRequests: [DownloadRequest] {
        box.read { $0.submitted.map(\.0) }
    }

    var submittedForces: [Bool] {
        box.read { $0.submitted.map(\.1) }
    }

    var pausedIDs: [UUID] {
        box.read { $0.paused }
    }

    var cancelledIDs: [UUID] {
        box.read { $0.cancelled }
    }

    var removedIDs: [UUID] {
        box.read { $0.removed }
    }

    var retriedIDs: [UUID] {
        box.read { $0.retried }
    }

    var forceStartedIDs: [UUID] {
        box.read { $0.forceStarted }
    }

    var retriedWithCookiesIDs: [UUID] {
        box.read { $0.retriedWithCookies }
    }

    let passcodeCalls = PasscodeCallLog()

    var restoreCalled: Bool {
        box.read { $0.restoreCalled }
    }

    var restoreCount: Int {
        box.read { $0.restoreCount }
    }

    var revalidateCalled: Bool {
        box.read { $0.revalidateCalled }
    }

    var previewedURLs: [String] {
        box.read { $0.previewed }
    }

    var previewPlaylistURLs: [String] {
        box.read { $0.previewedPlaylists }
    }

    var submittedPlaylistItems: [PlaylistSubmitItem] {
        box.read { $0.submittedPlaylistItems }
    }

    var ensureCount: Int {
        box.read { $0.ensureCount }
    }

    func attachPersistence(_ persistence: FakeQueuePersisting) {
        box.mutate { $0.persistence = persistence }
    }

    func stubPreview(_ result: Result<MediaMetadata, MetadataError>) {
        box.mutate { $0.previewResult = result }
    }

    func stubPreviewPlaylist(_ result: Result<PlaylistDump, MetadataError>) {
        box.mutate { $0.previewPlaylistResult = result }
    }

    func stubNextResult(_ result: SubmitResult) {
        box.mutate { $0.submitResults = [result] }
    }

    func stubSubmitResults(_ results: SubmitResult...) {
        box.mutate { $0.submitResults = results }
    }

    func stubPlaylistSubmitIDs(_ ids: [UUID]) {
        box.mutate { $0.stubPlaylistSubmitIDs = ids }
    }

    func setSnapshot(_ snapshot: QueueSnapshot) {
        box.mutate { $0.snapshot = snapshot }
    }

    func setRestoreSnapshot(_ snapshot: QueueSnapshot) {
        box.mutate { $0.restoreSnapshot = snapshot }
    }

    func emit(_ event: QueueEvent) {
        continuation.yield(event)
    }

    func currentSnapshot() async -> QueueSnapshot {
        box.read { $0.snapshot }
    }

    func hasActiveJobs() async -> Bool {
        false
    }

    func submit(
        _ request: DownloadRequest,
        force: Bool,
        prefetchedMetadata _: MediaMetadata?
    ) async -> SubmitResult {
        let result: SubmitResult? = box.mutate { state in
            state.submitted.append((request, force))
            guard !state.submitResults.isEmpty else { return nil }
            return state.submitResults.removeFirst()
        }
        return result ?? .queued(UUID())
    }

    func submitPlaylistItems(_ items: [PlaylistSubmitItem]) async -> [UUID] {
        box.mutate { state in
            state.submittedPlaylistItems.append(contentsOf: items)
        }
        if let stubbed = box.read { $0.stubPlaylistSubmitIDs } {
            return stubbed
        }
        return items.map { _ in UUID() }
    }

    func revalidate() async {
        box.mutate { $0.revalidateCalled = true }
    }

    func pause(_ jobID: UUID) async {
        box.mutate { $0.paused.append(jobID) }
    }

    func resume(_: UUID) async {}

    func retry(_ jobID: UUID) async {
        box.mutate { $0.retried.append(jobID) }
    }

    func retryWithCookies(_ jobID: UUID) async {
        box.mutate { $0.retriedWithCookies.append(jobID) }
    }

    func setPasscode(_ passcode: String, for url: String) async {
        passcodeCalls.recordSet(passcode, for: url)
    }

    func retryWithPasscode(_ jobID: UUID, passcode: String) async {
        passcodeCalls.recordRetry(jobID, passcode: passcode)
    }

    func cancel(_ jobID: UUID) async {
        box.mutate { $0.cancelled.append(jobID) }
    }

    func remove(_ jobID: UUID) async {
        let snapshot = box.mutate { state -> QueueSnapshot in
            state.removed.append(jobID)
            let jobs = state.snapshot.jobs.filter { $0.id != jobID }
            let live = Set(jobs.compactMap(\.playlistGroupID))
            state.playlistGroups.removeAll { !live.contains($0.id) }
            state.persistence?.savePlaylistGroups(state.playlistGroups)
            state.snapshot = QueueSnapshot(
                jobs: jobs,
                revision: state.snapshot.revision + 1,
                queueHalt: state.snapshot.queueHalt,
                hostRateSummary: state.snapshot.hostRateSummary,
                isOnline: state.snapshot.isOnline,
                shieldStatus: state.snapshot.shieldStatus,
                playlistGroups: state.playlistGroups.map {
                    PlaylistGroupSnapshot.rollup(from: jobs, registry: $0)
                }
            )
            return state.snapshot
        }
        continuation.yield(.snapshot(snapshot))
    }

    func forceStart(_ jobID: UUID) async {
        box.mutate { $0.forceStarted.append(jobID) }
    }

    func willForceStartEvict(_: UUID) async -> Bool {
        false
    }

    func resetCircuit(_: RateHost) async {}
    func resetAllCircuits() async {}

    func preview(_ url: String) async -> Result<MediaMetadata, MetadataError> {
        box.mutate { state in
            state.previewed.append(url)
            return state.previewResult
        }
    }

    func previewPlaylist(_ url: String) async -> Result<PlaylistDump, MetadataError> {
        box.mutate { state in
            state.previewedPlaylists.append(url)
            return state.previewPlaylistResult
        }
    }

    func ensureShield() async {
        box.mutate { $0.ensureCount += 1 }
    }

    func restartShield() async -> Bool {
        box.read { $0.restartShieldResult }
    }

    func setRestartShieldResult(_ result: Bool) {
        box.mutate { $0.restartShieldResult = result }
    }

    func shutdown() async {}
}

extension FakeEngine {
    func restore(active _: [PersistedJob], history _: [PersistedJob]) async {
        let snapshot = box.mutate { state -> QueueSnapshot? in
            state.restoreCalled = true
            state.restoreCount += 1
            if let restoreSnapshot = state.restoreSnapshot {
                state.snapshot = restoreSnapshot
                return restoreSnapshot
            }
            return nil
        }
        if let snapshot {
            continuation.yield(.snapshot(snapshot))
        }
    }

    func upsertPlaylistGroup(_ group: PersistedPlaylistGroup) async {
        let snapshot = box.mutate { state -> QueueSnapshot in
            if let index = state.playlistGroups.firstIndex(where: { $0.id == group.id }) {
                state.playlistGroups[index] = group
            } else {
                state.playlistGroups.append(group)
            }
            state.persistence?.savePlaylistGroups(state.playlistGroups)
            state.snapshot = withGroups(state.snapshot, groups: state.playlistGroups)
            return state.snapshot
        }
        continuation.yield(.snapshot(snapshot))
    }

    func setPlaylistGroupCollapsed(id: UUID, _ collapsed: Bool) async {
        let snapshot = box.mutate { state -> QueueSnapshot in
            guard let index = state.playlistGroups.firstIndex(where: { $0.id == id }) else {
                return state.snapshot
            }
            state.playlistGroups[index].isCollapsed = collapsed
            state.persistence?.savePlaylistGroups(state.playlistGroups)
            state.snapshot = withGroups(state.snapshot, groups: state.playlistGroups)
            return state.snapshot
        }
        continuation.yield(.snapshot(snapshot))
    }

    func loadPlaylistGroupsFromPersistence() async {
        let snapshot = box.mutate { state -> QueueSnapshot in
            let loaded = state.persistence?.loadPlaylistGroups() ?? state.playlistGroups
            let live = Set(state.snapshot.jobs.compactMap(\.playlistGroupID))
            state.playlistGroups = loaded.filter { live.contains($0.id) }
            state.snapshot = withGroups(state.snapshot, groups: state.playlistGroups)
            return state.snapshot
        }
        continuation.yield(.snapshot(snapshot))
    }

    private func withGroups(
        _ snapshot: QueueSnapshot,
        groups: [PersistedPlaylistGroup]
    ) -> QueueSnapshot {
        QueueSnapshot(
            jobs: snapshot.jobs,
            revision: snapshot.revision + 1,
            queueHalt: snapshot.queueHalt,
            hostRateSummary: snapshot.hostRateSummary,
            isOnline: snapshot.isOnline,
            shieldStatus: snapshot.shieldStatus,
            playlistGroups: groups.map {
                PlaylistGroupSnapshot.rollup(from: snapshot.jobs, registry: $0)
            }
        )
    }
}

@MainActor
final class FakeRevealSink: RevealSink {
    private(set) var revealed: [URL] = []

    nonisolated init() {}

    func reveal(_ files: [URL]) {
        revealed = files
    }
}
