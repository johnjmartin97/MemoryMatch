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

    private let particleCount = 8
    private let dotDiameter: CGFloat = 3
    private let travel: CGFloat = 46
    private let duration: Double = 0.520

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                let angle = Angle.degrees(Double(index) / Double(particleCount) * 360.0)
                Circle()
                    .fill(Palette.success(colorScheme))
                    .frame(width: dotDiameter, height: dotDiameter)
                    .offset(
                        x: cos(angle.radians) * travel * progress,
                        y: sin(angle.radians) * travel * progress
                    )
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
                withAnimation(.easeOut(duration: 0.240)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: duration)) { progress = 1 }
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
                guard matched, !reduceMotion else {
                    scale = 1.0
                    return
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                    scale = 1.12
                }
                // Settle back on the same spring so the two halves match.
                withAnimation(
                    .spring(response: 0.38, dampingFraction: 0.55).delay(0.19)
                ) {
                    scale = 1.0
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
