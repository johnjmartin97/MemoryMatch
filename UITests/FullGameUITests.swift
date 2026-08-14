import XCTest

/// PP-7 — accessibility labels, identifiers, and a full game driven through
/// the real app on a simulator.
///
/// Every test here talks to the app only the way VoiceOver and a player do:
/// by identifier, by spoken label, and by tapping. Nothing reaches inside the
/// app for state.
///
/// The identifiers this ticket fixes, and which element each one belongs to:
///
/// | Identifier        | Element                              |
/// |-------------------|--------------------------------------|
/// | `card-0`…`card-15`| the sixteen cards, in grid order     |
/// | `board.moveCount` | the move counter in the top bar      |
/// | `board.timer`     | the elapsed-time readout             |
/// | `board.restart`   | the restart control                  |
/// | `win.overlay`     | the win overlay panel                |
/// | `win.playAgain`   | the Play Again button on the overlay |
/// | `win.announcement`| see `testWinOverlayAnnouncesItself`  |
final class FullGameUITests: XCTestCase {

    // MARK: - The words the app is expected to speak

    /// The spoken name of each card face. These are the names the game
    /// already uses (`CardSymbol.accessibilityLabel`); a card label naming
    /// its face has to contain exactly one of them.
    private static let symbolNames = [
        "star",
        "heart",
        "lightning bolt",
        "leaf",
        "moon",
        "umbrella",
        "anchor",
        "bell",
    ]

    private static let faceDownWords = "face down"
    private static let faceUpWords = "face up"
    private static let matchedWord = "matched"

    /// How long a mismatched pair stays on show before it turns back down,
    /// plus a margin: 300 ms to judge, 900 ms on show.
    private static let mismatchWindow: TimeInterval = 1.2

    // MARK: - Launching

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches the app cold on a board nobody has played.
    ///
    /// `-savedGame` puts a plain string under the key the app saves its game
    /// to, in the argument domain, which sits above everything the app has
    /// written. The app asks for `Data` there, gets a string, and deals a
    /// fresh board — so one test never inherits the board another left.
    @discardableResult
    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-savedGame", "none"]
        app.launch()
        self.app = app
        XCTAssertTrue(
            card(0).waitForExistence(timeout: 30),
            "the board is on screen"
        )
        return app
    }

    // MARK: - Criterion 1: every card is identified by its grid index

    func testEveryCardExposesAnIdentifierMatchingItsGridIndex() {
        launchFreshApp()

        for index in 0..<16 {
            XCTAssertTrue(
                card(index).waitForExistence(timeout: 10),
                "a card is identified card-\(index)"
            )
        }

        XCTAssertFalse(
            card(16).exists,
            "there is no seventeenth card"
        )
    }

    // MARK: - Criterion 2: a face-down card says where it is, and no more

    func testFaceDownCardLabelsGiveRowAndColumnAndNoSymbol() {
        launchFreshApp()

        for index in 0..<16 {
            let label = card(index).label.lowercased()
            let row = index / 4 + 1
            let column = index % 4 + 1

            XCTAssertTrue(
                label.contains("row \(row)"),
                "card-\(index) says it is in row \(row), actual: \(card(index).label)"
            )
            XCTAssertTrue(
                label.contains("column \(column)"),
                "card-\(index) says it is in column \(column), actual: \(card(index).label)"
            )
            XCTAssertTrue(
                label.contains(Self.faceDownWords),
                "card-\(index) says it is face down, actual: \(card(index).label)"
            )
            for name in Self.symbolNames {
                XCTAssertFalse(
                    label.contains(name),
                    "a face-down card gives nothing away, but card-\(index) "
                        + "says \(name), actual: \(card(index).label)"
                )
            }
        }
    }

    // MARK: - Criterion 3: a turned card says where it is, its state, its face

    func testFaceUpAndMatchedCardLabelsGiveRowColumnStateAndSymbol() {
        launchFreshApp()

        // Turn one card. On an idle board a single card stays face up, so
        // there is no race to read it.
        card(0).tap()
        XCTAssertTrue(
            waitForLabel(of: 0, containing: Self.faceUpWords),
            "card-0 turned over, actual: \(card(0).label)"
        )

        let faceUp = card(0).label.lowercased()
        XCTAssertTrue(
            faceUp.contains("row 1") && faceUp.contains("column 1"),
            "the face-up card still says where it is, actual: \(card(0).label)"
        )
        guard let symbol = symbolName(in: faceUp) else {
            return XCTFail(
                "the face-up card names its face, actual: \(card(0).label)"
            )
        }

        // Find its partner and match the pair, so a matched label can be read.
        var partner: Int?
        for index in 1..<16 where partner == nil {
            settleBoard()
            card(0).tap()
            _ = waitForLabel(of: 0, containing: Self.faceUpWords)
            card(index).tap()
            if waitForLabel(of: index, containing: symbol, timeout: 3),
               symbolName(in: card(index).label.lowercased()) == symbol {
                partner = index
            }
        }

        guard let partner else {
            return XCTFail("the board holds a second \(symbol) card")
        }

        XCTAssertTrue(
            waitForLabel(of: partner, containing: Self.matchedWord, timeout: 5),
            "the matched pair says it is matched, actual: \(card(partner).label)"
        )

        for index in [0, partner] {
            let label = card(index).label.lowercased()
            let row = index / 4 + 1
            let column = index % 4 + 1
            XCTAssertTrue(
                label.contains("row \(row)") && label.contains("column \(column)"),
                "the matched card still says where it is, actual: \(card(index).label)"
            )
            XCTAssertTrue(
                label.contains(Self.matchedWord),
                "the matched card says it is matched, actual: \(card(index).label)"
            )
            XCTAssertEqual(
                symbolName(in: label),
                symbol,
                "the matched card still names its face, actual: \(card(index).label)"
            )
        }
    }

    // MARK: - Criterion 4: the counters, the control, and the overlay are named

    func testCountersRestartAndOverlayExposeStableIdentifiers() {
        launchFreshApp()

        XCTAssertTrue(
            element("board.moveCount").waitForExistence(timeout: 10),
            "the move counter is identified board.moveCount"
        )
        XCTAssertTrue(
            element("board.timer").exists,
            "the timer is identified board.timer"
        )
        XCTAssertTrue(
            element("board.restart").exists,
            "the restart control is identified board.restart"
        )

        playUntilWon()

        XCTAssertTrue(
            element("win.overlay").waitForExistence(timeout: 10),
            "the win overlay is identified win.overlay"
        )
        XCTAssertTrue(
            element("win.playAgain").exists,
            "the Play Again button is identified win.playAgain"
        )
    }

    // MARK: - Criterion 5: the overlay announces itself

    /// A UI test cannot listen for `UIAccessibility.post(.screenChanged:)`
    /// from outside the app — there is no API for it. So the app records the
    /// announcement it posted on an element identified `win.announcement`,
    /// and this test reads that record: the element exists only once the
    /// screen-changed announcement has gone out, and its label is the text
    /// that was announced.
    func testWinOverlayAnnouncesItself() {
        launchFreshApp()

        XCTAssertFalse(
            element("win.announcement").exists,
            "nothing has been announced before the game is won"
        )

        playUntilWon()

        let announcement = element("win.announcement")
        XCTAssertTrue(
            announcement.waitForExistence(timeout: 10),
            "the win overlay posted a screen-changed announcement"
        )
        XCTAssertFalse(
            announcement.label.trimmingCharacters(in: .whitespaces).isEmpty,
            "the announcement says something"
        )
    }

    // MARK: - Criterion 6: a cold launch lands straight on a playable board

    func testColdLaunchLandsOnAPlayableBoardWithNothingToDismiss() {
        launchFreshApp()

        XCTAssertEqual(app.alerts.count, 0, "no alert stands in the way")
        XCTAssertEqual(app.sheets.count, 0, "no sheet stands in the way")
        XCTAssertFalse(element("win.overlay").exists, "no overlay covers the board")

        XCTAssertTrue(card(5).isHittable, "a card can be tapped straight away")
        card(5).tap()
        XCTAssertTrue(
            waitForLabel(of: 5, containing: Self.faceUpWords),
            "the first tap of the session turned a card over, "
                + "actual: \(card(5).label)"
        )
    }

    // MARK: - Criterion 7: a whole game can be played through the labels

    func testPlayingEveryPairBringsUpTheWinOverlayWithTheMoveCount() {
        launchFreshApp()

        playUntilWon()

        XCTAssertTrue(
            element("win.overlay").waitForExistence(timeout: 10),
            "the win overlay appears once every pair is matched"
        )

        guard let moves = numberShown(by: element("board.moveCount")) else {
            return XCTFail("the move counter shows a number")
        }
        XCTAssertGreaterThanOrEqual(
            moves,
            8,
            "eight pairs take at least eight moves to match"
        )
    }

    // MARK: - Criterion 8: Play Again deals a fresh board

    func testPlayAgainDealsSixteenFaceDownCardsAndZeroMoves() {
        launchFreshApp()

        playUntilWon()

        let playAgain = element("win.playAgain")
        XCTAssertTrue(playAgain.waitForExistence(timeout: 10), "Play Again is on the overlay")
        playAgain.tap()

        XCTAssertTrue(
            waitForLabel(of: 0, containing: Self.faceDownWords, timeout: 10),
            "the new board is dealt face down"
        )
        XCTAssertFalse(element("win.overlay").exists, "the overlay has gone")

        for index in 0..<16 {
            XCTAssertTrue(
                card(index).label.lowercased().contains(Self.faceDownWords),
                "card-\(index) is face down again, actual: \(card(index).label)"
            )
        }

        XCTAssertEqual(
            numberShown(by: element("board.moveCount")),
            0,
            "the move counter is back to zero"
        )
    }

    // MARK: - Reaching the app

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func card(_ index: Int) -> XCUIElement {
        element("card-\(index)")
    }

    /// The spoken face name in a label, or `nil` if it names none.
    private func symbolName(in label: String) -> String? {
        Self.symbolNames.first { label.contains($0) }
    }

    /// The first whole number anywhere in an element — its label, its value,
    /// or the texts inside it.
    private func numberShown(by element: XCUIElement) -> Int? {
        var text = element.label
        if let value = element.value as? String { text += " " + value }
        for child in element.descendants(matching: .staticText).allElementsBoundByIndex {
            text += " " + child.label
        }

        var digits = ""
        for character in text where character.isNumber || !digits.isEmpty {
            if character.isNumber {
                digits.append(character)
            } else {
                break
            }
        }
        return Int(digits)
    }

    private func waitForLabel(
        of index: Int,
        containing text: String,
        timeout: TimeInterval = 5
    ) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: card(index)
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until no card is part-way through a turn: nothing face up.
    private func settleBoard(timeout: TimeInterval = 6) {
        let faceUp = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.faceUpWords)
        )
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if faceUp.count == 0 { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    // MARK: - Playing the game the way a player does

    /// Plays the board to a win, reading every card off its accessibility
    /// label. Nothing about the deal is known in advance: the cards are
    /// turned over, remembered by the face they name, and matched.
    private func playUntilWon() {
        var known: [Int: String] = [:]
        var matched = Set<Int>()
        var turns = 0

        while matched.count < 16 {
            turns += 1
            guard turns <= 60 else {
                return XCTFail(
                    "the game was still unfinished after 60 turns: "
                        + "\(matched.count) of 16 cards matched"
                )
            }

            settleBoard()

            // A pair both faces of which are already known: match it.
            if let (first, second) = knownPair(known: known, matched: matched) {
                card(first).tap()
                card(second).tap()
                if waitForLabel(of: second, containing: Self.matchedWord) {
                    matched.formUnion([first, second])
                }
                continue
            }

            // Otherwise turn over a card nobody has seen. A lone face-up card
            // stays up, so this read is never a race.
            guard let first = unseen(known: known, matched: matched, except: nil) else {
                return XCTFail("no card left to turn over")
            }
            card(first).tap()
            guard waitForLabel(of: first, containing: Self.faceUpWords),
                  let firstSymbol = symbolName(in: card(first).label.lowercased())
            else {
                return XCTFail(
                    "card-\(first) named its face when turned over, "
                        + "actual: \(card(first).label)"
                )
            }
            known[first] = firstSymbol

            // Its partner may already be known — then this turn is a match.
            if let partner = known.first(where: { index, symbol in
                index != first && symbol == firstSymbol && !matched.contains(index)
            })?.key {
                card(partner).tap()
                if waitForLabel(of: partner, containing: Self.matchedWord) {
                    matched.formUnion([first, partner])
                }
                continue
            }

            // Nothing known matches it, so turn over another new card.
            guard let second = unseen(known: known, matched: matched, except: first) else {
                continue
            }
            card(second).tap()
            if waitForLabel(of: second, containing: Self.matchedWord, timeout: 3) {
                // It matched, so it wore the same face.
                known[second] = firstSymbol
                matched.formUnion([first, second])
                continue
            }
            if let secondSymbol = symbolName(in: card(second).label.lowercased()) {
                known[second] = secondSymbol
            }
            // A mismatch goes back down on its own; wait it out.
            Thread.sleep(forTimeInterval: Self.mismatchWindow)
        }

        XCTAssertEqual(matched.count, 16, "all eight pairs were matched")
    }

    /// Two unmatched cards already known to wear the same face.
    private func knownPair(
        known: [Int: String],
        matched: Set<Int>
    ) -> (Int, Int)? {
        let open = known.filter { !matched.contains($0.key) }
        for (index, symbol) in open.sorted(by: { $0.key < $1.key }) {
            if let other = open.first(where: { $0.key != index && $0.value == symbol })?.key {
                return (index, other)
            }
        }
        return nil
    }

    /// The lowest card that is neither matched nor yet seen.
    private func unseen(
        known: [Int: String],
        matched: Set<Int>,
        except: Int?
    ) -> Int? {
        (0..<16).first { index in
            index != except && known[index] == nil && !matched.contains(index)
        }
    }
}
