import XCTest
@testable import MemoryMatch

/// PP-3 — turn sequencing: the 300 ms match pause, the 900 ms mismatch
/// window, cancelling that window with a tap-ahead, and starting over.
///
/// Time is driven by hand through `TestClock`, so every deadline is exact and
/// no test waits on a real timer. One test per acceptance criterion.
final class TurnSequencingTests: XCTestCase {

    // MARK: - A clock the test drives

    /// Holds one pending piece of work and runs it only when the test moves
    /// time past its due moment.
    final class TestClock: TurnClock {
        /// Milliseconds since the clock started.
        private(set) var now = 0

        private var pending: (dueAt: Int, work: () -> Void)?

        /// True while the model is waiting on a delay it asked for.
        var hasPendingWork: Bool { pending != nil }

        func schedule(after milliseconds: Int, _ work: @escaping () -> Void) {
            precondition(milliseconds >= 0, "a delay cannot run backwards")
            pending = (now + milliseconds, work)
        }

        func cancelPending() {
            pending = nil
        }

        /// Moves time forward, running whatever falls due on the way. Work
        /// that schedules more work is run too, in due order.
        func advance(by milliseconds: Int) {
            let target = now + milliseconds
            while let next = pending, next.dueAt <= target {
                pending = nil
                now = next.dueAt
                next.work()
            }
            now = target
        }
    }

    // MARK: - Fixtures

    /// The two timings this ticket is about, written out here rather than
    /// read from the app, so the test states its own expectation.
    private static let matchPauseMilliseconds = 300
    private static let mismatchWindowMilliseconds = 900

    /// A fixed 16-card layout: the eight symbols, each exactly twice.
    /// Matching pairs are (0, 15), (1, 14), (2, 13) and so on; positions 0
    /// and 1 hold different symbols.
    private static let referenceSymbols: [CardSymbol] = [
        .star, .heart, .bolt, .leaf,
        .moon, .umbrella, .anchor, .bell,
        .bell, .anchor, .umbrella, .moon,
        .leaf, .bolt, .heart, .star,
    ]

    /// Positions 0 and 15 both hold `star`.
    private static let matchingPair = (first: 0, second: 15)

    /// Position 0 holds `star`, position 1 holds `heart`.
    private static let mismatchedPair = (first: 0, second: 1)

    /// A board from the fixed layout, all 16 face down, driven by `clock`.
    private func freshBoard(_ clock: TestClock) -> GameModel {
        let cards = Self.referenceSymbols.map {
            Card(symbol: $0, state: .faceDown)
        }
        return GameModel(cards: cards, moveCount: 0, clock: clock)
    }

    private func faceUpCount(_ model: GameModel) -> Int {
        model.cards.filter { $0.state == .faceUp }.count
    }

    private func states(_ model: GameModel) -> [CardState] {
        model.cards.map { $0.state }
    }

    // MARK: - Criterion 1

    /// A matched pair turns from face up to matched exactly 300 ms after the
    /// second tap — not at 299 ms, not earlier.
    func testMatchedPairBecomesMatchedExactlyThreeHundredMillisecondsAfterSecondTap() {
        let clock = TestClock()
        let model = freshBoard(clock)
        let (first, second) = Self.matchingPair

        model.tap(first)
        model.tap(second)

        XCTAssertEqual(model.cards[first].state, .faceUp, "the pair is face up")
        XCTAssertEqual(model.cards[second].state, .faceUp, "the pair is face up")
        XCTAssertTrue(model.isLocked, "two face-up cards lock the board")

        // Every 100 ms up to one millisecond short of 300 ms: still face up,
        // still locked.
        while clock.now < 299 {
            clock.advance(by: min(100, 299 - clock.now))
            XCTAssertEqual(
                model.cards[first].state,
                .faceUp,
                "at \(clock.now) ms the first card is still face up"
            )
            XCTAssertEqual(
                model.cards[second].state,
                .faceUp,
                "at \(clock.now) ms the second card is still face up"
            )
            XCTAssertTrue(
                model.isLocked,
                "at \(clock.now) ms the board is still locked"
            )
        }

        clock.advance(by: 299 - clock.now)
        XCTAssertEqual(clock.now, 299, "the clock sits one millisecond short")
        XCTAssertEqual(
            model.cards[first].state,
            .faceUp,
            "at 299 ms the first card has not been matched yet"
        )
        XCTAssertEqual(
            model.cards[second].state,
            .faceUp,
            "at 299 ms the second card has not been matched yet"
        )

        clock.advance(by: 1)
        XCTAssertEqual(clock.now, Self.matchPauseMilliseconds, "the clock is at 300 ms")
        XCTAssertEqual(
            model.cards[first].state,
            .matched,
            "at 300 ms the first card is matched"
        )
        XCTAssertEqual(
            model.cards[second].state,
            .matched,
            "at 300 ms the second card is matched"
        )
        XCTAssertFalse(model.isLocked, "the board unlocks once the pair is matched")

        for position in 0..<16 where position != first && position != second {
            XCTAssertEqual(
                model.cards[position].state,
                .faceDown,
                "position \(position) was left alone"
            )
        }
    }

    // MARK: - Criterion 2

    /// A mismatched pair stays face up for 300 ms plus 900 ms, then both go
    /// back face down and the board unlocks at that same instant.
    func testMismatchedPairReturnsFaceDownAfterThreeHundredPlusNineHundredMilliseconds() {
        let clock = TestClock()
        let model = freshBoard(clock)
        let (first, second) = Self.mismatchedPair
        let total = Self.matchPauseMilliseconds + Self.mismatchWindowMilliseconds

        model.tap(first)
        model.tap(second)

        // Every 100 ms up to one millisecond short of 1200 ms: face up and
        // locked the whole way.
        while clock.now < total - 1 {
            clock.advance(by: min(100, total - 1 - clock.now))
            XCTAssertEqual(
                model.cards[first].state,
                .faceUp,
                "at \(clock.now) ms the first card is still face up"
            )
            XCTAssertEqual(
                model.cards[second].state,
                .faceUp,
                "at \(clock.now) ms the second card is still face up"
            )
            XCTAssertTrue(
                model.isLocked,
                "at \(clock.now) ms the board is still locked"
            )
        }
        XCTAssertEqual(clock.now, 1199, "the clock sits one millisecond short of 1200")

        clock.advance(by: 1)
        XCTAssertEqual(clock.now, 1200, "the clock is at 300 + 900 ms")
        XCTAssertEqual(
            model.cards[first].state,
            .faceDown,
            "at 1200 ms the first card is face down again"
        )
        XCTAssertEqual(
            model.cards[second].state,
            .faceDown,
            "at 1200 ms the second card is face down again"
        )
        XCTAssertFalse(
            model.isLocked,
            "the board unlocks at the instant the pair turns back down"
        )
        XCTAssertEqual(
            states(model),
            [CardState](repeating: .faceDown, count: 16),
            "the whole board is face down again"
        )
        XCTAssertEqual(model.moveCount, 1, "one finished turn is one move")
    }

    // MARK: - Criterion 3

    /// A tap on a face-down card during the 900 ms mismatch window turns the
    /// pair down at once, turns the tapped card up, adds exactly one move,
    /// and leaves the board unlocked.
    func testTapAheadDuringMismatchWindowResolvesThePairAndTurnsTheNewCardUp() {
        // Moments inside the window, measured from the second tap: its start,
        // the middle, and the last millisecond before it would have ended.
        for moment in [300, 301, 750, 1199] {
            let clock = TestClock()
            let model = freshBoard(clock)
            let (first, second) = Self.mismatchedPair
            let tapAhead = 5

            model.tap(first)
            model.tap(second)
            clock.advance(by: moment)

            XCTAssertEqual(
                model.cards[first].state,
                .faceUp,
                "at \(moment) ms the mismatch is still on show"
            )

            let movesBefore = model.moveCount

            model.tap(tapAhead)

            XCTAssertEqual(
                model.cards[first].state,
                .faceDown,
                "at \(moment) ms the tap-ahead turns the first card down at once"
            )
            XCTAssertEqual(
                model.cards[second].state,
                .faceDown,
                "at \(moment) ms the tap-ahead turns the second card down at once"
            )
            XCTAssertEqual(
                model.cards[tapAhead].state,
                .faceUp,
                "at \(moment) ms the tapped card is face up"
            )
            XCTAssertEqual(
                faceUpCount(model),
                1,
                "at \(moment) ms only the newly tapped card is face up"
            )
            XCTAssertEqual(
                model.moveCount,
                movesBefore + 1,
                "at \(moment) ms the cut-short turn counts exactly one move"
            )
            XCTAssertFalse(
                model.isLocked,
                "at \(moment) ms the board is left unlocked"
            )
        }
    }

    // MARK: - Criterion 4

    /// The cancelled 900 ms window never fires: time can run well past it and
    /// the card turned up by the tap-ahead stays up.
    func testCancelledWindowDoesNotTurnTheNewCardDown() {
        let clock = TestClock()
        let model = freshBoard(clock)
        let (first, second) = Self.mismatchedPair
        let tapAhead = 5

        model.tap(first)
        model.tap(second)
        clock.advance(by: 400)
        model.tap(tapAhead)

        let movesAfterTapAhead = model.moveCount

        // Past the moment the cancelled window would have ended (1200 ms),
        // and then far past it.
        for step in [500, 300, 1000, 5000] {
            clock.advance(by: step)
            XCTAssertEqual(
                model.cards[tapAhead].state,
                .faceUp,
                "at \(clock.now) ms the newly turned card is still face up"
            )
            XCTAssertEqual(
                faceUpCount(model),
                1,
                "at \(clock.now) ms exactly one card is face up"
            )
            XCTAssertEqual(
                model.moveCount,
                movesAfterTapAhead,
                "at \(clock.now) ms the cancelled window adds no move"
            )
            XCTAssertFalse(
                model.isLocked,
                "at \(clock.now) ms the board is still unlocked"
            )
        }
    }

    // MARK: - Criterion 5

    /// A tap during the 300 ms match pause changes nothing: no card state
    /// moves and the move count stays put.
    func testTapDuringMatchPauseChangesNothing() {
        for moment in [0, 1, 150, 299] {
            for position in 0..<16 {
                let clock = TestClock()
                let model = freshBoard(clock)
                let (first, second) = Self.matchingPair

                model.tap(first)
                model.tap(second)
                clock.advance(by: moment)

                let before = states(model)
                let movesBefore = model.moveCount
                XCTAssertEqual(
                    before[first],
                    .faceUp,
                    "at \(moment) ms the match is still on show"
                )

                model.tap(position)

                XCTAssertEqual(
                    states(model),
                    before,
                    "at \(moment) ms a tap on \(position) changes no card"
                )
                XCTAssertEqual(
                    model.moveCount,
                    movesBefore,
                    "at \(moment) ms a tap on \(position) changes no move count"
                )
            }
        }
    }

    // MARK: - Criterion 6

    /// Across 100 random taps, mixed with the clock running forward by random
    /// amounts, three cards are never face up at once.
    func testHundredRandomTapsNeverLeaveThreeCardsFaceUp() {
        // How far the clock jumps between taps: some jumps land inside the
        // 300 ms pause, some inside the 900 ms window, some past both.
        let jumps = [0, 50, 200, 299, 300, 500, 900, 1200, 3000]

        for seed in UInt64(1)...25 {
            var generator = SeededGenerator(seed: seed)
            let clock = TestClock()
            let model = freshBoard(clock)
            var everSawTwoFaceUp = false

            for tapNumber in 1...100 {
                model.tap(Int.random(in: 0..<16, using: &generator))
                if faceUpCount(model) == 2 { everSawTwoFaceUp = true }
                XCTAssertLessThan(
                    faceUpCount(model),
                    3,
                    "seed \(seed), tap \(tapNumber): fewer than 3 cards face up"
                )

                clock.advance(by: jumps.randomElement(using: &generator) ?? 0)
                if faceUpCount(model) == 2 { everSawTwoFaceUp = true }
                XCTAssertLessThan(
                    faceUpCount(model),
                    3,
                    "seed \(seed), tap \(tapNumber): fewer than 3 cards face up after time moves on"
                )
            }

            // The run has to have done something, or the check above passes
            // for the wrong reason.
            XCTAssertTrue(
                everSawTwoFaceUp,
                "seed \(seed): the run really did open pairs"
            )
            XCTAssertGreaterThan(
                model.moveCount,
                0,
                "seed \(seed): the run really did finish turns"
            )
        }
    }

    // MARK: - Criterion 7

    /// Starting a new game while a mismatch window is pending cancels it: no
    /// delayed work is left, and time running on leaves the fresh board with
    /// all 16 cards face down.
    func testNewGameCancelsAPendingMismatchWindow() {
        let clock = TestClock()
        let model = freshBoard(clock)
        let (first, second) = Self.mismatchedPair

        model.tap(first)
        model.tap(second)
        clock.advance(by: 400)

        XCTAssertEqual(
            model.cards[first].state,
            .faceUp,
            "the mismatch window is open"
        )
        XCTAssertTrue(
            clock.hasPendingWork,
            "the model is waiting on the flip-down it scheduled"
        )

        model.newGame(seed: 42)

        XCTAssertFalse(
            clock.hasPendingWork,
            "a new game leaves no delayed work behind"
        )
        XCTAssertEqual(
            states(model),
            [CardState](repeating: .faceDown, count: 16),
            "the fresh deal is all face down"
        )

        clock.advance(by: 5000)

        XCTAssertEqual(
            states(model),
            [CardState](repeating: .faceDown, count: 16),
            "time running on leaves all 16 cards face down"
        )
        XCTAssertEqual(model.moveCount, 0, "the fresh board has no moves on it")
        XCTAssertFalse(model.isLocked, "the fresh board is unlocked")
    }
}
