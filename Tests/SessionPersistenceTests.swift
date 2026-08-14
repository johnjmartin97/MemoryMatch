import XCTest
@testable import MemoryMatch

/// PP-4 — elapsed time, save and restore, and the restart control.
///
/// One test per acceptance criterion. Time never passes on its own: a clock
/// the test moves by hand is the only source of "now", so every expected
/// number below is one the test itself put there.
final class SessionPersistenceTests: XCTestCase {

    // MARK: - Criterion 1
    //
    // Elapsed time is 0 immediately after a deal and starts advancing only on
    // the first accepted card tap.

    func testElapsedTimeStartsAtZeroAndOnlyRunsAfterTheFirstAcceptedTap() {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        XCTAssertEqual(model.elapsed, 0, accuracy: 1e-9, "a fresh deal starts at zero")

        // The player is looking at the board, not touching it. The clock runs;
        // the game does not.
        clock.advance(by: 5.0)
        XCTAssertEqual(
            model.elapsed, 0, accuracy: 1e-9,
            "five seconds of staring at an untouched board still reads zero"
        )

        // A tap that is not accepted — no such position — starts nothing.
        model.tap(99)
        clock.advance(by: 3.0)
        XCTAssertEqual(
            model.elapsed, 0, accuracy: 1e-9,
            "a rejected tap does not start the timer"
        )

        // The first real tap starts it.
        model.tap(0)
        clock.advance(by: 2.0)
        XCTAssertEqual(
            model.elapsed, 2.0, accuracy: 1e-9,
            "two seconds after the first accepted tap reads two seconds"
        )

        clock.advance(by: 1.5)
        XCTAssertEqual(model.elapsed, 3.5, accuracy: 1e-9, "and it keeps running")
    }

    // MARK: - Criterion 2
    //
    // Going to the background pauses elapsed time; coming back resumes it,
    // and the total leaves out the time spent in the background.

    func testBackgroundingPausesElapsedTimeAndForegroundingResumesIt() {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        model.tap(0)
        clock.advance(by: 2.0)
        XCTAssertEqual(model.elapsed, 2.0, accuracy: 1e-9, "two seconds of play")

        model.enterBackground()
        clock.advance(by: 10.0)
        XCTAssertEqual(
            model.elapsed, 2.0, accuracy: 1e-9,
            "ten seconds in the background add nothing"
        )

        model.enterForeground()
        clock.advance(by: 3.0)

        // 2 s before + 3 s after. The 10 s away is not part of it.
        XCTAssertEqual(
            model.elapsed, 5.0, accuracy: 1e-9,
            "the total is the played time only"
        )
    }

    // MARK: - Criterion 3
    //
    // Elapsed time stops advancing once all 16 cards are matched.

    func testElapsedTimeStopsOnceEveryCardIsMatched() {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        playEveryPair(model, clock: clock)

        XCTAssertEqual(
            model.cards.filter { $0.state == .matched }.count, 16,
            "the board is finished"
        )
        let atTheWin = model.elapsed
        XCTAssertGreaterThan(atTheWin, 0, "the game took some time to play")

        clock.advance(by: 10.0)
        XCTAssertEqual(
            model.elapsed, atTheWin, accuracy: 1e-9,
            "the clock stops when the last pair is matched"
        )
    }

    // MARK: - Criterion 4
    //
    // Encoding then decoding a mid-game state returns the same symbol layout,
    // the same matched positions, the same move count, and the same
    // accumulated elapsed time.

    func testEncodingAndDecodingAMidGameStateKeepsLayoutMatchesMovesAndTime() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 23, clock: clock)

        playPairs(3, in: model, clock: clock)
        // Leave one card face up too, so the mid-game state is a real one.
        let faceUpIndex = try firstIndex(ofState: .faceDown, in: model)
        model.tap(faceUpIndex)
        clock.advance(by: 1.25)

        let symbolsBefore = model.cards.map(\.symbol)
        let matchedBefore = matchedPositions(of: model)
        let movesBefore = model.moveCount
        let elapsedBefore = model.elapsed

        XCTAssertEqual(matchedBefore.count, 6, "three pairs are matched")
        XCTAssertGreaterThan(movesBefore, 0, "moves were made")
        XCTAssertGreaterThan(elapsedBefore, 0, "time was accumulated")

        let data = try JSONEncoder().encode(model.snapshot())
        let decoded = try JSONDecoder().decode(SavedGame.self, from: data)
        let restored = GameModel(restoring: decoded, seed: 999, clock: ManualClock())

        XCTAssertEqual(
            restored.cards.map(\.symbol), symbolsBefore,
            "every position holds the symbol it held before"
        )
        XCTAssertEqual(
            matchedPositions(of: restored), matchedBefore,
            "the same positions are matched"
        )
        XCTAssertEqual(restored.moveCount, movesBefore, "the move count survives")
        XCTAssertEqual(
            restored.elapsed, elapsedBefore, accuracy: 1e-9,
            "the accumulated time survives"
        )
    }

    // MARK: - Criterion 5
    //
    // Restoring a saved state that held cards face up yields those cards face
    // down, with no card face up.

    func testRestoringASaveWithFaceUpCardsTurnsThemFaceDown() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 31, clock: clock)

        // One matched pair, then a single card left face up mid-turn.
        playPairs(1, in: model, clock: clock)
        let faceUpIndex = try firstIndex(ofState: .faceDown, in: model)
        model.tap(faceUpIndex)
        XCTAssertEqual(
            model.cards.filter { $0.state == .faceUp }.count, 1,
            "the save is taken with a card face up"
        )

        let saved = model.snapshot()
        let restored = GameModel(restoring: saved, seed: 999, clock: ManualClock())

        XCTAssertEqual(restored.cards.count, 16, "the restored board has 16 cards")
        XCTAssertEqual(
            restored.cards.filter { $0.state == .faceUp }.count, 0,
            "no card comes back face up"
        )
        XCTAssertEqual(
            restored.cards[faceUpIndex].state, .faceDown,
            "the card that was face up comes back face down"
        )
        XCTAssertEqual(
            matchedPositions(of: restored), matchedPositions(of: model),
            "matched cards are untouched by that rule"
        )
    }

    // MARK: - Criterion 6
    //
    // Restoring a saved state where all 16 cards are matched instead deals a
    // fresh board: all 16 face down, move count 0.

    func testRestoringAFinishedGameDealsAFreshBoardInstead() {
        let clock = ManualClock()
        let model = GameModel(seed: 41, clock: clock)

        playEveryPair(model, clock: clock)
        let saved = model.snapshot()

        let restored = GameModel(restoring: saved, seed: 77, clock: ManualClock())

        XCTAssertEqual(restored.cards.count, 16, "a full board")
        XCTAssertTrue(
            restored.cards.allSatisfy { $0.state == .faceDown },
            "a finished save is not resumed — every card is face down"
        )
        XCTAssertEqual(restored.moveCount, 0, "the move count starts over")
        assertIsAWellFormedDeal(restored.cards)
    }

    // MARK: - Criterion 7
    //
    // Launching with no saved state deals a fresh board rather than throwing
    // or showing an empty one.

    func testLaunchingWithNoSavedStateDealsAFreshBoard() {
        let model = GameModel(restoring: nil, seed: 5, clock: ManualClock())

        XCTAssertEqual(model.cards.count, 16, "16 cards are on the table")
        XCTAssertTrue(
            model.cards.allSatisfy { $0.state == .faceDown },
            "all face down"
        )
        XCTAssertEqual(model.moveCount, 0, "no moves yet")
        XCTAssertEqual(model.elapsed, 0, accuracy: 1e-9, "no time yet")
        assertIsAWellFormedDeal(model.cards)
    }

    // MARK: - Criterion 8
    //
    // Restart with no matched pairs deals a new board straight away and sets
    // the move count to 0, asking nothing.

    func testRestartWithNoMatchedPairsDealsImmediatelyWithoutAsking() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        // Turn over a mismatched pair and let it settle back: moves were made,
        // nothing is matched.
        let (a, b) = try twoPositionsWithDifferentSymbols(in: model)
        model.tap(a)
        model.tap(b)
        settle(clock)
        XCTAssertEqual(matchedPositions(of: model).count, 0, "nothing is matched")
        XCTAssertGreaterThan(model.moveCount, 0, "but moves were made")

        model.requestRestart(seed: 88)

        XCTAssertFalse(model.isConfirmingRestart, "nothing is asked")
        XCTAssertEqual(model.moveCount, 0, "the move count is back to zero")
        XCTAssertEqual(model.cards.count, 16, "a new board is dealt at once")
        XCTAssertTrue(
            model.cards.allSatisfy { $0.state == .faceDown },
            "every card on the new board is face down"
        )
        assertIsAWellFormedDeal(model.cards)
    }

    // MARK: - Criterion 9
    //
    // Restart with at least one matched pair asks first, and the board does
    // not change until the answer is yes.

    func testRestartWithAMatchedPairAsksFirstAndWaitsForTheAnswer() {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        playPairs(1, in: model, clock: clock)
        XCTAssertEqual(matchedPositions(of: model).count, 2, "one pair is matched")

        let symbolsBefore = model.cards.map(\.symbol)
        let statesBefore = model.cards.map(\.state)
        let movesBefore = model.moveCount

        model.requestRestart(seed: 88)

        XCTAssertTrue(model.isConfirmingRestart, "the player is asked to confirm")
        XCTAssertEqual(model.cards.map(\.symbol), symbolsBefore, "the layout is untouched")
        XCTAssertEqual(model.cards.map(\.state), statesBefore, "no card moves")
        XCTAssertEqual(model.moveCount, movesBefore, "the move count is untouched")

        model.confirmRestart()

        XCTAssertFalse(model.isConfirmingRestart, "the question is answered")
        XCTAssertEqual(model.cards.count, 16, "a new board is dealt")
        XCTAssertTrue(
            model.cards.allSatisfy { $0.state == .faceDown },
            "every card on the new board is face down"
        )
        XCTAssertEqual(model.moveCount, 0, "the move count starts over")
        assertIsAWellFormedDeal(model.cards)
    }

    // MARK: - Helpers

    /// Moves the clock far enough past any pending turn work that the board
    /// has settled, without leaning on the exact delay lengths.
    private func settle(_ clock: ManualClock) {
        clock.advance(by: 2.0)
    }

    /// Plays `count` pairs to matched, spending time on the way.
    private func playPairs(_ count: Int, in model: GameModel, clock: ManualClock) {
        var played = 0
        for symbol in CardSymbol.allCases where played < count {
            let positions = model.cards.indices.filter { model.cards[$0].symbol == symbol }
            guard positions.count == 2 else { continue }
            model.tap(positions[0])
            clock.advance(by: 0.5)
            model.tap(positions[1])
            settle(clock)
            played += 1
        }
        XCTAssertEqual(played, count, "the setup matched \(count) pair(s)")
    }

    private func playEveryPair(_ model: GameModel, clock: ManualClock) {
        playPairs(CardSymbol.allCases.count, in: model, clock: clock)
    }

    private func matchedPositions(of model: GameModel) -> [Int] {
        model.cards.indices.filter { model.cards[$0].state == .matched }
    }

    private func firstIndex(ofState state: CardState, in model: GameModel) throws -> Int {
        guard let index = model.cards.firstIndex(where: { $0.state == state }) else {
            throw TestSetupError.noSuchCard
        }
        return index
    }

    private func twoPositionsWithDifferentSymbols(in model: GameModel) throws -> (Int, Int) {
        let cards = model.cards
        for i in cards.indices {
            for j in cards.indices where j > i && cards[i].symbol != cards[j].symbol {
                return (i, j)
            }
        }
        throw TestSetupError.noSuchCard
    }

    /// Eight symbols, each in exactly two of the 16 places.
    private func assertIsAWellFormedDeal(
        _ cards: [Card],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(cards.count, 16, "16 cards", file: file, line: line)
        var counts: [CardSymbol: Int] = [:]
        for card in cards { counts[card.symbol, default: 0] += 1 }
        XCTAssertEqual(counts.count, 8, "eight distinct symbols", file: file, line: line)
        XCTAssertTrue(
            counts.values.allSatisfy { $0 == 2 },
            "each symbol appears exactly twice",
            file: file, line: line
        )
    }

    private enum TestSetupError: Error {
        case noSuchCard
    }
}

// MARK: - Fixtures

/// A clock that only moves when a test tells it to, and that reports the
/// moment it has been moved to. Work handed to `schedule` waits in a queue
/// until the clock passes its due moment.
final class ManualClock: GameClock {
    private struct Scheduled {
        let id: Int
        let dueAt: TimeInterval
        let work: () -> Void
    }

    private(set) var now: TimeInterval = 0
    private var pending: [Scheduled] = []
    private var nextID = 0

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        nextID += 1
        pending.append(Scheduled(id: nextID, dueAt: now + delay, work: work))
    }

    /// Moves the clock forward, running everything that comes due on the way,
    /// in the order it comes due, with `now` set to each due moment as it runs.
    func advance(by interval: TimeInterval) {
        let target = now + interval
        // A microsecond of slack, because 0.3 + 0.9 in binary floating point
        // is not exactly 1.2.
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
}
