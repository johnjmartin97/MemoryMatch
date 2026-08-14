import SwiftUI

/// The 4 x 4 grid of cards, drawn straight from the model in index order.
struct BoardView: View {
    let cards: [Card]

    /// Model indices laid out as 4 rows of 4, in order 0 to 15.
    var cellRows: [[Int]] {
        (0..<BoardLayout.rows).map { row in
            (0..<BoardLayout.columns).map { column in
                row * BoardLayout.columns + column
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let side = BoardLayout.cardSide(
                boardSide: min(geometry.size.width, geometry.size.height)
            )

            VStack(spacing: Metrics.cardGap) {
                ForEach(cellRows, id: \.self) { row in
                    HStack(spacing: Metrics.cardGap) {
                        ForEach(row, id: \.self) { index in
                            CardCellView(card: cards[index])
                                .frame(width: side, height: side)
                                .modifier(DealInModifier(cardIndex: index))
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// One cell: the appearance the display function asks for, turned over, with
/// the sound and the tap that go with the change.
private struct CardCellView: View {
    let card: Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True whenever the card is showing its face — face up or matched.
    private var isFaceUp: Bool { CardAppearance(card: card) != .back }

    private var isMatched: Bool { card.state == .matched }

    var body: some View {
        let motion = Motion.flip(reduceMotion: reduceMotion)

        Group {
            switch motion.style {
            case .rotate:
                CardFlipView(
                    degrees: isFaceUp ? motion.rotationDegrees : 0,
                    symbol: card.symbol,
                    isMatched: isMatched,
                    motion: motion
                )
            case .crossFade:
                ZStack {
                    CardBackView().opacity(isFaceUp ? 0 : 1)
                    CardFaceView(symbol: card.symbol, isMatched: isMatched)
                        .opacity(isFaceUp ? 1 : 0)
                }
            }
        }
        .animation(motion.animation, value: isFaceUp)
        .matchPop(isMatched: isMatched)
        .onChange(of: card.state) { _, state in
            switch state {
            case .faceUp:
                SoundPlayer.shared.play(.flip)
                Haptics.flip()
            case .matched:
                SoundPlayer.shared.play(.match)
                Haptics.match()
            case .faceDown:
                break
            }
        }
    }
}

/// The turn itself. The angle is animatable, so the two sides change places
/// half way through instead of the face showing through the back.
private struct CardFlipView: View, Animatable {
    var degrees: Double
    let symbol: CardSymbol
    let isMatched: Bool
    let motion: FlipMotion

    var animatableData: Double {
        get { degrees }
        set { degrees = newValue }
    }

    var body: some View {
        let axis = (x: motion.axis.x, y: motion.axis.y, z: motion.axis.z)

        Group {
            switch Motion.flipFacing(atDegrees: degrees) {
            case .back:
                CardBackView()
            case .face:
                // Turned back on itself, or the face would read mirrored.
                CardFaceView(symbol: symbol, isMatched: isMatched)
                    .rotation3DEffect(
                        .degrees(motion.rotationDegrees),
                        axis: axis,
                        perspective: motion.perspective
                    )
            }
        }
        .rotation3DEffect(
            .degrees(degrees),
            axis: axis,
            perspective: motion.perspective
        )
    }
}

/// The card arrives: it fades and lifts into place, 12 ms after the card
/// before it.
private struct DealInModifier: ViewModifier {
    let cardIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dealt = false

    func body(content: Content) -> some View {
        content
            .opacity(dealt ? 1 : 0)
            .scaleEffect(reduceMotion || dealt ? 1 : 0.92)
            .onAppear {
                let delay = Double(Motion.dealDelayMilliseconds(cardIndex: cardIndex)) / 1000
                withAnimation(Motion.deal.animation.delay(delay)) { dealt = true }
            }
    }
}

#Preview("Board") {
    BoardView(cards: GameModel(seed: 7).cards)
        .padding(Metrics.boardInset)
        .background(Palette.backgroundTopLight)
}
