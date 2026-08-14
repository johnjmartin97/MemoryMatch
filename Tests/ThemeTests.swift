import SwiftUI
import UIKit
import XCTest
@testable import MemoryMatch

/// PP-5 — the visual pass against `ART.md`.
///
/// One test per acceptance criterion. Every expected number and hex value is
/// written out here by hand, copied from `ART.md`, so no expectation is
/// computed by the code it checks.
final class ThemeTests: XCTestCase {

    // MARK: - Reading a colour back

    /// A colour as straight 8-bit sRGB plus alpha in 0...255.
    private struct RGBA: Equatable, CustomStringConvertible {
        var red: Int, green: Int, blue: Int, alpha: Int

        init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        /// `0xRRGGBB` with an optional separate alpha byte, the way `ART.md`
        /// writes them (`#00000014` is black at alpha `0x14`).
        init(hex: UInt32, alpha: Int = 255) {
            red = Int((hex >> 16) & 0xFF)
            green = Int((hex >> 8) & 0xFF)
            blue = Int(hex & 0xFF)
            self.alpha = alpha
        }

        /// Largest difference on any single channel, in 0...255.
        func distance(to other: RGBA) -> Int {
            max(
                max(abs(red - other.red), abs(green - other.green)),
                max(abs(blue - other.blue), abs(alpha - other.alpha))
            )
        }

        var description: String {
            String(
                format: "#%02X%02X%02X (alpha %02X)",
                red, green, blue, alpha
            )
        }
    }

    private func rgba(_ colour: Color) -> RGBA {
        var red: CGFloat = 0, green: CGFloat = 0
        var blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(colour).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(
            red: Int((red * 255).rounded()),
            green: Int((green * 255).rounded()),
            blue: Int((blue * 255).rounded()),
            alpha: Int((alpha * 255).rounded())
        )
    }

    /// Asserts a token matches the hex from `ART.md`, allowing one step of
    /// 8-bit rounding on any channel.
    private func assertColour(
        _ actual: Color,
        _ expected: RGBA,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let got = rgba(actual)
        XCTAssertLessThanOrEqual(
            got.distance(to: expected),
            1,
            "\(name) is \(expected.description), got \(got.description)",
            file: file,
            line: line
        )
    }

    // MARK: - Criterion 1: every colour token, light and dark

    /// The palette from `ART.md`, written out by hand.
    func testEveryColourTokenMatchesTheArtDirection() {
        let light: [(String, Color, RGBA)] = [
            ("background top, light", Palette.backgroundTop(.light), RGBA(hex: 0xFDF6EC)),
            ("background bottom, light", Palette.backgroundBottom(.light), RGBA(hex: 0xF0E2D2)),
            ("surface, light", Palette.surface(.light), RGBA(hex: 0xFFFFFF)),
            ("primary, light", Palette.primary(.light), RGBA(hex: 0x2E6F7E)),
            ("primary deep, light", Palette.primaryDeep(.light), RGBA(hex: 0x22545F)),
            ("secondary, light", Palette.secondary(.light), RGBA(hex: 0xE0A32E)),
            ("accent, light", Palette.accent(.light), RGBA(hex: 0xE0714F)),
            ("success, light", Palette.success(.light), RGBA(hex: 0x4C9A6A)),
            ("danger, light", Palette.danger(.light), RGBA(hex: 0xC7523F)),
            ("text primary, light", Palette.textPrimary(.light), RGBA(hex: 0x23282D)),
            ("text muted, light", Palette.textMuted(.light), RGBA(hex: 0x6E7780)),
            ("card stroke, light", Palette.cardStroke(.light), RGBA(hex: 0x000000, alpha: 0x14)),
            ("matched veil, light", Palette.matchedVeil(.light), RGBA(hex: 0xFFFFFF, alpha: 0x99)),
        ]

        let dark: [(String, Color, RGBA)] = [
            ("background top, dark", Palette.backgroundTop(.dark), RGBA(hex: 0x1A1F26)),
            ("background bottom, dark", Palette.backgroundBottom(.dark), RGBA(hex: 0x0F1318)),
            ("surface, dark", Palette.surface(.dark), RGBA(hex: 0x242B33)),
            ("primary, dark", Palette.primary(.dark), RGBA(hex: 0x3E8C9E)),
            ("primary deep, dark", Palette.primaryDeep(.dark), RGBA(hex: 0x2A6572)),
            ("secondary, dark", Palette.secondary(.dark), RGBA(hex: 0xE8B858)),
            ("accent, dark", Palette.accent(.dark), RGBA(hex: 0xF08A6C)),
            ("success, dark", Palette.success(.dark), RGBA(hex: 0x63B383)),
            ("danger, dark", Palette.danger(.dark), RGBA(hex: 0xD9695A)),
            ("text primary, dark", Palette.textPrimary(.dark), RGBA(hex: 0xEDEFF2)),
            ("text muted, dark", Palette.textMuted(.dark), RGBA(hex: 0x98A1AC)),
            ("card stroke, dark", Palette.cardStroke(.dark), RGBA(hex: 0xFFFFFF, alpha: 0x1A)),
            ("matched veil, dark", Palette.matchedVeil(.dark), RGBA(hex: 0x0F1318, alpha: 0x99)),
        ]

        XCTAssertEqual(light.count, 13, "13 light tokens are named in ART.md")
        XCTAssertEqual(dark.count, 13, "13 dark tokens are named in ART.md")

        for (name, colour, expected) in light + dark {
            assertColour(colour, expected, name)
        }
    }

    // MARK: - Criterion 2: the eight card faces

    /// The symbol table from `ART.md`, written out by hand: name, light
    /// tint, dark tint, in order.
    private static let referenceSymbols:
        [(symbol: CardSymbol, name: String, light: UInt32, dark: UInt32)] = [
            (.star, "star.fill", 0xE0A32E, 0xEFBA55),
            (.heart, "heart.fill", 0xD2566B, 0xE4788B),
            (.bolt, "bolt.fill", 0x7B5EA7, 0x9C81C4),
            (.leaf, "leaf.fill", 0x4C9A6A, 0x6FBA8B),
            (.moon, "moon.fill", 0x5B7FB9, 0x7D9FD4),
            (.umbrella, "umbrella.fill", 0xE0714F, 0xF08A6C),
            (.anchor, "anchor", 0x2E6F7E, 0x4E9CAD),
            (.bell, "bell.fill", 0x8C7A6B, 0xAD9B8B),
        ]

    func testSymbolSetHasEightEntriesWithTheirNamesAndTints() {
        XCTAssertEqual(
            CardSymbol.allCases.count,
            8,
            "the card symbol set has exactly 8 entries"
        )
        XCTAssertEqual(
            CardSymbol.allCases.map(\.systemImageName),
            Self.referenceSymbols.map(\.name),
            "the SF Symbol names, in ART.md order"
        )

        for entry in Self.referenceSymbols {
            assertColour(
                entry.symbol.tint(for: .light),
                RGBA(hex: entry.light),
                "\(entry.name) light tint"
            )
            assertColour(
                entry.symbol.tint(for: .dark),
                RGBA(hex: entry.dark),
                "\(entry.name) dark tint"
            )
        }

        // Distinct tints: no two faces share a colour in either appearance.
        for scheme in [ColorScheme.light, .dark] {
            let tints = CardSymbol.allCases.map { rgba($0.tint(for: scheme)) }
            for (first, one) in tints.enumerated() {
                for (second, other) in tints.enumerated() where second > first {
                    XCTAssertNotEqual(
                        one,
                        other,
                        """
                        \(CardSymbol.allCases[first]) and \
                        \(CardSymbol.allCases[second]) have different \
                        \(scheme) tints
                        """
                    )
                }
            }
        }
    }

    // MARK: - Criterion 3: distinct silhouettes

    func testTheEightSymbolNamesAreAllDistinct() {
        let names = CardSymbol.allCases.map(\.systemImageName)
        XCTAssertEqual(
            Set(names).count,
            8,
            "8 different SF Symbol names, so every pair is a different shape"
        )
    }

    // MARK: - Criterion 4: type

    func testTextStylesAreRoundedAtTheArtDirectionSizes() {
        // (style, size, weight) copied from the type table in ART.md.
        let expected: [(String, TextStyle, CGFloat, Font.Weight)] = [
            ("display", Typography.display, 40, .bold),
            ("title", Typography.title, 26, .semibold),
            ("body", Typography.body, 17, .medium),
            ("caption", Typography.caption, 13, .semibold),
        ]

        for (name, style, size, weight) in expected {
            XCTAssertEqual(style.size, size, accuracy: 0.0001, "\(name) is \(size) pt")
            XCTAssertEqual(style.weight, weight, "\(name) weight")
            XCTAssertEqual(style.design, .rounded, "\(name) is SF Rounded")
        }

        // Numbers that change never shift the layout around them.
        for (name, style) in [
            ("move count", Typography.moveCount),
            ("timer", Typography.timer),
        ] {
            XCTAssertTrue(
                style.monospacedDigits,
                "the \(name) style uses monospaced digits"
            )
            XCTAssertEqual(style.design, .rounded, "the \(name) style is SF Rounded")
            XCTAssertTrue(
                [40, 26, 17, 13].contains(style.size),
                "the \(name) style sits on the type scale, got \(style.size)"
            )
        }
    }

    // MARK: - Criterion 5: corner radii

    func testCornerRadiiAreFourteenTwentyFourAndTwelveContinuous() {
        XCTAssertEqual(Metrics.cardCornerRadius, 14, accuracy: 0.0001, "card corner")
        XCTAssertEqual(Metrics.panelCornerRadius, 24, accuracy: 0.0001, "win panel corner")
        XCTAssertEqual(Metrics.buttonCornerRadius, 12, accuracy: 0.0001, "button corner")
        XCTAssertEqual(
            Metrics.cornerStyle,
            .continuous,
            "every rounded corner is continuous, not circular"
        )
    }

    // MARK: - Criterion 6: card stroke and card-back pattern

    func testCardStrokeAndCardBackPattern() {
        XCTAssertEqual(
            Metrics.cardHairline,
            1.5,
            accuracy: 0.0001,
            "the hairline around every card is 1.5 pt"
        )

        XCTAssertEqual(
            CardBackView.patternInsets,
            [8, 15, 22],
            "three concentric rings, inset 8 / 15 / 22 pt from the card edge"
        )
        XCTAssertEqual(
            CardBackView.patternOpacities.count,
            3,
            "one opacity per ring"
        )
        let opacities = CardBackView.patternOpacities
        for (index, expected) in [0.22, 0.16, 0.10].enumerated()
        where index < opacities.count {
            XCTAssertEqual(
                opacities[index],
                expected,
                accuracy: 0.0001,
                "ring \(index + 1) opacity"
            )
        }
    }

    // MARK: - Criterion 7: the spacing scale

    func testEverySpacingOnTheGameScreenIsOnTheScale() {
        let scale: [CGFloat] = [4, 8, 12, 16, 24, 32]
        XCTAssertEqual(Spacing.scale, scale, "the scale from ART.md, in order")

        let used = Metrics.gameScreenSpacings
        XCTAssertFalse(used.isEmpty, "the game screen declares the spacings it uses")
        for value in used {
            XCTAssertTrue(
                scale.contains(value),
                "spacing \(value) is on the 4/8/12/16/24/32 scale"
            )
        }
    }

    // MARK: - Criterion 8: top bar and restart target

    func testTopBarHeightAndRestartHitTarget() {
        XCTAssertEqual(
            Metrics.topBarHeight,
            44,
            accuracy: 0.0001,
            "the top bar is 44 pt tall"
        )
        XCTAssertGreaterThanOrEqual(
            Metrics.restartHitTarget.width,
            44,
            "the restart control is at least 44 pt wide to tap"
        )
        XCTAssertGreaterThanOrEqual(
            Metrics.restartHitTarget.height,
            44,
            "the restart control is at least 44 pt tall to tap"
        )
    }
}
