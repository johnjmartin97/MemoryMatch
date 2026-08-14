import Foundation
import Observation

/// One sitting at the game: the board, the move count, the clock the player
/// sees, the restart control, and the saved state the app comes back to.
///
/// The clock is read through `now`, so tests can wind it by hand.
@Observable
final class GameSession {
    private let now: () -> TimeInterval

    /// Draws the seed for every re-deal, so a restart lays out a new board
    /// while a given starting seed still plays out the same way.
    private var dealGenerator: SeededGenerator

    private var model: GameModel

    /// Seconds already banked, plus the run since the clock last started.
    private var bankedElapsed: TimeInterval = 0
    /// When the running stretch began. `nil` while the clock is stopped.
    private var runningSince: TimeInterval?
    /// True once the first tap has been accepted; the clock only ever runs
    /// after that.
    private var hasStarted = false
    private var isBackgrounded = false

    /// True while the restart control is waiting for a yes or no.
    private(set) var isRestartConfirmationRequested = false

    /// True once the win overlay is up. It waits 600 ms after the last pair
    /// matches, so the pop and the sparkle are seen before the panel covers
    /// the board.
    private(set) var isWinOverlayPresented = false

    /// Where the win pause goes. Held so a test can drive time by hand.
    private let clock: TurnClock

    var cards: [Card] { model.cards }
    var moveCount: Int { model.moveCount }
    var isWon: Bool { model.isWon }

    /// Seconds of play. Time before the first accepted tap, time in the
    /// background, and time after the win are all left out.
    var elapsed: TimeInterval {
        bankedElapsed + (runningSince.map { now() - $0 } ?? 0)
    }

    init(
        seed: UInt64 = .random(in: 0...UInt64.max),
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate },
        clock: TurnClock = SystemTurnClock()
    ) {
        self.now = now
        self.clock = clock
        dealGenerator = SeededGenerator(seed: seed)
        model = GameModel(seed: seed, clock: clock)
        watchForWin()
    }

    /// Picks up a saved game. Anything missing, unreadable or already
    /// finished deals a fresh board instead.
    convenience init(
        restoring data: Data?,
        seed: UInt64 = .random(in: 0...UInt64.max),
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate },
        clock: TurnClock = SystemTurnClock()
    ) {
        self.init(seed: seed, now: now, clock: clock)
        guard let data, let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              let cards = snapshot.restoredCards(),
              !cards.allSatisfy({ $0.state == .matched })
        else { return }

        model = GameModel(cards: cards, moveCount: snapshot.moveCount, clock: clock)
        bankedElapsed = snapshot.elapsed
        watchForWin()
    }

    // MARK: - Playing

    /// Turns a card, and starts the clock on the first tap the board accepts.
    func tap(_ index: Int) {
        let before = model.cards[index].state
        model.tap(index)
        guard model.cards[index].state != before else { return }
        hasStarted = true
        runClock()
    }

    /// Judges the two face-up cards. Winning stops the clock for good.
    func resolveTurn() {
        model.resolveTurn()
        if model.isWon {
            bankRunningTime()
        }
    }

    // MARK: - Foreground and background

    /// Leaving the app banks what has been played so far and stops counting.
    func moveToBackground() {
        bankRunningTime()
        isBackgrounded = true
    }

    /// Coming back picks up where the player left off, without the gap.
    func moveToForeground() {
        isBackgrounded = false
        runClock()
    }

    // MARK: - Restarting

    /// Re-deals. Once a pair is matched there is something to lose, so this
    /// asks first instead.
    func restart() {
        guard cards.contains(where: { $0.state == .matched }) else {
            return deal()
        }
        isRestartConfirmationRequested = true
    }

    func confirmRestart() {
        isRestartConfirmationRequested = false
        deal()
    }

    func cancelRestart() {
        isRestartConfirmationRequested = false
    }

    /// Takes the win overlay away and deals again. Nothing is left to lose at
    /// this point, so it does not ask first.
    func playAgain() {
        isWinOverlayPresented = false
        deal()
    }

    // MARK: - Saving

    func encoded() throws -> Data {
        let snapshot = Snapshot(
            symbols: cards.map { $0.symbol.rawValue },
            matched: cards.map { $0.state == .matched },
            moveCount: moveCount,
            elapsed: elapsed
        )
        return try JSONEncoder().encode(snapshot)
    }

    // MARK: - Internals

    private func deal() {
        model = GameModel(seed: dealGenerator.next(), clock: clock)
        watchForWin()
        bankedElapsed = 0
        runningSince = nil
        hasStarted = false
        isWinOverlayPresented = false
    }

    /// Winning stops the clock at once, and brings the overlay up after the
    /// celebration has had its moment.
    private func watchForWin() {
        model.onWin = { [weak self] in
            guard let self else { return }
            bankRunningTime()
            clock.schedule(after: Motion.winOverlayDelayMilliseconds) { [weak self] in
                self?.isWinOverlayPresented = true
            }
        }
    }

    /// Starts, or resumes, the running stretch — never before the first
    /// accepted tap, and never while backgrounded, already running, or won.
    private func runClock() {
        guard hasStarted, runningSince == nil, !isBackgrounded, !model.isWon else { return }
        runningSince = now()
    }

    private func bankRunningTime() {
        guard let runningSince else { return }
        bankedElapsed += now() - runningSince
        self.runningSince = nil
    }

    /// What gets written to disk. Face-up cards are saved as face down: a
    /// half-turned card is not something to come back to.
    private struct Snapshot: Codable {
        let symbols: [String]
        let matched: [Bool]
        let moveCount: Int
        let elapsed: TimeInterval

        /// The saved board, or `nil` if the save does not describe 16 cards.
        func restoredCards() -> [Card]? {
            guard symbols.count == 16, matched.count == 16 else { return nil }
            var cards: [Card] = []
            for (rawSymbol, isMatched) in zip(symbols, matched) {
                guard let symbol = CardSymbol(rawValue: rawSymbol) else { return nil }
                cards.append(Card(symbol: symbol, state: isMatched ? .matched : .faceDown))
            }
            return cards
        }
    }
}
