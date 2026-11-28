import GrabberKit
import SwiftUI

struct ResolvedLinkTitle: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.palette.accent)
                .accessibilityHidden(true)
            Text(appModel.resolved?.title ?? "")
                .font(theme.bodyFont(14, .medium))
                .foregroundStyle(theme.palette.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(-1)
    }
}

struct ResolvedLinkDetails: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.theme) private var theme

    let mediaType: MediaType
    let videoHeight: Int
    let audioFormat: AudioFormat
    let selectedTrackID: String
    let destFolder: URL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            if let meta = appModel.resolvedVideo {
                let kind = downloadKindFrom(mediaType: mediaType, videoHeight: videoHeight, audioFormat: audioFormat)
                let audioLanguage = audioLanguageFromTrackID(meta, selectedTrackID)

                if let filename = filenameForCurrentSelection(meta, kind: kind) {
                    HStack(spacing: Spacing.s1) {
                        Text("Saves as")
                            .font(theme.bodyFont(12, .regular))
                            .foregroundStyle(theme.palette.dim)
                        Text(filename)
                            .font(theme.monoFont(12, .regular))
                            .foregroundStyle(theme.palette.text)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        let conflict = FilenameConflictChecker.checkConflict(filename: filename, in: destFolder)
                        if conflict.exists {
                            Text("Already in this folder")
                                .font(theme.bodyFont(11, .regular))
                                .foregroundStyle(theme.palette.accent)
                        }
                    }
                }

                let size = FormatSizeEstimator
                    .estimateFileSize(for: meta, kind: kind, audioLanguage: audioLanguage)

                if let summary = GrabDetailText
                    .summary(sizeBytes: size, durationSeconds: meta.durationSeconds)
                {
                    HStack(spacing: Spacing.s1) {
                        if let size {
                            Text("≈")
                                .font(theme.bodyFont(12, .regular))
                                .foregroundStyle(theme.palette.dim)
                            Text(GrabDetailText.size(size))
                                .font(theme.monoFont(12, .regular))
                                .foregroundStyle(theme.palette.text)
                        }
                        if size != nil, meta.durationSeconds != nil {
                            Text("·")
                                .font(theme.bodyFont(12, .regular))
                                .foregroundStyle(theme.palette.dim)
                        }
                        if let duration = meta.durationSeconds {
                            Text(GrabDetailText.length(duration))
                                .font(theme.bodyFont(12, .regular))
                                .foregroundStyle(theme.palette.dim)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(summary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func downloadKindFrom(mediaType: MediaType, videoHeight: Int, audioFormat: AudioFormat) -> DownloadKind {
        switch mediaType {
        case .video:
            .video(maxHeight: videoHeight)
        case .audio:
            .audio(format: audioFormat)
        }
    }

    private func audioLanguageFromTrackID(_ meta: MediaMetadata, _ trackID: String) -> AudioLanguage {
        guard let track = meta.audioTracks.first(where: { $0.id == trackID }) else {
            return .unspecified
        }
        if track.isOriginal {
            return .original
        }
        if let code = track.languageCode {
            return .code(code)
        }
        return .unspecified
    }

    private func filenameForCurrentSelection(_ meta: MediaMetadata, kind: DownloadKind) -> String? {
        let audioLanguage = audioLanguageFromTrackID(meta, selectedTrackID)
        return FilenameTemplate.apply(
            appModel.prefs.filenameTemplate,
            metadata: meta,
            kind: kind,
            audioLanguage: audioLanguage
        )
    }
}

// The link card's size + length line, shared by the view and its test.
enum GrabDetailText {
    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func length(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func summary(sizeBytes: Int64?, durationSeconds: Int?) -> String? {
        var parts: [String] = []
        if let sizeBytes {
            parts.append("≈ " + size(sizeBytes))
        }
        if let durationSeconds {
            parts.append(length(durationSeconds))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct ClearLinkButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            appModel.homeFieldText = ""
            appModel.clearResolved()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.palette.faint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear link")
    }
}
