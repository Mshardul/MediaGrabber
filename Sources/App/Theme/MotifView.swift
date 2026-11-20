import SwiftUI

struct MotifView: View {
    var isActive: Bool
    var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let stops: [Color] = [
        Color(hex: "#5EF2C8"),
        Color(hex: "#8B7BFF"),
        Color(hex: "#FF7A6B"),
        Color(hex: "#5EF2C8")
    ]

    func isSpinning(reduceMotion: Bool) -> Bool {
        isActive && !reduceMotion
    }

    var body: some View {
        TimelineView(.animation(paused: !isSpinning(reduceMotion: reduceMotion))) { context in
            let angle = isSpinning(reduceMotion: reduceMotion)
                ? Angle.degrees(context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 6) / 6 * 360)
                : .zero
            Circle()
                .fill(AngularGradient(colors: Self.stops, center: .center))
                .rotationEffect(angle)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
