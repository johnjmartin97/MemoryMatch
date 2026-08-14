import Foundation

/// How one card should be drawn. A pure function of the model card: the same
/// card value always gives the same appearance.
enum CardAppearance: Equatable {
    case back
    case face(symbol: CardSymbol, matchedVeil: Bool)

    init(card: Card) {
        switch card.state {
        case .faceDown:
            self = .back
        case .faceUp:
            self = .face(symbol: card.symbol, matchedVeil: false)
        case .matched:
            self = .face(symbol: card.symbol, matchedVeil: true)
        }
    }
}
