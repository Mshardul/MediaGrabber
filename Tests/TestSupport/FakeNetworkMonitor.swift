import Foundation
import GrabberKit

public final class FakeNetworkMonitor: NetworkPathMonitoring, @unchecked Sendable {
    private let continuation: AsyncStream<Bool>.Continuation
    public let stream: AsyncStream<Bool>

    public init() {
        (stream, continuation) = AsyncStream<Bool>.makeStream()
    }

    public func goOffline() {
        push(false)
    }

    public func goOnline() {
        push(true)
    }

    private func push(_ online: Bool) {
        continuation.yield(online)
    }
}
