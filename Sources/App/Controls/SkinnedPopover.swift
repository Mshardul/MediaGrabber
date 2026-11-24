import SwiftUI

struct SkinnedPopover<Content: View>: View {
    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.s3)
            .background(theme.palette.panelSolid)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.cardRadius).stroke(
                theme.palette.stroke,
                lineWidth: theme.hairlineWidth
            ))
            .shadow(
                color: .black.opacity(0.35),
                radius: theme.cardShadowRadius,
                x: theme.cardShadowOffset,
                y: theme.cardShadowOffset
            )
    }
}
