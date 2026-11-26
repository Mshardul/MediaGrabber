@testable import GrabberKit
import TestSupport
import XCTest

class PersistenceTestCase: XCTestCase {
    var dir = URL(fileURLWithPath: "/tmp")
    var clock = FakeClock()

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mg-persist-\(UUID().uuidString)")
        clock = FakeClock(now: Date(timeIntervalSince1970: 0))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func makePersistence(reset: Bool = false) -> Persistence {
        Persistence(
            dir: dir,
            clock: clock,
            log: LogWriter(directory: dir.appendingPathComponent("logs")),
            debug: PersistenceDebug(resetState: reset)
        )
    }

    func job(
        _ index: Int,
        state: PersistedState = .queued,
        finishedAt: Date? = nil,
        title: String? = "t",
        extractor: String? = "youtube",
        duration: Int? = 10
    ) -> PersistedJob {
        PersistedJob(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)")!,
            request: request(url: "u\(index)"),
            title: title, extractor: extractor, durationSeconds: duration,
            state: state, attempt: 0, playlistGroupID: nil,
            addedAt: Date(timeIntervalSince1970: TimeInterval(index)), finishedAt: finishedAt
        )
    }

    func request(
        url: String = "https://archive.org/x",
        kind: DownloadKind = .video(maxHeight: 1080),
        container: String? = "mp4",
        template: String = "%(title)s.%(ext)s",
        dest: URL = URL(fileURLWithPath: "/tmp/out")
    ) -> DownloadRequest {
        DownloadRequest(
            url: url,
            destFolder: dest,
            kind: kind,
            container: container,
            filenameTemplate: template
        )
    }

    func flush(_ persistence: Persistence) async {
        await persistence.flushNow()
    }
}
