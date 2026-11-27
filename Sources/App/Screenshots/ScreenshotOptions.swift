#if DEBUG
    import Foundation
    import GrabberKit

    struct ScreenshotOptions: Equatable {
        let outputDir: URL
        let scene: String?
        let theme: ThemeKind?
        var flow: ScreenshotFlow?

        static let flag = "-MGScreenshots"
        private static let sceneFlag = "-MGScreenshotScene"
        private static let themeFlag = "-MGScreenshotTheme"
        private static let flowFlag = "-MGScreenshotFlow"

        static func parse(_ argv: [String]) -> ScreenshotOptions? {
            guard let values = flagValues(in: argv), let output = values[flag] else { return nil }
            let theme = values[themeFlag].map(ThemeKind.init(rawValue:))
            let flow = values[flowFlag].map(ScreenshotFlow.init(rawValue:))
            // A theme or flow that was given but not recognised fails the whole parse.
            if theme == .some(nil) || flow == .some(nil) {
                return nil
            }
            return ScreenshotOptions(
                outputDir: URL(fileURLWithPath: output),
                scene: values[sceneFlag],
                theme: theme ?? nil,
                flow: flow ?? nil
            )
        }

        // Nil when one of the tour's flags is the last argument, with no value after it.
        private static func flagValues(in argv: [String]) -> [String: String]? {
            let known: Set = [flag, sceneFlag, themeFlag, flowFlag]
            var values: [String: String] = [:]
            var arguments = argv.makeIterator()
            while let argument = arguments.next() {
                guard known.contains(argument) else { continue }
                guard let value = arguments.next() else { return nil }
                values[argument] = value
            }
            return values
        }
    }
#endif
