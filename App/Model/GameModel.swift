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

    /// Completed turns. A turn counts 1 when it is resolved, match or not.
    private(set) var moveCount: Int = 0

    /// True while two cards are face up and waiting to be judged. Taps do
    /// nothing while the board is locked.
    var isLocked: Bool { faceUpIndices.count >= 2 }

    /// True only when all 16 cards are matched.
    var isWon: Bool { cards.allSatisfy { $0.state == .matched } }

    /// The positions of the cards currently face up.
    private var faceUpIndices: [Int] {
        cards.indices.filter { cards[$0].state == .faceUp }
    }

    /// Where delayed work goes. Held so a test can drive time by hand.
    @ObservationIgnored private let clock: TurnClock

    init(
        seed: UInt64 = .random(in: 0...UInt64.max),
        clock: TurnClock = SystemTurnClock()
    ) {
        self.clock = clock
        cards = []
        newGame(seed: seed)
    }

    /// Builds a board in a given state. The board is locked exactly when two
    /// cards are face up.
    init(cards: [Card], moveCount: Int = 0, clock: TurnClock = SystemTurnClock()) {
        self.clock = clock
        self.cards = cards
        self.moveCount = moveCount
    }

    /// Deals a fresh board and clears the move count.
    func newGame(seed: UInt64 = .random(in: 0...UInt64.max)) {
        var generator = SeededGenerator(seed: seed)
        let pairs = CardSymbol.allCases.flatMap { [$0, $0] }
        cards = pairs.shuffled(using: &generator).map {
            Card(symbol: $0, state: .faceDown)
        }
        moveCount = 0
    }

    /// Turns a face-down card face up, when the board allows it.
    func tap(_ index: Int) {
        guard !isLocked, cards[index].state == .faceDown else { return }
        cards[index].state = .faceUp
    }

    /// Judges the two face-up cards and ends the turn.
    func resolveTurn() {
        let open = faceUpIndices
        guard open.count == 2 else { return }

        let (first, second) = (open[0], open[1])
        let matched = cards[first].symbol == cards[second].symbol
        let resolved: CardState = matched ? .matched : .faceDown
        cards[first].state = resolved
        cards[second].state = resolved
        moveCount += 1
    }
}
