#if DEBUG
    import GrabberKit

    @MainActor
    enum PreferencesScenes {
        static let all: [SceneSpec] = panes + downloads + cookies + diagnostics

        private static var panes: [SceneSpec] {
            PreferencesPane.allCases.map { scene("prefs-\($0.rawValue)", $0) }
        }

        private static var downloads: [SceneSpec] {
            [
                scene("prefs-downloads-custom-naming", .downloads) {
                    $0.model.prefs.filenameTemplate = "%(uploader)s/%(upload_date)s %(title)s [%(id)s].%(ext)s"
                }
            ]
        }

        private static var cookies: [SceneSpec] {
            [
                scene("prefs-cookies-none", .cookies) { $0.model.prefs.cookiesFromBrowser = .none },
                scene("prefs-cookies-firefox", .cookies) { $0.model.prefs.signInScope = .allSites },
                scene("prefs-cookies-safari", .cookies) { $0.model.prefs.cookiesFromBrowser = .safari },
                scene("prefs-cookies-safari-denied", .cookies) { stage in
                    stage.model.prefs.cookiesFromBrowser = .safari
                    stage.setSafariCookiesReadable(false)
                },
                scene("prefs-cookies-chrome-missing", .cookies) { $0.model.prefs.cookiesFromBrowser = .chrome },
                retryPending,
                scene("prefs-cookies-test-passed", .cookies, hooks: ["signIn.test"]),
                scene("prefs-cookies-test-failed", .cookies, hooks: ["signIn.test"]) {
                    $0.world.signInResult = .failure(.cookieReadFailed)
                }
            ]
        }

        // A failed download waiting for a browser to be picked.
        private static var retryPending: SceneSpec {
            SceneSpec(
                name: "prefs-cookies-retry-pending",
                prepare: { stage in
                    let state = ScreenshotJobs.mixed(now: stage.now)
                    await stage.show(state)
                    stage.model.prefs.cookiesFromBrowser = .none
                    stage.model.page = .preferences(.cookies)
                    stage.model.setPendingCookieRetry(state.jobs.first { $0.signInAdvice != .none }?.id)
                },
                expect: { $0.pendingCookieRetryJobID != nil && $0.page == .preferences(.cookies) }
            )
        }

        private static var diagnostics: [SceneSpec] {
            [
                scene("prefs-diagnostics-passed", .diagnostics, hooks: ["diagnostics.run"]),
                scene("prefs-diagnostics-failed", .diagnostics, hooks: ["diagnostics.run"]) { stage in
                    stage.world.testRunPasses = false
                    stage.world.environment = DummyWorld.degradedEnvironment
                }
            ]
        }

        private static func scene(
            _ name: String,
            _ pane: PreferencesPane,
            hooks: [String] = [],
            change: @escaping @MainActor (ScreenshotStage) -> Void = { _ in }
        ) -> SceneSpec {
            SceneSpec(
                name: name,
                prepare: { stage in
                    change(stage)
                    stage.model.page = .preferences(pane)
                },
                hooks: hooks,
                expect: { $0.page == .preferences(pane) }
            )
        }
    }
#endif
