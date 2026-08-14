import SwiftUI

/// The back of a card: a flat Primary field under three concentric
/// continuous-rounded-rectangle strokes, inset 8 / 15 / 22 pt from the edge at
/// 22% / 16% / 10% opacity in Primary deep.
///
/// Drawn entirely in SwiftUI so it stays exact at any card size. On the
/// smallest supported card (64 pt) the innermost ring would collapse, so rings
/// whose inset leaves no room are simply skipped rather than drawn inverted.
struct CardBackView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Inset from the card edge, and the opacity of that ring.
    private static let rings: [(inset: CGFloat, opacity: Double)] = [
        (8, 0.22),
        (15, 0.16),
        (22, 0.10),
    ]

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let shape = RoundedRectangle(
                cornerRadius: Metrics.cardCornerRadius,
                style: .continuous
            )

            shape
                .fill(Palette.primary(colorScheme))
                .overlay {
                    ZStack {
                        ForEach(Self.rings.indices, id: \.self) { index in
                            let ring = Self.rings[index]
                            // Keep a little air inside the smallest ring.
                            if side - ring.inset * 2 > Metrics.cardBackPatternStroke * 4 {
                                RoundedRectangle(
                                    cornerRadius: max(
                                        2,
                                        Metrics.cardCornerRadius - ring.inset * 0.5
                                    ),
                                    style: .continuous
                                )
                                .strokeBorder(
                                    Palette.primaryDeep(colorScheme)
                                        .opacity(ring.opacity),
                                    lineWidth: Metrics.cardBackPatternStroke
                                )
                                .padding(ring.inset)
                            }
                        }
                    }
                }
                .overlay {
                    shape.strokeBorder(
                        Palette.cardStroke(colorScheme),
                        lineWidth: Metrics.cardHairline
                    )
                }
                .clipShape(shape)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Card back") {
    HStack(spacing: Metrics.cardGap) {
        CardBackView().frame(width: 78, height: 78)
        CardBackView().frame(width: 120, height: 120)
    }
    .padding(Metrics.boardInset)
    .background(Palette.backgroundTopLight)
}

#Preview("Card back, dark") {
    CardBackView()
        .frame(width: 120, height: 120)
        .padding(Metrics.boardInset)
        .background(Palette.backgroundTopDark)
        .preferredColorScheme(.dark)
}
