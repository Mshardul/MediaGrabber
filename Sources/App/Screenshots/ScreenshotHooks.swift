#if DEBUG
    import Foundation

    // State that lives inside a view, set by the same call a click would make; only on-screen views are registered.
    @MainActor
    final class ScreenshotHooks {
        typealias Action = @MainActor () async -> Void

        static let shared = ScreenshotHooks()

        private var actions: [String: (token: UUID, run: Action)] = [:]

        var registeredIDs: Set<String> {
            Set(actions.keys)
        }

        @discardableResult
        func register(_ id: String, _ action: @escaping Action) -> UUID {
            let token = UUID()
            actions[id] = (token, action)
            return token
        }

        // With a token, a view that is going away cannot remove the registration of the view that replaced it.
        func unregister(_ id: String, token: UUID? = nil) {
            guard token == nil || actions[id]?.token == token else { return }
            actions[id] = nil
        }

        func fire(_ id: String) async -> Bool {
            guard let action = actions[id] else { return false }
            await action.run()
            return true
        }
    }
#endif

import SwiftUI

extension View {
    func screenshotHook(_ id: String, perform: @escaping @MainActor () async -> Void) -> some View {
        #if DEBUG
            modifier(ScreenshotHookModifier(id: id, action: perform))
        #else
            self
        #endif
    }
}

#if DEBUG
    private struct ScreenshotHookModifier: ViewModifier {
        let id: String
        let action: ScreenshotHooks.Action

        @State private var token: UUID?

        func body(content: Content) -> some View {
            content
                .onAppear { token = ScreenshotHooks.shared.register(id, action) }
                .onDisappear { ScreenshotHooks.shared.unregister(id, token: token) }
        }
    }
#endif
