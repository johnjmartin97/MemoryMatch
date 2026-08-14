import SwiftUI
import XCTest
@testable import MemoryMatch

/// The Reduce Motion confetti fade.
///
/// The existing PP-6 test reads the numbers out of `Motion.confetti`. This one
/// drives the state the view's opacity actually comes from, because numbers
/// nothing on screen uses do not fade anything in.
final class ConfettiFadeTests: XCTestCase {

    /// The win puts the confetti on screen with `isActive` already `true` and
    /// never changing. So the fade cannot hang off `isActive`: on the first
    /// frame the ribbons have to be invisible, and something that changes has
    /// to carry them to full strength.
    func testTheRibbonsStartInvisibleAndFadeToFull() {
        var fade = ConfettiFadeState()

        XCTAssertEqual(
            fade.opacity,
            0,
            "the ribbons are not on screen in the frame the win arrives"
        )

        let seconds = fade.begin(isActive: true)

        XCTAssertEqual(
            seconds,
            0.400,
            "the fade takes the 400 ms Reduce Motion asks for"
        )
        XCTAssertEqual(
            fade.opacity,
            0,
            "and it still starts from invisible once it has begun"
        )

        fade.complete()

        XCTAssertEqual(fade.opacity, 1, "the ribbons end up fully on screen")
    }

    /// The value the fade is animated against has to actually change, or
    /// SwiftUI has nothing to animate and the ribbons snap on in one frame.
    func testTheFadeIsDrivenByAValueThatChanges() {
        var fade = ConfettiFadeState()
        let before = fade

        _ = fade.begin(isActive: true)
        fade.complete()

        XCTAssertNotEqual(
            before.opacity,
            fade.opacity,
            "the opacity moves, so the 400 ms easeOut has something to run on"
        )
        XCTAssertEqual(
            ConfettiFadeState.animation,
            .easeOut(duration: 0.400),
            "and it moves on the Reduce Motion curve"
        )
    }

    /// Nothing shows before the win, and the fade does not restart itself on
    /// every pass through the body.
    func testTheFadeWaitsForTheWinAndThenRunsOnce() {
        var fade = ConfettiFadeState()

        XCTAssertNil(fade.begin(isActive: false), "no win yet, nothing to fade")
        XCTAssertEqual(fade.opacity, 0, "and nothing on screen")

        XCTAssertEqual(fade.begin(isActive: true), 0.400, "the win starts the fade")
        fade.complete()

        XCTAssertNil(
            fade.begin(isActive: true),
            "the ribbons stay put instead of fading in again"
        )
        XCTAssertEqual(fade.opacity, 1, "and stay on screen")
    }
}
