import Observation

/// A repeatable random source, so a given seed always deals the same board.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Any non-zero start works; the constant just avoids a zero state.
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The dealt board: eight pairs, shuffled, all face down.
@Observable
final class GameModel {
    private(set) var cards: [Card]

    /// Completed turns. A turn counts once it resolves, matched or not — never
    /// on a tap.
    private(set) var moveCount: Int

    /// True while two cards are face up and waiting to be judged.
    private(set) var isLocked: Bool

    init(seed: UInt64 = .random(in: 0...UInt64.max)) {
        var generator = SeededGenerator(seed: seed)
        let pairs = CardSymbol.allCases.flatMap { [$0, $0] }
        cards = pairs.shuffled(using: &generator).map {
            Card(symbol: $0, state: .faceDown)
        }
        moveCount = 0
        isLocked = false
    }

    /// Starts from a given board. Tests use this to set up an exact position.
    init(cards: [Card], moveCount: Int = 0, isLocked: Bool = false) {
        self.cards = cards
        self.moveCount = moveCount
        self.isLocked = isLocked
    }

    // MARK: - Play

    /// True when every card is matched.
    var isWon: Bool { cards.allSatisfy { $0.state == .matched } }

    /// The positions of the cards currently face up.
    private var faceUpPositions: [Int] {
        cards.indices.filter { cards[$0].state == .faceUp }
    }

    /// Turns a face-down card face up, if the board allows it. A tap is refused
    /// while the board is locked, on a card that is not face down, and once two
    /// cards are already face up.
    func tap(_ index: Int) {
        guard !isLocked, cards.indices.contains(index) else { return }
        guard cards[index].state == .faceDown else { return }

        var faceUp = faceUpPositions
        guard faceUp.count < 2 else { return }

        cards[index].state = .faceUp
        faceUp.append(index)
        if faceUp.count == 2 {
            isLocked = true
        }
    }

    /// Judges the two face-up cards and ends the turn: same symbol and they
    /// stay up as matched, different and they go back down. Either way the
    /// board unlocks and the turn counts as one move.
    func resolveTurn() {
        let faceUp = faceUpPositions
        guard faceUp.count == 2 else { return }

        let first = faceUp[0]
        let second = faceUp[1]
        let matched = cards[first].symbol == cards[second].symbol
        let resolvedState: CardState = matched ? .matched : .faceDown
        cards[first].state = resolvedState
        cards[second].state = resolvedState

        moveCount += 1
        isLocked = false
    }
}
