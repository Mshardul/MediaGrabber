import SwiftUI

struct SkinnedTextButton: View {
    @Environment(\.theme) private var theme
    private let title: String
    private let action: () -> Void
    @State private var hovering = false
    @State private var pressing = false
    @FocusState private var focused: Bool

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.bodyFont(12, .medium))
                .foregroundStyle(
                    pressing ? theme.palette.accent.opacity(0.8) :
                        (hovering || focused) ? theme.palette.accent :
                        theme.palette.accent
                )
                .padding(.horizontal, Spacing.s2)
                .padding(.vertical, Spacing.s1)
                .background(
                    RoundedRectangle(cornerRadius: theme.controlRadius)
                        .fill(pressing ? theme.palette.accent.opacity(0.1) :
                            (hovering || focused) ? theme.palette.accent.opacity(0.08) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.controlRadius)
                        .stroke(focused ? theme.palette.accent : .clear, lineWidth: theme.hairlineWidth)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focused)
        .onPointerHover { hovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false }
        )
    }
}
