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

    /// The moment of the win. Everything on screen is measured from it.
    @State private var burstStartedAt: Date?
    /// True once the ribbons have come to rest.
    @State private var hasSettled = false
    /// The wait for the end of the burst, held so a second win can replace it.
    @State private var settle: Task<Void, Never>?

    static let ribbonCount = Motion.confetti(reduceMotion: false).ribbonCount

    private let ribbonSize = CGSize(width: 6, height: 12)

    /// How long the burst lasts, in seconds.
    static let duration = Double(Motion.confetti(reduceMotion: false).durationMilliseconds) / 1000

    var body: some View {
        GeometryReader { geometry in
            let ribbons = Self.ribbons(count: Self.ribbonCount, in: geometry.size)

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
                .animation(Motion.confetti(reduceMotion: true).animation, value: isActive)
            } else if isActive, let burstStartedAt, !hasSettled {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(
                            Self.drawnRibbons(
                                now: timeline.date,
                                burstStartedAt: burstStartedAt,
                                in: size
                            ),
                            context: &context
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { startBurst() }
        .onChange(of: isActive) { _, active in
            if active { startBurst() }
        }
    }

    /// Marks the moment of the win, and takes the canvas away again once the
    /// two seconds are up so nothing keeps redrawing behind the win panel.
    private func startBurst() {
        guard isActive, !reduceMotion else { return }
        settle?.cancel()
        burstStartedAt = Date()
        hasSettled = false
        settle = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hasSettled = true
        }
    }

    // MARK: - Drawing

    /// One ribbon as it appears in a single frame.
    struct DrawnRibbon: Equatable {
        let id: Int
        let position: CGPoint
        let radians: Double
        let opacity: Double
    }

    /// Every ribbon on screen at `now`, for a burst that began at
    /// `burstStartedAt`. Empty once the burst has settled.
    static func drawnRibbons(
        now: Date,
        burstStartedAt: Date,
        in size: CGSize
    ) -> [DrawnRibbon] {
        // Time is measured from the win itself, so the burst always starts at
        // its beginning and, once it has settled, stays settled.
        let elapsed = now.timeIntervalSince(burstStartedAt)
        guard isBurstRunning(now: now, burstStartedAt: burstStartedAt) else { return [] }

        return ribbons(count: ribbonCount, in: size).compactMap { ribbon -> DrawnRibbon? in
            guard elapsed >= ribbon.delay else { return nil }
            let local = elapsed - ribbon.delay
            let life = duration - ribbon.delay
            guard life > 0 else { return nil }
            let progress = min(1.0, local / life)

            return DrawnRibbon(
                id: ribbon.id,
                position: position(for: ribbon, at: local, in: size),
                radians: ribbon.spin * local * 6.0,
                opacity: progress > 0.7 ? (1.0 - (progress - 0.7) / 0.3) : 1.0
            )
        }
    }

    /// True while the burst still has something to draw. It runs once: after
    /// two seconds the ribbons have settled and nothing is redrawn again.
    static func isBurstRunning(now: Date, burstStartedAt: Date) -> Bool {
        let elapsed = now.timeIntervalSince(burstStartedAt)
        return elapsed >= 0 && elapsed < duration
    }

    private func draw(_ drawn: [DrawnRibbon], context: inout GraphicsContext) {
        for ribbon in drawn {
            var layer = context
            layer.opacity = ribbon.opacity
            layer.translateBy(x: ribbon.position.x, y: ribbon.position.y)
            layer.rotate(by: .radians(ribbon.radians))
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
                with: .color(colorFor(ribbon.id))
            )
        }
    }

    /// Burst upward and out, then fall — gravity settles them near the bottom.
    private static func position(
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
        colorFor(ribbon.id)
    }

    /// Ribbons take the three palette colours in turn.
    private func colorFor(_ ribbonID: Int) -> Color {
        switch ribbonID % 3 {
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
