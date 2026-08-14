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
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// One cell: the appearance the display function asks for, and nothing else.
private struct CardCellView: View {
    let card: Card

    var body: some View {
        switch CardAppearance(card: card) {
        case .back:
            CardBackView()
        case let .face(symbol, matchedVeil):
            CardFaceView(symbol: symbol, isMatched: matchedVeil)
        }
    }
}

#Preview("Board") {
    BoardView(cards: GameModel(seed: 7).cards)
        .padding(Metrics.boardInset)
        .background(Palette.backgroundTopLight)
}
