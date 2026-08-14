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

    // MARK: - Red-gate stubs (behaviour not implemented yet)

    /// True when every card is matched.
    var isWon: Bool { false }

    /// Turns a face-down card face up, if the board allows it.
    func tap(_ index: Int) {}

    /// Judges the two face-up cards and ends the turn.
    func resolveTurn() {}
}
