import XCTest
@testable import MemoryMatch

/// Two things the sequencing tests did not pin down: what a "move" counts, and
/// what a stray tap does while a mismatch is being held on screen.
///
/// These drive the model the way a player drives it — whole turns, taps on
/// whatever happens to be under a finger — rather than checking a step in
/// isolation. The fake clock and helpers come from `TurnSequencingTests`.
final class TurnCountingTests: XCTestCase {

    // MARK: - A move is a turn, not a tap

    func testAMatchedTurnCountsAsExactlyOneMove() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try samePair(in: model.cards)

        XCTAssertEqual(model.moveCount, 0, "a fresh board has no moves")

        model.tap(first)
        model.tap(second)
        clock.advance(to: 0.300)

        XCTAssertEqual(model.cards[first].state, .matched, "the pair matched")
        XCTAssertEqual(model.moveCount, 1, "one turn is one move, not one per card")
    }

    func testAMismatchedTurnCountsAsExactlyOneMove() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try differentPair(in: model.cards)

        model.tap(first)
        model.tap(second)
        clock.advance(to: 1.200)

        XCTAssertEqual(model.cards[first].state, .faceDown, "the pair flipped back")
        XCTAssertEqual(model.moveCount, 1, "one turn is one move, not one per card")
    }

    /// A perfect game — every turn a match — is eight turns, so eight moves.
    func testAPerfectGameOfEightTurnsCountsEightMoves() {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)

        for turn in 1...8 {
            guard let (first, second) = nextUnmatchedPair(in: model.cards) else {
                return XCTFail("turn \(turn): no face-down pair left to play")
            }
            model.tap(first)
            model.tap(second)
            clock.advance(by: 0.300)
            XCTAssertEqual(model.moveCount, turn, "after \(turn) matched turns")
        }

        XCTAssertTrue(
            model.cards.allSatisfy { $0.state == .matched },
            "all sixteen cards are matched"
        )
        XCTAssertEqual(model.moveCount, 8, "a perfect game reports eight moves")
    }

    // MARK: - A stray tap during the mismatch hold

    /// Brushing a card that is already matched must not cut the look at the
    /// mismatched pair short.
    func testTappingAMatchedCardDuringTheMismatchHoldChangesNothing() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)

        // Play one matching turn so the board has a matched card on it.
        let (matchedA, matchedB) = try samePair(in: model.cards)
        model.tap(matchedA)
        model.tap(matchedB)
        clock.advance(by: 0.300)
        XCTAssertEqual(model.cards[matchedA].state, .matched, "there is a matched card to brush")

        // Now open a mismatch hold.
        let (first, second) = try differentPair(
            in: model.cards, excluding: [matchedA, matchedB]
        )
        model.tap(first)
        model.tap(second)
        clock.advance(by: 0.300)
        XCTAssertEqual(model.cards[first].state, .faceUp, "the mismatch is on screen")
        XCTAssertEqual(model.cards[second].state, .faceUp, "the mismatch is on screen")

        let statesBefore = model.cards.map(\.state)
        let movesBefore = model.moveCount

        model.tap(matchedA)

        XCTAssertEqual(model.cards.map(\.state), statesBefore, "no card state changes")
        XCTAssertEqual(model.moveCount, movesBefore, "the move count does not change")
        XCTAssertTrue(model.isLocked, "the hold is still running")

        // The hold still ends on its own schedule: 900 ms from when it opened.
        clock.advance(by: 0.899)
        XCTAssertEqual(model.cards[first].state, .faceUp, "still held at 899 ms")
        clock.advance(by: 0.001)
        XCTAssertEqual(model.cards[first].state, .faceDown, "the hold ends at 900 ms")
        XCTAssertEqual(model.cards[second].state, .faceDown, "the hold ends at 900 ms")
        XCTAssertFalse(model.isLocked, "and the board unlocks then")
    }

    /// The same for a tap on one of the two cards the player just turned over.
    func testTappingAFaceUpCardDuringTheMismatchHoldChangesNothing() throws {
        let clock = TestClock()
        let model = GameModel(seed: 11, clock: clock)
        let (first, second) = try differentPair(in: model.cards)

        model.tap(first)
        model.tap(second)
        clock.advance(by: 0.300)

        let statesBefore = model.cards.map(\.state)
        let movesBefore = model.moveCount

        model.tap(first)

        XCTAssertEqual(model.cards.map(\.state), statesBefore, "no card state changes")
        XCTAssertEqual(model.moveCount, movesBefore, "the move count does not change")
        XCTAssertTrue(model.isLocked, "the hold is still running")

        clock.advance(by: 0.900)
        XCTAssertEqual(model.cards[first].state, .faceDown, "the hold ends on time")
        XCTAssertEqual(model.cards[second].state, .faceDown, "the hold ends on time")
    }

    // MARK: - Helpers

    private func samePair(in cards: [Card]) throws -> (Int, Int) {
        for i in cards.indices {
            for j in cards.indices
            where j > i && cards[i].symbol == cards[j].symbol
                && cards[i].state == .faceDown && cards[j].state == .faceDown {
                return (i, j)
            }
        }
        throw SetupError.noSuchPair
    }

    private func differentPair(
        in cards: [Card], excluding excluded: [Int] = []
    ) throws -> (Int, Int) {
        for i in cards.indices where !excluded.contains(i) && cards[i].state == .faceDown {
            for j in cards.indices
            where j > i && !excluded.contains(j) && cards[j].state == .faceDown
                && cards[i].symbol != cards[j].symbol {
                return (i, j)
            }
        }
        throw SetupError.noSuchPair
    }

    private func nextUnmatchedPair(in cards: [Card]) -> (Int, Int)? {
        try? samePair(in: cards)
    }

    private enum SetupError: Error { case noSuchPair }
}
