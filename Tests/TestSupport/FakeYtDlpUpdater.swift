import Foundation
@testable import GrabberKit

public final class FakeYtDlpUpdater: YtDlpUpdating, @unchecked Sendable {
    private let result: YtDlpUpdateResult

    public init(result: YtDlpUpdateResult = .success(newVersion: "2026.08.19")) {
        self.result = result
    }

    public func updateToLatest() async -> YtDlpUpdateResult {
        result
    }
}
