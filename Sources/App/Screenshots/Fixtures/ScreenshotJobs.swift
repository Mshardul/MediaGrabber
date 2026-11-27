#if DEBUG
    import Foundation
    import GrabberKit

    enum ScreenshotJobs {
        static let playlistGroupID = ScreenshotJob.id(900)
        // Half a second past a whole number, so a countdown reads the same however fast the capture is.
        static let countdownSeconds: TimeInterval = 272.5

        private static let longTitle = "The Complete Restoration of a 1962 Reel-to-Reel Tape Recorder: Cleaning, "
            + "Re-belting, Capacitor Replacement, Head Alignment and a Full Listening Test (Extended Cut)"

        static func mixed(now: Date) -> DummyQueueState {
            DummyQueueState(jobs: (active(now: now) + finished + failures).map(\.snapshot))
        }

        static func playlist(now: Date, collapsed: Bool) -> DummyQueueState {
            let group = PersistedPlaylistGroup(
                id: playlistGroupID,
                title: "Field Recording Basics",
                sourceURL: ScreenshotLinks.playlist.sourceURL,
                isCollapsed: collapsed
            )
            let loose = Array((active(now: now) + finished).prefix(2))
            return DummyQueueState(
                jobs: (playlistChildren + loose).map(\.snapshot),
                playlistGroups: [group]
            )
        }

        static func halted(_ reason: QueueHaltReason, now: Date) -> DummyQueueState {
            switch reason {
            case .networkDown:
                var state = DummyQueueState(jobs: (offlineJobs + finished).map(\.snapshot), queueHalt: reason)
                state.isOnline = false
                return state
            case .circuitOpen:
                var state = mixed(now: now)
                state.queueHalt = reason
                state.hostRateSummary = [youTube: circuitOpen(now: now)]
                return state
            case .depMissing:
                var state = mixed(now: now)
                state.queueHalt = reason
                return state
            }
        }

        static func rateLimited(now: Date) -> DummyQueueState {
            var state = mixed(now: now)
            state.hostRateSummary = [
                youTube: HostRateDisplayState(
                    state: .cooldown(until: now.addingTimeInterval(countdownSeconds), strikes: 2),
                    lastErrorKey: ErrorClass.rateLimited().key,
                    concurrencyReducedToOne: true
                ),
                RateHost(urlString: "https://vimeo.com"): circuitOpen(now: now)
            ]
            return state
        }

        static func shield(_ status: ShieldStatus, now: Date) -> DummyQueueState {
            var state = mixed(now: now)
            state.shieldStatus = status
            return state
        }

        private static let youTube = RateHost(urlString: "https://youtube.com")

        private static func circuitOpen(now: Date) -> HostRateDisplayState {
            HostRateDisplayState(
                state: .circuitOpen(since: now, strikes: 4),
                lastErrorKey: ErrorClass.rateLimited().key,
                concurrencyReducedToOne: false
            )
        }

        private static func active(now: Date) -> [ScreenshotJob] {
            downloading + waiting(now: now)
        }

        private static var downloading: [ScreenshotJob] {
            [
                ScreenshotJob(
                    number: 1,
                    title: "Aurora timelapse over the northern fjords, four nights in one take",
                    state: .running,
                    kind: .video(maxHeight: 2160),
                    durationSeconds: 43512,
                    sizeBytes: 24_600_000_000,
                    progress: ScreenshotJob.progress(0.02, of: 24_600_000_000, speed: 11_400_000, eta: 2114),
                    playerClient: "web_safari"
                ),
                ScreenshotJob(
                    number: 2,
                    title: "How a mechanical watch keeps time",
                    state: .running,
                    url: "https://vimeo.example.com/90210",
                    extractor: "vimeo",
                    sizeBytes: 512_000_000,
                    quality: "720p",
                    progress: ScreenshotJob.progress(0.52, of: 512_000_000, speed: 3_200_000, eta: 77),
                    playerClient: "default"
                ),
                ScreenshotJob(
                    number: 3,
                    title: "Rain on a tin roof (field recording)",
                    state: .running,
                    url: "https://soundcloud.example.com/field/rain",
                    kind: .audio(format: .m4a),
                    extractor: "soundcloud",
                    durationSeconds: 3605,
                    sizeBytes: 58_000_000,
                    progress: ScreenshotJob.progress(0.97, of: 58_000_000, speed: 940_000, eta: 2),
                    destFolder: URL(fileURLWithPath: "/Users/example/Music/Field Recordings", isDirectory: true)
                )
            ]
        }

        private static func waiting(now: Date) -> [ScreenshotJob] {
            let soon = now.addingTimeInterval(countdownSeconds)
            return [
                ScreenshotJob(number: 4, title: "Sourdough, start to finish", state: .queued, attempt: 0),
                ScreenshotJob(
                    number: 5,
                    title: "Designing a type family",
                    state: .queued,
                    attempt: 2,
                    cooldownUntil: soon
                ),
                ScreenshotJob(number: 6, title: nil, state: .probing, durationSeconds: nil, sizeBytes: nil),
                ScreenshotJob(
                    number: 7,
                    title: "Weekly community call",
                    state: .probing,
                    url: "https://zoom.example.com/rec/share/abc",
                    extractor: "zoom",
                    sizeBytes: nil,
                    probeWaitUntil: soon
                ),
                ScreenshotJob(
                    number: 8,
                    title: "Bridge engineering lecture 7",
                    state: .paused,
                    url: "https://archive.example.com/details/bridges-7",
                    extractor: "archive.org",
                    durationSeconds: 5400,
                    progress: ScreenshotJob.progress(0.35, of: 184_000_000)
                ),
                ScreenshotJob(
                    number: 9,
                    title: "Coastline drone survey",
                    state: .waitingForNetwork,
                    progress: ScreenshotJob.progress(0.47, of: 184_000_000)
                ),
                ScreenshotJob(
                    number: 10,
                    title: "Modular synth patch notes",
                    state: .cooldown(until: soon),
                    progress: ScreenshotJob.progress(0.18, of: 184_000_000),
                    attempt: 3,
                    cooldownUntil: soon
                )
            ]
        }

        private static var offlineJobs: [ScreenshotJob] {
            [
                ScreenshotJob(
                    number: 9,
                    title: "Coastline drone survey",
                    state: .waitingForNetwork,
                    progress: ScreenshotJob.progress(0.47, of: 184_000_000)
                ),
                ScreenshotJob(number: 4, title: "Sourdough, start to finish", state: .queued, attempt: 0)
            ]
        }

        private static var finished: [ScreenshotJob] {
            [
                ScreenshotJob(
                    number: 11,
                    title: longTitle,
                    state: .completed,
                    kind: .video(maxHeight: Int.max),
                    durationSeconds: 7322,
                    sizeBytes: 3_900_000_000,
                    quality: "1440p",
                    integrity: .passed,
                    playerClient: "tv"
                ),
                ScreenshotJob(
                    number: 12,
                    title: "東京の朝市を歩く — Прогулка по рынку — جولة في السوق",
                    state: .completed,
                    url: "https://vimeo.example.com/55102",
                    kind: .video(maxHeight: 480),
                    extractor: "vimeo",
                    quality: "480p",
                    integrity: .failed(reason: "The saved file is shorter than the video.")
                ),
                ScreenshotJob(
                    number: 13,
                    title: "Door chime",
                    state: .completed,
                    url: "https://media.example.com/chime",
                    kind: .audio(format: .mp3),
                    extractor: "generic",
                    durationSeconds: 4,
                    sizeBytes: 412_000,
                    integrity: .skipped(reason: "The file could not be checked.")
                ),
                ScreenshotJob(
                    number: 14,
                    title: "Cancelled livestream replay",
                    state: .cancelled,
                    sizeBytes: nil
                )
            ]
        }

        private static var playlistChildren: [ScreenshotJob] {
            let states: [(String, JobState)] = [
                ("Choosing a microphone", .completed),
                ("Setting levels outdoors", .completed),
                ("Wind protection that works", .running),
                ("Monitoring while you record", .queued),
                ("Editing out handling noise", .failed(.unavailable)),
                ("Archiving your takes", .paused)
            ]
            return states.enumerated().map { offset, item in
                var job = ScreenshotJob(number: 101 + offset, title: item.0, state: item.1)
                job.group = playlistGroupID
                job.playlistIndex = offset + 1
                switch item.1 {
                case .running:
                    job.progress = ScreenshotJob.progress(0.61, of: 184_000_000, speed: 2_100_000, eta: 34)
                case .paused:
                    job.progress = ScreenshotJob.progress(0.12, of: 184_000_000)
                case .completed:
                    job.integrity = .passed
                    job.quality = "1080p"
                default:
                    break
                }
                return job
            }
        }
    }
#endif
