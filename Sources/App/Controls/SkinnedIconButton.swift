import SwiftUI

struct SkinnedIconButton: View {
    @Environment(\.theme) private var theme
    private let systemImage: String
    private let action: () -> Void

    init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(theme.bodyFont(13, .medium))
                .foregroundStyle(theme.palette.dim)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
