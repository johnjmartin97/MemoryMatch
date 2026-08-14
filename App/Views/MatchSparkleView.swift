import SwiftUI

/// The match celebration: eight small dots that travel outward from the centre
/// of a matched card and fade, over 520 ms.
///
/// Warm and brief. Nothing here blocks input — the board unlocks as soon as the
/// pair resolves, and the sparkle finishes on its own after that.
struct MatchSparkleView: View {
    /// Drives the animation. Flip it to `true` when the pair matches.
    var isActive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let particleCount = 8
    static let dotDiameter: CGFloat = 3
    static let travelRadius: CGFloat = 46
    static let durationMilliseconds = 520

    /// Where the eight dots sit at a given point in the sparkle: evenly
    /// spread around the centre, `travelRadius` out at the end.
    static func particleOffsets(progress: CGFloat) -> [CGSize] {
        let distance = travelRadius * progress
        return (0..<particleCount).map { index in
            let angle = Double(index) / Double(particleCount) * 2 * .pi
            return CGSize(
                width: CGFloat(cos(angle)) * distance,
                height: CGFloat(sin(angle)) * distance
            )
        }
    }

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            let offsets = Self.particleOffsets(progress: progress)
            ForEach(offsets.indices, id: \.self) { index in
                Circle()
                    .fill(Palette.success(colorScheme))
                    .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                    .offset(x: offsets[index].width, y: offsets[index].height)
                    .opacity(Double(1 - progress))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isActive) { _, active in
            guard active else {
                progress = 0
                return
            }
            progress = 0
            if reduceMotion {
                // No travel: the dots simply bloom and fade in place.
                withAnimation(Motion.matchPop(reduceMotion: true).animation) { progress = 1 }
            } else {
                withAnimation(
                    .easeOut(duration: Double(Self.durationMilliseconds) / 1000)
                ) { progress = 1 }
            }
        }
    }
}

/// The pop a matched card makes: scale 1.0 → 1.12 → 1.0 on a spring over
/// 380 ms, with the sparkle riding on top. Reduce Motion keeps the veil
/// settling but drops the scale entirely.
struct MatchPopModifier: ViewModifier {
    var isMatched: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay { MatchSparkleView(isActive: isMatched) }
            .onChange(of: isMatched) { _, matched in
                let pop = Motion.matchPop(reduceMotion: reduceMotion)
                guard matched, pop.scaleKeyframes.contains(where: { $0 != 1.0 }) else {
                    scale = 1.0
                    return
                }
                withAnimation(pop.animation) { scale = pop.scaleKeyframes[1] }
                // Settle back on the same spring so the two halves match.
                withAnimation(pop.animation.delay(Double(pop.durationMilliseconds) / 2000)) {
                    scale = pop.scaleKeyframes[2]
                }
            }
    }
}

extension View {
    /// Plays the match pop and sparkle when `isMatched` becomes true.
    func matchPop(isMatched: Bool) -> some View {
        modifier(MatchPopModifier(isMatched: isMatched))
    }
}

private struct MatchSparklePreview: View {
    @State private var matched = false

    var body: some View {
        VStack(spacing: 32) {
            CardFaceView(symbol: .leaf, isMatched: matched)
                .frame(width: 96, height: 96)
                .matchPop(isMatched: matched)
            Button(matched ? "Reset" : "Match") { matched.toggle() }
        }
        .padding(32)
        .background(Palette.backgroundTopLight)
    }
}

#Preview("Sparkle") {
    MatchSparklePreview()
}
