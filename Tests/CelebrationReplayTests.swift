import SwiftUI
import XCTest
@testable import MemoryMatch

/// Two things the player sees more than once: the confetti burst that follows
/// a win, and the deal that follows every new board.
///
/// The existing PP-6 tests read the numbers out of `Motion`. These drive the
/// views the numbers feed, so a burst that never ends, or a deal that only
/// ever plays once, is caught.
final class CelebrationReplayTests: XCTestCase {

    /// A clock the test drives by hand, so the win overlay's 600 ms pause is
    /// exact and nothing happens on its own.
    private final class TestClock: TurnClock {
        /// Only one piece of work is ever waiting, as the protocol says.
        private var pending: (() -> Void)?

        func schedule(after milliseconds: Int, _ work: @escaping () -> Void) {
            pending = work
        }

        func cancelPending() {
            pending = nil
        }

        /// Runs whatever is waiting.
        func runPending() {
            let due = pending
            pending = nil
            due?()
        }
    }

    private let boardSize = CGSize(width: 390, height: 640)

    // MARK: - The confetti burst

    /// The burst starts at its beginning whatever the time of day is when the
    /// player wins.
    ///
    /// A burst driven by the wall clock instead of the moment of the win puts
    /// a player who wins one and a half seconds "into" the clock straight into
    /// falling, fading ribbons.
    func testTheBurstStartsAtItsBeginningWheneverThePlayerWins() {
        let onTheSecond = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let partWayThrough = Date(timeIntervalSinceReferenceDate: 1_000_001.4)

        // The same moments of the burst, for two wins at different times of
        // day. What is on screen depends on the win, not on the clock.
        for secondsSinceTheWin in [0.0, 0.2, 0.5, 1.0, 1.9] {
            XCTAssertEqual(
                ConfettiView.drawnRibbons(
                    now: onTheSecond.addingTimeInterval(secondsSinceTheWin),
                    burstStartedAt: onTheSecond,
                    in: boardSize
                ),
                ConfettiView.drawnRibbons(
                    now: partWayThrough.addingTimeInterval(secondsSinceTheWin),
                    burstStartedAt: partWayThrough,
                    in: boardSize
                ),
                "\(secondsSinceTheWin) s into the burst looks the same whenever the win happens"
            )
        }

        // Early on the ribbons are still rising from where they launch, and
        // none of them has begun to fade.
        let launchHeight = boardSize.height * 0.42
        let early = ConfettiView.drawnRibbons(
            now: partWayThrough.addingTimeInterval(0.2),
            burstStartedAt: partWayThrough,
            in: boardSize
        )
        XCTAssertFalse(early.isEmpty, "ribbons are on screen a fifth of a second in")
        for ribbon in early {
            XCTAssertLessThan(
                ribbon.position.y,
                launchHeight,
                "ribbon \(ribbon.id) is still on its way up, not already falling"
            )
            XCTAssertEqual(ribbon.opacity, 1, accuracy: 0.001, "nothing has faded yet")
        }
    }

    /// The burst runs once and stops. It does not snap back to the start and
    /// go again every two seconds while the win overlay is on screen.
    func testTheBurstRunsOnceAndDoesNotLoop() {
        let win = Date(timeIntervalSinceReferenceDate: 1_000_000)

        // Part way through, ribbons are on screen.
        let midBurst = ConfettiView.drawnRibbons(
            now: win.addingTimeInterval(0.5),
            burstStartedAt: win,
            in: boardSize
        )
        XCTAssertFalse(midBurst.isEmpty, "half a second in, the ribbons are flying")

        // After two seconds it is over, and it stays over.
        for secondsAfterTheWin in [2.0, 2.5, 4.1, 60.0] {
            let frame = ConfettiView.drawnRibbons(
                now: win.addingTimeInterval(secondsAfterTheWin),
                burstStartedAt: win,
                in: boardSize
            )
            XCTAssertTrue(
                frame.isEmpty,
                "\(secondsAfterTheWin) s after the win the burst has settled and drawn nothing"
            )
        }

        XCTAssertFalse(
            ConfettiView.isBurstRunning(now: win.addingTimeInterval(2.5), burstStartedAt: win),
            "the burst is finished, so nothing needs redrawing every frame"
        )
    }

    /// Winning again starts a fresh burst rather than picking up where the
    /// last one left off.
    func testWinningAgainStartsAFreshBurst() {
        let firstWin = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let secondWin = firstWin.addingTimeInterval(90.7)

        for secondsSinceTheWin in [0.0, 0.3, 1.0] {
            XCTAssertEqual(
                ConfettiView.drawnRibbons(
                    now: firstWin.addingTimeInterval(secondsSinceTheWin),
                    burstStartedAt: firstWin,
                    in: boardSize
                ),
                ConfettiView.drawnRibbons(
                    now: secondWin.addingTimeInterval(secondsSinceTheWin),
                    burstStartedAt: secondWin,
                    in: boardSize
                ),
                "the second win bursts from the beginning too"
            )
        }
    }

    // MARK: - The deal

    /// Every board deals in, not just the first one of the app launch.
    ///
    /// The player wins, taps Play Again, and the sixteen cards arrive one
    /// after another again — card 5 still waiting its 60 ms, and still
    /// starting from hidden.
    func testEveryNewBoardDealsInAgain() {
        let clock = TestClock()
        let session = GameSession(seed: 11, now: { 0 }, clock: clock)

        let firstBoard = BoardView(cards: session.cards, dealID: session.dealID)
        var cell = DealInState()

        XCTAssertEqual(
            cell.begin(dealID: firstBoard.dealID, cardIndex: 5),
            0.060,
            "on the first board card 5 waits its 60 ms"
        )
        cell.land()
        XCTAssertTrue(cell.isDealt, "and then it is in place")

        // Still the same board: it does not deal itself in a second time.
        XCTAssertNil(
            cell.begin(dealID: firstBoard.dealID, cardIndex: 5),
            "a card already in place stays in place"
        )

        // Win the board, then tap Play Again.
        while !session.isWon {
            let firstDown = session.cards.firstIndex { $0.state == .faceDown }
            guard let first = firstDown else { break }
            session.tap(first)
            let match = session.cards.indices.first {
                $0 != first
                    && session.cards[$0].state == .faceDown
                    && session.cards[$0].symbol == session.cards[first].symbol
            }
            guard let match else { break }
            session.tap(match)
            session.resolveTurn()
        }
        XCTAssertTrue(session.isWon, "the board is solved")
        clock.runPending()
        session.playAgain()

        let newBoard = BoardView(cards: session.cards, dealID: session.dealID)
        XCTAssertNotEqual(
            newBoard.dealID,
            firstBoard.dealID,
            "a new board is a new deal"
        )
        XCTAssertEqual(
            cell.begin(dealID: newBoard.dealID, cardIndex: 5),
            0.060,
            "card 5 waits its 60 ms on the new board too"
        )
        XCTAssertFalse(
            cell.isDealt,
            "and it starts hidden again instead of already being in place"
        )
    }

    /// Restarting mid-game deals in as well.
    func testRestartingDealsInAgain() {
        let session = GameSession(seed: 4, now: { 0 }, clock: TestClock())
        let before = session.dealID

        session.restart()

        XCTAssertNotEqual(session.dealID, before, "restart deals a new board")

        var cell = DealInState()
        _ = cell.begin(dealID: before, cardIndex: 0)
        cell.land()
        XCTAssertEqual(
            cell.begin(dealID: session.dealID, cardIndex: 15),
            0.180,
            "the last card of the new board still comes in last"
        )
    }
}
