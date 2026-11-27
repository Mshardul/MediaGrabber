#if DEBUG
    import GrabberKit

    @MainActor
    enum OnboardingScenes {
        static let all: [SceneSpec] = [
            scene("onboarding-ready"),
            scene("onboarding-shield-pending") { $0.world.shieldInstalled = false },
            scene("onboarding-shield-failed", hooks: ["onboarding.setUpShield"]) { $0.world.shieldInstalled = false },
            scene("onboarding-test-failed") { $0.world.testRunPasses = false },
            scene("onboarding-not-ready") {
                $0.world.environment = EnvironmentReport(ytDlp: nil, ffmpeg: nil)
                $0.world.shieldInstalled = false
            }
        ]

        private static func scene(
            _ name: String,
            hooks: [String] = [],
            world: @escaping @MainActor (ScreenshotStage) -> Void = { _ in }
        ) -> SceneSpec {
            SceneSpec(
                name: name,
                prepare: { stage in
                    world(stage)
                    stage.model.hasCompletedOnboarding = false
                    await stage.model.refreshOnboardingState()
                },
                hooks: hooks,
                expect: { $0.needsOnboarding }
            )
        }
    }
#endif
