import SwiftUI

/// The bar above the board: moves on the left, time in the middle, the
/// restart control on the right.
struct TopBarView: View {
    let moveCount: Int
    let elapsed: TimeInterval
    let restart: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            counter(
                label: "MOVES",
                value: "\(moveCount)",
                style: Typography.moveCount,
                tint: Palette.secondary(colorScheme)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            counter(
                label: "TIME",
                value: TopBarView.clockText(elapsed),
                style: Typography.timer,
                tint: Palette.textPrimary(colorScheme)
            )
            // The launch UI test looks for this element by identifier.
            .accessibilityIdentifier("app.title")

            Button(action: restart) {
                Image(systemName: "arrow.clockwise")
                    .font(Typography.body.font)
                    .foregroundStyle(Palette.primary(colorScheme))
                    .frame(
                        width: Metrics.restartHitTarget.width,
                        height: Metrics.restartHitTarget.height
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Restart")
            .accessibilityIdentifier("board.restart")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: Metrics.topBarHeight)
        .padding(.horizontal, Metrics.topBarSideInset)
    }

    /// Minutes and seconds, e.g. `2:07`. Monospaced digits keep it still.
    static func clockText(_ elapsed: TimeInterval) -> String {
        let whole = Int(elapsed)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func counter(
        label: String,
        value: String,
        style: TextStyle,
        tint: Color
    ) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(Typography.caption.font)
                .tracking(Typography.captionTracking)
                .foregroundStyle(Palette.textMuted(colorScheme))
            Text(value)
                .font(style.font)
                .foregroundStyle(tint)
        }
    }
}

#Preview("Top bar") {
    TopBarView(moveCount: 12, elapsed: 127, restart: {})
        .background(Palette.backgroundTopLight)
}
