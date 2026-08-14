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

    /// Called the moment the last pair turns matched.
    @ObservationIgnored var onWin: (() -> Void)?

    /// How long a finished pair stays face up before it is judged.
    static let matchPauseMilliseconds = Motion.matchResolveMilliseconds(reduceMotion: false)

    /// How long a mismatched pair stays on show before it turns back down.
    /// The two waits together are the mismatch timing the player feels.
    static let mismatchWindowMilliseconds =
        Motion.mismatchResolveMilliseconds(reduceMotion: false) - matchPauseMilliseconds

    /// Where the current turn has got to.
    private enum Phase {
        /// Nothing is waiting: fewer than two cards are face up.
        case idle
        /// Two cards are face up and the 300 ms pause is running.
        case judging
        /// The pair did not match and is on show for 900 ms.
        case showingMismatch(first: Int, second: Int)
    }

    @ObservationIgnored private var phase: Phase = .idle

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
        clock.cancelPending()
        phase = .idle
    }

    /// Turns a face-down card face up, when the board allows it.
    ///
    /// A tap on a face-down card while a mismatch is on show cuts that window
    /// short: the pair turns down at once and the tap lands on the fresh board.
    func tap(_ index: Int) {
        if case .showingMismatch(let first, let second) = phase {
            guard cards[index].state == .faceDown else { return }
            clock.cancelPending()
            endMismatch(first, second)
        }

        guard !isLocked, cards[index].state == .faceDown else { return }
        cards[index].state = .faceUp

        if faceUpIndices.count == 2 {
            phase = .judging
            clock.schedule(after: Self.matchPauseMilliseconds) { [weak self] in
                self?.judgePair()
            }
        }
    }

    /// Judges the two face-up cards and ends the turn.
    func resolveTurn() {
        let open = faceUpIndices
        guard open.count == 2 else { return }

        clock.cancelPending()
        phase = .idle

        let (first, second) = (open[0], open[1])
        let matched = cards[first].symbol == cards[second].symbol
        let resolved: CardState = matched ? .matched : .faceDown
        cards[first].state = resolved
        cards[second].state = resolved
        moveCount += 1
        announceWin()
    }

    /// The 300 ms pause is up: a matched pair is done, a mismatched one goes
    /// on show for its 900 ms window.
    private func judgePair() {
        let open = faceUpIndices
        guard case .judging = phase, open.count == 2 else {
            phase = .idle
            return
        }

        let (first, second) = (open[0], open[1])
        guard cards[first].symbol == cards[second].symbol else {
            phase = .showingMismatch(first: first, second: second)
            clock.schedule(after: Self.mismatchWindowMilliseconds) { [weak self] in
                self?.endMismatch(first, second)
            }
            return
        }

        cards[first].state = .matched
        cards[second].state = .matched
        moveCount += 1
        phase = .idle
        announceWin()
    }

    private func announceWin() {
        guard isWon else { return }
        onWin?()
    }

    /// Turns a mismatched pair back down and closes the turn.
    private func endMismatch(_ first: Int, _ second: Int) {
        cards[first].state = .faceDown
        cards[second].state = .faceDown
        moveCount += 1
        phase = .idle
    }
}
