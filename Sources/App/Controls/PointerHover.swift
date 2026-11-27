import SwiftUI

extension View {
    // A screenshot run ignores the pointer, which may be anywhere while the app is behind other windows.
    func onPointerHover(_ action: @escaping (Bool) -> Void) -> some View {
        onHover { hovering in
            guard !RunMode.isScreenshotTour else { return }
            action(hovering)
        }
    }
}
