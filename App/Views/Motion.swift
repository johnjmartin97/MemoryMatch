import SwiftUI

/// Which side of a card is showing part-way through a flip.
enum FlipFacing: Equatable {
    case back, face
}

/// The axis a rotation turns about.
struct Axis3D: Equatable {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
}

/// How a card changes sides: turning over, or fading across in place.
enum FlipStyle: Equatable {
    case rotate, crossFade
}

/// Everything the flip needs, already resolved for the Reduce Motion setting.
struct FlipMotion: Equatable {
    var durationMilliseconds: Int
    var style: FlipStyle
    var rotationDegrees: Double
    var axis: Axis3D
    var perspective: Double
    var faceSwapDegrees: Double

    var animation: Animation { .easeInOut(duration: Double(durationMilliseconds) / 1000) }
}

/// The pop a matched card makes.
struct PopMotion {
    var durationMilliseconds: Int
    var animation: Animation
    var springResponse: Double
    var springDampingFraction: Double
    /// The sizes the card passes through, in order.
    var scaleKeyframes: [CGFloat]
}

/// The win burst.
struct ConfettiMotion {
    var ribbonCount: Int
    var durationMilliseconds: Int
    var falls: Bool
    var spins: Bool

    var animation: Animation { .easeOut(duration: Double(durationMilliseconds) / 1000) }
}

/// How the sixteen cards arrive.
struct DealMotion {
    var durationMilliseconds: Int
    var staggerMilliseconds: Int

    var animation: Animation { .easeOut(duration: Double(durationMilliseconds) / 1000) }
}

/// Every timing and curve the game moves on, in one place, so the numbers can
/// be read without rendering anything.
///
/// Reduce Motion changes how a thing moves, never how long the player waits:
/// the turn timings below are the same either way.
enum Motion {
    /// Turning a card over. With Reduce Motion the two sides cross-fade
    /// instead, and nothing rotates.
    static func flip(reduceMotion: Bool) -> FlipMotion {
        FlipMotion(
            durationMilliseconds: 300,
            style: reduceMotion ? .crossFade : .rotate,
            rotationDegrees: reduceMotion ? 0 : 180,
            axis: Axis3D(x: 0, y: 1, z: 0),
            perspective: 0.35,
            faceSwapDegrees: 90
        )
    }

    /// Which side shows part-way through a flip: the back up to the half
    /// turn, the face from there on.
    static func flipFacing(atDegrees degrees: Double) -> FlipFacing {
        degrees < flip(reduceMotion: false).faceSwapDegrees ? .back : .face
    }

    /// The matched-pair pop. With Reduce Motion the size never changes.
    static func matchPop(reduceMotion: Bool) -> PopMotion {
        guard !reduceMotion else {
            return PopMotion(
                durationMilliseconds: 240,
                animation: .easeOut(duration: 0.240),
                springResponse: 0,
                springDampingFraction: 0,
                scaleKeyframes: [1.0, 1.0, 1.0]
            )
        }
        return PopMotion(
            durationMilliseconds: 380,
            animation: .spring(response: 0.38, dampingFraction: 0.55),
            springResponse: 0.38,
            springDampingFraction: 0.55,
            scaleKeyframes: [1.0, 1.12, 1.0]
        )
    }

    /// The win burst. With Reduce Motion the ribbons simply fade in where
    /// they land.
    static func confetti(reduceMotion: Bool) -> ConfettiMotion {
        ConfettiMotion(
            ribbonCount: 60,
            durationMilliseconds: reduceMotion ? 400 : 2000,
            falls: !reduceMotion,
            spins: !reduceMotion
        )
    }

    /// Dealing the board.
    static let deal = DealMotion(durationMilliseconds: 260, staggerMilliseconds: 12)

    /// When the card at `cardIndex` starts arriving.
    static func dealDelayMilliseconds(cardIndex: Int) -> Int {
        cardIndex * deal.staggerMilliseconds
    }

    /// How long a matched pair stays face up before it is judged.
    static func matchResolveMilliseconds(reduceMotion: Bool) -> Int { 300 }

    /// How long a mismatched pair is on show before it turns back down.
    static func mismatchResolveMilliseconds(reduceMotion: Bool) -> Int { 1200 }

    /// The pause between the last pair matching and the win overlay.
    static let winOverlayDelayMilliseconds = 600
}
