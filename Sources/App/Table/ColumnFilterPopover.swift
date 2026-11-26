import AppKit
import GrabberKit
import SwiftUI

struct ColumnFilterPopover: View {
    @Environment(\.theme) private var theme
    let column: ColumnID
    let values: [String]
    let selectedValues: Set<String>
    let onToggle: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ColumnMetrics.title(for: column))
                .font(theme.monoFont(10, .semibold))
                .textCase(.uppercase)
                .foregroundStyle(theme.palette.faint)
                .padding(.horizontal, Spacing.s3)
                .padding(.top, Spacing.s3)
                .padding(.bottom, Spacing.s1)

            Divider().overlay(theme.palette.hair)
                .padding(.horizontal, Spacing.s3)

            if values.isEmpty {
                Text("(none)")
                    .font(theme.bodyFont(12, .regular))
                    .foregroundStyle(theme.palette.faint)
                    .padding(.horizontal, Spacing.s3)
                    .padding(.vertical, Spacing.s2)
            } else {
                ForEach(values, id: \.self) { value in
                    let isSelected = selectedValues.contains(value)

                    Button {
                        onToggle(value)
                    } label: {
                        HStack {
                            Text(value)
                                .font(theme.bodyFont(12, .regular))
                                .foregroundStyle(theme.palette.text)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.palette.accent)
                            }
                        }
                        .padding(.horizontal, Spacing.s3)
                        .padding(.vertical, Spacing.s1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if value != values.last {
                        Divider().overlay(theme.palette.hair)
                            .padding(.leading, Spacing.s3)
                    }
                }
            }
        }
        .frame(width: popoverWidth)
        .padding(.bottom, Spacing.s3)
        .background(theme.palette.panelSolid)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cardRadius)
                .stroke(theme.palette.stroke, lineWidth: theme.hairlineWidth)
        )
        .shadow(
            color: theme.kind == .aurora ? theme.palette.glowB : .black.opacity(0.35),
            radius: theme.kind == .aurora ? 20 : theme.cardShadowRadius,
            x: theme.kind == .aurora ? 0 : theme.cardShadowOffset,
            y: theme.kind == .aurora ? 0 : theme.cardShadowOffset
        )
    }

    private var popoverWidth: CGFloat {
        let longest = values
            .map(\.count)
            .max() ?? 0
        let estimated = CGFloat(longest) * 7 + 72
        return min(300, max(160, estimated))
    }
}
