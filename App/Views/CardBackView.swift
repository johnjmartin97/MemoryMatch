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

    /// Inset of each ring from the card edge, outermost first.
    static let patternInsets: [CGFloat] = [8, 15, 22]
    /// Opacity of each ring, in the same order.
    static let patternOpacities: [Double] = [0.22, 0.16, 0.10]

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let shape = RoundedRectangle(
                cornerRadius: Metrics.cardCornerRadius,
                style: Metrics.cornerStyle
            )

            shape
                .fill(Palette.primary(colorScheme))
                .overlay {
                    ZStack {
                        ForEach(Self.patternInsets.indices, id: \.self) { index in
                            let inset = Self.patternInsets[index]
                            // Keep a little air inside the smallest ring.
                            if side - inset * 2 > Metrics.cardBackPatternStroke * 4 {
                                RoundedRectangle(
                                    cornerRadius: max(
                                        2,
                                        Metrics.cardCornerRadius - inset * 0.5
                                    ),
                                    style: Metrics.cornerStyle
                                )
                                .strokeBorder(
                                    Palette.primaryDeep(colorScheme)
                                        .opacity(Self.patternOpacities[index]),
                                    lineWidth: Metrics.cardBackPatternStroke
                                )
                                .padding(inset)
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
