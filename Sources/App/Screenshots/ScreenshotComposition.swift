#if DEBUG
    import Foundation
    import GrabberKit

    enum ScreenshotCompositionError: Error, Equatable {
        case homeNotIsolated
    }

    // The real app model, installer and link controller, with every outside dependency passed as a dummy.
    @MainActor
    struct ScreenshotComposition {
        let model: AppModel
        let installer: OnboardingInstaller
        let incomingLinks: IncomingLinkController
        let engine: DummyEngine
        let world: DummyWorld
        let pasteboard: DummyPasteboard

        // Any app under /Applications counts as installed, so no offer to move it appears.
        static let bundleURL = URL(fileURLWithPath: "/Applications/MediaGrabber.app", isDirectory: true)

        static func make(locations: AppLocations) throws -> ScreenshotComposition {
            guard locations.settingsDomain != nil else { throw ScreenshotCompositionError.homeNotIsolated }
            let settings = locations.makeSettings()
            guard settings !== UserDefaults.standard else { throw ScreenshotCompositionError.homeNotIsolated }

            let world = DummyWorld()
            let engine = DummyEngine(world: world)
            let model = makeModel(locations: locations, settings: settings, engine: engine, world: world)
            // The tour is not always in front while a scene settles, and "saved" messages show only when it is.
            model.isAppActive = { true }
            let pasteboard = DummyPasteboard()
            return ScreenshotComposition(
                model: model,
                installer: makeInstaller(locations: locations, world: world),
                incomingLinks: IncomingLinkController(home: model, pasteboard: pasteboard),
                engine: engine,
                world: world,
                pasteboard: pasteboard
            )
        }

        private static func makeModel(
            locations: AppLocations,
            settings: UserDefaults,
            engine: DummyEngine,
            world: DummyWorld
        ) -> AppModel {
            AppModel(
                engine: engine,
                prefs: Preferences(defaults: settings, downloadsFolder: locations.downloads),
                log: LogWriter(directory: locations.logs),
                locations: locations,
                defaults: settings,
                suppression: UserDefaultsSuppressionStore(defaults: settings),
                envProbe: DummyEnvironmentProbe(world: world),
                ytDlpUpdater: DummyYtDlpUpdater(),
                ytDlpLocator: .fixed(URL(fileURLWithPath: "/Users/example/MediaGrabber/Tools/yt-dlp")),
                debugFlags: DebugFlags(),
                notificationRouter: DummyNotificationRouter(),
                revealSink: DummyRevealSink(),
                openURLSink: DummyOpenURLSink(),
                appUpdating: IdleAppUpdating(),
                shieldInstaller: makeShieldInstaller(locations: locations, world: world),
                bundleURL: bundleURL,
                persistence: nil,
                columnConfig: .default,
                vpnDetector: DummyVPNDetector(),
                makeCanaryProbe: { _ in DummyMetadataProbe(world: world) },
                sharePresenter: DummySharePresenter(),
                settingsLink: DummySettingsLink()
            )
        }

        private static func makeInstaller(locations: AppLocations, world: DummyWorld) -> OnboardingInstaller {
            OnboardingInstaller(
                locations: locations,
                probe: DummyEnvironmentProbe(world: world),
                makeCanaryProbe: { _ in DummyMetadataProbe(world: world) },
                shieldInstaller: makeShieldInstaller(locations: locations, world: world),
                isShieldInstalled: { world.shieldInstalled }
            )
        }

        private static func makeShieldInstaller(locations: AppLocations, world: DummyWorld) -> ShieldInstaller {
            ShieldInstaller(tools: .live(locations: locations), fileExists: { _ in world.shieldInstalled })
        }
    }
#endif
