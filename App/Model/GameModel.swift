import Foundation

/// Where delayed work goes. The app hands this to the main queue; tests hand
/// it to a clock they move by hand, so no test ever waits on real time.
protocol GameClock {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}

enum CardState: CaseIterable, Hashable { case faceDown, faceUp, matched }

struct Card: Equatable { let symbol: CardSymbol; var state: CardState }

/// How long each part of a turn takes, in seconds.
enum Timing {
    /// The pair stays face up this long before it is judged.
    static let reveal: TimeInterval = 0.3
    /// A mismatched pair then stays face up this much longer.
    static let mismatchHold: TimeInterval = 0.9
}

/// The board and the rules of a turn.
///
/// A turn runs in two steps. Both cards sit face up for `reveal`; taps are
/// ignored while that settles. A matched pair is done there. A mismatched pair
/// then holds for `mismatchHold`, and a tap during that hold ends the hold at
/// once and starts the next turn — the player never has to wait out the flip
/// back.
final class GameModel {
    private(set) var cards: [Card] = []
    /// Completed turns. A turn is a pair of cards, so it counts 1 whether the
    /// pair matched or not, and counts when the turn finishes — not on a tap.
    private(set) var moveCount = 0

    /// True while a turn is still settling: taps do nothing during the reveal,
    /// and a mismatch is still on screen during the hold.
    var isLocked: Bool { phase != .idle }

    private enum Phase { case idle, revealing, mismatchHold }

    private let clock: GameClock
    private var phase: Phase = .idle
    private var faceUpIndices: [Int] = []
    /// Bumped whenever pending work stops being wanted. Scheduled work that
    /// wakes up with a stale number does nothing.
    private var generation = 0

    init(seed: UInt64, clock: GameClock) {
        self.clock = clock
        newGame(seed: seed)
    }

    /// Deals a fresh board: eight pairs, shuffled by the seed, all face down.
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
        // Taps do nothing while a pair is being judged.
        guard phase != .revealing else { return }
        // Only a face-down card is a move. Anything else — a card already
        // matched, or one of the two still on show — leaves the board alone,
        // including a hold that is running.
        guard cards[index].state == .faceDown else { return }

        if phase == .mismatchHold {
            // Tap-ahead: end the hold now and carry on with this tap.
            turnFaceUpCardsDown()
        }

        cards[index].state = .faceUp
        faceUpIndices.append(index)

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
            moveCount += 1
        } else {
            phase = .mismatchHold
            schedule(after: Timing.mismatchHold) { [weak self] in
                self?.turnFaceUpCardsDown()
            }
        }
    }

    /// Ends a mismatched turn, either when its hold runs out or when a
    /// tap-ahead cuts the hold short. Either way the turn is over, so it is
    /// counted here — one move per turn, matching the matched case.
    private func turnFaceUpCardsDown() {
        if faceUpIndices.count == 2 {
            moveCount += 1
        }
        for index in faceUpIndices {
            cards[index].state = .faceDown
        }
        faceUpIndices = []
        phase = .idle
        generation += 1
    }

    /// Hands work to the clock, tagged so anything that happens first — a
    /// tap-ahead, a new game — cancels it.
    private func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        generation += 1
        let scheduledGeneration = generation
        clock.schedule(after: delay) { [weak self] in
            guard let self, self.generation == scheduledGeneration else { return }
            work()
        }
    }
}
