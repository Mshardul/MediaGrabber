@testable import GrabberKit
import TestSupport
import XCTest

final class EnginePreparedInfoTests: XCTestCase {
    private typealias Fix = EngineFixture

    private let zoomURL = "https://example.zoom.us/rec/share/abc"
    private let now = Date(timeIntervalSince1970: 10000)

    func test_freshCheckDataIsUsedInsteadOfTheLink() async throws {
        let argv = await downloadArguments(preparedAgo: 60)

        let flag = try XCTUnwrap(argv.firstIndex(of: "--load-info-json"))
        XCTAssertFalse(argv.contains(zoomURL), "a second URL would run the site's whole check again")
        XCTAssertTrue(argv.contains("--abort-on-error"), "without it a dead saved link never falls back to the page")
        XCTAssertFalse(FileManager.default.fileExists(atPath: argv[flag + 1]), "session cookies must not stay on disk")
    }

    // The video request follows the check directly, so the downloader itself has to wait before sending it.
    func test_savedDataDownloadWaitsBeforeTheVideoRequest() async throws {
        let argv = await downloadArguments(preparedAgo: 0)

        for flag in ["--sleep-interval", "--max-sleep-interval"] {
            XCTAssertEqual(try argv[XCTUnwrap(argv.firstIndex(of: flag)) + 1], "5")
        }
    }

    func test_staleCheckDataFallsBackToTheLink() async {
        let argv = await downloadArguments(preparedAgo: 11 * 60)

        XCTAssertFalse(argv.contains("--load-info-json"))
        XCTAssertEqual(argv.last, zoomURL)
    }

    func test_checkDataIsWrittenReadableByTheOwnerOnly() throws {
        let file = try PreparedInfo(json: "{}", capturedAt: now).write(jobID: UUID())
        defer { try? FileManager.default.removeItem(at: file) }

        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "{}")
    }

    func test_onlyZoomChecksAreKeptForReuse() throws {
        func prepared(_ extractor: String) throws -> PreparedInfo? {
            let json = "{\"title\": \"T\", \"extractor\": \"\(extractor)\"}"
            return try MetadataProbe.decodeForTest(json, sourceURL: zoomURL).get().prepared
        }

        XCTAssertNotNil(try prepared("zoom"))
        XCTAssertNil(try prepared("youtube"))
    }

    private func downloadArguments(preparedAgo seconds: TimeInterval) async -> [String] {
        let runner = FakeProcessRunner()
        runner.script(Fix.completingScript(), forPathEndingIn: "yt-dlp")
        let engine = Fix.engine(runner: runner, probe: FakeMetadataProbe(), clock: FakeClock(now: now))
        let collector = EventCollector(engine.events)
        let meta = MediaMetadata(
            title: "Clip",
            durationSeconds: nil,
            isPlaylist: false,
            sourceURL: zoomURL,
            extractor: "zoom",
            prepared: PreparedInfo(json: "{}", capturedAt: now.addingTimeInterval(-seconds))
        )
        let result = await engine.submit(Fix.request(url: zoomURL), force: false, prefetchedMetadata: meta)
        guard case let .queued(id) = result else {
            XCTFail("expected .queued")
            return []
        }
        await expectState(collector, id) { $0 == .completed }
        await engine.shutdown()
        return runner.launches.first { $0.executableURL.lastPathComponent == "yt-dlp" }?.arguments ?? []
    }
}
