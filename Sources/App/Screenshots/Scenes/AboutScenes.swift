#if DEBUG
    @MainActor
    enum AboutScenes {
        static let all: [SceneSpec] = AboutTab.allCases.map { tab in
            SceneSpec(
                name: tab.rawValue,
                prepare: { $0.model.page = .about(tab) },
                expect: { $0.page == .about(tab) }
            )
        } + [updateAvailable]

        private static var updateAvailable: SceneSpec {
            SceneSpec(
                name: "about-update-available",
                prepare: { stage in
                    stage.world.environment = DummyWorld.outdatedEnvironment
                    await stage.model.refreshOnboardingState()
                    await stage.show(.empty)
                    stage.model.page = .about(.about)
                },
                expect: { model in
                    if case .drift = model.latestEnvironmentReport?.ytDlpDriftVerdict {
                        return model.page == .about(.about)
                    }
                    return false
                }
            )
        }
    }
#endif
