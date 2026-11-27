import Foundation
@testable import GrabberKit

public final class FakeMetadataProbe: MetadataProbing, @unchecked Sendable {
    public typealias Outcome = Result<MediaMetadata, MetadataError>
    public typealias PlaylistOutcome = Result<PlaylistDump, MetadataError>

    private struct State {
        var fallback: Outcome
        var playlistFallback: PlaylistOutcome = .failure(.malformedOutput)
        var probedURLs: [String] = []
        var probedContexts: [ExtractorContext] = []
        var perProbeDelay: Duration = .zero
    }

    private let box: LockedBox<State>

    public init(default fallback: Outcome = .failure(.malformedOutput)) {
        box = LockedBox(State(fallback: fallback))
    }

    public var probedURLs: [String] {
        box.read { $0.probedURLs }
    }

    public var probedContexts: [ExtractorContext] {
        box.read { $0.probedContexts }
    }

    public var perProbeDelay: Duration {
        get { box.read { $0.perProbeDelay } }
        set { box.mutate { $0.perProbeDelay = newValue } }
    }

    public func result(_ result: Outcome) {
        box.mutate { $0.fallback = result }
    }

    public func playlistResult(_ result: PlaylistOutcome) {
        box.mutate { $0.playlistFallback = result }
    }

    // Defaults are probe-complete so the job downloads after probing.
    public static func success(
        title: String,
        durationSeconds: Int? = 10,
        extractor: String? = "youtube",
        sourceURL: String = ""
    ) -> Outcome {
        .success(MediaMetadata(
            title: title,
            durationSeconds: durationSeconds,
            isPlaylist: false,
            sourceURL: sourceURL,
            extractor: extractor
        ))
    }

    public func probe(
        _ url: String,
        context: ExtractorContext,
        onWait _: (@Sendable (Date?) -> Void)?
    ) async -> Outcome {
        let (result, delay) = box.mutate { state -> (Outcome, Duration) in
            state.probedURLs.append(url)
            state.probedContexts.append(context)
            return (state.fallback, state.perProbeDelay)
        }
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        return result
    }

    public func probePlaylist(_: String, context _: ExtractorContext) async -> PlaylistOutcome {
        let (result, delay) = box.mutate { state -> (PlaylistOutcome, Duration) in
            (state.playlistFallback, state.perProbeDelay)
        }
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        return result
    }
}
