import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import XCTest

@MainActor
final class ScreenshotFixturesTests: XCTestCase {
    func test_noFixtureRowIsQueued() {
        for seed in [ScreenshotFixtures.mixed, ScreenshotFixtures.playlist] {
            for job in seed.active + seed.history {
                XCTAssertNotEqual(job.state, .queued, "Job \(job.id) is queued")
            }
        }
    }

    func test_mixedCoversStates() {
        let activeStates = ScreenshotFixtures.mixed.active.map(\.state)
        let historyStates = ScreenshotFixtures.mixed.history.map(\.state)
        let allStates = activeStates + historyStates
        XCTAssertTrue(allStates.contains(.paused))
        XCTAssertTrue(allStates.contains(.completed))
        XCTAssertTrue(allStates.contains(.failed(reason: "network error")))
        XCTAssertTrue(allStates.contains(.cancelled))
        let pausedWithProgress = ScreenshotFixtures.mixed.active
            .first { $0.state == .paused && ($0.progressFraction ?? 0) > 0 && ($0.progressFraction ?? 1) < 1 }
        XCTAssertNotNil(pausedWithProgress)
    }

    func test_fixturesAreDeterministic() {
        XCTAssertEqual(ScreenshotFixtures.mixed, ScreenshotFixtures.mixed)
        let allJobs = ScreenshotFixtures.mixed.active + ScreenshotFixtures.mixed.history
        for job in allJobs {
            XCTAssertEqual(job.addedAt, ScreenshotFixtures.epoch)
            if let finishedAt = job.finishedAt {
                XCTAssertEqual(finishedAt, ScreenshotFixtures.epoch.addingTimeInterval(60))
            }
            XCTAssertNotEqual(job.id, UUID())
        }
    }

    func test_playlistSeedHasGroupWithChildren() {
        XCTAssertEqual(ScreenshotFixtures.playlist.groups.count, 1)
        let groupID = ScreenshotFixtures.playlist.groups[0].id
        let jobsInGroup = ScreenshotFixtures.playlist.active.filter { $0.playlistGroupID == groupID }
        XCTAssertGreaterThanOrEqual(jobsInGroup.count, 3)
        let indices = Set(jobsInGroup.compactMap(\.playlistIndex))
        XCTAssertGreaterThanOrEqual(indices.count, 3)
    }

    func test_urlsAreExampleDomains() {
        let allJobs = ScreenshotFixtures.mixed.active + ScreenshotFixtures.mixed.history + ScreenshotFixtures.playlist
            .active + ScreenshotFixtures.playlist.history
        for job in allJobs {
            let host = URL(string: job.request.url)?.host
            XCTAssertTrue(host?.hasSuffix("example.com") == true, "URL \(job.request.url) is not example.com")
        }
    }
}
