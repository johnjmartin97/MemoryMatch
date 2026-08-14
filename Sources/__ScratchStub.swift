import SwiftUI

// Scratch stubs so the PP-2 tests compile and fail on their assertions rather
// than on missing symbols. No behaviour here — the build stage replaces this
// file with the real implementation.

enum CardState: CaseIterable, Hashable {
    case faceDown, faceUp, matched
}

struct Card: Equatable {
    let symbol: CardSymbol
    var state: CardState
}

final class GameModel {
    private(set) var cards: [Card] = []

    init(seed: UInt64) {}
}

enum CardAppearance: Equatable {
    case back
    case face(symbol: CardSymbol, matchedVeil: Bool)

    init(card: Card) {
        self = .back
    }
}

enum BoardLayout {
    static func cardSide(boardSide: CGFloat) -> CGFloat { 0 }

    static func boardSize(availableWidth: CGFloat, availableHeight: CGFloat) -> CGSize {
        .zero
    }
}

struct BoardView: View {
    let cards: [Card]

    var cellRows: [[Int]] { [] }

    var body: some View { EmptyView() }
}

enum RootScreen: Equatable {
    case splash, menu, board
}

enum BoardOverlay: Equatable {
    case win
}

extension ContentView {
    var screen: RootScreen { .splash }
    var overlay: BoardOverlay? { .win }
    var cards: [Card] { [] }
}
