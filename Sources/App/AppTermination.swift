import AppKit

@MainActor
enum AppTermination {
    static func request(
        terminate: @escaping @MainActor @Sendable () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        // terminate blocks until the quit Task replies, so calling it from inside a Task or the main queue hangs.
        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) {
            MainActor.assumeIsolated(terminate)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }
}
