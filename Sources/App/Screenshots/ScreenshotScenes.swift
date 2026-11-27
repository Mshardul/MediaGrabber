#if DEBUG
    import Foundation

    @MainActor
    struct SceneSpec {
        typealias Step = @MainActor (ScreenshotStage) async -> Void

        let name: String
        // Set by the registry; a scene built outside it belongs to no flow.
        var flow: ScreenshotFlow?
        // Runs before the views are rebuilt: data and model state a view reads when it appears.
        var prepare: Step = { _ in }
        // Runs once the views are on screen: changes a view only reacts to while it is showing.
        var interact: Step = { _ in }
        var hooks: [String] = []
        // Popovers and sheets that must be on screen in the picture.
        var overlays = 0
        // Checked before the capture, so a state that was not reached fails the run.
        var expect: @MainActor (AppModel) -> Bool
    }

    @MainActor
    enum ScreenshotScenes {
        static let all: [SceneSpec] = ScreenshotFlow.allCases.flatMap { flow in
            flow.scenes.map { scene in
                var member = scene
                member.flow = flow
                return member
            }
        }

        static func selected(_ options: ScreenshotOptions, from scenes: [SceneSpec] = all) -> [SceneSpec] {
            scenes.filter { scene in
                (options.flow == nil || scene.flow == options.flow)
                    && (options.scene == nil || scene.name == options.scene)
            }
        }
    }
#endif
