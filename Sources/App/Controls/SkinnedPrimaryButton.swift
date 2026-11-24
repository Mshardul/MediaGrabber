import SwiftUI

struct SkinnedPrimaryButton: View {
    @Environment(\.theme) private var theme
    private let title: String
    private let enabled: Bool
    private let action: () -> Void
    @State private var hovering = false

    init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.bodyFont(13, .semibold))
                .foregroundStyle(theme.palette.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: theme.controlRadius)
                )
                .opacity(hovering && enabled ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
    }

    private var gradientColors: [Color] {
        if enabled {
            return [theme.palette.goFillStart, theme.palette.goFillEnd]
        } else {
            return [
                theme.palette.goFillStart.opacity(0.5),
                theme.palette.goFillEnd.opacity(0.5)
            ]
        }
    }
}
