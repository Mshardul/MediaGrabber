#if DEBUG
    import Foundation
    import GrabberKit

    enum ScreenshotTour {
        @MainActor
        static func runScene(_ scene: SceneSpec, model: AppModel) async {
            await scene.navigate(model)
            try? await Task.sleep(for: .milliseconds(100))
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
    }
#endif
