import XCTest
@testable import MemoryMatch

/// Review findings on PP-4's model, written as the player's experience.
///
/// Three things a reviewer found that the existing tests did not cover: what a
/// "move" means, what a stray tap during the mismatch hold does, and what
/// happens when the saved game on disk is not a whole board.
final class TurnAndRestoreIntegrityTests: XCTestCase {

    // MARK: - Finding 1: a move is a turn, not a tap

    func testAMatchedTurnCountsAsOneMove() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        let (a, b) = try twoPositionsWithTheSameSymbol(in: model)
        model.tap(a)
        model.tap(b)
        clock.advance(by: 0.3)

        XCTAssertEqual(model.cards[a].state, .matched, "the pair is matched")
        XCTAssertEqual(model.cards[b].state, .matched, "both of it")
        XCTAssertEqual(
            model.moveCount, 1,
            "turning over two cards is one move, not two"
        )
    }

    func testAMismatchedTurnAlsoCountsAsOneMove() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        let (a, b) = try twoPositionsWithDifferentSymbols(in: model)
        model.tap(a)
        model.tap(b)
        clock.advance(by: 2.0)

        XCTAssertEqual(model.cards[a].state, .faceDown, "the pair went back down")
        XCTAssertEqual(
            model.moveCount, 1,
            "a failed turn costs one move, the same as a good one"
        )
    }

    func testHalfATurnHasNotCostAMoveYet() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        model.tap(0)
        clock.advance(by: 0.1)

        XCTAssertEqual(model.cards[0].state, .faceUp, "one card is up")
        XCTAssertEqual(
            model.moveCount, 0,
            "the move is not spent until the turn resolves"
        )
    }

    func testAPerfectGameCountsEightMoves() {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        playEveryPair(model, clock: clock)

        XCTAssertEqual(
            model.cards.filter { $0.state == .matched }.count, 16,
            "the board is finished"
        )
        XCTAssertEqual(
            model.moveCount, 8,
            "eight pairs found without a single mistake is eight moves"
        )
    }

    // MARK: - Finding 2: a stray tap during the mismatch hold changes nothing

    func testTappingAMatchedCardDuringTheMismatchHoldLeavesTheBoardAlone() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 11, clock: clock)

        // One pair matched, so there is a matched card on screen to brush.
        playPairs(1, in: model, clock: clock)
        let matchedIndex = try firstIndex(ofState: .matched, in: model)

        // Now a turn that misses, held face up for the player to look at.
        let (a, b) = try twoFaceDownPositionsWithDifferentSymbols(in: model)
        model.tap(a)
        model.tap(b)
        clock.advance(by: 0.3)
        XCTAssertEqual(model.cards[a].state, .faceUp, "the miss is on show")
        XCTAssertEqual(model.cards[b].state, .faceUp, "both cards of it")

        let statesBefore = model.cards.map(\.state)
        let movesBefore = model.moveCount

        model.tap(matchedIndex)

        XCTAssertEqual(
            model.cards.map(\.state), statesBefore,
            "brushing a matched card does not snap the miss face down"
        )
        XCTAssertEqual(model.moveCount, movesBefore, "and costs nothing")

        // The hold still ends on its own schedule.
        clock.advance(by: 2.0)
        XCTAssertEqual(model.cards[a].state, .faceDown, "the miss turns back down after")
        XCTAssertEqual(model.cards[b].state, .faceDown, "both cards of it")
    }

    func testTappingAFaceUpCardDuringTheMismatchHoldLeavesTheBoardAlone() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 17, clock: clock)

        let (a, b) = try twoPositionsWithDifferentSymbols(in: model)
        model.tap(a)
        model.tap(b)
        clock.advance(by: 0.3)

        let statesBefore = model.cards.map(\.state)
        let movesBefore = model.moveCount

        model.tap(a)

        XCTAssertEqual(
            model.cards.map(\.state), statesBefore,
            "tapping one of the two cards already up changes nothing"
        )
        XCTAssertEqual(model.moveCount, movesBefore, "and costs nothing")
    }

    func testTappingAFaceDownCardDuringTheMismatchHoldStillPlaysAhead() throws {
        let clock = ManualClock()
        let model = GameModel(seed: 17, clock: clock)

        let (a, b) = try twoPositionsWithDifferentSymbols(in: model)
        model.tap(a)
        model.tap(b)
        clock.advance(by: 0.3)

        let next = try XCTUnwrap(
            model.cards.indices.first { $0 != a && $0 != b && model.cards[$0].state == .faceDown },
            "there is another card to play"
        )
        model.tap(next)

        XCTAssertEqual(model.cards[a].state, .faceDown, "the miss is cleared away")
        XCTAssertEqual(model.cards[b].state, .faceDown, "both cards of it")
        XCTAssertEqual(model.cards[next].state, .faceUp, "the played-ahead card is up")
    }

    // MARK: - Finding 3: a save that is not a whole board is not a save

    func testRestoringASaveWithTooFewStatesDealsAFreshBoard() {
        // A crash mid-write, or an older build: 16 symbols, 10 states.
        let symbols = CardSymbol.allCases.flatMap { [$0, $0] }
        let saved = SavedGame(
            symbols: symbols,
            states: Array(repeating: .faceDown, count: 10),
            moveCount: 3,
            elapsed: 12
        )

        let model = GameModel(restoring: saved, seed: 7, clock: ManualClock())

        XCTAssertEqual(model.cards.count, 16, "a whole board, not ten cards")
        XCTAssertTrue(model.cards.allSatisfy { $0.state == .faceDown }, "all face down")
        XCTAssertEqual(model.moveCount, 0, "a fresh deal starts at zero moves")
        XCTAssertEqual(model.elapsed, 0, accuracy: 1e-9, "and zero time")
        assertIsAWellFormedDeal(model.cards)
    }

    func testRestoringASaveWithTooFewSymbolsDealsAFreshBoard() {
        let saved = SavedGame(
            symbols: Array(CardSymbol.allCases.prefix(4)),
            states: Array(repeating: .faceDown, count: 16),
            moveCount: 2,
            elapsed: 5
        )

        let model = GameModel(restoring: saved, seed: 7, clock: ManualClock())

        XCTAssertEqual(model.cards.count, 16, "a whole board")
        assertIsAWellFormedDeal(model.cards)
        XCTAssertEqual(model.moveCount, 0, "a fresh deal starts at zero moves")
    }

    func testRestoringASaveWhoseSymbolsAreNotEightPairsDealsAFreshBoard() {
        // 16 cards, but the symbols do not pair up — the game is unwinnable.
        let saved = SavedGame(
            symbols: Array(repeating: .star, count: 16),
            states: Array(repeating: .faceDown, count: 16),
            moveCount: 1,
            elapsed: 1
        )

        let model = GameModel(restoring: saved, seed: 7, clock: ManualClock())

        XCTAssertEqual(model.cards.count, 16, "a whole board")
        assertIsAWellFormedDeal(model.cards)
        XCTAssertEqual(model.moveCount, 0, "a fresh deal starts at zero moves")
    }

    func testAGoodSaveIsStillRestored() {
        let clock = ManualClock()
        let model = GameModel(seed: 23, clock: clock)
        playPairs(2, in: model, clock: clock)
        let saved = model.snapshot()

        let restored = GameModel(restoring: saved, seed: 999, clock: ManualClock())

        XCTAssertEqual(restored.cards.map(\.symbol), model.cards.map(\.symbol), "same layout")
        XCTAssertEqual(restored.cards.map(\.state), model.cards.map(\.state), "same states")
        XCTAssertEqual(restored.moveCount, model.moveCount, "same move count")
    }

    // MARK: - Helpers

    private func playPairs(_ count: Int, in model: GameModel, clock: ManualClock) {
        var played = 0
        for symbol in CardSymbol.allCases where played < count {
            let positions = model.cards.indices.filter { model.cards[$0].symbol == symbol }
            guard positions.count == 2 else { continue }
            model.tap(positions[0])
            model.tap(positions[1])
            clock.advance(by: 2.0)
            played += 1
        }
        XCTAssertEqual(played, count, "the setup matched \(count) pair(s)")
    }

    private func playEveryPair(_ model: GameModel, clock: ManualClock) {
        playPairs(CardSymbol.allCases.count, in: model, clock: clock)
    }

    private func firstIndex(ofState state: CardState, in model: GameModel) throws -> Int {
        try XCTUnwrap(
            model.cards.firstIndex(where: { $0.state == state }),
            "no card is \(state)"
        )
    }

    private func twoPositionsWithTheSameSymbol(in model: GameModel) throws -> (Int, Int) {
        let cards = model.cards
        for i in cards.indices {
            for j in cards.indices where j > i && cards[i].symbol == cards[j].symbol {
                return (i, j)
            }
        }
        throw TestSetupError.noSuchPair
    }

    private func twoPositionsWithDifferentSymbols(in model: GameModel) throws -> (Int, Int) {
        let cards = model.cards
        for i in cards.indices {
            for j in cards.indices where j > i && cards[i].symbol != cards[j].symbol {
                return (i, j)
            }
        }
        throw TestSetupError.noSuchPair
    }

    private func twoFaceDownPositionsWithDifferentSymbols(in model: GameModel) throws -> (Int, Int) {
        let cards = model.cards
        let open = cards.indices.filter { cards[$0].state == .faceDown }
        for i in open {
            for j in open where j > i && cards[i].symbol != cards[j].symbol {
                return (i, j)
            }
        }
        throw TestSetupError.noSuchPair
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
        case noSuchPair
    }
}
