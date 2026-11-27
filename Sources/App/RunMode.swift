// Lets a screenshot run switch off motion and outside input without a build condition at each call site.
@MainActor
enum RunMode {
    static var isScreenshotTour: Bool {
        #if DEBUG
            ScreenshotMode.isActive
        #else
            false
        #endif
    }
}
