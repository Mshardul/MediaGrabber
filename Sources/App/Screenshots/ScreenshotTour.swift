#if DEBUG
    import AppKit
    import Foundation
    import GrabberKit
    import SwiftUI

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

        @MainActor
        static func capture(model: AppModel, scene: SceneSpec, theme: ThemeKind, outputDir: URL) async throws {
            let outputURL = outputURLForScene(scene: scene.name, theme: theme, outputDir: outputDir)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let themeInstance = Theme(themeKind: theme, paletteKind: defaultPaletteForTheme(theme))

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(
                rootView: MainWindow()
                    .environment(model)
                    .environment(\.theme, themeInstance)
            )
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(200))

            guard let cgImage = window.contentView?
                .bitmapImageRepForCachingDisplay(in: window.contentView!.bounds)?
                .cgImage
            else {
                throw ScreenshotError.captureFailed
            }

            let rep = NSBitmapImageRep(cgImage: cgImage)
            rep.size = window.contentView!.bounds.size
            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                throw ScreenshotError.encodingFailed
            }
            try pngData.write(to: outputURL)
            window.close()
        }

        private static func defaultPaletteForTheme(_ theme: ThemeKind) -> PaletteKind {
            switch theme {
            case .aurora: .auroraMintIris
            case .tapeDeck: .tapeDeckA
            }
        }

        enum ScreenshotError: Error {
            case captureFailed
            case encodingFailed
        }
    }
#endif
