import Foundation
@testable import GrabberKit
@testable import MediaGrabber
import TestSupport
import XCTest

@MainActor
final class DummyEngineTests: XCTestCase {
    private let world = DummyWorld()

    func test_publishEmitsSnapshotWithRisingRevision() async {
        let engine = DummyEngine(world: world)
        engine.publish(DummyQueueState(jobs: [job()]))
        engine.publish(.empty)

        var seen: [QueueSnapshot] = []
        for await event in engine.events {
            if case let .snapshot(snapshot) = event {
                seen.append(snapshot)
            }
            if seen.count == 2 {
                break
            }
        }

        XCTAssertGreaterThan(seen[1].revision, seen[0].revision)
        let current = await engine.currentSnapshot()
        XCTAssertEqual(current, seen[1])
    }

    func test_playlistGroupCountsComeFromJobs() async throws {
        let engine = DummyEngine(world: world)
        let groupID = UUID()
        engine.publish(DummyQueueState(
            jobs: [
                job(state: .completed, group: groupID),
                job(state: .queued, group: groupID),
                job(state: .paused, group: groupID)
            ],
            playlistGroups: [PersistedPlaylistGroup(
                id: groupID,
                title: "Group",
                sourceURL: "https://example.com/list",
                isCollapsed: false
            )]
        ))

        let snapshot = await engine.currentSnapshot()
        let group = try XCTUnwrap(snapshot.playlistGroups.first)
        XCTAssertEqual(group.totalCount, 3)
        XCTAssertEqual(group.completedCount, 1)
    }

    func test_controlCallsChangeNothing() async {
        let engine = DummyEngine(world: world)
        let running = job(state: .running)
        engine.publish(DummyQueueState(jobs: [running]))
        let before = await engine.currentSnapshot()

        await engine.pause(running.id)
        await engine.cancel(running.id)
        await engine.remove(running.id)
        await engine.retry(running.id)

        let after = await engine.currentSnapshot()
        XCTAssertEqual(after, before)
    }

    func test_pendingLinkNeverAnswers() async throws {
        world.linkResult = .pending
        let engine = DummyEngine(world: world)
        let answered = LockedBox(false)
        let check = Task {
            _ = await engine.preview("https://example.com/v")
            answered.mutate { $0 = true }
        }

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(answered.read { $0 })

        check.cancel()
        let returned = expectation(description: "cancelled check returns")
        Task {
            await check.value
            returned.fulfill()
        }
        await fulfillment(of: [returned], timeout: 5)
        XCTAssertTrue(answered.read { $0 })
    }

    private func job(state: JobState = .completed, group: UUID? = nil) -> JobSnapshot {
        AppModelTestHelpers.jobSnapshot(state: state, playlistGroupID: group)
    }
}
