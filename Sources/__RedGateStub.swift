import Foundation

/// Throwaway red-gate stub, deleted when PP-4 is implemented.
///
/// The turn-taking half is the baseline PP-3 already shipped, so the PP-4
/// tests fail on what PP-4 is about — elapsed time, save/restore and the
/// restart control — and not on a board that never deals.

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

    // MARK: PP-4 surface — declared, not implemented.

    /// Seconds of play so far.
    var elapsed: TimeInterval { 0 }
    /// True while the player is being asked to confirm a restart.
    private(set) var isConfirmingRestart = false

    func enterBackground() {}
    func enterForeground() {}
    func requestRestart(seed: UInt64) {}
    func confirmRestart() {}

    /// Verbatim copy of the board — no faceUp coercion, no elapsed time.
    func snapshot() -> SavedGame {
        SavedGame(
            symbols: cards.map(\.symbol),
            states: cards.map(\.state),
            moveCount: moveCount,
            elapsed: 0
        )
    }

    // MARK: Baseline

    private enum Phase { case idle, revealing, mismatchHold }

    private let clock: GameClock
    private var phase: Phase = .idle
    private var faceUpIndices: [Int] = []
    private var generation = 0

    init(seed: UInt64, clock: GameClock) {
        self.clock = clock
        newGame(seed: seed)
    }

    /// Reads the save back exactly as it was left.
    init(restoring saved: SavedGame?, seed: UInt64, clock: GameClock) {
        self.clock = clock
        guard let saved else {
            newGame(seed: seed)
            return
        }
        cards = zip(saved.symbols, saved.states).map { Card(symbol: $0, state: $1) }
        moveCount = saved.moveCount
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
    }

    func tap(_ index: Int) {
        guard cards.indices.contains(index) else { return }

        switch phase {
        case .revealing: return
        case .mismatchHold: turnFaceUpCardsDown()
        case .idle: break
        }

        guard cards[index].state == .faceDown else { return }

        cards[index].state = .faceUp
        faceUpIndices.append(index)
        moveCount += 1

        guard faceUpIndices.count == 2 else { return }

        phase = .revealing
        schedule(after: Timing.reveal) { [weak self] in self?.judgePair() }
    }

    private func judgePair() {
        let first = faceUpIndices[0]
        let second = faceUpIndices[1]

        if cards[first].symbol == cards[second].symbol {
            cards[first].state = .matched
            cards[second].state = .matched
            faceUpIndices = []
            phase = .idle
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
