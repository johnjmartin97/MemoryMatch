import Foundation

/// What the player can see of a card.
enum CardState: CaseIterable, Hashable, Sendable {
    case faceDown
    case faceUp
    case matched
}

/// One card on the board: its symbol and what the player can see of it.
struct Card: Equatable, Sendable {
    let symbol: CardSymbol
    var state: CardState
}
