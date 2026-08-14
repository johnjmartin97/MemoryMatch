import SwiftUI

/// One entry in the type scale from `ART.md`: SF Rounded throughout, with
/// monospaced digits wherever a number on screen changes.
struct TextStyle: Equatable {
    var size: CGFloat
    var weight: Font.Weight
    var design: Font.Design = .rounded
    var monospacedDigits: Bool = false

    var font: Font {
        let base = Font.system(size: size, weight: weight, design: design)
        return monospacedDigits ? base.monospacedDigit() : base
    }
}

/// The four type styles, plus the two number styles that reuse them with
/// monospaced digits so the layout never jitters as the values change.
enum Typography {
    static let display = TextStyle(size: 40, weight: .bold)
    static let title = TextStyle(size: 26, weight: .semibold)
    static let body = TextStyle(size: 17, weight: .medium)
    static let caption = TextStyle(size: 13, weight: .semibold)

    static let moveCount = TextStyle(size: 17, weight: .medium, monospacedDigits: true)
    static let timer = TextStyle(size: 17, weight: .medium, monospacedDigits: true)

    /// Tracking on the uppercase caption labels ("MOVES", "TIME").
    static let captionTracking: CGFloat = 0.6
}

/// The spacing scale. Nothing on the game screen sits off it.
enum Spacing {
    static let scale: [CGFloat] = [4, 8, 12, 16, 24, 32]
}
