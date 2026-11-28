import GrabberKit
import SwiftUI

struct Theme {
    let kind: ThemeKind
    let palette: PaletteTokens

    init(_ kind: ThemeKind, palette: PaletteTokens = .auroraMintIris) {
        self.kind = kind
        self.palette = palette
    }

    init(themeKind: ThemeKind, paletteKind: PaletteKind) {
        kind = themeKind
        palette = MediaGrabber.palette(for: paletteKind)
    }

    static let auroraDisplayFamily = "Sora"
    static let auroraBodyFamily = "IBM Plex Sans"
    static let auroraMonoFamily = "JetBrains Mono"
    static let tapeDeckDisplayFamily = "Bricolage Grotesque"
    static let tapeDeckBodyFamily = "DM Sans"
    static let tapeDeckMonoFamily = "DM Mono"

    private var isAurora: Bool {
        kind == .aurora
    }

    var displayFamily: String {
        isAurora ? Self.auroraDisplayFamily : Self.tapeDeckDisplayFamily
    }

    var bodyFamily: String {
        isAurora ? Self.auroraBodyFamily : Self.tapeDeckBodyFamily
    }

    var monoFamily: String {
        isAurora ? Self.auroraMonoFamily : Self.tapeDeckMonoFamily
    }

    var displayFont: (CGFloat, Font.Weight) -> Font {
        { size, weight in Self.resolvedFont(displayFamily, size: size, weight: weight) }
    }

    var bodyFont: (CGFloat, Font.Weight) -> Font {
        { size, weight in Self.resolvedFont(bodyFamily, size: size, weight: weight) }
    }

    var monoFont: (CGFloat, Font.Weight) -> Font {
        { size, weight in
            Self.resolvedFont(
                monoFamily,
                size: size,
                weight: weight,
                fallbackDesign: .monospaced
            )
        }
    }

    private static func resolvedFont(
        _ family: String,
        size: CGFloat,
        weight: Font.Weight,
        fallbackDesign: Font.Design = .default
    ) -> Font {
        #if canImport(AppKit)
            if NSFont(name: family, size: size) != nil {
                return Font.custom(family, size: size).weight(weight)
            }
        #endif
        return Font.system(size: size, weight: weight, design: fallbackDesign)
    }

    var windowRadius: CGFloat {
        isAurora ? 18 : 14
    }

    var cardRadius: CGFloat {
        isAurora ? 14 : 12
    }

    var controlRadius: CGFloat {
        isAurora ? 9 : 8
    }

    var pillRadius: CGFloat {
        20
    }

    var chipRadius: CGFloat {
        isAurora ? 7 : 6
    }

    var hairlineWidth: CGFloat {
        isAurora ? 1 : 2
    }

    var controlBorderWidth: CGFloat {
        isAurora ? 1 : 1.5
    }

    var cardShadowOffset: CGFloat {
        isAurora ? 0 : 8
    }

    var cardShadowRadius: CGFloat {
        isAurora ? 24 : 0
    }

    var cardShadowColor: Color {
        Color.black.opacity(0.35)
    }
}

// Elevation for raised surfaces; Aurora glows, Tape Deck uses a hard offset shadow.
struct CardElevation: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        if theme.kind == .aurora {
            content
                .shadow(color: theme.palette.glowA, radius: 1, x: 0, y: 0)
                .shadow(color: theme.palette.glowB, radius: 32, x: 0, y: 0)
        } else {
            content
                .shadow(
                    color: theme.cardShadowColor,
                    radius: theme.cardShadowRadius,
                    x: theme.cardShadowOffset,
                    y: theme.cardShadowOffset
                )
        }
    }
}

extension View {
    func cardElevation(theme: Theme) -> some View {
        modifier(CardElevation(theme: theme))
    }
}

enum Spacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 22
    static let s6: CGFloat = 30
    static let s7: CGFloat = 44
}
