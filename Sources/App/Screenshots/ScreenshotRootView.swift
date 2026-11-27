#if DEBUG
    import SwiftUI

    // Rebuilds the whole view tree for each scene, so no view state carries over.
    struct ScreenshotRootView<Content: View>: View {
        let tour: ScreenshotTour
        @ViewBuilder let content: () -> Content

        var body: some View {
            if tour.isStaging {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content()
                    .id(tour.generation)
                    // Controls ask this before drawing their active colours.
                    .environment(\.controlActiveState, .key)
            }
        }
    }
#endif
