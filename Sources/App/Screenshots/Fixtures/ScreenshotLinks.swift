#if DEBUG
    import Foundation
    import GrabberKit

    enum ScreenshotLinks {
        static let videoURL = "https://youtube.example.com/watch?v=watchmaking"
        // Only a real YouTube playlist address is treated as a playlist; the dummy engine answers it.
        static let playlistURL = "https://www.youtube.com/playlist?list=PLexample"

        static let video = MediaMetadata(
            title: "How a mechanical watch keeps time",
            durationSeconds: 754,
            isPlaylist: false,
            sourceURL: videoURL,
            extractor: "youtube",
            formatAvailability: .listed,
            videoHeights: [2160, 1440, 1080, 720, 480]
        )

        static let multiAudioVideo = MediaMetadata(
            title: "Deep sea documentary with several narrations",
            durationSeconds: 3180,
            isPlaylist: false,
            sourceURL: videoURL,
            extractor: "youtube",
            formatAvailability: .listed,
            videoHeights: [1080, 720, 480],
            audioTracks: [
                track("en", "English (original)", isOriginal: true, isDefault: true),
                track("es", "Spanish"),
                track("ja", "Japanese"),
                track("pt-BR", "Portuguese (Brazil)")
            ]
        )

        static let playlist = PlaylistDump.parsed(
            title: "Field Recording Basics",
            uploader: "Example Sound Club",
            sourceURL: "https://youtube.example.com/playlist?list=PLexample",
            entries: playlistTitles.enumerated().map { offset, title in
                [
                    "id": "episode\(offset + 1)",
                    "title": title,
                    "duration": 240 + offset * 97,
                    "webpage_url": "https://youtube.example.com/watch?v=episode\(offset + 1)",
                    "ie_key": "youtube",
                    "playlist_index": offset + 1
                ]
            }
        )

        private static let playlistTitles = [
            "Choosing a microphone",
            "Setting levels outdoors",
            "Wind protection that works",
            "Monitoring while you record",
            "Editing out handling noise",
            "Archiving your takes",
            "Recording birds at dawn: patience, placement and a very long cable run across a meadow",
            "Traffic as an instrument",
            "Underwater microphones",
            "Contact microphones on metal",
            "Questions and answers Interview",
            "Sound designer Interview",
            "Location mixer Interview"
        ]

        private static func track(
            _ code: String,
            _ label: String,
            isOriginal: Bool = false,
            isDefault: Bool = false
        ) -> AudioTrack {
            AudioTrack(id: code, languageCode: code, label: label, isOriginal: isOriginal, isDefault: isDefault)
        }
    }

    private extension PlaylistDump {
        // Built through the app's own decoder, which is the only way to make one outside the core module.
        static func parsed(
            title: String,
            uploader: String,
            sourceURL: String,
            entries: [[String: Any]]
        ) -> PlaylistDump {
            let object: [String: Any] = [
                "title": title,
                "uploader": uploader,
                "webpage_url": sourceURL,
                "entries": entries
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: object),
                  let text = String(bytes: data, encoding: .utf8),
                  case let .success(dump) = PlaylistDump.decode(text, pasteURL: sourceURL)
            else {
                preconditionFailure("the dummy playlist does not decode")
            }
            return dump
        }
    }
#endif
