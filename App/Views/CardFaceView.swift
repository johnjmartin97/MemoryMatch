import SwiftUI

/// The face of a card: a matte Surface panel carrying one SF Symbol at 52% of
/// the card's shorter side, hierarchical rendering in the symbol's own tint.
///
/// When a card is matched it keeps its place on the board — a hole in the grid
/// destroys the spatial memory the game runs on — so it stays visible under a
/// veil with its tint pulled back.
struct CardFaceView: View {
    let symbol: CardSymbol
    /// True once the pair has been found: veiled, dimmed, non-interactive.
    var isMatched: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let glyphSide = side * Metrics.symbolScale
            let shape = RoundedRectangle(
                cornerRadius: Metrics.cardCornerRadius,
                style: .continuous
            )

            shape
                .fill(Palette.surface(colorScheme))
                .overlay {
                    Image(systemName: symbol.systemImageName)
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(symbol.tint(for: colorScheme))
                        .frame(width: glyphSide, height: glyphSide)
                        .opacity(isMatched ? 0.55 : 1.0)
                }
                .overlay {
                    // Matched veil: 60% white in light, 60% background in dark.
                    shape.fill(
                        isMatched
                            ? Palette.matchedVeil(colorScheme)
                            : Color.clear
                    )
                }
                .overlay {
                    shape.strokeBorder(
                        Palette.cardStroke(colorScheme),
                        lineWidth: Metrics.cardHairline
                    )
                }
                .clipShape(shape)
        }
        .accessibilityElement()
        .accessibilityLabel(
            isMatched
                ? "\(symbol.accessibilityLabel), matched"
                : symbol.accessibilityLabel
        )
    }
}

#Preview("Card faces") {
    LazyVGrid(
        columns: Array(
            repeating: GridItem(.fixed(78), spacing: Metrics.cardGap),
            count: 4
        ),
        spacing: Metrics.cardGap
    ) {
        ForEach(CardSymbol.allCases) { symbol in
            CardFaceView(symbol: symbol)
                .frame(width: 78, height: 78)
                .shadow(color: .black.opacity(0x1F / 255.0), radius: 6, y: 2)
        }
    }
    .padding(Metrics.boardInset)
    .background(Palette.backgroundTopLight)
}

#Preview("Matched") {
    HStack(spacing: Metrics.cardGap) {
        CardFaceView(symbol: .leaf)
        CardFaceView(symbol: .leaf, isMatched: true)
    }
    .frame(height: 96)
    .padding(Metrics.boardInset)
    .background(Palette.backgroundTopLight)
}
