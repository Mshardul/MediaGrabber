import Foundation
@testable import GrabberKit

public final class FakeEnvironmentProbe: EnvironmentProbing, @unchecked Sendable {
    private let reports: [EnvironmentReport]
    private let callCount = LockedBox(0)

    public init(_ reports: EnvironmentReport...) {
        precondition(!reports.isEmpty)
        self.reports = reports
    }

    public convenience init(ready: Bool) {
        self.init(.with(ytDlp: ready, ffmpeg: ready))
    }

    public func probe() async -> EnvironmentReport {
        let index = callCount.mutate { count -> Int in
            let current = count
            count += 1
            return current
        }
        return reports[min(index, reports.count - 1)]
    }
}

public extension EnvironmentReport {
    static func with(
        ytDlp: Bool = false,
        ffmpeg: Bool = false,
        ffprobe: Bool = false
    ) -> EnvironmentReport {
        func tool(_ name: String, _ present: Bool) -> ToolInfo? {
            present
                ? ToolInfo(path: URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"), version: "0")
                : nil
        }
        return EnvironmentReport(
            ytDlp: tool("yt-dlp", ytDlp),
            ffmpeg: tool("ffmpeg", ffmpeg),
            ffprobe: tool("ffprobe", ffprobe)
        )
    }
}
