import SwiftUI

struct SkinnedToggle: View {
    @Environment(\.theme) private var theme
    @Binding private var isOn: Bool
    private let label: String?
    @State private var hovering = false
    @State private var pressing = false
    @FocusState private var focused: Bool

    init(_ label: String? = nil, isOn: Binding<Bool>) {
        self.label = label
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: Spacing.s2) {
            if let label {
                Text(label)
                    .font(theme.bodyFont(12, .regular))
                    .foregroundStyle(theme.palette.text)
            }
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? theme.palette.accent : theme.palette.panel)
                    .overlay(
                        Capsule().stroke(
                            focused ? theme.palette.accent :
                                (hovering || pressing) ? theme.palette.accent :
                                theme.palette.stroke,
                            lineWidth: theme.hairlineWidth
                        )
                    )
                Circle()
                    .fill(theme.palette.panelSolid)
                    .padding(2)
                    .scaleEffect(pressing ? 0.9 : 1)
                    .animation(.easeOut(duration: 0.1), value: pressing)
            }
            .frame(width: 34, height: 20)
            .contentShape(Rectangle())
            .onTapGesture { isOn.toggle() }
            .onPointerHover { hovering = $0 }
            .focusable()
            .focused($focused)
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { isOn.toggle() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false }
        )
    }
}
