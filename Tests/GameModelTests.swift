import XCTest
@testable import MemoryMatch

/// PP-1 — the core game model: the deal, card states, turn resolution and
/// win detection.
///
/// One test per acceptance criterion. Every expected value is written out by
/// hand or enumerated here; no expectation is computed with the code it
/// checks.
final class GameModelTests: XCTestCase {

    // MARK: - Fixtures

    /// A fixed 16-card layout: the eight symbols, each exactly twice. Used
    /// wherever a test needs a board it can compare against exactly.
    private static let referenceSymbols: [CardSymbol] = [
        .star, .heart, .bolt, .leaf,
        .moon, .umbrella, .anchor, .bell,
        .bell, .anchor, .umbrella, .moon,
        .leaf, .bolt, .heart, .star,
    ]

    /// Builds a board from the fixed layout with the given states.
    private func board(states: [CardState], moveCount: Int = 0) -> GameModel {
        precondition(states.count == 16, "a board is 16 cards")
        let cards = zip(Self.referenceSymbols, states).map {
            Card(symbol: $0, state: $1)
        }
        return GameModel(cards: cards, moveCount: moveCount)
    }

    /// A board where `position` holds `state`, every other card is face down,
    /// and — when `locked` is true — enough other cards are face up that the
    /// board is locked. The board is locked exactly when two cards are face
    /// up, which is what criteria 6, 8 and 9 describe.
    private func board(
        position: Int,
        state: CardState,
        locked: Bool
    ) -> GameModel {
        var states = [CardState](repeating: .faceDown, count: 16)
        states[position] = state

        if locked {
            let needed = (state == .faceUp) ? 1 : 2
            var added = 0
            for index in 0..<16 where index != position && added < needed {
                states[index] = .faceUp
                added += 1
            }
        }
        return board(states: states)
    }

    /// Two positions in the model's deal that carry the same symbol.
    private func matchingPair(in model: GameModel) -> (Int, Int) {
        for first in 0..<16 {
            for second in (first + 1)..<16
            where model.cards[first].symbol == model.cards[second].symbol {
                return (first, second)
            }
        }
        XCTFail("a dealt board always contains a matching pair")
        return (0, 1)
    }

    /// Two positions in the model's deal that carry different symbols.
    private func mismatchedPair(in model: GameModel) -> (Int, Int) {
        for first in 0..<16 {
            for second in (first + 1)..<16
            where model.cards[first].symbol != model.cards[second].symbol {
                return (first, second)
            }
        }
        XCTFail("a dealt board always contains a mismatched pair")
        return (0, 1)
    }

    private func faceUpCount(_ model: GameModel) -> Int {
        model.cards.filter { $0.state == .faceUp }.count
    }

    // MARK: - Criterion 1

    /// A new deal is 16 cards, 8 distinct symbols each appearing exactly
    /// twice, all face down.
    func testNewDealHasSixteenCardsEightPairsAllFaceDown() {
        for seed in UInt64(1)...50 {
            let model = GameModel(seed: seed)

            XCTAssertEqual(model.cards.count, 16, "seed \(seed): 16 cards")

            var counts: [CardSymbol: Int] = [:]
            for card in model.cards {
                counts[card.symbol, default: 0] += 1
            }

            XCTAssertEqual(counts.count, 8, "seed \(seed): 8 distinct symbols")
            for symbol in CardSymbol.allCases {
                XCTAssertEqual(
                    counts[symbol],
                    2,
                    "seed \(seed): \(symbol) appears exactly twice"
                )
            }
            XCTAssertTrue(
                model.cards.allSatisfy { $0.state == .faceDown },
                "seed \(seed): every card starts face down"
            )
        }
    }

    // MARK: - Criterion 2

    /// Across 1000 seeded deals, every one of the 16 positions holds each of
    /// the 8 symbols at least once.
    func testEveryPositionHoldsEverySymbolAcrossAThousandDeals() {
        var seen = [Set<CardSymbol>](repeating: [], count: 16)

        for seed in UInt64(1)...1000 {
            let model = GameModel(seed: seed)
            XCTAssertEqual(model.cards.count, 16, "seed \(seed): 16 cards")
            for position in 0..<16 {
                seen[position].insert(model.cards[position].symbol)
            }
        }

        for position in 0..<16 {
            for symbol in CardSymbol.allCases {
                XCTAssertTrue(
                    seen[position].contains(symbol),
                    "position \(position) held \(symbol) at least once"
                )
            }
        }
    }

    // MARK: - Criterion 3

    /// Two deals from two different seeds put the symbols in a different
    /// order.
    func testDifferentSeedsGiveDifferentOrders() {
        // Hand-picked seed pairs, each pair two different numbers.
        let seedPairs: [(UInt64, UInt64)] = [
            (1, 2), (7, 8), (42, 99), (100, 1000), (12345, 54321),
        ]

        for (left, right) in seedPairs {
            let a = GameModel(seed: left).cards.map { $0.symbol }
            let b = GameModel(seed: right).cards.map { $0.symbol }
            XCTAssertNotEqual(
                a,
                b,
                "seeds \(left) and \(right) deal different orders"
            )
        }

        // The same seed always deals the same order.
        for seed in UInt64(1)...20 {
            XCTAssertEqual(
                GameModel(seed: seed).cards.map { $0.symbol },
                GameModel(seed: seed).cards.map { $0.symbol },
                "seed \(seed) is repeatable"
            )
        }
    }

    // MARK: - Criterion 4

    /// For all 16 positions and all 3 card states, locked and unlocked: a tap
    /// changes the board only when the card is face down and the board is
    /// unlocked. In every other combination the card states and the move
    /// count are untouched.
    func testTapIsAcceptedOnlyWhenCardIsFaceDownAndBoardUnlocked() {
        for position in 0..<16 {
            for state in CardState.allCases {
                for locked in [false, true] {
                    let model = board(
                        position: position,
                        state: state,
                        locked: locked
                    )
                    let before = model.cards
                    let movesBefore = model.moveCount

                    XCTAssertEqual(
                        model.isLocked,
                        locked,
                        "position \(position)/\(state): board lock is \(locked)"
                    )

                    model.tap(position)

                    let shouldAccept = (state == .faceDown) && !locked
                    if shouldAccept {
                        XCTAssertEqual(
                            model.cards[position].state,
                            .faceUp,
                            "position \(position): a face-down tap on an unlocked board turns the card up"
                        )
                    } else {
                        XCTAssertEqual(
                            model.cards,
                            before,
                            "position \(position)/\(state)/locked=\(locked): the cards are unchanged"
                        )
                    }
                    XCTAssertEqual(
                        model.moveCount,
                        movesBefore,
                        "position \(position)/\(state)/locked=\(locked): a tap never changes the move count"
                    )
                }
            }
        }
    }

    // MARK: - Criterion 5

    /// The first tap turns exactly that card face up, leaves the other 15
    /// alone, and leaves the board unlocked.
    func testFirstTapTurnsExactlyThatCardFaceUpAndLeavesBoardUnlocked() {
        for position in 0..<16 {
            let model = GameModel(seed: 7)
            let before = model.cards

            model.tap(position)

            XCTAssertEqual(
                model.cards[position].state,
                .faceUp,
                "position \(position) is face up"
            )
            for other in 0..<16 where other != position {
                XCTAssertEqual(
                    model.cards[other],
                    before[other],
                    "position \(other) is unchanged by a tap on \(position)"
                )
            }
            XCTAssertEqual(
                faceUpCount(model),
                1,
                "exactly one card is face up"
            )
            XCTAssertFalse(
                model.isLocked,
                "the board stays unlocked after one tap"
            )
        }
    }

    // MARK: - Criterion 6

    /// The second tap turns that card face up and locks the board.
    func testSecondTapTurnsCardFaceUpAndLocksBoard() {
        let model = GameModel(seed: 7)

        model.tap(3)
        model.tap(9)

        XCTAssertEqual(model.cards[3].state, .faceUp, "the first card is face up")
        XCTAssertEqual(model.cards[9].state, .faceUp, "the second card is face up")
        XCTAssertEqual(faceUpCount(model), 2, "exactly two cards are face up")
        XCTAssertTrue(model.isLocked, "two face-up cards lock the board")
    }

    // MARK: - Criterion 7

    /// While the board is locked, a tap on any of the 16 positions leaves
    /// every card state and the move count alone.
    func testTapsDoNothingWhileBoardIsLocked() {
        for position in 0..<16 {
            let model = GameModel(seed: 11)
            model.tap(0)
            model.tap(1)
            XCTAssertTrue(model.isLocked, "the board is locked before the tap")

            let before = model.cards
            let movesBefore = model.moveCount

            model.tap(position)

            XCTAssertEqual(
                model.cards,
                before,
                "a locked-board tap on \(position) changes no card"
            )
            XCTAssertEqual(
                model.moveCount,
                movesBefore,
                "a locked-board tap on \(position) changes no move count"
            )
            XCTAssertTrue(model.isLocked, "the board is still locked")
        }
    }

    // MARK: - Criterion 8

    /// Resolving a turn where both face-up cards carry the same symbol marks
    /// both matched, unlocks the board, and adds exactly 1 to the move count.
    func testResolvingAMatchMarksBothMatchedUnlocksAndCountsOneMove() {
        for seed in UInt64(1)...20 {
            let model = GameModel(seed: seed)
            let (first, second) = matchingPair(in: model)
            let before = model.cards

            model.tap(first)
            model.tap(second)
            model.resolveTurn()

            XCTAssertEqual(
                model.cards[first].state,
                .matched,
                "seed \(seed): position \(first) is matched"
            )
            XCTAssertEqual(
                model.cards[second].state,
                .matched,
                "seed \(seed): position \(second) is matched"
            )
            for other in 0..<16 where other != first && other != second {
                XCTAssertEqual(
                    model.cards[other],
                    before[other],
                    "seed \(seed): position \(other) is untouched"
                )
            }
            XCTAssertFalse(model.isLocked, "seed \(seed): the board is unlocked")
            XCTAssertEqual(
                model.moveCount,
                1,
                "seed \(seed): one resolved turn is one move"
            )
        }
    }

    // MARK: - Criterion 9

    /// Resolving a turn where the two face-up cards carry different symbols
    /// turns both back face down, unlocks the board, and adds exactly 1 to
    /// the move count.
    func testResolvingAMismatchTurnsBothBackDownUnlocksAndCountsOneMove() {
        for seed in UInt64(1)...20 {
            let model = GameModel(seed: seed)
            let (first, second) = mismatchedPair(in: model)
            let before = model.cards

            model.tap(first)
            model.tap(second)
            model.resolveTurn()

            XCTAssertEqual(
                model.cards[first].state,
                .faceDown,
                "seed \(seed): position \(first) is face down again"
            )
            XCTAssertEqual(
                model.cards[second].state,
                .faceDown,
                "seed \(seed): position \(second) is face down again"
            )
            XCTAssertEqual(
                model.cards,
                before,
                "seed \(seed): a mismatch leaves the whole board as it was"
            )
            XCTAssertFalse(model.isLocked, "seed \(seed): the board is unlocked")
            XCTAssertEqual(
                model.moveCount,
                1,
                "seed \(seed): one resolved turn is one move"
            )
        }
    }

    // MARK: - Criterion 10

    /// All 16 matched means won. Any card not matched means not won.
    func testIsWonOnlyWhenAllSixteenCardsAreMatched() {
        let won = board(states: [CardState](repeating: .matched, count: 16))
        XCTAssertTrue(won.isWon, "all 16 matched is a win")

        // One card short of a win, in every position and every non-matched
        // state.
        for position in 0..<16 {
            for state in [CardState.faceDown, .faceUp] {
                var states = [CardState](repeating: .matched, count: 16)
                states[position] = state
                XCTAssertFalse(
                    board(states: states).isWon,
                    "position \(position) in state \(state) is not a win"
                )
            }
        }

        // A fresh deal is never a win.
        for seed in UInt64(1)...20 {
            XCTAssertFalse(
                GameModel(seed: seed).isWon,
                "seed \(seed): a fresh deal is not a win"
            )
        }

        // Two cards short, face up as a locked pair.
        var pending = [CardState](repeating: .matched, count: 16)
        pending[4] = .faceUp
        pending[5] = .faceUp
        XCTAssertFalse(
            board(states: pending).isWon,
            "a board with a turn still open is not a win"
        )
    }

    // MARK: - Criterion 11

    /// Over every one of the 3^2 state pairs for positions 0 and 1, with the
    /// two symbols equal and unequal, no operation ever leaves three or more
    /// cards face up.
    func testNoOperationEverLeavesThreeOrMoreCardsFaceUp() {
        // Guard: the invariant is only worth checking if the operations do
        // something. A board that never turns a card up would satisfy it for
        // the wrong reason.
        let live = GameModel(seed: 3)
        live.tap(0)
        live.tap(1)
        XCTAssertEqual(faceUpCount(live), 2, "taps really do turn cards face up")

        var checked = 0

        for firstState in CardState.allCases {
            for secondState in CardState.allCases {
                for symbolsEqual in [true, false] {
                    // Every operation runs on its own fresh board.
                    for operation in 0...16 {
                        let model = makeProbeBoard(
                            firstState: firstState,
                            secondState: secondState,
                            symbolsEqual: symbolsEqual
                        )
                        XCTAssertLessThan(
                            faceUpCount(model),
                            3,
                            "the starting board itself never has 3 face up"
                        )

                        if operation < 16 {
                            model.tap(operation)
                        } else {
                            model.resolveTurn()
                        }

                        XCTAssertLessThan(
                            faceUpCount(model),
                            3,
                            "states \(firstState)/\(secondState), equal symbols \(symbolsEqual), operation \(operation): fewer than 3 cards face up"
                        )
                        checked += 1
                    }
                }
            }
        }

        XCTAssertEqual(checked, 3 * 3 * 2 * 17, "every combination was exercised")

        // Long runs of taps and resolutions hold the same invariant.
        for seed in UInt64(1)...20 {
            let model = GameModel(seed: seed)
            for step in 0..<200 {
                model.tap(step % 16)
                XCTAssertLessThan(
                    faceUpCount(model),
                    3,
                    "seed \(seed) step \(step): fewer than 3 cards face up after a tap"
                )
                if model.isLocked {
                    model.resolveTurn()
                    XCTAssertLessThan(
                        faceUpCount(model),
                        3,
                        "seed \(seed) step \(step): fewer than 3 cards face up after a resolve"
                    )
                }
            }
        }
    }

    /// A board where only positions 0 and 1 differ: their states are set, the
    /// other 14 cards are face down, and the two symbols are made equal or
    /// unequal on purpose.
    private func makeProbeBoard(
        firstState: CardState,
        secondState: CardState,
        symbolsEqual: Bool
    ) -> GameModel {
        var states = [CardState](repeating: .faceDown, count: 16)
        states[0] = firstState
        states[1] = secondState

        var symbols = Self.referenceSymbols
        symbols[0] = .star
        symbols[1] = symbolsEqual ? .star : .heart

        let cards = zip(symbols, states).map { Card(symbol: $0, state: $1) }
        return GameModel(cards: cards, moveCount: 0)
    }
}
