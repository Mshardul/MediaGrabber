#if DEBUG
    import Foundation
    import GrabberKit

    struct ScreenshotOptions: Equatable {
        let outputDir: URL
        let scene: String?
        let theme: ThemeKind?

        static func parse(_ argv: [String]) -> ScreenshotOptions? {
            var outputDir: URL?
            var scene: String?
            var theme: ThemeKind?

            var index = argv.startIndex
            while index < argv.endIndex {
                let arg = argv[index]
                switch arg {
                case "-MGScreenshots":
                    index = argv.index(after: index)
                    guard index < argv.endIndex else { return nil }
                    outputDir = URL(fileURLWithPath: argv[index])
                case "-MGScreenshotScene":
                    index = argv.index(after: index)
                    guard index < argv.endIndex else { return nil }
                    scene = argv[index]
                case "-MGScreenshotTheme":
                    index = argv.index(after: index)
                    guard index < argv.endIndex else { return nil }
                    guard let parsed = ThemeKind(rawValue: argv[index]) else { return nil }
                    theme = parsed
                default:
                    break
                }
                index = argv.index(after: index)
            }

            guard let outputDir else { return nil }
            return ScreenshotOptions(outputDir: outputDir, scene: scene, theme: theme)
        }
    }
#endif
