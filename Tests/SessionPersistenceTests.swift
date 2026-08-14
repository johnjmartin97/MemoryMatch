import XCTest
@testable import MemoryMatch

/// PP-4 — elapsed time, the move counter, the restart control, and saving and
/// restoring a game.
///
/// One test per acceptance criterion. Time is driven by a hand-wound clock so
/// every expected duration is a number written out here, never a number the
/// session worked out for itself.
final class SessionPersistenceTests: XCTestCase {

    // MARK: - Fixtures

    /// A clock the test winds by hand. `now` only ever moves because a test
    /// moves it, so elapsed-time expectations are exact.
    private final class TestClock {
        var now: TimeInterval = 0

        func advance(_ seconds: TimeInterval) {
            now += seconds
        }
    }

    /// A session with a fixed deal and a clock the test controls.
    private func makeSession(
        seed: UInt64 = 7,
        clock: TestClock
    ) -> GameSession {
        GameSession(seed: seed, now: { clock.now })
    }

    /// The two positions holding `symbol`.
    private func positions(
        of symbol: CardSymbol,
        in session: GameSession
    ) -> [Int] {
        session.cards.indices.filter { session.cards[$0].symbol == symbol }
    }

    /// Two face-down positions carrying different symbols.
    private func mismatchedFaceDownPair(in session: GameSession) -> (Int, Int) {
        let open = session.cards.indices.filter {
            session.cards[$0].state == .faceDown
        }
        for first in open {
            for second in open
            where second > first
                && session.cards[first].symbol != session.cards[second].symbol {
                return (first, second)
            }
        }
        XCTFail("expected two face-down cards with different symbols")
        return (0, 1)
    }

    private func faceUpCount(_ session: GameSession) -> Int {
        session.cards.filter { $0.state == .faceUp }.count
    }

    private func matchedPositions(_ session: GameSession) -> Set<Int> {
        Set(session.cards.indices.filter { session.cards[$0].state == .matched })
    }

    /// Resolves one matching pair. Returns the two positions it turned.
    @discardableResult
    private func playPair(
        _ symbol: CardSymbol,
        in session: GameSession,
        pauseBeforeSecondTap: TimeInterval = 0,
        clock: TestClock
    ) -> [Int] {
        let pair = positions(of: symbol, in: session)
        XCTAssertEqual(pair.count, 2, "\(symbol) sits in exactly two positions")
        session.tap(pair[0])
        if pauseBeforeSecondTap > 0 {
            clock.advance(pauseBeforeSecondTap)
        }
        session.tap(pair[1])
        session.resolveTurn()
        return pair
    }

    /// Matches all eight pairs, leaving the board won.
    private func playToWin(_ session: GameSession, clock: TestClock) {
        for symbol in CardSymbol.allCases {
            playPair(symbol, in: session, clock: clock)
        }
    }

    /// Checks a board is a fresh deal: 16 cards, eight symbols twice each,
    /// every card face down.
    private func assertFreshDeal(
        _ session: GameSession,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            session.cards.count, 16, "\(message): 16 cards",
            file: file, line: line
        )
        var counts: [CardSymbol: Int] = [:]
        for card in session.cards {
            counts[card.symbol, default: 0] += 1
        }
        for symbol in CardSymbol.allCases {
            XCTAssertEqual(
                counts[symbol], 2, "\(message): \(symbol) appears twice",
                file: file, line: line
            )
        }
        XCTAssertTrue(
            session.cards.allSatisfy { $0.state == .faceDown },
            "\(message): every card is face down",
            file: file, line: line
        )
        XCTAssertEqual(
            faceUpCount(session), 0, "\(message): no card is face up",
            file: file, line: line
        )
    }

    // MARK: - Criterion 1

    /// Elapsed time is 0 right after a deal, stays 0 while nobody plays, and
    /// starts moving only when a card tap is actually accepted.
    func testElapsedStartsAtZeroAndOnlyRunsAfterTheFirstAcceptedTap() {
        let clock = TestClock()
        let session = makeSession(clock: clock)

        XCTAssertEqual(session.elapsed, 0, accuracy: 0.001, "a fresh deal is at 0")

        // Ten seconds pass with nobody playing.
        clock.advance(10)
        XCTAssertEqual(
            session.elapsed, 0, accuracy: 0.001,
            "waiting without playing leaves the clock at 0"
        )

        // The first accepted tap starts it.
        session.tap(0)
        XCTAssertEqual(
            session.elapsed, 0, accuracy: 0.001,
            "the instant of the first tap is still 0"
        )
        clock.advance(3)
        XCTAssertEqual(
            session.elapsed, 3, accuracy: 0.001,
            "three seconds after the first tap the clock reads 3"
        )

        // A tap the board refuses does not start the clock. Build that case
        // by saving a board with a matched pair on it, restoring it, and
        // tapping the matched card. The whole set-up runs with the clock
        // still, so the saved elapsed time is 0.
        let stillClock = TestClock()
        let played = makeSession(seed: 21, clock: stillClock)
        let matched = playPair(.star, in: played, clock: stillClock)
        XCTAssertEqual(
            played.elapsed, 0, accuracy: 0.001,
            "the set-up game banked no time"
        )

        let data: Data
        do {
            data = try played.encoded()
        } catch {
            return XCTFail("saving a game should not throw: \(error)")
        }

        let rejectClock = TestClock()
        let restored = GameSession(
            restoring: data, seed: 21, now: { rejectClock.now }
        )
        XCTAssertEqual(
            restored.cards[matched[0]].state, .matched,
            "the restored board still has the matched card"
        )

        restored.tap(matched[0])
        rejectClock.advance(9)
        XCTAssertEqual(
            restored.elapsed, 0, accuracy: 0.001,
            "a tap the board refuses does not start the clock"
        )

        let free = restored.cards.indices.first {
            restored.cards[$0].state == .faceDown
        }
        guard let free else { return XCTFail("expected a face-down card") }
        restored.tap(free)
        rejectClock.advance(4)
        XCTAssertEqual(
            restored.elapsed, 4, accuracy: 0.001,
            "the first accepted tap does start the clock"
        )
    }

    // MARK: - Criterion 2

    /// Time spent in the background is not counted.
    func testBackgroundingPausesElapsedTimeAndForegroundingResumesIt() {
        let clock = TestClock()
        let session = makeSession(clock: clock)

        session.tap(0)
        clock.advance(4)
        XCTAssertEqual(session.elapsed, 4, accuracy: 0.001, "four seconds played")

        session.moveToBackground()
        clock.advance(100)
        XCTAssertEqual(
            session.elapsed, 4, accuracy: 0.001,
            "a hundred seconds in the background add nothing"
        )

        session.moveToForeground()
        XCTAssertEqual(
            session.elapsed, 4, accuracy: 0.001,
            "coming back does not add the gap either"
        )

        clock.advance(3)
        XCTAssertEqual(
            session.elapsed, 7, accuracy: 0.001,
            "four seconds before plus three seconds after is seven"
        )

        // A second trip out and back behaves the same way.
        session.moveToBackground()
        clock.advance(50)
        session.moveToForeground()
        clock.advance(2)
        XCTAssertEqual(
            session.elapsed, 9, accuracy: 0.001,
            "seven plus two is nine; the fifty backgrounded seconds are gone"
        )
    }

    // MARK: - Criterion 3

    /// Once all sixteen cards are matched the clock stops for good.
    func testElapsedStopsAdvancingOnceEveryCardIsMatched() {
        let clock = TestClock()
        let session = makeSession(clock: clock)

        // Five seconds of real play, then finish the board with the clock
        // held still.
        playPair(.star, in: session, pauseBeforeSecondTap: 5, clock: clock)
        XCTAssertEqual(session.elapsed, 5, accuracy: 0.001, "five seconds played")

        for symbol in CardSymbol.allCases where symbol != .star {
            playPair(symbol, in: session, clock: clock)
        }
        XCTAssertTrue(session.isWon, "every card is matched")
        XCTAssertEqual(
            session.elapsed, 5, accuracy: 0.001,
            "finishing the board banked no extra time"
        )

        clock.advance(120)
        XCTAssertEqual(
            session.elapsed, 5, accuracy: 0.001,
            "two minutes after the win the clock still reads five"
        )

        clock.advance(3600)
        XCTAssertEqual(
            session.elapsed, 5, accuracy: 0.001,
            "an hour later it still reads five"
        )
    }

    // MARK: - Criterion 4

    /// Saving a half-played game and loading it back gives the same layout,
    /// the same matched positions, the same move count and the same time.
    func testSavingAndLoadingAMidGameStateKeepsLayoutMatchesMovesAndTime() {
        let clock = TestClock()
        let session = makeSession(seed: 31, clock: clock)

        // One matched pair, three seconds.
        playPair(.moon, in: session, pauseBeforeSecondTap: 3, clock: clock)
        // One failed turn, four more seconds.
        let (left, right) = mismatchedFaceDownPair(in: session)
        session.tap(left)
        clock.advance(4)
        session.tap(right)
        session.resolveTurn()

        XCTAssertEqual(session.moveCount, 2, "two turns were resolved")
        XCTAssertEqual(session.elapsed, 7, accuracy: 0.001, "seven seconds played")

        let expectedSymbols = session.cards.map { $0.symbol }
        let expectedMatched = matchedPositions(session)
        XCTAssertEqual(expectedMatched.count, 2, "one pair is matched")

        let data: Data
        do {
            data = try session.encoded()
        } catch {
            return XCTFail("saving a game should not throw: \(error)")
        }

        // A different clock, wound elsewhere, to prove nothing leaks across.
        let laterClock = TestClock()
        laterClock.advance(9999)
        let restored = GameSession(
            restoring: data, seed: 999, now: { laterClock.now }
        )

        XCTAssertEqual(
            restored.cards.map { $0.symbol }, expectedSymbols,
            "the sixteen symbols come back in the same order"
        )
        XCTAssertEqual(
            matchedPositions(restored), expectedMatched,
            "the same positions are still matched"
        )
        XCTAssertEqual(restored.moveCount, 2, "the move count comes back as 2")
        XCTAssertEqual(
            restored.elapsed, 7, accuracy: 0.001,
            "the banked seven seconds come back"
        )
    }

    // MARK: - Criterion 5

    /// Cards that were face up when the game was saved come back face down —
    /// while the rest of the saved game really is restored, so "turn them
    /// down" cannot be met by throwing the save away.
    func testRestoringABoardWithFaceUpCardsTurnsThemFaceDown() {
        // Every position gets a turn at being the face-up card. The board also
        // carries a matched pair, so the test can tell a real restore from a
        // fresh deal.
        for position in 0..<16 {
            let clock = TestClock()
            let session = makeSession(seed: 5, clock: clock)

            let matched = playPair(.star, in: session, clock: clock)
            guard !matched.contains(position) else { continue }

            session.tap(position)
            XCTAssertEqual(
                session.cards[position].state, .faceUp,
                "position \(position) is face up before saving"
            )
            XCTAssertEqual(
                faceUpCount(session), 1,
                "position \(position): exactly one card is face up before saving"
            )

            let expectedSymbols = session.cards.map { $0.symbol }
            let expectedMatched = matchedPositions(session)

            let data: Data
            do {
                data = try session.encoded()
            } catch {
                return XCTFail("saving a game should not throw: \(error)")
            }

            let restored = GameSession(
                restoring: data, seed: 99, now: { clock.now }
            )

            XCTAssertEqual(
                restored.cards[position].state, .faceDown,
                "position \(position) comes back face down"
            )
            XCTAssertEqual(
                faceUpCount(restored), 0,
                "position \(position): no card is face up after restoring"
            )
            XCTAssertEqual(
                restored.cards.map { $0.symbol }, expectedSymbols,
                "position \(position): the saved layout really was restored"
            )
            XCTAssertEqual(
                matchedPositions(restored), expectedMatched,
                "position \(position): the saved matched pair really was restored"
            )
            XCTAssertEqual(
                restored.moveCount, 1,
                "position \(position): the saved move count really was restored"
            )
        }

        // Two face-up cards — a turn saved mid-judgement — come back down too.
        let clock = TestClock()
        let session = makeSession(seed: 13, clock: clock)
        let matched = playPair(.bell, in: session, clock: clock)
        let (left, right) = mismatchedFaceDownPair(in: session)
        session.tap(left)
        session.tap(right)
        XCTAssertEqual(faceUpCount(session), 2, "two cards are face up")

        let expectedSymbols = session.cards.map { $0.symbol }

        let data: Data
        do {
            data = try session.encoded()
        } catch {
            return XCTFail("saving a game should not throw: \(error)")
        }
        let restored = GameSession(restoring: data, seed: 99, now: { clock.now })

        XCTAssertEqual(restored.cards[left].state, .faceDown, "the first comes back down")
        XCTAssertEqual(restored.cards[right].state, .faceDown, "the second comes back down")
        XCTAssertEqual(faceUpCount(restored), 0, "no card is face up after restoring")
        XCTAssertEqual(
            restored.cards.map { $0.symbol }, expectedSymbols,
            "the saved layout really was restored"
        )
        XCTAssertEqual(
            matchedPositions(restored), Set(matched),
            "the saved matched pair really was restored"
        )
    }

    // MARK: - Criterion 6

    /// A finished game is not restored. Loading it deals a fresh board.
    func testRestoringAFinishedGameDealsAFreshBoardInstead() {
        let clock = TestClock()
        let session = makeSession(seed: 17, clock: clock)

        playToWin(session, clock: clock)
        XCTAssertTrue(session.isWon, "the saved game was finished")
        XCTAssertEqual(session.moveCount, 8, "eight turns finished the board")

        let data: Data
        do {
            data = try session.encoded()
        } catch {
            return XCTFail("saving a game should not throw: \(error)")
        }

        let restored = GameSession(restoring: data, seed: 17, now: { clock.now })

        assertFreshDeal(restored, "a finished save deals fresh")
        XCTAssertEqual(restored.moveCount, 0, "the move count is back to 0")
        XCTAssertFalse(restored.isWon, "the fresh board is not already won")
        XCTAssertEqual(
            matchedPositions(restored), [],
            "no card is matched on the fresh board"
        )
    }

    // MARK: - Criterion 7

    /// A first launch, with nothing saved, deals a board rather than throwing
    /// or showing nothing.
    func testLaunchingWithNoSavedStateDealsAFreshBoard() {
        let clock = TestClock()

        let firstLaunch = GameSession(
            restoring: nil, seed: 3, now: { clock.now }
        )
        assertFreshDeal(firstLaunch, "no saved state")
        XCTAssertEqual(firstLaunch.moveCount, 0, "no saved state: move count is 0")
        XCTAssertEqual(
            firstLaunch.elapsed, 0, accuracy: 0.001,
            "no saved state: the clock starts at 0"
        )

        // The board is playable, not an empty shell.
        firstLaunch.tap(0)
        XCTAssertEqual(
            firstLaunch.cards[0].state, .faceUp,
            "the freshly dealt board takes a tap"
        )
    }

    // MARK: - Criterion 8

    /// With no pairs matched yet, restart just re-deals. It asks nothing.
    func testRestartWithNoMatchedPairsRedealsImmediatelyWithoutConfirmation() {
        var everChangedLayout = false

        for seed in UInt64(1)...20 {
            let clock = TestClock()
            let session = makeSession(seed: seed, clock: clock)

            // A failed turn: the move count moves, nothing gets matched.
            let (left, right) = mismatchedFaceDownPair(in: session)
            session.tap(left)
            clock.advance(6)
            session.tap(right)
            session.resolveTurn()

            XCTAssertEqual(session.moveCount, 1, "seed \(seed): one turn played")
            XCTAssertEqual(
                matchedPositions(session), [],
                "seed \(seed): no pair is matched"
            )

            let before = session.cards.map { $0.symbol }
            session.restart()

            XCTAssertFalse(
                session.isRestartConfirmationRequested,
                "seed \(seed): restart asks nothing when no pair is matched"
            )
            assertFreshDeal(session, "seed \(seed): restart re-deals")
            XCTAssertEqual(
                session.moveCount, 0,
                "seed \(seed): restart puts the move count back to 0"
            )

            if session.cards.map({ $0.symbol }) != before {
                everChangedLayout = true
            }
        }

        XCTAssertTrue(
            everChangedLayout,
            "restart deals a new board, not the same one over and over"
        )
    }

    // MARK: - Criterion 9

    /// With at least one pair matched, restart asks first and leaves the board
    /// alone until the answer is yes.
    func testRestartWithAMatchedPairAsksFirstAndLeavesTheBoardUntilAccepted() {
        let clock = TestClock()
        let session = makeSession(seed: 23, clock: clock)

        playPair(.leaf, in: session, pauseBeforeSecondTap: 2, clock: clock)
        XCTAssertEqual(
            matchedPositions(session).count, 2,
            "one pair is matched before the restart"
        )
        XCTAssertFalse(
            session.isRestartConfirmationRequested,
            "nothing is being asked yet"
        )

        let cardsBefore = session.cards
        let movesBefore = session.moveCount

        session.restart()

        XCTAssertTrue(
            session.isRestartConfirmationRequested,
            "restart asks for confirmation once a pair is matched"
        )
        XCTAssertEqual(
            session.cards, cardsBefore,
            "the board is untouched while the question is open"
        )
        XCTAssertEqual(
            session.moveCount, movesBefore,
            "the move count is untouched while the question is open"
        )

        // Saying no leaves the game exactly as it was.
        session.cancelRestart()
        XCTAssertFalse(
            session.isRestartConfirmationRequested,
            "the question is closed after saying no"
        )
        XCTAssertEqual(session.cards, cardsBefore, "saying no keeps the board")
        XCTAssertEqual(
            session.moveCount, movesBefore, "saying no keeps the move count"
        )

        // Saying yes re-deals.
        session.restart()
        XCTAssertTrue(
            session.isRestartConfirmationRequested,
            "asked again on the second restart"
        )
        session.confirmRestart()

        XCTAssertFalse(
            session.isRestartConfirmationRequested,
            "the question is closed after saying yes"
        )
        assertFreshDeal(session, "an accepted restart re-deals")
        XCTAssertEqual(
            session.moveCount, 0,
            "an accepted restart puts the move count back to 0"
        )
        XCTAssertEqual(
            matchedPositions(session), [],
            "an accepted restart clears the matched pair"
        )
    }
}
