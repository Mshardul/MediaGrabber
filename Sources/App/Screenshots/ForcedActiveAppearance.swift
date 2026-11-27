#if DEBUG
    import AppKit
    import ObjectiveC

    struct ForcedActiveAppearanceError: Error, CustomStringConvertible {
        let missing: [String]

        var description: String {
            "this macOS no longer has \(missing.joined(separator: ", ")), "
                + "so a window behind other apps cannot be drawn as active"
        }
    }

    // Overrides private AppKit methods, so windows behind other apps still draw as active.
    @MainActor
    enum ForcedActiveAppearance {
        static let methods = ["_hasActiveAppearance", "hasKeyAppearance", "hasMainAppearance"]

        // All or none: a half-forced window would look wrong in a way that is easy to miss.
        static func apply(_ names: [String] = methods) throws {
            let found = names.map { ($0, class_getInstanceMethod(NSWindow.self, NSSelectorFromString($0))) }
            let missing = found.filter { $0.1 == nil }.map(\.0)
            guard missing.isEmpty else { throw ForcedActiveAppearanceError(missing: missing) }
            let always: @convention(block) (AnyObject) -> Bool = { _ in true }
            for method in found.compactMap(\.1) {
                method_setImplementation(method, imp_implementationWithBlock(always))
            }
        }
    }
#endif
