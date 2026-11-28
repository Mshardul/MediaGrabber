import Foundation

public enum FormatSizeEstimator {
    public static func estimateFileSize(
        for meta: MediaMetadata,
        kind: DownloadKind,
        audioLanguage: AudioLanguage
    ) -> Int64? {
        guard meta.formatAvailability == .listed else { return nil }
        guard !meta.formatInfos.isEmpty else { return nil }

        switch kind {
        case let .video(maxHeight: height):
            return estimateVideoSize(meta: meta, maxHeight: height, audioLanguage: audioLanguage)
        case let .audio(format: format):
            return estimateAudioSize(meta: meta, audioFormat: format, audioLanguage: audioLanguage)
        }
    }

    private static func estimateVideoSize(
        meta: MediaMetadata,
        maxHeight: Int,
        audioLanguage: AudioLanguage
    ) -> Int64? {
        let videoFormats = meta.formatInfos.filter { info in
            info.vcodec != nil && info.vcodec != "none" &&
                (info.acodec == nil || info.acodec == "none")
        }

        let heightFiltered: [FormatCatalog.FormatInfo] = if maxHeight == Int.max {
            videoFormats
        } else {
            videoFormats.filter { ($0.height ?? 0) <= maxHeight }
        }

        let mp4Video = heightFiltered.filter { $0.ext == "mp4" }
        let candidateVideo = mp4Video.isEmpty ? heightFiltered : mp4Video

        guard let bestVideo = candidateVideo.max(by: { ($0.height ?? 0) < ($1.height ?? 0) }),
              let videoSize = bestVideo.filesize else { return nil }

        let audioFormats = meta.formatInfos.filter { info in
            (info.vcodec == nil || info.vcodec == "none") &&
                info.acodec != nil && info.acodec != "none"
        }

        let languageFiltered = filterAudioByLanguage(audioFormats, audioLanguage: audioLanguage)

        let m4aAudio = languageFiltered.filter { $0.ext == "m4a" }
        let candidateAudio = m4aAudio.isEmpty ? languageFiltered : m4aAudio

        guard let bestAudio = candidateAudio.first(where: { $0.filesize != nil }),
              let audioSize = bestAudio.filesize else { return nil }

        return videoSize + audioSize
    }

    private static func filterAudioByLanguage(
        _ formats: [FormatCatalog.FormatInfo],
        audioLanguage: AudioLanguage
    ) -> [FormatCatalog.FormatInfo] {
        switch audioLanguage {
        case .unspecified:
            formats
        case .original:
            formats.filter { ($0.formatNote ?? "").localizedCaseInsensitiveContains("original") }
        case let .code(code):
            formats.filter { $0.language == code }
        }
    }

    private static func estimateAudioSize(
        meta: MediaMetadata,
        audioFormat: AudioFormat,
        audioLanguage: AudioLanguage
    ) -> Int64? {
        let audioFormats = meta.formatInfos.filter { info in
            (info.vcodec == nil || info.vcodec == "none") &&
                info.acodec != nil && info.acodec != "none"
        }

        let languageFiltered = filterAudioByLanguage(audioFormats, audioLanguage: audioLanguage)

        let targetExt = audioFormat == .m4a ? "m4a" : "mp3"
        let targetAudio = languageFiltered.filter { $0.ext == targetExt }
        let candidateAudio = targetAudio.isEmpty ? languageFiltered : targetAudio

        guard let bestAudio = candidateAudio.first(where: { $0.filesize != nil }),
              let audioSize = bestAudio.filesize else { return nil }

        return audioSize
    }
}
