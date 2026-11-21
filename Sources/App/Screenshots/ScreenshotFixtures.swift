#if DEBUG
    import Foundation
    import GrabberKit

    struct ScreenshotSeed: Equatable {
        var active: [PersistedJob]
        var history: [PersistedJob]
        var groups: [PersistedPlaylistGroup]
    }

    enum ScreenshotFixtures {
        static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

        static let empty = ScreenshotSeed(
            active: [],
            history: [],
            groups: []
        )

        static let mixed = ScreenshotSeed(
            active: [
                PersistedJob(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    request: DownloadRequest(
                        url: "https://example.com/video1",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Video 1",
                    extractor: "youtube",
                    durationSeconds: 300,
                    state: .paused,
                    attempt: 1,
                    addedAt: epoch,
                    progressFraction: 0.5
                ),
                PersistedJob(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    request: DownloadRequest(
                        url: "https://example.com/video2",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Video 2",
                    extractor: "youtube",
                    durationSeconds: 240,
                    state: .completed,
                    attempt: 1,
                    addedAt: epoch,
                    finishedAt: epoch.addingTimeInterval(60),
                    sizeBytes: 10_000_000,
                    actualQuality: "1080p"
                ),
                PersistedJob(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    request: DownloadRequest(
                        url: "https://example.com/video3",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Video 3",
                    extractor: "youtube",
                    durationSeconds: 180,
                    state: .failed(reason: "network error"),
                    attempt: 2,
                    addedAt: epoch,
                    finishedAt: epoch.addingTimeInterval(60)
                ),
                PersistedJob(
                    id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    request: DownloadRequest(
                        url: "https://example.com/video4",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Video 4",
                    extractor: "youtube",
                    durationSeconds: 120,
                    state: .cancelled,
                    attempt: 1,
                    addedAt: epoch,
                    finishedAt: epoch.addingTimeInterval(60)
                )
            ],
            history: [
                PersistedJob(
                    id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    request: DownloadRequest(
                        url: "https://example.com/video5",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Video 5",
                    extractor: "youtube",
                    durationSeconds: 60,
                    state: .completed,
                    attempt: 1,
                    addedAt: epoch,
                    finishedAt: epoch.addingTimeInterval(60),
                    sizeBytes: 5_000_000,
                    actualQuality: "720p"
                )
            ],
            groups: []
        )

        static let playlist = ScreenshotSeed(
            active: [
                PersistedJob(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    request: DownloadRequest(
                        url: "https://example.com/playlist/1",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Playlist Item 1",
                    extractor: "youtube",
                    durationSeconds: 300,
                    state: .paused,
                    attempt: 1,
                    playlistGroupID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
                    playlistIndex: 1,
                    addedAt: epoch,
                    progressFraction: 0.3
                ),
                PersistedJob(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    request: DownloadRequest(
                        url: "https://example.com/playlist/2",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Playlist Item 2",
                    extractor: "youtube",
                    durationSeconds: 240,
                    state: .paused,
                    attempt: 1,
                    playlistGroupID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
                    playlistIndex: 2,
                    addedAt: epoch,
                    progressFraction: 0.1
                ),
                PersistedJob(
                    id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                    request: DownloadRequest(
                        url: "https://example.com/playlist/3",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Playlist Item 3",
                    extractor: "youtube",
                    durationSeconds: 180,
                    state: .completed,
                    attempt: 1,
                    playlistGroupID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
                    playlistIndex: 3,
                    addedAt: epoch,
                    finishedAt: epoch.addingTimeInterval(60),
                    sizeBytes: 8_000_000,
                    actualQuality: "1080p"
                ),
                PersistedJob(
                    id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
                    request: DownloadRequest(
                        url: "https://example.com/playlist/4",
                        destFolder: URL(fileURLWithPath: "/Users/example/Downloads"),
                        kind: .video(maxHeight: 1080)
                    ),
                    title: "Playlist Item 4",
                    extractor: "youtube",
                    durationSeconds: 120,
                    state: .failed(reason: "extractor error"),
                    attempt: 1,
                    playlistGroupID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
                    playlistIndex: 4,
                    addedAt: epoch,
                    finishedAt: epoch.addingTimeInterval(60)
                )
            ],
            history: [],
            groups: [
                PersistedPlaylistGroup(
                    id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
                    title: "Example Playlist",
                    sourceURL: "https://example.com/playlist",
                    isCollapsed: false
                )
            ]
        )

        static let playlistDump: PlaylistDump = {
            let json = """
            {
                "title": "Example Playlist",
                "uploader": "Example Uploader",
                "extractor": "youtube",
                "webpage_url": "https://example.com/playlist",
                "entries": [
                    {"id": "1", "title": "Item 1", "duration": 300,
                     "webpage_url": "https://example.com/watch?v=1", "ie_key": "youtube", "playlist_index": 1},
                    {"id": "2", "title": "Item 2", "duration": 240,
                     "webpage_url": "https://example.com/watch?v=2", "ie_key": "youtube", "playlist_index": 2},
                    {"id": "3", "title": "Item 3", "duration": 180,
                     "webpage_url": "https://example.com/watch?v=3", "ie_key": "youtube", "playlist_index": 3},
                    {"id": "4", "title": "Item 4", "duration": 120,
                     "webpage_url": "https://example.com/watch?v=4", "ie_key": "youtube", "playlist_index": 4}
                ]
            }
            """
            let result = PlaylistDump.decodeForTest(json, pasteURL: "https://example.com/playlist")
            guard case let .success(dump) = result else {
                fatalError("Invalid playlist fixture JSON")
            }
            return dump
        }()
    }
#endif
