#if DEBUG
    import Foundation
    import GrabberKit
    import Observation

    // For each theme and scene: set the state, wait for it to show, then save a picture of the app's windows.
    @MainActor
    @Observable
    final class ScreenshotTour {
        static let windowSize = CGSize(width: 980, height: 720)

        // True while a scene's data is set, so no view from the last scene is there to react to it.
        private(set) var isStaging = false
        private(set) var generation = 0

        private let composition: ScreenshotComposition
        private let options: ScreenshotOptions
        private let say: @MainActor (String) -> Void
        private let window: any ScreenshotWindow
        private let scenes: [SceneSpec]
        private let hookTimeout: Duration

        init(
            composition: ScreenshotComposition,
            options: ScreenshotOptions,
            window: any ScreenshotWindow,
            scenes: [SceneSpec] = ScreenshotScenes.all,
            hookTimeout: Duration = .seconds(5),
            // The capture script reads these lines; they are written unbuffered so it sees each one at once.
            say: @escaping @MainActor (String) -> Void = {
                FileHandle.standardOutput.write(Data("\($0)\n".utf8))
            }
        ) {
            self.composition = composition
            self.options = options
            self.say = say
            self.window = window
            self.scenes = scenes
            self.hookTimeout = hookTimeout
        }

        static func outputURLForScene(
            scene: String,
            theme: ThemeKind,
            outputDir: URL
        ) -> URL {
            let sanitizedScene = scene.replacingOccurrences(of: "/", with: "-")
            let themeDir = outputDir.appendingPathComponent(theme.rawValue)
            return themeDir.appendingPathComponent("\(sanitizedScene).png")
        }

        // Returns 0 only when every screen was captured.
        func run() async -> Int32 {
            let selected: [SceneSpec]
            do {
                try await prepareRun()
                try window.prepare()
                selected = ScreenshotScenes.selected(options, from: scenes)
                guard !selected.isEmpty else { throw Failure(noSceneReason) }
            } catch {
                report("tour-abort \(Self.reason(for: error))")
                return 1
            }
            let failures = await captureAll(selected)
            // Quitting the app by hand also exits cleanly, so the end of the run needs its own line.
            report("tour-finished")
            return failures == 0 ? 0 : 1
        }

        // One screen failing does not stop the rest. A screen keeps its number whatever happened before it.
        private func captureAll(_ selected: [SceneSpec]) async -> Int {
            let planned = themes.flatMap { theme in selected.map { (theme: theme, scene: $0) } }
            report("tour-plan \(planned.count)")
            var failures = 0
            for (index, item) in planned.enumerated() {
                let number = index + 1
                report("tour-start \(number) \(item.theme.rawValue)/\(item.scene.name).png")
                do {
                    try await capture(item.scene, theme: item.theme)
                    report("tour-pass \(number)")
                } catch {
                    failures += 1
                    report("tour-fail \(number) \(Self.reason(for: error))")
                }
            }
            return failures
        }

        private func report(_ line: String) {
            say(line.replacingOccurrences(of: "\n", with: " "))
        }

        private static func reason(for error: any Error) -> String {
            (error as? Failure)?.reason ?? "\(error)"
        }

        private struct Failure: Error {
            let reason: String

            init(_ reason: String) {
                self.reason = reason
            }
        }

        private var noSceneReason: String {
            let name = options.scene.map { "no scene named \($0)" } ?? "no scene"
            return options.flow.map { "\(name) in the \($0.rawValue) flow" } ?? name
        }

        private var themes: [ThemeKind] {
            options.theme.map { [$0] } ?? [.aurora, .tapeDeck]
        }

        private func prepareRun() async throws {
            let locations = composition.model.locations
            try FileManager.default.createDirectory(at: options.outputDir, withIntermediateDirectories: true)
            // The script deletes this settings domain when the run ends.
            try (locations.settingsDomain ?? "").write(
                to: options.outputDir.appendingPathComponent("settings.domain"),
                atomically: true,
                encoding: .utf8
            )
            try await ScreenshotSettingsSeed.seedHome(locations)
        }

        private func capture(_ scene: SceneSpec, theme: ThemeKind) async throws {
            let stage = ScreenshotStage(composition: composition)
            isStaging = true
            await window.settle()
            await stage.reset()
            stage.model.prefs.theme = theme
            stage.model.prefs.palette = theme == .aurora ? .auroraMintIris : .tapeDeckA
            await scene.prepare(stage)
            generation += 1
            isStaging = false
            window.place(contentSize: Self.windowSize)
            await window.settle()
            await scene.interact(stage)
            await window.settle()
            for hook in scene.hooks {
                try await fire(hook)
                await window.settle()
            }
            guard scene.expect(stage.model) else { throw Failure("the expected state was not reached") }
            let shown = window.overlayCount
            guard shown >= scene.overlays else {
                throw Failure("expected \(scene.overlays) popover or sheet fully on screen, found \(shown)")
            }
            try await window.saveImage(to: Self.outputURLForScene(
                scene: scene.name,
                theme: theme,
                outputDir: options.outputDir
            ))
        }

        // A view registers its hook when it appears, so a hook that never registers means the view is not there.
        private func fire(_ hook: String) async throws {
            let deadline = ContinuousClock.now + hookTimeout
            while await !(ScreenshotHooks.shared.fire(hook)) {
                guard ContinuousClock.now < deadline else {
                    throw Failure("nothing on screen answers the hook \(hook)")
                }
                try await Task.sleep(for: .milliseconds(50))
            }
        }
    }
#endif
