import Foundation

public struct QueueLoadNotice: Sendable, Equatable {
    public enum Cause: Sendable, Equatable {
        case damaged
        case newerVersion
        case unopenable
    }

    public let cause: Cause
    // False means the old file is the only copy, so the app leaves it alone.
    public let copied: Bool
    public let fileURL: URL

    public var sentence: String {
        guard copied else {
            return "\(problem) and no copy could be made. The old file is left as it is, so changes to the list "
                + "won't be saved. Move that file somewhere safe, then reopen MediaGrabber."
        }
        return "\(problem), so MediaGrabber started with an empty list. A copy of the old list was saved."
    }

    public var actionTitle: String {
        copied ? "Show copy" : "Show file"
    }

    private var problem: String {
        switch cause {
        case .damaged: "Your download list was damaged"
        case .newerVersion: "Your download list was made by a newer version of MediaGrabber"
        case .unopenable: "Your download list couldn't be opened"
        }
    }
}
