#if DEBUG
    import AppKit

    @MainActor
    protocol ScreenshotWindow {
        // Called once, before the first scene.
        func prepare() throws
        func place(contentSize: CGSize)
        func settle() async
        // Popovers and sheets that are fully on screen over the main window.
        var overlayCount: Int { get }
        func saveImage(to url: URL) async throws
    }

    final class AppKitScreenshotWindow: ScreenshotWindow {
        // Longer than a sheet, popover or dialog takes to finish appearing.
        private static let settleTime = Duration.milliseconds(800)
        // Two pictures this far apart must match before one is saved.
        private static let stillTime = Duration.milliseconds(300)
        private static let stillAttempts = 10

        private var activity: (any NSObjectProtocol)?

        var overlayCount: Int {
            guard let main = mainWindow else { return 0 }
            return attached(to: main).dropFirst().filter { $0.alphaValue >= 1 }.count
        }

        func prepare() throws {
            try ForcedActiveAppearance.apply()
            // Without this macOS may slow a hidden app down until the run stalls.
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Taking screenshots"
            )
            // Launching brought the app forward; hand the front back and stay behind.
            NSApp.deactivate()
            mainWindow?.orderBack(nil)
        }

        private var visibleWindows: [NSWindow] {
            NSApp.windows.filter(\.isVisible)
        }

        private var mainWindow: NSWindow? {
            visibleWindows.first { $0.styleMask.contains(.titled) && $0.sheetParent == nil }
        }

        // Always the sharpest display, centred: otherwise image scale and popover sides change between runs.
        func place(contentSize: CGSize) {
            guard let window = mainWindow else { return }
            // macOS saves a window's position in the app's real settings, which a temporary home does not move.
            window.setFrameAutosaveName("")
            window.setContentSize(contentSize)
            let sharpest = NSScreen.screens.max { $0.backingScaleFactor < $1.backingScaleFactor }
            guard let area = sharpest?.visibleFrame else { return }
            window.setFrameOrigin(NSPoint(
                x: (area.midX - window.frame.width / 2).rounded(),
                y: (area.midY - window.frame.height / 2).rounded()
            ))
        }

        func settle() async {
            try? await Task.sleep(for: Self.settleTime)
        }

        func saveImage(to url: URL) async throws {
            // The main window first, then the sheets and popovers attached to it.
            let windows = mainWindow.map(attached) ?? []
            await endTextEditing(in: windows)
            try await write(stillPicture(of: windows.map(\.windowNumber)), to: url)
        }

        // A picture taken while something is still appearing or fading differs from the next one.
        private func stillPicture(of windowIDs: [Int]) async throws -> Data {
            var previous = try await OwnWindowCapture.png(of: windowIDs)
            for _ in 0 ..< Self.stillAttempts {
                try await Task.sleep(for: Self.stillTime)
                let next = try await OwnWindowCapture.png(of: windowIDs)
                if next == previous {
                    return next
                }
                previous = next
            }
            throw OwnWindowCaptureError.stillChanging
        }

        private func write(_ picture: Data, to url: URL) throws {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try picture.write(to: url, options: .atomic)
        }

        // A text cursor blinks, so two runs would not match if a field kept it.
        private func endTextEditing(in windows: [NSWindow]) async {
            let editing = windows.filter { $0.firstResponder is NSTextView }
            guard !editing.isEmpty else { return }
            for window in editing {
                window.makeFirstResponder(nil)
            }
            await settle()
        }

        private func attached(to window: NSWindow) -> [NSWindow] {
            let over = (window.sheets + (window.childWindows ?? [])).filter(\.isVisible)
            var seen = Set<ObjectIdentifier>()
            return ([window] + over.flatMap(attached)).filter { seen.insert(ObjectIdentifier($0)).inserted }
        }
    }
#endif
