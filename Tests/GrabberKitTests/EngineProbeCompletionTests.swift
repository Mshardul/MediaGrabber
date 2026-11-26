@testable import GrabberKit
import TestSupport
import XCTest

final class EngineProbeCompletionTests: XCTestCase {
    private typealias Fix = EngineFixture

    func test_linkWithNoDuration_isProbedOnceAndDownloaded() async {
        let runner = FakeProcessRunner()
        runner.script(Fix.completingScript(), forPathEndingIn: "yt-dlp")
        let probe = FakeMetadataProbe()
        probe.result(FakeMetadataProbe.success(title: "Live", durationSeconds: nil))
        let engine = Fix.engine(runner: runner, probe: probe)
        let collector = EventCollector(engine.events)

        let id = await submitJob(engine, Fix.request())
        await expectState(collector, id) { $0 == .completed }

        XCTAssertEqual(probe.probedURLs.count, 1)
        await engine.shutdown()
    }
}
