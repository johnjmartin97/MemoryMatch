import SwiftUI

/// The win celebration: sixty small ribbons that burst upward, spin, and settle
/// under gravity over two seconds behind the win panel.
///
/// This is the one deliberate exception to the "nothing over 400 ms" rule. It
/// is also entirely skippable — it never blocks a tap, so the player can start
/// a new game mid-confetti and miss nothing.
struct ConfettiView: View {
    /// Flip to `true` when the board is solved.
    var isActive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ribbonCount = 60
    private let ribbonSize = CGSize(width: 6, height: 12)
    private let duration: Double = 2.0

    var body: some View {
        GeometryReader { geometry in
            let ribbons = Self.ribbons(count: ribbonCount, in: geometry.size)

            if reduceMotion {
                // Static scatter that fades in over 400 ms: no fall, no spin.
                ZStack {
                    ForEach(ribbons) { ribbon in
                        ribbonShape(ribbon)
                            .rotationEffect(.degrees(ribbon.spin * 90))
                            .position(restingPoint(for: ribbon, in: geometry.size))
                    }
                }
                .opacity(isActive ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: isActive)
            } else if isActive {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        draw(
                            ribbons: ribbons,
                            elapsed: elapsed,
                            in: size,
                            context: &context
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func draw(
        ribbons: [Ribbon],
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        // Anchor the burst to whole seconds so the animation is stable across
        // redraws without needing any stored start date.
        let phase = elapsed.truncatingRemainder(dividingBy: duration)

        for ribbon in ribbons {
            let t = phase
            guard t >= ribbon.delay else { continue }
            let local = t - ribbon.delay
            let life = duration - ribbon.delay
            guard life > 0 else { continue }
            let progress = min(1.0, local / life)

            let point = position(for: ribbon, at: local, in: size)
            let angle = ribbon.spin * local * 6.0
            let fade = progress > 0.7 ? (1.0 - (progress - 0.7) / 0.3) : 1.0

            var layer = context
            layer.opacity = fade
            layer.translateBy(x: point.x, y: point.y)
            layer.rotate(by: .radians(angle))
            layer.fill(
                Path(
                    roundedRect: CGRect(
                        x: -ribbonSize.width / 2,
                        y: -ribbonSize.height / 2,
                        width: ribbonSize.width,
                        height: ribbonSize.height
                    ),
                    cornerRadius: 1.5
                ),
                with: .color(color(for: ribbon))
            )
        }
    }

    /// Burst upward and out, then fall — gravity settles them near the bottom.
    private func position(
        for ribbon: Ribbon,
        at time: TimeInterval,
        in size: CGSize
    ) -> CGPoint {
        let originX = size.width * ribbon.originX
        let originY = size.height * 0.42
        let gravity: CGFloat = 900
        let x = originX + ribbon.velocityX * CGFloat(time)
        let y = originY
            + ribbon.velocityY * CGFloat(time)
            + 0.5 * gravity * CGFloat(time * time)
        return CGPoint(x: x, y: min(y, size.height + 40))
    }

    private func restingPoint(for ribbon: Ribbon, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * ribbon.originX,
            y: size.height * (0.18 + 0.64 * ribbon.restY)
        )
    }

    private func ribbonShape(_ ribbon: Ribbon) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color(for: ribbon))
            .frame(width: ribbonSize.width, height: ribbonSize.height)
    }

    private func color(for ribbon: Ribbon) -> Color {
        switch ribbon.colorIndex {
        case 0: return Palette.secondary(colorScheme)
        case 1: return Palette.accent(colorScheme)
        default: return Palette.primary(colorScheme)
        }
    }

    // MARK: - Ribbons

    struct Ribbon: Identifiable {
        let id: Int
        let originX: CGFloat
        let velocityX: CGFloat
        let velocityY: CGFloat
        let spin: Double
        let delay: TimeInterval
        let colorIndex: Int
        let restY: CGFloat
    }

    /// Deterministic scatter: same layout every win, no stored random state.
    /// A tiny integer hash gives each ribbon its own spread of values.
    private static func ribbons(count: Int, in size: CGSize) -> [Ribbon] {
        (0..<count).map { index in
            Ribbon(
                id: index,
                originX: 0.18 + 0.64 * noise(index, 1),
                velocityX: (noise(index, 2) - 0.5) * 520,
                velocityY: -260 - noise(index, 3) * 420,
                spin: (noise(index, 4) - 0.5) * 4.0,
                delay: Double(noise(index, 5)) * 0.18,
                colorIndex: index % 3,
                restY: noise(index, 6)
            )
        }
    }

    /// A cheap deterministic value in 0...1 from an index and a salt.
    private static func noise(_ index: Int, _ salt: Int) -> CGFloat {
        var value = UInt64(bitPattern: Int64(index &* 73_856_093 &+ salt &* 19_349_663))
        value ^= value >> 33
        value = value &* 0xFF51_AFD7_ED55_8CCD
        value ^= value >> 33
        return CGFloat(value % 10_000) / 10_000.0
    }
}

#Preview("Confetti") {
    ConfettiView(isActive: true)
        .frame(width: 390, height: 640)
        .background(Palette.backgroundTopLight)
}
