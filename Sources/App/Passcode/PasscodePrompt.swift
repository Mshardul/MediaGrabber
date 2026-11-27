import Foundation

struct PasscodePrompt: Equatable {
    enum Target: Equatable {
        case link(String)
        case job(UUID)
    }

    let target: Target
    let wasRejected: Bool
}
