import AVFoundation
import SwiftUI
import XCTest
@testable import MemoryMatch

/// PP-6 — motion, the win overlay, the celebration effects, sound.
///
/// One test per acceptance criterion. Every expected number is written out
/// here by hand, copied from the ticket and `ART.md`; nothing is computed by
/// the code under test.
///
/// The app is expected to answer these questions through a small set of
/// values, so a test can ask what an animation resolves to without rendering
/// it:
///
/// - `Motion.flip(reduceMotion:)`, `Motion.matchPop(reduceMotion:)`,
///   `Motion.confetti(reduceMotion:)`, `Motion.deal` — one value per
///   interaction, resolved for the Reduce Motion setting.
/// - `Motion.flipFacing(atDegrees:)` — which side shows part-way through a
///   flip.
/// - `Motion.matchResolveMilliseconds(reduceMotion:)` and
///   `Motion.mismatchResolveMilliseconds(reduceMotion:)` — the turn timings
///   the model runs on.
/// - `MatchSparkleView` and `ConfettiView` — their particle counts, sizes and
///   travel, readable without drawing.
/// - `GameSession.isWinOverlayPresented`, `GameSession.playAgain()` and
///   `WinOverlayView` — the win overlay.
/// - `SoundEffect` and `SoundPlayer` — the three bundled sounds and the audio
///   session category.
final class MotionAndCelebrationTests: XCTestCase {

    // MARK: - A clock the test drives

    /// Runs delayed work only when the test moves time past its due moment.
    /// Unlike a real timer nothing here happens on its own, so every deadline
    /// in this file is exact.
    private final class TestClock: TurnClock {
        /// Milliseconds since the clock started.
        private(set) var nowMilliseconds = 0

        private var pending: [(dueAt: Int, work: () -> Void)] = []

        /// Seconds since the clock started, for the session's own timer.
        var nowSeconds: TimeInterval { TimeInterval(nowMilliseconds) / 1000 }

        var hasPendingWork: Bool { !pending.isEmpty }

        func schedule(after milliseconds: Int, _ work: @escaping () -> Void) {
            precondition(milliseconds >= 0, "a delay cannot run backwards")
            pending.append((nowMilliseconds + milliseconds, work))
        }

        func cancelPending() {
            pending.removeAll()
        }

        /// Moves time forward, running whatever falls due on the way, in due
        /// order. Work that schedules more work is run too.
        func advance(by milliseconds: Int) {
            let target = nowMilliseconds + milliseconds
            while let next = pending.filter({ $0.dueAt <= target })
                .min(by: { $0.dueAt < $1.dueAt }) {
                pending.removeAll { $0.dueAt == next.dueAt }
                nowMilliseconds = next.dueAt
                next.work()
            }
            nowMilliseconds = target
        }
    }

    // MARK: - Fixtures

    /// A fixed 16-card layout: the eight symbols, each exactly twice.
    /// Positions 0 and 15 both hold `star`; positions 0 and 1 differ.
    private static let referenceSymbols: [CardSymbol] = [
        .star, .heart, .bolt, .leaf,
        .moon, .umbrella, .anchor, .bell,
        .bell, .anchor, .umbrella, .moon,
        .leaf, .bolt, .heart, .star,
    ]

    private static let matchingPair = (first: 0, second: 15)
    private static let mismatchedPair = (first: 0, second: 1)

    private func freshBoard(_ clock: TestClock) -> GameModel {
        let cards = Self.referenceSymbols.map {
            Card(symbol: $0, state: .faceDown)
        }
        return GameModel(cards: cards, moveCount: 0, clock: clock)
    }

    /// The two positions holding `symbol`.
    private func positions(
        of symbol: CardSymbol,
        in session: GameSession
    ) -> [Int] {
        session.cards.indices.filter { session.cards[$0].symbol == symbol }
    }

    // MARK: - Criterion 1: the flip

    /// 300 ms easeInOut, rotated about the Y axis with perspective 0.35, and
    /// the face swaps in at 90 degrees.
    func testFlipIsThreeHundredMillisecondEaseInOutRotationAboutYWithFaceSwapAtNinety() {
        let flip = Motion.flip(reduceMotion: false)

        XCTAssertEqual(flip.durationMilliseconds, 300, "the flip runs for 300 ms")
        XCTAssertEqual(
            flip.animation,
            .easeInOut(duration: 0.300),
            "the flip curve is easeInOut over 0.3 s"
        )
        XCTAssertEqual(flip.style, .rotate, "the flip turns the card over")
        XCTAssertEqual(
            flip.rotationDegrees,
            180,
            accuracy: 0.0001,
            "a face-up card is rotated a half turn"
        )
        XCTAssertEqual(
            flip.axis,
            Axis3D(x: 0, y: 1, z: 0),
            "the card turns about the Y axis"
        )
        XCTAssertEqual(
            flip.perspective,
            0.35,
            accuracy: 0.0001,
            "the rotation has perspective 0.35"
        )
        XCTAssertEqual(
            flip.faceSwapDegrees,
            90,
            accuracy: 0.0001,
            "the two sides change over at 90 degrees"
        )

        // Every whole degree of the half turn: the back shows below 90, the
        // face shows from 90 on.
        for degrees in 0...180 {
            let expected: FlipFacing = degrees < 90 ? .back : .face
            XCTAssertEqual(
                Motion.flipFacing(atDegrees: Double(degrees)),
                expected,
                "at \(degrees) degrees the card shows its \(expected)"
            )
        }
        XCTAssertEqual(
            Motion.flipFacing(atDegrees: 89.99),
            .back,
            "just short of 90 degrees the back still shows"
        )
        XCTAssertEqual(
            Motion.flipFacing(atDegrees: 90),
            .face,
            "at exactly 90 degrees the face takes over"
        )
    }

    // MARK: - Criterion 2: the flip with Reduce Motion

    /// Same 300 ms easeInOut, but a cross-fade: nothing rotates.
    func testFlipWithReduceMotionIsAThreeHundredMillisecondCrossFadeWithNoRotation() {
        let flip = Motion.flip(reduceMotion: true)

        XCTAssertEqual(flip.durationMilliseconds, 300, "still 300 ms")
        XCTAssertEqual(
            flip.animation,
            .easeInOut(duration: 0.300),
            "still easeInOut over 0.3 s"
        )
        XCTAssertEqual(
            flip.style,
            .crossFade,
            "the back fades into the face instead of turning"
        )
        XCTAssertEqual(
            flip.rotationDegrees,
            0,
            accuracy: 0.0001,
            "the rotation angle is held at zero"
        )
    }

    // MARK: - Criterion 3: the match pop

    /// A spring from 1.0 out to 1.12 and back; with Reduce Motion a 240 ms
    /// easeOut that never changes the size.
    func testMatchPopIsASpringToOnePointOneTwoAndFlatUnderReduceMotion() {
        let pop = Motion.matchPop(reduceMotion: false)

        XCTAssertEqual(
            pop.animation,
            .spring(response: 0.38, dampingFraction: 0.55),
            "the pop is a spring, response 0.38, damping fraction 0.55"
        )
        XCTAssertEqual(
            pop.springResponse,
            0.38,
            accuracy: 0.0001,
            "spring response 0.38"
        )
        XCTAssertEqual(
            pop.springDampingFraction,
            0.55,
            accuracy: 0.0001,
            "spring damping fraction 0.55"
        )
        XCTAssertEqual(
            pop.scaleKeyframes.count,
            3,
            "the pop goes out and comes back: three sizes"
        )
        for (index, expected) in [1.0, 1.12, 1.0].enumerated()
        where index < pop.scaleKeyframes.count {
            XCTAssertEqual(
                pop.scaleKeyframes[index],
                CGFloat(expected),
                accuracy: 0.0001,
                "scale step \(index) is \(expected)"
            )
        }

        let reduced = Motion.matchPop(reduceMotion: true)

        XCTAssertEqual(reduced.durationMilliseconds, 240, "240 ms with Reduce Motion")
        XCTAssertEqual(
            reduced.animation,
            .easeOut(duration: 0.240),
            "easeOut over 0.24 s with Reduce Motion"
        )
        for (index, scale) in reduced.scaleKeyframes.enumerated() {
            XCTAssertEqual(
                scale,
                1.0,
                accuracy: 0.0001,
                "scale step \(index) does not change size with Reduce Motion"
            )
        }
    }

    // MARK: - Criterion 4: turn timings ignore Reduce Motion

    /// A match resolves at 300 ms and a mismatch at 1200 ms whether Reduce
    /// Motion is on or off.
    func testTurnTimingsAreThreeHundredAndTwelveHundredWithAndWithoutReduceMotion() {
        for reduceMotion in [false, true] {
            XCTAssertEqual(
                Motion.matchResolveMilliseconds(reduceMotion: reduceMotion),
                300,
                "Reduce Motion \(reduceMotion): a match resolves at 300 ms"
            )
            XCTAssertEqual(
                Motion.mismatchResolveMilliseconds(reduceMotion: reduceMotion),
                1200,
                "Reduce Motion \(reduceMotion): a mismatch resolves at 1200 ms"
            )

            // And the board really runs on those numbers.
            let matchClock = TestClock()
            let matching = freshBoard(matchClock)
            let (first, second) = Self.matchingPair
            matching.tap(first)
            matching.tap(second)

            matchClock.advance(by: 299)
            XCTAssertEqual(
                matching.cards[first].state,
                .faceUp,
                "Reduce Motion \(reduceMotion): at 299 ms the pair is not matched yet"
            )
            matchClock.advance(by: 1)
            XCTAssertEqual(
                matching.cards[first].state,
                .matched,
                "Reduce Motion \(reduceMotion): at 300 ms the first card is matched"
            )
            XCTAssertEqual(
                matching.cards[second].state,
                .matched,
                "Reduce Motion \(reduceMotion): at 300 ms the second card is matched"
            )

            let mismatchClock = TestClock()
            let mismatching = freshBoard(mismatchClock)
            let (left, right) = Self.mismatchedPair
            mismatching.tap(left)
            mismatching.tap(right)

            mismatchClock.advance(by: 1199)
            XCTAssertEqual(
                mismatching.cards[left].state,
                .faceUp,
                "Reduce Motion \(reduceMotion): at 1199 ms the mismatch is still up"
            )
            mismatchClock.advance(by: 1)
            XCTAssertEqual(
                mismatching.cards[left].state,
                .faceDown,
                "Reduce Motion \(reduceMotion): at 1200 ms the first card is down"
            )
            XCTAssertEqual(
                mismatching.cards[right].state,
                .faceDown,
                "Reduce Motion \(reduceMotion): at 1200 ms the second card is down"
            )
        }
    }

    // MARK: - Criterion 5: the match sparkle

    /// Eight dots, 3 pt across, travelling 46 pt over 520 ms.
    func testMatchSparkleEmitsEightThreePointParticlesToFortySixPointsOverFiveTwenty() {
        XCTAssertEqual(MatchSparkleView.particleCount, 8, "exactly 8 particles")
        XCTAssertEqual(
            MatchSparkleView.dotDiameter,
            3,
            accuracy: 0.0001,
            "each particle is a 3 pt dot"
        )
        XCTAssertEqual(
            MatchSparkleView.travelRadius,
            46,
            accuracy: 0.0001,
            "the particles travel 46 pt out"
        )
        XCTAssertEqual(
            MatchSparkleView.durationMilliseconds,
            520,
            "the sparkle lasts 520 ms"
        )

        // Where the eight particles sit at the start, half way, and at the end.
        // Distance from the centre of the card, worked out by hand from the
        // 46 pt radius.
        for (progress, expectedRadius) in [(0.0, 0.0), (0.5, 23.0), (1.0, 46.0)] {
            let offsets = MatchSparkleView.particleOffsets(progress: CGFloat(progress))
            XCTAssertEqual(
                offsets.count,
                8,
                "8 particles at progress \(progress)"
            )
            for (index, offset) in offsets.enumerated() {
                let across = Double(offset.width)
                let down = Double(offset.height)
                let distance = (across * across + down * down).squareRoot()
                XCTAssertEqual(
                    distance,
                    expectedRadius,
                    accuracy: 0.0001,
                    "particle \(index) is \(expectedRadius) pt out at progress \(progress)"
                )
            }
        }

        // The eight go in eight different directions.
        let spread = MatchSparkleView.particleOffsets(progress: 1)
        for (first, one) in spread.enumerated() {
            for (second, other) in spread.enumerated() where second > first {
                let across = Double(one.width) - Double(other.width)
                let down = Double(one.height) - Double(other.height)
                let gap = (across * across + down * down).squareRoot()
                XCTAssertGreaterThan(
                    gap,
                    0.5,
                    "particles \(first) and \(second) travel to different places"
                )
            }
        }
    }

    // MARK: - Criterion 6: when the win overlay appears

    /// Absent for the whole game, then present exactly 600 ms after the last
    /// pair turns matched.
    func testWinOverlayAppearsSixHundredMillisecondsAfterTheFinalPairMatches() {
        let clock = TestClock()
        let session = GameSession(
            seed: 7,
            now: { clock.nowSeconds },
            clock: clock
        )

        for symbol in CardSymbol.allCases {
            let pair = positions(of: symbol, in: session)
            XCTAssertEqual(pair.count, 2, "\(symbol) sits in exactly two positions")

            session.tap(pair[0])
            XCTAssertFalse(
                session.isWinOverlayPresented,
                "no overlay with \(symbol) half turned"
            )

            session.tap(pair[1])
            clock.advance(by: 300)

            XCTAssertEqual(
                session.cards[pair[0]].state,
                .matched,
                "\(symbol) matched at 300 ms"
            )

            if session.cards.contains(where: { $0.state != .matched }) {
                XCTAssertFalse(
                    session.isWinOverlayPresented,
                    "no overlay while cards are still unmatched"
                )
            }
        }

        XCTAssertTrue(
            session.cards.allSatisfy { $0.state == .matched },
            "all 16 cards are matched"
        )
        XCTAssertFalse(
            session.isWinOverlayPresented,
            "the overlay does not appear the instant the last pair matches"
        )

        clock.advance(by: 599)
        XCTAssertFalse(
            session.isWinOverlayPresented,
            "at 599 ms the overlay is still not there"
        )

        clock.advance(by: 1)
        XCTAssertTrue(
            session.isWinOverlayPresented,
            "at 600 ms the overlay is present"
        )
    }

    // MARK: - Criterion 7: what the win overlay shows, and Play Again

    /// The final move count and the final time, and a Play Again that deals
    /// 16 face-down cards with no moves on them.
    func testWinOverlayShowsFinalStatsAndPlayAgainDealsAFreshBoard() {
        let clock = TestClock()
        let session = GameSession(
            seed: 7,
            now: { clock.nowSeconds },
            clock: clock
        )

        // Eight pairs, each one taking a whole second: 700 ms of thinking
        // between the two taps, then the 300 ms match. The clock starts on
        // the first tap, so the game ends at exactly 8.000 s and 8 moves.
        for symbol in CardSymbol.allCases {
            let pair = positions(of: symbol, in: session)
            session.tap(pair[0])
            clock.advance(by: 700)
            session.tap(pair[1])
            clock.advance(by: 300)
        }
        clock.advance(by: 600)

        XCTAssertTrue(session.isWinOverlayPresented, "the game is won and shown")
        XCTAssertEqual(session.moveCount, 8, "eight pairs is eight moves")
        XCTAssertEqual(
            session.elapsed,
            8.0,
            accuracy: 0.0001,
            "the game took 8 seconds of play"
        )

        let overlay = WinOverlayView(
            moveCount: session.moveCount,
            elapsed: session.elapsed,
            playAgain: { session.playAgain() }
        )
        XCTAssertEqual(overlay.moveCountText, "8", "the overlay shows 8 moves")
        XCTAssertEqual(overlay.elapsedText, "0:08", "the overlay shows 0:08")

        // Time running on after the win does not change what is shown.
        clock.advance(by: 5000)
        XCTAssertEqual(
            WinOverlayView(
                moveCount: session.moveCount,
                elapsed: session.elapsed,
                playAgain: {}
            ).elapsedText,
            "0:08",
            "the time on the overlay is the time the game finished in"
        )

        overlay.playAgain()

        XCTAssertEqual(session.cards.count, 16, "Play Again deals 16 cards")
        XCTAssertTrue(
            session.cards.allSatisfy { $0.state == .faceDown },
            "every one of the 16 cards is face down"
        )
        XCTAssertEqual(session.moveCount, 0, "the fresh board has no moves on it")
        XCTAssertFalse(
            session.isWinOverlayPresented,
            "the overlay goes away when the new board is dealt"
        )
    }

    // MARK: - Criterion 8: the confetti

    /// Sixty ribbons over two seconds; with Reduce Motion a 400 ms fade that
    /// neither falls nor spins.
    func testConfettiIsSixtyRibbonsOverTwoSecondsAndAStillFadeUnderReduceMotion() {
        let burst = Motion.confetti(reduceMotion: false)

        XCTAssertEqual(burst.ribbonCount, 60, "60 ribbons")
        XCTAssertEqual(burst.durationMilliseconds, 2000, "over 2000 ms")
        XCTAssertTrue(burst.falls, "the ribbons fall")
        XCTAssertTrue(burst.spins, "the ribbons spin")
        XCTAssertEqual(
            ConfettiView.ribbonCount,
            60,
            "the confetti view draws 60 ribbons"
        )

        let reduced = Motion.confetti(reduceMotion: true)

        XCTAssertEqual(reduced.ribbonCount, 60, "still 60 ribbons")
        XCTAssertEqual(reduced.durationMilliseconds, 400, "400 ms with Reduce Motion")
        XCTAssertEqual(
            reduced.animation,
            .easeOut(duration: 0.400),
            "easeOut over 0.4 s with Reduce Motion"
        )
        XCTAssertFalse(reduced.falls, "nothing falls with Reduce Motion")
        XCTAssertFalse(reduced.spins, "nothing spins with Reduce Motion")
    }

    // MARK: - Criterion 9: the deal

    /// Sixteen cards, each starting 12 ms after the one before, over 260 ms.
    func testDealStaggersSixteenCardsByTwelveMillisecondsInIndexOrder() {
        XCTAssertEqual(Motion.deal.durationMilliseconds, 260, "each card takes 260 ms")
        XCTAssertEqual(
            Motion.deal.animation,
            .easeOut(duration: 0.260),
            "easeOut over 0.26 s"
        )
        XCTAssertEqual(
            Motion.deal.staggerMilliseconds,
            12,
            "12 ms between one card and the next"
        )

        // The sixteen start times, written out: index x 12 ms.
        let expected = [
            0, 12, 24, 36,
            48, 60, 72, 84,
            96, 108, 120, 132,
            144, 156, 168, 180,
        ]
        XCTAssertEqual(expected.count, 16, "one start time per card")

        for (index, delay) in expected.enumerated() {
            XCTAssertEqual(
                Motion.dealDelayMilliseconds(cardIndex: index),
                delay,
                "card \(index) starts at \(delay) ms"
            )
        }
    }

    // MARK: - Criterion 10: the sounds

    /// Three bundled sound files that are really there, played on an ambient
    /// audio session.
    func testThreeSoundEffectsResolveToBundledFilesOnAnAmbientSession() {
        XCTAssertEqual(
            Set(SoundEffect.allCases),
            [.flip, .match, .win],
            "three effects: flip, match and win"
        )

        for effect in [SoundEffect.flip, .match, .win] {
            guard let url = SoundPlayer.url(for: effect) else {
                XCTFail("the \(effect) sound resolves to a file in the bundle")
                continue
            }
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "the \(effect) sound file is really there at \(url.path)"
            )
        }

        XCTAssertEqual(
            SoundPlayer.sessionCategory,
            AVAudioSession.Category.ambient,
            "the audio session is ambient, so it never stops the player's music"
        )
    }
}
