import SwiftUI

struct SkinnedStepper: View {
    @Environment(\.theme) private var theme
    @Binding private var value: Int
    private let range: ClosedRange<Int>

    init(value: Binding<Int>, in range: ClosedRange<Int> = 0 ... 99) {
        _value = value
        self.range = range
    }

    var body: some View {
        HStack(spacing: 0) {
            stepperButton("−", canDecrement, action: { if canDecrement { value -= 1 } })
            Text("\(value)")
                .font(theme.monoFont(12, .medium))
                .foregroundStyle(theme.palette.text)
                .frame(minWidth: 28)
            stepperButton("+", canIncrement, action: { if canIncrement { value += 1 } })
        }
        .padding(2)
        .background(theme.palette.panel, in: RoundedRectangle(cornerRadius: theme.controlRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.controlRadius)
                .stroke(theme.palette.stroke, lineWidth: theme.hairlineWidth)
        )
    }

    private var canDecrement: Bool { value > range.lowerBound }
    private var canIncrement: Bool { value < range.upperBound }

    private func stepperButton(
        _ title: String,
        _ enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.bodyFont(13, .semibold))
                .foregroundStyle(enabled ? theme.palette.text : theme.palette.faint)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: theme.controlRadius)
                        .fill(enabled ? (pressing ? theme.palette.accent.opacity(0.15) : (hovering ? theme.palette.panelHi : .clear)) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.controlRadius)
                        .stroke(
                            focused && enabled ? theme.palette.accent : .clear,
                            lineWidth: theme.hairlineWidth
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .focusable()
        .focused($focused)
        .onHover { hovering = $0 && enabled }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = enabled }
                .onEnded { _ in pressing = false }
        )
    }

    @State private var hovering = false
    @State private var pressing = false
    @FocusState private var focused: Bool
}