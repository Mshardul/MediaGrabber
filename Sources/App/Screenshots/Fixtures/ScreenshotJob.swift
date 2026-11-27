#if DEBUG
    import Foundation
    import GrabberKit

    // One dummy row; actions come from the engine's own rule, so a row offers what it would in the app.
    struct ScreenshotJob {
        // Shown as a date and time, so it is fixed: a date taken from the clock would read differently each run.
        static let addedAnchor = Date(timeIntervalSince1970: 1_794_500_000)
        static let downloads = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)

        var number: Int
        var title: String?
        var state: JobState
        var url: String?
        var kind = DownloadKind.video(maxHeight: 1080)
        var extractor: String? = "youtube"
        var durationSeconds: Int? = 754
        var sizeBytes: Int64? = 184_000_000
        var quality: String?
        var progress: DownloadProgress?
        var attempt = 1
        var cooldownUntil: Date?
        var probeWaitUntil: Date?
        var signInAdvice = SignInAdvice.none
        var integrity: IntegrityVerdict?
        var playerClient: String?
        var destFolder = ScreenshotJob.downloads
        var group: UUID?
        var playlistIndex: Int?

        static func id(_ number: Int) -> UUID {
            let tail = String(format: "%012d", number)
            return UUID(uuidString: "00000000-0000-4000-8000-\(tail)") ?? UUID()
        }

        var snapshot: JobSnapshot {
            let address = url ?? "https://youtube.example.com/watch?v=clip\(number)"
            let added = Self.addedAnchor.addingTimeInterval(TimeInterval(-number * 5400))
            let isCompleted = state == .completed
            return JobSnapshot(
                id: Self.id(number),
                url: address,
                rateHost: RateHost(urlString: address),
                title: title,
                state: state,
                progress: progress,
                kind: kind,
                durationSeconds: durationSeconds,
                extractor: extractor,
                addedAt: added,
                finishedAt: isFinished ? added.addingTimeInterval(1260) : nil,
                destFolder: destFolder,
                outputFiles: isCompleted ? [destFolder.appendingPathComponent("clip\(number).mp4")] : [],
                sizeBytes: sizeBytes,
                actualQuality: quality,
                attempt: attempt,
                cooldownUntil: cooldownUntil,
                playerClientUsed: playerClient,
                playlistGroupID: group,
                playlistIndex: playlistIndex,
                integrityVerdict: integrity,
                availableActions: DownloadEngine.availableActions(for: state, signInAdvice: signInAdvice),
                probeWaitUntil: probeWaitUntil,
                signInAdvice: signInAdvice
            )
        }

        private var isFinished: Bool {
            switch state {
            case .completed, .cancelled, .failed: true
            case .queued, .probing, .running, .paused, .waitingForNetwork, .cooldown: false
            }
        }

        static func progress(
            _ fraction: Double,
            of total: Int64,
            speed: Double? = nil,
            eta: Int? = nil
        ) -> DownloadProgress {
            DownloadProgress(
                fraction: fraction,
                speedBytesPerSec: speed,
                etaSeconds: eta,
                downloadedBytes: Int64(Double(total) * fraction),
                totalBytes: total
            )
        }
    }
#endif
