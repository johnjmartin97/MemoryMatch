import Foundation

/// Where delayed work goes, and where the current moment comes from.
protocol GameClock {
    /// Seconds since the clock started.
    var now: TimeInterval { get }
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}

enum CardState: CaseIterable, Hashable, Codable { case faceDown, faceUp, matched }

struct Card: Equatable { let symbol: CardSymbol; var state: CardState }

extension CardSymbol: Codable {}

enum Timing {
    static let reveal: TimeInterval = 0.3
    static let mismatchHold: TimeInterval = 0.9
}

/// A game written to disk and read back at launch.
struct SavedGame: Codable, Equatable {
    var symbols: [CardSymbol]
    var states: [CardState]
    var moveCount: Int
    var elapsed: TimeInterval
}

final class GameModel {
    private(set) var cards: [Card] = []
    private(set) var moveCount = 0

    var isLocked: Bool { phase != .idle }

    // MARK: Elapsed time

    /// Seconds of play so far. Runs from the first accepted tap, pauses in the
    /// background, and stops for good when the last pair is matched.
    var elapsed: TimeInterval {
        guard let runningSince else { return accumulated }
        return accumulated + (clock.now - runningSince)
    }

    /// Everything the timer has banked while it was not running.
    private var accumulated: TimeInterval = 0
    /// The moment the running stretch began, or nil while paused.
    private var runningSince: TimeInterval?
    /// True once the first accepted tap has happened, until the next deal.
    private var hasStarted = false

    func enterBackground() {
        bankRunningTime()
    }

    func enterForeground() {
        guard hasStarted, !isFinished, runningSince == nil else { return }
        runningSince = clock.now
    }

    /// Moves any running stretch into `accumulated` and stops the clock.
    private func bankRunningTime() {
        guard let runningSince else { return }
        accumulated += clock.now - runningSince
        self.runningSince = nil
    }

    private var isFinished: Bool { cards.allSatisfy { $0.state == .matched } }

    // MARK: Restart

    /// True while the player is being asked to confirm a restart.
    private(set) var isConfirmingRestart = false
    private var pendingRestartSeed: UInt64 = 0

    /// Restarts at once from an untouched board; asks first if the player has
    /// matched anything worth losing.
    func requestRestart(seed: UInt64) {
        guard cards.contains(where: { $0.state == .matched }) else {
            newGame(seed: seed)
            return
        }
        pendingRestartSeed = seed
        isConfirmingRestart = true
    }

    func confirmRestart() {
        isConfirmingRestart = false
        newGame(seed: pendingRestartSeed)
    }

    func cancelRestart() {
        isConfirmingRestart = false
    }

    // MARK: Save and restore

    /// The board as it stands, with the time played so far.
    func snapshot() -> SavedGame {
        SavedGame(
            symbols: cards.map(\.symbol),
            states: cards.map(\.state),
            moveCount: moveCount,
            elapsed: elapsed
        )
    }

    // MARK: Turn taking

    private enum Phase { case idle, revealing, mismatchHold }

    private let clock: GameClock
    private var phase: Phase = .idle
    private var faceUpIndices: [Int] = []
    private var generation = 0

    init(seed: UInt64, clock: GameClock) {
        self.clock = clock
        newGame(seed: seed)
    }

    /// Picks up a saved game, or deals a fresh one when there is nothing to
    /// pick up. A game that was already won is not resumed.
    init(restoring saved: SavedGame?, seed: UInt64, clock: GameClock) {
        self.clock = clock
        guard let saved,
              GameModel.isWellFormed(saved),
              saved.states.contains(where: { $0 != .matched }) else {
            newGame(seed: seed)
            return
        }
        // A card left mid-turn comes back face down: the player has had time to
        // forget it, so showing it again would be a free look.
        cards = zip(saved.symbols, saved.states).map {
            Card(symbol: $0, state: $1 == .faceUp ? .faceDown : $1)
        }
        moveCount = saved.moveCount
        accumulated = saved.elapsed
    }

    /// A save is only usable if it describes a whole board: 16 symbols, 16
    /// matching states, and eight symbols each appearing exactly twice. A save
    /// truncated by a crash, or written by an older build, would otherwise
    /// build a short board that the 16-cell grid reads off the end of — and it
    /// would do that on every launch, with no way out.
    private static func isWellFormed(_ saved: SavedGame) -> Bool {
        guard saved.symbols.count == 16, saved.states.count == 16 else { return false }
        var counts: [CardSymbol: Int] = [:]
        for symbol in saved.symbols { counts[symbol, default: 0] += 1 }
        return counts.count == 8 && counts.values.allSatisfy { $0 == 2 }
    }

    func newGame(seed: UInt64) {
        var s = seed &+ 1
        var pairs = CardSymbol.allCases.flatMap { [$0, $0] }
        for i in (1..<pairs.count).reversed() {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            pairs.swapAt(i, Int(s >> 33) % (i + 1))
        }
        cards = pairs.map { Card(symbol: $0, state: .faceDown) }
        moveCount = 0
        faceUpIndices = []
        phase = .idle
        generation += 1
        accumulated = 0
        runningSince = nil
        hasStarted = false
    }

    func tap(_ index: Int) {
        guard cards.indices.contains(index) else { return }

        // Rejected taps come first: a tap on a matched or face-up card must not
        // cut short the look the player was given at a missed pair.
        guard cards[index].state == .faceDown else { return }

        switch phase {
        case .revealing: return
        case .mismatchHold: turnFaceUpCardsDown()
        case .idle: break
        }

        cards[index].state = .faceUp
        faceUpIndices.append(index)
        startTimingIfNeeded()

        guard faceUpIndices.count == 2 else { return }

        phase = .revealing
        schedule(after: Timing.reveal) { [weak self] in self?.judgePair() }
    }

    /// The first accepted tap is what starts the clock.
    private func startTimingIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        runningSince = clock.now
    }

    private func judgePair() {
        let first = faceUpIndices[0]
        let second = faceUpIndices[1]

        // A move is a turn — two cards resolved — not a single card tap. Eight
        // pairs found without a mistake is eight moves.
        moveCount += 1

        if cards[first].symbol == cards[second].symbol {
            cards[first].state = .matched
            cards[second].state = .matched
            faceUpIndices = []
            phase = .idle
            if isFinished { bankRunningTime() }
        } else {
            phase = .mismatchHold
            schedule(after: Timing.mismatchHold) { [weak self] in
                self?.turnFaceUpCardsDown()
            }
        }
    }

    private func turnFaceUpCardsDown() {
        for index in faceUpIndices {
            cards[index].state = .faceDown
        }
        faceUpIndices = []
        phase = .idle
        generation += 1
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        generation += 1
        let scheduledGeneration = generation
        clock.schedule(after: delay) { [weak self] in
            guard let self, self.generation == scheduledGeneration else { return }
            work()
        }
    }
}
