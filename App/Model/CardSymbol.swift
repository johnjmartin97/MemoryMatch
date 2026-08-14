import SwiftUI

/// The eight card faces.
///
/// Each pair is identified by silhouette first: the shapes stay distinct in
/// greyscale, so colour is redundant and never load-bearing. Tints come
/// straight from `ART.md`.
enum CardSymbol: String, CaseIterable, Identifiable, Hashable, Sendable {
    case star
    case heart
    case bolt
    case leaf
    case moon
    case umbrella
    case anchor
    case bell

    var id: String { rawValue }

    /// SF Symbol name for the face glyph.
    var systemImageName: String {
        switch self {
        case .star: return "star.fill"
        case .heart: return "heart.fill"
        case .bolt: return "bolt.fill"
        case .leaf: return "leaf.fill"
        case .moon: return "moon.fill"
        case .umbrella: return "umbrella.fill"
        case .anchor: return "anchor"
        case .bell: return "bell.fill"
        }
    }

    /// Spoken name for VoiceOver. Plain words, no symbol jargon.
    var accessibilityLabel: String {
        switch self {
        case .star: return "Star"
        case .heart: return "Heart"
        case .bolt: return "Lightning bolt"
        case .leaf: return "Leaf"
        case .moon: return "Moon"
        case .umbrella: return "Umbrella"
        case .anchor: return "Anchor"
        case .bell: return "Bell"
        }
    }

    var lightTint: Color {
        switch self {
        case .star: return Color(hex: 0xE0A32E)
        case .heart: return Color(hex: 0xD2566B)
        case .bolt: return Color(hex: 0x7B5EA7)
        case .leaf: return Color(hex: 0x4C9A6A)
        case .moon: return Color(hex: 0x5B7FB9)
        case .umbrella: return Color(hex: 0xE0714F)
        case .anchor: return Color(hex: 0x2E6F7E)
        case .bell: return Color(hex: 0x8C7A6B)
        }
    }

    var darkTint: Color {
        switch self {
        case .star: return Color(hex: 0xEFBA55)
        case .heart: return Color(hex: 0xE4788B)
        case .bolt: return Color(hex: 0x9C81C4)
        case .leaf: return Color(hex: 0x6FBA8B)
        case .moon: return Color(hex: 0x7D9FD4)
        case .umbrella: return Color(hex: 0xF08A6C)
        case .anchor: return Color(hex: 0x4E9CAD)
        case .bell: return Color(hex: 0xAD9B8B)
        }
    }

    /// The tint for a given appearance.
    func tint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkTint : lightTint
    }
}

/// The shared palette from `ART.md`. Every colour the game draws comes from
/// here, so there is exactly one place a hex value lives.
enum Palette {
    // Light
    static let backgroundTopLight = Color(hex: 0xFDF6EC)
    static let backgroundBottomLight = Color(hex: 0xF0E2D2)
    static let surfaceLight = Color(hex: 0xFFFFFF)
    static let primaryLight = Color(hex: 0x2E6F7E)
    static let primaryDeepLight = Color(hex: 0x22545F)
    static let secondaryLight = Color(hex: 0xE0A32E)
    static let accentLight = Color(hex: 0xE0714F)
    static let successLight = Color(hex: 0x4C9A6A)
    static let dangerLight = Color(hex: 0xC7523F)
    static let textPrimaryLight = Color(hex: 0x23282D)
    static let textMutedLight = Color(hex: 0x6E7780)
    static let cardStrokeLight = Color.black.opacity(0x14 / 255.0)
    static let matchedVeilLight = Color.white.opacity(0x99 / 255.0)

    // Dark
    static let backgroundTopDark = Color(hex: 0x1A1F26)
    static let backgroundBottomDark = Color(hex: 0x0F1318)
    static let surfaceDark = Color(hex: 0x242B33)
    static let primaryDark = Color(hex: 0x3E8C9E)
    static let primaryDeepDark = Color(hex: 0x2A6572)
    static let secondaryDark = Color(hex: 0xE8B858)
    static let accentDark = Color(hex: 0xF08A6C)
    static let successDark = Color(hex: 0x63B383)
    static let dangerDark = Color(hex: 0xD9695A)
    static let textPrimaryDark = Color(hex: 0xEDEFF2)
    static let textMutedDark = Color(hex: 0x98A1AC)
    static let cardStrokeDark = Color.white.opacity(0x1A / 255.0)
    static let matchedVeilDark = Color(hex: 0x0F1318).opacity(0x99 / 255.0)

    static func backgroundTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundTopDark : backgroundTopLight
    }

    static func backgroundBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundBottomDark : backgroundBottomLight
    }

    /// The screen's background wash, top to bottom, for one appearance.
    static func backgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [backgroundTop(scheme), backgroundBottom(scheme)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceDark : surfaceLight
    }

    static func primary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryDark : primaryLight
    }

    static func primaryDeep(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryDeepDark : primaryDeepLight
    }

    static func secondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? secondaryDark : secondaryLight
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accentDark : accentLight
    }

    static func success(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? successDark : successLight
    }

    static func danger(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? dangerDark : dangerLight
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? textPrimaryDark : textPrimaryLight
    }

    static func textMuted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? textMutedDark : textMutedLight
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardStrokeDark : cardStrokeLight
    }

    static func matchedVeil(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? matchedVeilDark : matchedVeilLight
    }
}

/// Layout constants from `ART.md`. Spacing stays on the 4/8/12/16/24/32 scale.
enum Metrics {
    static let cardCornerRadius: CGFloat = 14
    static let panelCornerRadius: CGFloat = 24
    static let buttonCornerRadius: CGFloat = 12
    static let cardHairline: CGFloat = 1.5
    static let cardBackPatternStroke: CGFloat = 2
    static let cardGap: CGFloat = 10
    static let boardInset: CGFloat = 16
    static let minimumCardSide: CGFloat = 64
    /// Glyph occupies 52% of the card's shorter side.
    static let symbolScale: CGFloat = 0.52

    /// Every rounded corner in the game is continuous, never circular.
    static let cornerStyle: RoundedCornerStyle = .continuous

    /// The top bar: 44 pt tall, with a 44 x 44 pt target on the restart
    /// control so it is comfortable to hit.
    static let topBarHeight: CGFloat = 44
    static let restartHitTarget = CGSize(width: 44, height: 44)

    /// Every gap and inset the game screen lays out with. All of them sit on
    /// `Spacing.scale`.
    ///
    /// `cardGap` is not here: it is the gap inside the board grid, which
    /// `ART.md` pins at 10 pt in the same breath as the scale it breaks.
    static let gameScreenSpacings: [CGFloat] = [
        boardInset,
        topBarStackSpacing,
        topBarSideInset,
    ]

    /// Space between the top bar and the board.
    static let topBarStackSpacing: CGFloat = 16
    /// Side inset on the top bar's contents.
    static let topBarSideInset: CGFloat = 16
}

extension Color {
    /// Builds a colour from a 24-bit RGB literal, e.g. `Color(hex: 0x2E6F7E)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
