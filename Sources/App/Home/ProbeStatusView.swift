import GrabberKit
import SwiftUI

enum ProbeStatusCopy {
    static let checking = "Checking link…"
    static let checkingZoom = "Checking link… Zoom links can take up to a minute."

    static func message(for link: String) -> String {
        let host = RateHost(urlString: link.trimmingCharacters(in: .whitespacesAndNewlines)).canonical
        return host == "zoom.us" || host.hasSuffix(".zoom.us") ? checkingZoom : checking
    }
}

struct ProbeStatusView: View {
    let link: String

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(theme.palette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(angle))
                .accessibilityHidden(true)
            Text(ProbeStatusCopy.message(for: link))
                .font(theme.bodyFont(12, .regular))
                .foregroundStyle(theme.palette.text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ProbeStatusCopy.message(for: link))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}
