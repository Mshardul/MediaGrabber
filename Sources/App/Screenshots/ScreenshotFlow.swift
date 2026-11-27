#if DEBUG
    // The parts of the app a run can be narrowed to.
    enum ScreenshotFlow: String, CaseIterable {
        case onboarding
        case home
        case table
        case popovers
        case overlays
        case preferences
        case about

        @MainActor
        var scenes: [SceneSpec] {
            switch self {
            case .onboarding: OnboardingScenes.all
            case .home: HomeScenes.all
            case .table: TableScenes.all
            case .popovers: PopoverScenes.all
            case .overlays: OverlayScenes.all
            case .preferences: PreferencesScenes.all
            case .about: AboutScenes.all
            }
        }
    }
#endif
