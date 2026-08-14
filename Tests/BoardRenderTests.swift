import SwiftUI
import XCTest
@testable import MemoryMatch

/// PP-2 — the board view renders model state in a 4x4 grid.
///
/// One test per acceptance criterion. Every expected value is written out
/// here by hand: no expectation is computed with the function it checks.
final class BoardRenderTests: XCTestCase {

    // MARK: - Reference table

    /// The whole input space of the display function: 8 symbols x 3 states.
    /// The expected appearance for each one, written out by hand.
    private static let referenceAppearances: [(Card, CardAppearance)] = [
        (Card(symbol: .star, state: .faceDown), .back),
        (Card(symbol: .star, state: .faceUp), .face(symbol: .star, matchedVeil: false)),
        (Card(symbol: .star, state: .matched), .face(symbol: .star, matchedVeil: true)),

        (Card(symbol: .heart, state: .faceDown), .back),
        (Card(symbol: .heart, state: .faceUp), .face(symbol: .heart, matchedVeil: false)),
        (Card(symbol: .heart, state: .matched), .face(symbol: .heart, matchedVeil: true)),

        (Card(symbol: .bolt, state: .faceDown), .back),
        (Card(symbol: .bolt, state: .faceUp), .face(symbol: .bolt, matchedVeil: false)),
        (Card(symbol: .bolt, state: .matched), .face(symbol: .bolt, matchedVeil: true)),

        (Card(symbol: .leaf, state: .faceDown), .back),
        (Card(symbol: .leaf, state: .faceUp), .face(symbol: .leaf, matchedVeil: false)),
        (Card(symbol: .leaf, state: .matched), .face(symbol: .leaf, matchedVeil: true)),

        (Card(symbol: .moon, state: .faceDown), .back),
        (Card(symbol: .moon, state: .faceUp), .face(symbol: .moon, matchedVeil: false)),
        (Card(symbol: .moon, state: .matched), .face(symbol: .moon, matchedVeil: true)),

        (Card(symbol: .umbrella, state: .faceDown), .back),
        (Card(symbol: .umbrella, state: .faceUp), .face(symbol: .umbrella, matchedVeil: false)),
        (Card(symbol: .umbrella, state: .matched), .face(symbol: .umbrella, matchedVeil: true)),

        (Card(symbol: .anchor, state: .faceDown), .back),
        (Card(symbol: .anchor, state: .faceUp), .face(symbol: .anchor, matchedVeil: false)),
        (Card(symbol: .anchor, state: .matched), .face(symbol: .anchor, matchedVeil: true)),

        (Card(symbol: .bell, state: .faceDown), .back),
        (Card(symbol: .bell, state: .faceUp), .face(symbol: .bell, matchedVeil: false)),
        (Card(symbol: .bell, state: .matched), .face(symbol: .bell, matchedVeil: true)),
    ]

    // MARK: - Criterion 1

    /// faceDown -> back, faceUp -> face with that card's symbol,
    /// matched -> face with the matched veil flag set. Every combination.
    func testEveryCardStateMapsToItsAppearance() {
        XCTAssertEqual(
            Self.referenceAppearances.count,
            24,
            "the reference table covers all 8 symbols in all 3 states"
        )

        for (card, expected) in Self.referenceAppearances {
            XCTAssertEqual(
                CardAppearance(card: card),
                expected,
                "\(card.symbol) in state \(card.state) renders as \(expected)"
            )
        }
    }

    // MARK: - Criterion 2

    /// The appearance depends only on the card value, so the same card
    /// always yields the same appearance — whatever else has happened.
    func testSameCardValueAlwaysYieldsSameAppearance() {
        let cards = Self.referenceAppearances.map { $0.0 }

        // Call once in order, once in reverse, once again in order. Every
        // call for a given card value must agree with the others.
        var firstPass: [CardAppearance] = []
        for card in cards {
            firstPass.append(CardAppearance(card: card))
        }
        for (index, card) in cards.enumerated().reversed() {
            XCTAssertEqual(
                CardAppearance(card: card),
                firstPass[index],
                "repeat call for \(card.symbol)/\(card.state) agrees with the first"
            )
        }

        // Two separately constructed cards holding the same value are
        // indistinguishable to the display function.
        for card in cards {
            let twin = Card(symbol: card.symbol, state: card.state)
            XCTAssertEqual(
                CardAppearance(card: twin),
                CardAppearance(card: card),
                "an equal card value gives an equal appearance"
            )
        }
    }

    // MARK: - Criterion 3

    /// Exactly 16 cells, as 4 rows of 4, in model index order 0...15.
    func testBoardBuildsSixteenCellsAsFourRowsOfFour() {
        let model = GameModel(seed: 7)
        let rows = BoardView(cards: model.cards).cellRows

        XCTAssertEqual(
            rows,
            [
                [0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11],
                [12, 13, 14, 15],
            ],
            "4 rows of 4, model index order 0 to 15"
        )
        XCTAssertEqual(rows.flatMap { $0 }.count, 16, "exactly 16 cells")
    }

    // MARK: - Criterion 4

    /// Board side 375 - 32 = 343. Card side = (343 - 3 * 10) / 4 = 78.25,
    /// and never below the 64 pt floor.
    func testCardSideFromBoardSide() {
        let boardSide: CGFloat = 375 - 32
        XCTAssertEqual(boardSide, 343, "the board side under test")

        let cardSide = BoardLayout.cardSide(boardSide: boardSide)
        XCTAssertEqual(
            cardSide,
            78.25,
            accuracy: 0.0001,
            "(343 - 3 * 10) / 4"
        )
        XCTAssertGreaterThanOrEqual(cardSide, 64, "the card side floor is 64 pt")

        // The floor holds even when the board is too small to honour it.
        XCTAssertGreaterThanOrEqual(
            BoardLayout.cardSide(boardSide: 200),
            64,
            "a cramped board still yields at least a 64 pt card"
        )
    }

    // MARK: - Criterion 5

    /// Board side = min(availableWidth - 32, availableHeight), and the
    /// board is square.
    func testBoardSideIsMinusInsetAndSquare() {
        // (available width, available height, expected side) — by hand.
        let cases: [(CGFloat, CGFloat, CGFloat)] = [
            (375, 812, 343),   // width - 32 wins
            (768, 500, 500),   // height wins
            (430, 398, 398),   // height wins by 0
            (320, 900, 288),   // width - 32 wins
            (1024, 992, 992),  // height wins
        ]

        for (width, height, expected) in cases {
            let size = BoardLayout.boardSize(
                availableWidth: width,
                availableHeight: height
            )
            XCTAssertEqual(
                size.width,
                expected,
                accuracy: 0.0001,
                "board side for \(width) x \(height)"
            )
            XCTAssertEqual(
                size.height,
                size.width,
                accuracy: 0.0001,
                "the board is square at \(width) x \(height)"
            )
        }
    }

    // MARK: - Criterion 6

    /// At launch the root view shows the dealt board — no menu, no splash,
    /// no overlay.
    func testRootViewShowsDealtBoardAtLaunch() {
        let root = ContentView()

        XCTAssertEqual(root.screen, .board, "the root screen is the board")
        XCTAssertNil(root.overlay, "no overlay is present at launch")
        XCTAssertEqual(root.cards.count, 16, "the board is dealt: 16 cards")
        XCTAssertTrue(
            root.cards.allSatisfy { $0.state == .faceDown },
            "a fresh deal starts every card face down"
        )
    }
}
