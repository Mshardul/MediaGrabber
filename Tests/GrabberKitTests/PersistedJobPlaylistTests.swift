@testable import GrabberKit
import XCTest

final class PersistedJobPlaylistTests: XCTestCase {
    private let playlistGroupID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let jobID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let addedAt = Date(timeIntervalSince1970: 10)

    func test_persistedJobRoundTripPreservesPlaylistFields() throws {
        let original = PersistedJob(
            id: jobID,
            request: request(),
            state: .queued,
            playlistGroupID: playlistGroupID,
            playlistIndex: 3,
            addedAt: addedAt
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedJob.self, from: data)

        XCTAssertEqual(decoded.playlistGroupID, playlistGroupID)
        XCTAssertEqual(decoded.playlistIndex, 3)
    }

    func test_downloadJobSnapshotIncludesPlaylistFields() {
        let job = DownloadJob(request: request(), id: jobID, addedAt: addedAt)
        job.playlistGroupID = playlistGroupID
        job.playlistIndex = 3

        let snapshot = job.snapshot(availableActions: [])

        XCTAssertEqual(snapshot.playlistGroupID, playlistGroupID)
        XCTAssertEqual(snapshot.playlistIndex, 3)
    }

    func test_isProbeComplete_requiresTitleAndExtractor_notDuration() {
        let request = request()
        let base: (String?, String?, Int?) -> PersistedJob = { [jobID, addedAt] title, extractor, duration in
            PersistedJob(
                id: jobID,
                request: request,
                title: title,
                extractor: extractor,
                durationSeconds: duration,
                state: .queued,
                attempt: 0,
                playlistGroupID: nil,
                addedAt: addedAt
            )
        }

        XCTAssertTrue(base("t", "youtube", 10).isProbeComplete)
        // Duration is optional: a probed link with no duration is still probe-complete.
        XCTAssertTrue(base("t", "youtube", nil).isProbeComplete)
        XCTAssertFalse(base(nil, "youtube", 10).isProbeComplete)
        XCTAssertFalse(base("t", nil, 10).isProbeComplete)
        XCTAssertFalse(base(nil, nil, 10).isProbeComplete)
    }

    func test_enginePersistenceProjectionPreservesPlaylistFields() {
        let job = DownloadJob(request: request(), id: jobID, addedAt: addedAt)
        job.playlistGroupID = playlistGroupID
        job.playlistIndex = 3

        let persisted = DownloadEngine.persistedJob(from: job)
        let restored = DownloadEngine.downloadJob(from: persisted)

        XCTAssertEqual(persisted.playlistGroupID, playlistGroupID)
        XCTAssertEqual(persisted.playlistIndex, 3)
        XCTAssertEqual(restored.playlistGroupID, playlistGroupID)
        XCTAssertEqual(restored.playlistIndex, 3)
    }

    private func request() -> DownloadRequest {
        DownloadRequest(
            url: "https://archive.org/details/example",
            destFolder: URL(fileURLWithPath: "/tmp/out"),
            kind: .video(maxHeight: 1080),
            container: "mp4",
            filenameTemplate: "%(title)s.%(ext)s"
        )
    }
}
