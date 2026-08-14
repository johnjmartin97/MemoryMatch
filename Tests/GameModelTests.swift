import XCTest
@testable import MemoryMatch

/// PP-1 — the core game model: deal, card states, turn resolution, win detection.
///
/// One test per acceptance criterion. Every expected value is written out here
/// by hand: no expectation is computed with the code it checks.
final class GameModelTests: XCTestCase {

    // MARK: - Fixtures

    /// The eight symbols, written out rather than read from `allCases`, so the
    /// test still fails if a symbol is ever added or dropped by mistake.
    private static let eightSymbols: [CardSymbol] = [
        .star, .heart, .bolt, .leaf, .moon, .umbrella, .anchor, .bell,
    ]

    /// A hand-written board. Eight symbols, each twice. Positions 0 and 1
    /// carry *different* symbols.
    /// Pairs: 0-15 star, 1-14 heart, 2-13 bolt, 3-12 leaf,
    ///        4-11 moon, 5-10 umbrella, 6-9 anchor, 7-8 bell.
    private static let unequalLayout: [CardSymbol] = [
        .star, .heart, .bolt, .leaf, .moon, .umbrella, .anchor, .bell,
        .bell, .anchor, .umbrella, .moon, .leaf, .bolt, .heart, .star,
    ]

    /// The same board rotated so positions 0 and 1 carry the *same* symbol.
    /// Pairs: 0-1 star, 2-15 heart, 3-14 bolt, 4-13 leaf,
    ///        5-12 moon, 6-11 umbrella, 7-10 anchor, 8-9 bell.
    private static let equalLayout: [CardSymbol] = [
        .star, .star, .heart, .bolt, .leaf, .moon, .umbrella, .anchor,
        .bell, .bell, .anchor, .umbrella, .moon, .leaf, .bolt, .heart,
    ]

    /// Builds a board from a layout with every card in `state`.
    private func cards(
        _ layout: [CardSymbol],
        allIn state: CardState = .faceDown
    ) -> [Card] {
        layout.map { Card(symbol: $0, state: state) }
    }

    // MARK: - Criterion 1

    /// A new deal is 16 cards, 8 distinct symbols each appearing exactly
    /// twice, every card face down.
    func testNewDealIsSixteenFaceDownCardsOfEightSymbolPairs() {
        for seed in UInt64(0)..<20 {
            let model = GameModel(seed: seed)

            XCTAssertEqual(model.cards.count, 16, "seed \(seed) deals 16 cards")

            for symbol in Self.eightSymbols {
                let count = model.cards.filter { $0.symbol == symbol }.count
                XCTAssertEqual(
                    count,
                    2,
                    "seed \(seed): \(symbol) appears exactly twice"
                )
            }

            XCTAssertEqual(
                Set(model.cards.map { $0.symbol }).count,
                8,
                "seed \(seed): exactly 8 distinct symbols"
            )

            XCTAssertTrue(
                model.cards.allSatisfy { $0.state == .faceDown },
                "seed \(seed): every card starts face down"
            )
        }
    }

    // MARK: - Criterion 2

    /// Over 1000 seeded deals, every position holds every symbol at least
    /// once — so the shuffle reaches the whole board, not a fixed pattern.
    func testEveryPositionHoldsEverySymbolAcrossAThousandSeededDeals() {
        var seen: [Set<CardSymbol>] = Array(repeating: [], count: 16)

        for seed in UInt64(0)..<1000 {
            let model = GameModel(seed: seed)
            XCTAssertEqual(model.cards.count, 16, "seed \(seed) deals 16 cards")
            for position in 0..<16 {
                seen[position].insert(model.cards[position].symbol)
            }
        }

        for position in 0..<16 {
            for symbol in Self.eightSymbols {
                XCTAssertTrue(
                    seen[position].contains(symbol),
                    "position \(position) held \(symbol) in at least one of 1000 deals"
                )
            }
        }
    }

    // MARK: - Criterion 3

    /// Two different seeds deal a different position-to-symbol order.
    func testTwoDifferentSeedsDealDifferentOrders() {
        let seedPairs: [(UInt64, UInt64)] = [
            (1, 2), (7, 8), (42, 99), (0, 1000), (123_456, 654_321),
        ]

        for (first, second) in seedPairs {
            let a = GameModel(seed: first).cards.map { $0.symbol }
            let b = GameModel(seed: second).cards.map { $0.symbol }
            XCTAssertNotEqual(
                a,
                b,
                "seeds \(first) and \(second) deal different orders"
            )
        }

        // The same seed is repeatable — otherwise "different seeds differ"
        // would be satisfied by a shuffle that ignores the seed entirely.
        for seed in [UInt64(1), 7, 42, 123_456] {
            XCTAssertEqual(
                GameModel(seed: seed).cards.map { $0.symbol },
                GameModel(seed: seed).cards.map { $0.symbol },
                "seed \(seed) deals the same order twice"
            )
        }
    }

    // MARK: - Criterion 4

    /// Every position, every card state, board locked and unlocked: the tap
    /// is accepted only for a face-down card on an unlocked board. In every
    /// other case the card states and the move count are untouched.
    func testTapIsAcceptedOnlyOnAFaceDownCardOfAnUnlockedBoard() {
        for position in 0..<16 {
            for state in [CardState.faceDown, .faceUp, .matched] {
                for locked in [false, true] {
                    var board = cards(Self.unequalLayout)
                    board[position].state = state

                    // A locked board holds exactly two face-up cards. If the
                    // card under test is already one of them, only one more
                    // is needed.
                    if locked {
                        let needed = state == .faceUp ? 1 : 2
                        for other in (0..<16).filter({ $0 != position })
                            .prefix(needed) {
                            board[other].state = .faceUp
                        }
                    }

                    let model = GameModel(
                        cards: board,
                        moveCount: 3,
                        isLocked: locked
                    )
                    model.tap(position)

                    let shouldAccept = (state == .faceDown) && !locked
                    let context =
                        "position \(position), state \(state), locked \(locked)"

                    if shouldAccept {
                        var expected = board
                        expected[position].state = .faceUp
                        XCTAssertEqual(
                            model.cards,
                            expected,
                            "\(context): the tap turns exactly that card face up"
                        )
                    } else {
                        XCTAssertEqual(
                            model.cards,
                            board,
                            "\(context): the tap is refused, card states unchanged"
                        )
                    }

                    XCTAssertEqual(
                        model.moveCount,
                        3,
                        "\(context): a tap never changes the move count"
                    )
                }
            }
        }
    }

    // MARK: - Criterion 5

    /// The first tap turns exactly that card face up, leaves the other 15
    /// alone, and leaves the board unlocked.
    func testFirstTapTurnsOneCardFaceUpAndLeavesTheBoardUnlocked() {
        for position in 0..<16 {
            let board = cards(Self.unequalLayout)
            let model = GameModel(cards: board)

            model.tap(position)

            var expected = board
            expected[position].state = .faceUp
            XCTAssertEqual(
                model.cards,
                expected,
                "tapping \(position) turns up that card and nothing else"
            )
            XCTAssertEqual(
                model.cards.filter { $0.state == .faceUp }.count,
                1,
                "exactly one card is face up after the first tap"
            )
            XCTAssertFalse(
                model.isLocked,
                "the board stays unlocked after one tap"
            )
            XCTAssertEqual(model.moveCount, 0, "one tap is not a move")
        }
    }

    // MARK: - Criterion 6

    /// The second tap turns that card face up too, and locks the board.
    func testSecondTapTurnsItFaceUpAndLocksTheBoard() {
        for first in 0..<16 {
            for second in (0..<16).filter({ $0 != first }) {
                let board = cards(Self.unequalLayout)
                let model = GameModel(cards: board)

                model.tap(first)
                model.tap(second)

                var expected = board
                expected[first].state = .faceUp
                expected[second].state = .faceUp
                XCTAssertEqual(
                    model.cards,
                    expected,
                    "tapping \(first) then \(second) turns up exactly those two"
                )
                XCTAssertTrue(
                    model.isLocked,
                    "the board locks once two cards are face up (\(first), \(second))"
                )
                XCTAssertEqual(
                    model.moveCount,
                    0,
                    "the move is not counted until the turn resolves"
                )
            }
        }
    }

    // MARK: - Criterion 7

    /// While the board is locked, a tap on any of the 16 positions changes
    /// nothing at all.
    func testTapsDoNothingWhileTheBoardIsLocked() {
        let board = cards(Self.unequalLayout)
        let model = GameModel(cards: board, moveCount: 5)

        model.tap(0)
        model.tap(1)
        XCTAssertTrue(model.isLocked, "two taps lock the board")

        let locked = model.cards

        for position in 0..<16 {
            model.tap(position)
            XCTAssertEqual(
                model.cards,
                locked,
                "tapping \(position) on a locked board changes no card"
            )
            XCTAssertEqual(
                model.moveCount,
                5,
                "tapping \(position) on a locked board changes no move count"
            )
            XCTAssertTrue(
                model.isLocked,
                "tapping \(position) does not unlock the board"
            )
        }
    }

    // MARK: - Criterion 8

    /// Two face-up cards with the same symbol: both become matched, the board
    /// unlocks, and the move count goes up by exactly one.
    func testResolvingAMatchingPairMarksBothMatchedAndCountsOneMove() {
        // Every pair of positions that holds the same symbol on the
        // hand-written board, written out by hand.
        let matchingPairs: [(Int, Int)] = [
            (0, 15), (1, 14), (2, 13), (3, 12),
            (4, 11), (5, 10), (6, 9), (7, 8),
        ]

        for (first, second) in matchingPairs {
            let board = cards(Self.unequalLayout)
            let model = GameModel(cards: board, moveCount: 4)

            model.tap(first)
            model.tap(second)
            model.resolveTurn()

            var expected = board
            expected[first].state = .matched
            expected[second].state = .matched
            XCTAssertEqual(
                model.cards,
                expected,
                "matching \(first) and \(second) marks both matched, nothing else"
            )
            XCTAssertFalse(
                model.isLocked,
                "the board unlocks after a match at \(first), \(second)"
            )
            XCTAssertEqual(
                model.moveCount,
                5,
                "a resolved match counts exactly one move"
            )
        }
    }

    // MARK: - Criterion 9

    /// Two face-up cards with different symbols: both go back face down, the
    /// board unlocks, and the move count goes up by exactly one.
    func testResolvingAMismatchTurnsBothBackDownAndCountsOneMove() {
        // Pairs of positions holding different symbols on the hand-written
        // board, written out by hand.
        let mismatchedPairs: [(Int, Int)] = [
            (0, 1), (0, 14), (1, 2), (2, 3), (3, 4),
            (5, 11), (6, 8), (7, 9), (10, 13), (12, 15),
        ]

        for (first, second) in mismatchedPairs {
            let board = cards(Self.unequalLayout)
            let model = GameModel(cards: board, moveCount: 4)

            model.tap(first)
            model.tap(second)
            model.resolveTurn()

            XCTAssertEqual(
                model.cards,
                board,
                "a mismatch at \(first), \(second) leaves the board as it was"
            )
            XCTAssertFalse(
                model.isLocked,
                "the board unlocks after a mismatch at \(first), \(second)"
            )
            XCTAssertEqual(
                model.moveCount,
                5,
                "a resolved mismatch counts exactly one move"
            )
        }
    }

    // MARK: - Criterion 10

    /// `isWon` is true exactly when all 16 cards are matched.
    func testIsWonOnlyWhenEveryCardIsMatched() {
        let allMatched = cards(Self.unequalLayout, allIn: .matched)
        XCTAssertTrue(
            GameModel(cards: allMatched).isWon,
            "a board of 16 matched cards is won"
        )

        // Every board that is one card short of matched, for each position
        // and each of the two non-matched states.
        for position in 0..<16 {
            for state in [CardState.faceDown, .faceUp] {
                var board = allMatched
                board[position].state = state
                XCTAssertFalse(
                    GameModel(cards: board).isWon,
                    "position \(position) in state \(state) means not won"
                )
            }
        }

        // Boards with 1 through 16 cards still face down.
        for unmatched in 1...16 {
            var board = allMatched
            for position in 0..<unmatched {
                board[position].state = .faceDown
            }
            XCTAssertFalse(
                GameModel(cards: board).isWon,
                "\(unmatched) card(s) face down means not won"
            )
        }

        // A fresh deal is not won.
        XCTAssertFalse(GameModel(seed: 7).isWon, "a fresh deal is not won")
    }

    // MARK: - Criterion 11

    /// Across all 9 state pairs for positions 0 and 1, on a board where those
    /// two carry the same symbol and on one where they carry different
    /// symbols, locked and unlocked: no tap and no resolve ever leaves three
    /// or more cards face up.
    func testNoOperationEverLeavesThreeCardsFaceUp() {
        let states: [CardState] = [.faceDown, .faceUp, .matched]
        var scenarios = 0

        for layout in [Self.equalLayout, Self.unequalLayout] {
            for stateOfFirst in states {
                for stateOfSecond in states {
                    for locked in [false, true] {
                        var board = cards(layout)
                        board[0].state = stateOfFirst
                        board[1].state = stateOfSecond
                        scenarios += 1

                        let label =
                            "0=\(stateOfFirst) 1=\(stateOfSecond) locked=\(locked)"

                        // Each operation is applied to its own fresh model.
                        for position in 0..<16 {
                            let model = GameModel(cards: board, isLocked: locked)
                            model.tap(position)
                            assertAtMostTwoFaceUp(
                                model,
                                "\(label): after tapping \(position)"
                            )
                        }

                        let resolved = GameModel(cards: board, isLocked: locked)
                        resolved.resolveTurn()
                        assertAtMostTwoFaceUp(resolved, "\(label): after resolve")

                        // And a whole turn run end to end.
                        let turn = GameModel(cards: board, isLocked: locked)
                        for position in 0..<16 {
                            turn.tap(position)
                            assertAtMostTwoFaceUp(
                                turn,
                                "\(label): during a run, after tapping \(position)"
                            )
                            turn.resolveTurn()
                            assertAtMostTwoFaceUp(
                                turn,
                                "\(label): during a run, after resolving at \(position)"
                            )
                        }
                    }
                }
            }
        }

        XCTAssertEqual(
            scenarios,
            36,
            "2 layouts x 9 state pairs x 2 lock states were enumerated"
        )
    }

    private func assertAtMostTwoFaceUp(
        _ model: GameModel,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let faceUp = model.cards.filter { $0.state == .faceUp }.count
        XCTAssertLessThanOrEqual(
            faceUp,
            2,
            "\(context): \(faceUp) cards face up",
            file: file,
            line: line
        )
    }
}
