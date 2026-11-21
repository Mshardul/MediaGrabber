#if DEBUG
    import Foundation
    import GrabberKit
    import SwiftUI

    struct SceneSpec: Equatable {
        let name: String
        let navigate: @MainActor @Sendable (AppModel) async -> Void

        static func == (lhs: SceneSpec, rhs: SceneSpec) -> Bool {
            lhs.name == rhs.name
        }
    }

    enum ScreenshotScenes {
        static let all: [SceneSpec] = makeRegistry()

        static func makeRegistry() -> [SceneSpec] {
            var scenes: [SceneSpec] = []

            for pane in PreferencesPane.allCases {
                scenes.append(SceneSpec(name: "prefs-\(pane.rawValue)") { model in
                    await model.navigateToPreferences(pane)
                })
            }

            for tab in AboutTab.allCases {
                scenes.append(SceneSpec(name: tab.rawValue) { model in
                    model.page = .about(tab)
                })
            }

            scenes.append(SceneSpec(name: "dialog-confirm") { model in
                model.pendingConfirmation = AppModelDialogs.removeConfirmation()
            })

            scenes.append(SceneSpec(name: "banner-warning") { model in
                model.bannerContent = BannerContent(
                    text: "This is a warning banner with a button",
                    buttonTitle: "Action",
                    action: {}
                )
            })

            scenes.append(SceneSpec(name: "picker-playlist") { model in
                model.isPlaylistPickerPresented = true
                model.resolved = .playlist(ScreenshotFixtures.playlistDump)
            })

            scenes.append(SceneSpec(name: "onboarding") { model in
                await model.refreshOnboardingState()
            })

            scenes.append(SceneSpec(name: "home-empty") { model in
                model.page = .home
                model.homeFieldText = ""
            })

            scenes.append(SceneSpec(name: "home-with-input") { model in
                model.page = .home
                model.homeFieldText = "https://example.com/video"
            })

            scenes.append(SceneSpec(name: "home-probing") { model in
                model.page = .home
                model.homeFieldText = "https://example.com/video"
                model.isProbing = true
                model.probingURL = "https://example.com/video"
            })

            return scenes
        }

        static func validateCoverage() {
            let names = Set(all.map(\.name))
            var missing: [String] = []

            for pane in PreferencesPane.allCases where !names.contains("prefs-\(pane.rawValue)") {
                missing.append("prefs-\(pane.rawValue)")
            }

            for tab in AboutTab.allCases where !names.contains(tab.rawValue) {
                missing.append(tab.rawValue)
            }

            let requiredScenes = [
                "dialog-confirm", "banner-warning", "picker-playlist",
                "onboarding", "home-empty", "home-with-input", "home-probing"
            ]
            for scene in requiredScenes where !names.contains(scene) {
                missing.append(scene)
            }

            if !missing.isEmpty {
                fatalError("Missing screenshot scenes: \(missing.sorted().joined(separator: ", "))")
            }
        }

        static func selected(_ options: ScreenshotOptions) -> [SceneSpec] {
            guard let sceneName = options.scene else {
                return all
            }
            return all.filter { $0.name == sceneName }
        }
    }
#endif
