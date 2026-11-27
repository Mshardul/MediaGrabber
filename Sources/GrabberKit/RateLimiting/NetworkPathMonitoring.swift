import Foundation
import Network

public protocol NetworkPathMonitoring: Sendable {
    var stream: AsyncStream<Bool> { get }
}

final class NWPathNetworkMonitor: NetworkPathMonitoring, @unchecked Sendable {
    typealias Sleeper = @Sendable (TimeInterval) async -> Void

    private let offlineGrace: TimeInterval
    private let onlineSettle: TimeInterval
    private let sleep: Sleeper
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "mg.network-path")
    private var lastPublished = true // touched only on `queue`
    private var pendingTask: Task<Void, Never>?
    private let continuation: AsyncStream<Bool>.Continuation
    let stream: AsyncStream<Bool>

    init(
        offlineGrace: TimeInterval,
        onlineSettle: TimeInterval,
        sleep: @escaping Sleeper = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.offlineGrace = offlineGrace
        self.onlineSettle = onlineSettle
        self.sleep = sleep
        (stream, continuation) = AsyncStream<Bool>.makeStream()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handleRaw(satisfied: path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    func pushRawPathForTesting(satisfied: Bool) {
        queue.async { self.handleRaw(satisfied: satisfied) }
    }

    // always called on `queue`
    private func handleRaw(satisfied: Bool) {
        let grace = satisfied ? onlineSettle : offlineGrace
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            guard let self else { return }
            await sleep(grace)
            guard !Task.isCancelled else { return }
            queue.async {
                guard self.lastPublished != satisfied else { return }
                self.lastPublished = satisfied
                self.continuation.yield(satisfied)
            }
        }
    }

    deinit {
        monitor.cancel()
        continuation.finish()
    }
}
