import SwiftUI

/// What the player sees when the board is cleared: how many moves it took,
/// how long it took, and one way on.
struct WinOverlayView: View {
    let moveCount: Int
    let elapsed: TimeInterval
    let playAgain: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// The final move count, as shown.
    var moveCountText: String { "\(moveCount)" }

    /// The final time, as shown, in minutes and seconds.
    var elapsedText: String { TopBarView.clockText(elapsed) }

    var body: some View {
        ZStack {
            Palette.textPrimary(colorScheme)
                .opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("All matched")
                    .font(Typography.title.font)
                    .foregroundStyle(Palette.accent(colorScheme))

                HStack(spacing: 32) {
                    stat(label: "MOVES", value: moveCountText)
                    stat(label: "TIME", value: elapsedText)
                }

                Button(action: playAgain) {
                    Text("Play Again")
                        .font(Typography.body.font)
                        .foregroundStyle(Palette.surface(colorScheme))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Palette.primary(colorScheme))
                        )
                }
                .accessibilityIdentifier("win.playAgain")
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: Metrics.cornerStyle)
                    .fill(Palette.surface(colorScheme))
            )
            .padding(32)
        }
        .accessibilityIdentifier("win.overlay")
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(Typography.caption.font)
                .tracking(Typography.captionTracking)
                .foregroundStyle(Palette.textMuted(colorScheme))
            Text(value)
                .font(Typography.moveCount.font)
                .foregroundStyle(Palette.textPrimary(colorScheme))
        }
    }
}

#Preview("Win overlay") {
    WinOverlayView(moveCount: 14, elapsed: 96, playAgain: {})
        .background(Palette.backgroundTopLight)
}
