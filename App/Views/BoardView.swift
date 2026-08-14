import SwiftUI

/// The 4 x 4 grid of cards, drawn straight from the model in index order.
struct BoardView: View {
    let cards: [Card]

    /// Identifies the board on screen. A new value means a new deal.
    var dealID: Int = 0

    /// What a tap on a card does. Defaulted to nothing so previews and
    /// render-only call sites keep working — but the app must pass the
    /// session's tap, because this closure IS the game: every layer beneath
    /// it was built and tested green while no view ever called it, and the
    /// shipped board rendered beautifully and could not be played.
    var tap: (Int) -> Void = { _ in }

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
                                .contentShape(Rectangle())
                                .onTapGesture { tap(index) }
                                .modifier(DealInModifier(cardIndex: index, dealID: dealID))
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

/// The arrival of one card: hidden until its turn in the deal comes round,
/// then in place.
struct DealInState: Equatable {
    /// True once the card has landed.
    private(set) var isDealt = false

    private var dealtID: Int?

    /// Starts this card's arrival on the given board. Returns the seconds to
    /// wait before it lands, or `nil` if it has already arrived on this board.
    mutating func begin(dealID: Int, cardIndex: Int) -> Double? {
        guard dealtID != dealID else { return nil }
        dealtID = dealID
        isDealt = false
        return Double(Motion.dealDelayMilliseconds(cardIndex: cardIndex)) / 1000
    }

    mutating func land() {
        isDealt = true
    }
}

/// The card arrives: it fades and lifts into place, 12 ms after the card
/// before it.
private struct DealInModifier: ViewModifier {
    let cardIndex: Int
    let dealID: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deal = DealInState()

    func body(content: Content) -> some View {
        content
            .opacity(deal.isDealt ? 1 : 0)
            .scaleEffect(reduceMotion || deal.isDealt ? 1 : 0.92)
            .onAppear { dealIn() }
            // The cells are never torn down when the board is re-dealt, so a
            // new deal has to be noticed here or only the first one animates.
            .onChange(of: dealID) { _, _ in dealIn() }
    }

    private func dealIn() {
        guard let delay = deal.begin(dealID: dealID, cardIndex: cardIndex) else { return }
        // The card is hidden again first. That has to reach the screen before
        // the arrival is animated, or on a re-deal both changes land in one
        // pass and the card simply appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(Motion.deal.animation) { deal.land() }
        }
    }
}

#Preview("Board") {
    BoardView(cards: GameModel(seed: 7).cards)
        .padding(Metrics.boardInset)
        .background(Palette.backgroundTopLight)
}
