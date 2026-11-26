import Foundation

public enum SubmitResult: Sendable, Equatable {
    case queued(UUID)
    case duplicateExists(existing: UUID, wasCompleted: Bool)
}

public enum PersistedState: Sendable, Equatable, Codable {
    case queued, paused, completed, cancelled
    case failed(reason: String)
}

// Lets the log tell why a start was deferred.
public enum DeferReason: Sendable, Equatable {
    case backoff(attempt: Int)
    case hostCooldown(host: String, strikes: Int)
}
