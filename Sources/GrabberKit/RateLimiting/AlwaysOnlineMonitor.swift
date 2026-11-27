import Foundation

struct AlwaysOnlineMonitor: NetworkPathMonitoring {
    init() {}

    var stream: AsyncStream<Bool> {
        AsyncStream { $0.finish() } // never yields
    }
}
