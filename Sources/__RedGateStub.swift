import Foundation

protocol GameClock {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}

enum CardState: CaseIterable, Hashable { case faceDown, faceUp, matched }

struct Card: Equatable { let symbol: CardSymbol; var state: CardState }

/// Throwaway stub: deals a board and does nothing else.
final class GameModel {
    private(set) var cards: [Card] = []
    private(set) var moveCount = 0
    private(set) var isLocked = false
    private let clock: GameClock

    init(seed: UInt64, clock: GameClock) {
        self.clock = clock
        newGame(seed: seed)
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
        isLocked = false
    }

    func tap(_ index: Int) {}
}
