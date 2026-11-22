#if DEBUG
    import Foundation

    enum ScreenshotHandoffError: Error, Equatable {
        case timedOut(key: String)
    }

    struct ScreenshotHandoff: Sendable {
        let dir: URL
        let timeout: TimeInterval
        let pollInterval: TimeInterval

        init(dir: URL, timeout: TimeInterval = 30, pollInterval: TimeInterval = 0.05) {
            self.dir = dir
            self.timeout = timeout
            self.pollInterval = pollInterval
        }

        func announceReady(key: String, windowIDs: [Int]) throws {
            let lines = windowIDs.map { "\($0)\n" }.joined()
            try lines.write(to: dir.appendingPathComponent("\(key).ready"), atomically: true, encoding: .utf8)
        }

        func waitForDone(key: String) async throws {
            let doneURL = dir.appendingPathComponent("\(key).done")
            let deadline = Date().addingTimeInterval(timeout)
            while !FileManager.default.fileExists(atPath: doneURL.path) {
                guard Date() < deadline else { throw ScreenshotHandoffError.timedOut(key: key) }
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }

        func finish() throws {
            try "".write(to: dir.appendingPathComponent("tour.finished"), atomically: true, encoding: .utf8)
        }

        func fail(key: String, reason: String) throws {
            try "\(key)\n\(reason)\n".write(
                to: dir.appendingPathComponent("tour.failed"),
                atomically: true,
                encoding: .utf8
            )
        }
    }
#endif
