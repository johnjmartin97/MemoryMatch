import SwiftUI
import UIKit
import XCTest
@testable import MemoryMatch

/// Proves the visual pass matches `ART.md`.
///
/// Every expected value here is written out by hand from the art direction. No
/// expectation is computed from the code under test, so a wrong constant in the
/// app cannot make its own test pass.
final class ThemeTests: XCTestCase {

    // MARK: - Reading a colour back

    /// The eight-digit `RRGGBBAA` form of a resolved colour, e.g. `0xFDF6ECFF`.
    ///
    /// Resolving through `UIColor` is how the colour actually reaches the
    /// screen, so this asserts on what the player sees rather than on how the
    /// value was written.
    private func rgba(_ color: Color) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a),
            "colour did not resolve to sRGB components"
        )
        let byte: (CGFloat) -> UInt32 = { UInt32(max(0, min(255, ($0 * 255).rounded()))) }
        return byte(r) << 24 | byte(g) << 16 | byte(b) << 8 | byte(a)
    }

    private func assertColor(
        _ color: Color,
        _ expected: UInt32,
        _ role: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = rgba(color)
        XCTAssertEqual(
            actual,
            expected,
            """
            \(role): expected #\(String(format: "%08X", expected)), \
            got #\(String(format: "%08X", actual))
            """,
            file: file,
            line: line
        )
    }

    // MARK: - 1. Every colour token exists with the exact light and dark values

    func testEveryPaletteTokenMatchesTheArtDirectionInBothAppearances() {
        // Straight from the two palette tables in ART.md. Opaque roles carry an
        // implicit FF alpha; the two translucent roles carry the alpha listed.
        let expected: [(role: String, light: UInt32, dark: UInt32, token: (ColorScheme) -> Color)] = [
            ("Background (top)", 0xFDF6ECFF, 0x1A1F26FF, Palette.backgroundTop),
            ("Background (bottom)", 0xF0E2D2FF, 0x0F1318FF, Palette.backgroundBottom),
            ("Surface", 0xFFFFFFFF, 0x242B33FF, Palette.surface),
            ("Primary", 0x2E6F7EFF, 0x3E8C9EFF, Palette.primary),
            ("Primary deep", 0x22545FFF, 0x2A6572FF, Palette.primaryDeep),
            ("Secondary", 0xE0A32EFF, 0xE8B858FF, Palette.secondary),
            ("Accent", 0xE0714FFF, 0xF08A6CFF, Palette.accent),
            ("Success", 0x4C9A6AFF, 0x63B383FF, Palette.success),
            ("Danger", 0xC7523FFF, 0xD9695AFF, Palette.danger),
            ("Text primary", 0x23282DFF, 0xEDEFF2FF, Palette.textPrimary),
            ("Text muted", 0x6E7780FF, 0x98A1ACFF, Palette.textMuted),
            ("Card stroke", 0x00000014, 0xFFFFFF1A, Palette.cardStroke),
            ("Matched veil", 0xFFFFFF99, 0x0F131899, Palette.matchedVeil),
        ]

        XCTAssertEqual(expected.count, 13, "ART.md names thirteen colour roles")

        for entry in expected {
            assertColor(entry.token(.light), entry.light, "\(entry.role) (light)")
            assertColor(entry.token(.dark), entry.dark, "\(entry.role) (dark)")
        }
    }

    // MARK: - 2. Eight card symbols, named and tinted as the art direction says

    func testCardSymbolSetHasTheEightNamedSymbolsWithTheirTints() {
        // The card-faces table in ART.md, in order.
        let expected: [(name: String, light: UInt32, dark: UInt32)] = [
            ("star.fill", 0xE0A32EFF, 0xEFBA55FF),
            ("heart.fill", 0xD2566BFF, 0xE4788BFF),
            ("bolt.fill", 0x7B5EA7FF, 0x9C81C4FF),
            ("leaf.fill", 0x4C9A6AFF, 0x6FBA8BFF),
            ("moon.fill", 0x5B7FB9FF, 0x7D9FD4FF),
            ("umbrella.fill", 0xE0714FFF, 0xF08A6CFF),
            ("anchor", 0x2E6F7EFF, 0x4E9CADFF),
            ("bell.fill", 0x8C7A6BFF, 0xAD9B8BFF),
        ]

        let symbols = CardSymbol.allCases
        XCTAssertEqual(symbols.count, 8, "the symbol set must contain exactly 8 entries")
        guard symbols.count == expected.count else { return }

        for (symbol, want) in zip(symbols, expected) {
            XCTAssertEqual(symbol.systemImageName, want.name)
            assertColor(symbol.tint(for: .light), want.light, "\(want.name) light tint")
            assertColor(symbol.tint(for: .dark), want.dark, "\(want.name) dark tint")
        }

        // Colour is redundant, never load-bearing: no two faces share a tint in
        // either appearance.
        let lightTints = Set(symbols.map { rgba($0.tint(for: .light)) })
        let darkTints = Set(symbols.map { rgba($0.tint(for: .dark)) })
        XCTAssertEqual(lightTints.count, 8, "each face needs a distinct light tint")
        XCTAssertEqual(darkTints.count, 8, "each face needs a distinct dark tint")
    }

    // MARK: - 3. The eight silhouettes are all different

    func testEveryPairIsIdentifiedByADifferentSilhouette() {
        let names = CardSymbol.allCases.map(\.systemImageName)
        XCTAssertEqual(
            Set(names).count,
            8,
            "two pairs share a silhouette, so they cannot be told apart: \(names)"
        )
    }

    // MARK: - 4. Type scale

    func testTextStylesAreSFRoundedAtTheSizesAndWeightsInTheArtDirection() {
        // Written independently from the type table in ART.md.
        XCTAssertEqual(
            Typography.display,
            Font.system(size: 40, weight: .bold, design: .rounded),
            "Display: 40 pt bold, SF Rounded"
        )
        XCTAssertEqual(
            Typography.title,
            Font.system(size: 26, weight: .semibold, design: .rounded),
            "Title: 26 pt semibold, SF Rounded"
        )
        XCTAssertEqual(
            Typography.body,
            Font.system(size: 17, weight: .medium, design: .rounded),
            "Body: 17 pt medium, SF Rounded"
        )
        XCTAssertEqual(
            Typography.caption,
            Font.system(size: 13, weight: .semibold, design: .rounded),
            "Caption: 13 pt semibold, SF Rounded"
        )
    }

    func testMoveCountAndTimerUseMonospacedDigitsSoTheLayoutNeverJitters() {
        let bodyRounded = Font.system(size: 17, weight: .medium, design: .rounded)

        XCTAssertEqual(
            Typography.moveCount,
            bodyRounded.monospacedDigit(),
            "the move count is a changing number, so its digits must be monospaced"
        )
        XCTAssertEqual(
            Typography.timer,
            bodyRounded.monospacedDigit(),
            "the timer is a changing number, so its digits must be monospaced"
        )
        XCTAssertNotEqual(
            Typography.moveCount,
            bodyRounded,
            "move count must differ from the plain body style by monospaced digits"
        )
    }

    // MARK: - 5. Corner radii

    func testCornerRadiiMatchTheArtDirectionAndAreAllContinuous() {
        XCTAssertEqual(Metrics.cardCornerRadius, 14, "card corner radius")
        XCTAssertEqual(Metrics.panelCornerRadius, 24, "win panel corner radius")
        XCTAssertEqual(Metrics.buttonCornerRadius, 12, "button corner radius")
        XCTAssertEqual(
            Metrics.cornerStyle,
            RoundedCornerStyle.continuous,
            "every rounded corner in the game is continuous, not circular"
        )
    }

    // MARK: - 6. Card stroke and the card-back pattern

    func testCardStrokeAndCardBackPatternMatchTheArtDirection() {
        XCTAssertEqual(Metrics.cardHairline, 1.5, "card hairline is 1.5 pt")

        // Three concentric rounded-rectangle strokes, outermost first.
        let expectedInsets: [CGFloat] = [8, 15, 22]
        let expectedOpacities: [Double] = [0.22, 0.16, 0.10]

        let rings = CardBackView.rings
        XCTAssertEqual(rings.count, 3, "the card back draws three concentric strokes")
        guard rings.count == 3 else { return }

        XCTAssertEqual(rings.map { $0.inset }, expectedInsets, "ring insets, in points")
        for (ring, want) in zip(rings, expectedOpacities) {
            XCTAssertEqual(ring.opacity, want, accuracy: 0.0001, "ring opacity at inset \(ring.inset)")
        }
    }

    // MARK: - 7. Spacing scale

    func testEverySpacingValueTheGameScreenUsesIsOnTheScale() {
        let scale: Set<CGFloat> = [4, 8, 12, 16, 24, 32]

        XCTAssertEqual(
            Set(Spacing.allCases.map(\.points)),
            scale,
            "the spacing scale is exactly 4 / 8 / 12 / 16 / 24 / 32 — nothing off-scale"
        )

        // The game screen's own spacing constants have to sit on that scale too.
        let used: [(name: String, value: CGFloat)] = [
            ("board inset from the screen edge", Metrics.boardInset),
            ("top bar side inset", Metrics.topBarSideInset),
        ]
        for entry in used {
            XCTAssertTrue(
                scale.contains(entry.value),
                "\(entry.name) is \(entry.value) pt, which is off the spacing scale"
            )
        }
    }

    // MARK: - 8. Top bar and the restart control's hit target

    func testTopBarHeightAndRestartHitTargetMeetTheArtDirection() {
        XCTAssertEqual(Metrics.topBarHeight, 44, "the top bar is 44 pt tall")

        let target = Metrics.restartHitTarget
        XCTAssertGreaterThanOrEqual(
            target.width,
            44,
            "the restart control must be at least 44 pt wide to be thumb-safe"
        )
        XCTAssertGreaterThanOrEqual(
            target.height,
            44,
            "the restart control must be at least 44 pt tall to be thumb-safe"
        )
    }
}
