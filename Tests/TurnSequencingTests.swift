import XCTest
@testable import MemoryMatch

/// PP-3 — turn sequencing with cancellable delays and tap-ahead.
///
/// One test per acceptance criterion. Time never passes on its own here: a
/// fake clock holds the scheduled work, and each test says exactly how far
/// the clock moves. Every expected value is written out by hand.
final class TurnSequencingTests: XCTestCase {

    // MARK: - Criterion 1
    //
    // A matched pair moves from faceUp to matched exactly 300 ms after the
    // second tap, and not before 300 ms.

    func testMatchedPairBecomesMatchedExactlyAfterThreeHundredMilliseconds() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try pairWithSameSymbol(in: model.cards)

        model.tap(first)
        model.tap(second)

        XCTAssertEqual(model.cards[first].state, .faceUp, "first card is face up on tap")
        XCTAssertEqual(model.cards[second].state, .faceUp, "second card is face up on tap")

        // One millisecond short of the deadline: still face up, not matched.
        clock.advance(by: 0.299)
        XCTAssertEqual(model.cards[first].state, .faceUp, "still face up at 299 ms")
        XCTAssertEqual(model.cards[second].state, .faceUp, "still face up at 299 ms")

        // Landing exactly on 300 ms settles the pair.
        clock.advance(by: 0.001)
        XCTAssertEqual(model.cards[first].state, .matched, "matched at 300 ms")
        XCTAssertEqual(model.cards[second].state, .matched, "matched at 300 ms")
        XCTAssertFalse(model.isLocked, "the board unlocks once the pair is matched")
    }

    // MARK: - Criterion 2
    //
    // A mismatched pair stays faceUp for 300 ms plus 900 ms, then both return
    // to faceDown, and the board unlocks at that instant.

    func testMismatchedPairReturnsFaceDownAfterTwelveHundredMilliseconds() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try pairWithDifferentSymbols(in: model.cards)

        model.tap(first)
        model.tap(second)

        // 300 ms + 900 ms = 1200 ms. Face up for every instant before that.
        for elapsed in [0.299, 0.300, 0.301, 0.899, 1.199] as [TimeInterval] {
            clock.advance(to: elapsed)
            XCTAssertEqual(
                model.cards[first].state, .faceUp,
                "first card still face up at \(elapsed) s"
            )
            XCTAssertEqual(
                model.cards[second].state, .faceUp,
                "second card still face up at \(elapsed) s"
            )
            XCTAssertTrue(model.isLocked, "the board stays locked at \(elapsed) s")
        }

        clock.advance(to: 1.200)
        XCTAssertEqual(model.cards[first].state, .faceDown, "face down at 1200 ms")
        XCTAssertEqual(model.cards[second].state, .faceDown, "face down at 1200 ms")
        XCTAssertFalse(model.isLocked, "the board unlocks at that same instant")
    }

    // MARK: - Criterion 3
    //
    // A tap on a faceDown card during the 900 ms mismatch window immediately
    // turns the mismatched pair face down, turns the tapped card face up,
    // adds exactly 1 to the move count, and leaves the board unlocked.

    func testTapDuringMismatchWindowResolvesItImmediately() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try pairWithDifferentSymbols(in: model.cards)

        model.tap(first)
        model.tap(second)

        // Sit inside the 900 ms window: past 300 ms, short of 1200 ms.
        clock.advance(to: 0.600)
        XCTAssertEqual(model.cards[first].state, .faceUp, "the window is open")
        XCTAssertEqual(model.cards[second].state, .faceUp, "the window is open")

        let movesBefore = model.moveCount
        let third = try anyFaceDownIndex(in: model.cards, excluding: [first, second])

        model.tap(third)

        XCTAssertEqual(model.cards[first].state, .faceDown, "the mismatched pair goes face down at once")
        XCTAssertEqual(model.cards[second].state, .faceDown, "the mismatched pair goes face down at once")
        XCTAssertEqual(model.cards[third].state, .faceUp, "the tapped card turns face up")
        XCTAssertEqual(model.moveCount, movesBefore + 1, "exactly one move is added")
        XCTAssertFalse(model.isLocked, "the board is left unlocked")
    }

    // MARK: - Criterion 4
    //
    // After a tap-ahead, advancing the clock past the cancelled 900 ms window
    // does not flip the new faceUp card down.

    func testCancelledMismatchWindowDoesNotFlipTheNewCardDown() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try pairWithDifferentSymbols(in: model.cards)

        model.tap(first)
        model.tap(second)
        clock.advance(to: 0.600)

        let third = try anyFaceDownIndex(in: model.cards, excluding: [first, second])
        model.tap(third)
        XCTAssertEqual(model.cards[third].state, .faceUp, "the tap-ahead card is face up")

        // 1.200 s was when the cancelled window would have fired. Walk well
        // past it; the card the player just turned over must stay up.
        for elapsed in [1.199, 1.200, 1.201, 2.000, 5.000] as [TimeInterval] {
            clock.advance(to: elapsed)
            XCTAssertEqual(
                model.cards[third].state, .faceUp,
                "the new card is still face up at \(elapsed) s"
            )
        }
        XCTAssertFalse(model.isLocked, "one card face up leaves the board unlocked")
    }

    // MARK: - Criterion 5
    //
    // A tap during the 300 ms match resolution window leaves all card states
    // and the move count unchanged.

    func testTapDuringMatchResolutionWindowChangesNothing() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try pairWithSameSymbol(in: model.cards)

        model.tap(first)
        model.tap(second)
        clock.advance(to: 0.100)

        let statesBefore = model.cards.map(\.state)
        let movesBefore = model.moveCount
        let other = try anyFaceDownIndex(in: model.cards, excluding: [first, second])

        model.tap(other)

        XCTAssertEqual(model.cards.map(\.state), statesBefore, "no card state changes")
        XCTAssertEqual(model.moveCount, movesBefore, "the move count does not change")

        // Taps at other points inside the window are ignored just as firmly.
        clock.advance(to: 0.299)
        model.tap(other)
        XCTAssertEqual(model.cards.map(\.state), statesBefore, "no card state changes at 299 ms")
        XCTAssertEqual(model.moveCount, movesBefore, "the move count does not change at 299 ms")
    }

    // MARK: - Criterion 6
    //
    // At no point in a 100-tap randomised tap sequence are three or more
    // cards face up at once.

    func testRandomisedTapSequenceNeverLeavesThreeCardsFaceUp() {
        // Several runs, each with its own repeatable random stream, so the
        // sequence is different every run but the same on every rerun.
        for seed in [1, 2, 3, 4, 5] as [UInt64] {
            let clock = TestClock()
            let model = GameModel(seed: seed, clock: clock)
            var random = TestRandom(seed: seed &* 7919 &+ 13)

            assertAtMostTwoFaceUp(model, step: 0, seed: seed)

            for step in 1...100 {
                model.tap(Int(random.next(upperBound: 16)))
                assertAtMostTwoFaceUp(model, step: step, seed: seed)

                // Let some amount of time pass between taps: sometimes none,
                // sometimes enough to fire a pending delay.
                let waits: [TimeInterval] = [0, 0.050, 0.299, 0.300, 0.700, 1.200, 2.000]
                clock.advance(by: waits[Int(random.next(upperBound: UInt64(waits.count)))])
                assertAtMostTwoFaceUp(model, step: step, seed: seed)
            }

            // A board that never moved would satisfy the invariant for the
            // wrong reason, so check the sequence actually played.
            XCTAssertGreaterThan(
                model.moveCount, 0,
                "seed \(seed): 100 taps completed at least one turn"
            )
        }
    }

    // MARK: - Criterion 7
    //
    // Starting a new game while a mismatch window is pending cancels it:
    // advancing the clock leaves the freshly dealt board all face down.

    func testNewGameCancelsAPendingMismatchWindow() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try pairWithDifferentSymbols(in: model.cards)

        model.tap(first)
        model.tap(second)
        clock.advance(to: 0.500)
        XCTAssertEqual(model.cards[first].state, .faceUp, "a mismatch window is pending")

        model.newGame(seed: 99)

        XCTAssertEqual(model.cards.count, 16, "a fresh board has 16 cards")
        XCTAssertTrue(
            model.cards.allSatisfy { $0.state == .faceDown },
            "the fresh deal starts all face down"
        )

        // The cancelled window would have fired 700 ms from here. Nothing it
        // was going to do may touch the new board.
        clock.advance(by: 5.0)
        XCTAssertTrue(
            model.cards.allSatisfy { $0.state == .faceDown },
            "all 16 cards are still face down after the clock runs on"
        )
        XCTAssertFalse(model.isLocked, "the fresh board is unlocked")
    }

    // MARK: - Helpers

    private func assertAtMostTwoFaceUp(
        _ model: GameModel,
        step: Int,
        seed: UInt64,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let faceUp = model.cards.filter { $0.state == .faceUp }.count
        XCTAssertLessThanOrEqual(
            faceUp, 2,
            "seed \(seed), step \(step): \(faceUp) cards face up at once",
            file: file, line: line
        )
    }

    /// Two positions holding the same symbol.
    private func pairWithSameSymbol(in cards: [Card]) throws -> (Int, Int) {
        for i in cards.indices {
            for j in cards.indices where j > i && cards[i].symbol == cards[j].symbol {
                return (i, j)
            }
        }
        throw TestSetupError.noSuchPair
    }

    /// Two positions holding different symbols.
    private func pairWithDifferentSymbols(in cards: [Card]) throws -> (Int, Int) {
        for i in cards.indices {
            for j in cards.indices where j > i && cards[i].symbol != cards[j].symbol {
                return (i, j)
            }
        }
        throw TestSetupError.noSuchPair
    }

    /// Any face-down position other than the ones named.
    private func anyFaceDownIndex(in cards: [Card], excluding excluded: [Int]) throws -> Int {
        for index in cards.indices
        where !excluded.contains(index) && cards[index].state == .faceDown {
            return index
        }
        throw TestSetupError.noSuchPair
    }

    private enum TestSetupError: Error {
        case noSuchPair
    }
}

// MARK: - Fixtures

/// A clock that only moves when a test tells it to. Work handed to
/// `schedule` sits in a queue until the clock passes its due moment.
final class TestClock: GameClock {
    private struct Scheduled {
        let id: Int
        let dueAt: TimeInterval
        let work: () -> Void
    }

    /// Where the clock stands now, in seconds since the test began.
    private(set) var now: TimeInterval = 0
    private var pending: [Scheduled] = []
    private var nextID = 0

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        nextID += 1
        pending.append(Scheduled(id: nextID, dueAt: now + delay, work: work))
    }

    /// Moves the clock forward, running everything that comes due on the way
    /// in the order it comes due.
    func advance(by interval: TimeInterval) {
        let target = now + interval
        // A tolerance, because 0.3 + 0.9 in binary floating point is not
        // exactly 1.2. A microsecond is far finer than any delay here.
        let tolerance: TimeInterval = 1e-6

        while let next = pending
            .filter({ $0.dueAt <= target + tolerance })
            .min(by: { ($0.dueAt, $0.id) < ($1.dueAt, $1.id) }) {
            pending.removeAll { $0.id == next.id }
            now = max(now, next.dueAt)
            next.work()
        }
        now = target
    }

    /// Moves the clock forward to an absolute moment.
    func advance(to moment: TimeInterval) {
        advance(by: max(0, moment - now))
    }
}

/// A small repeatable random stream, so a failing sequence can be replayed.
/// SplitMix64.
struct TestRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(upperBound: UInt64) -> UInt64 {
        next() % upperBound
    }
}
