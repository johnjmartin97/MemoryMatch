import SwiftUI

/// Which screen the app is showing. The game opens straight on the board:
/// no splash, no menu.
enum RootScreen: Equatable {
    case splash, menu, board
}

/// Anything laid over the board. Nothing at launch.
enum BoardOverlay: Equatable {
    case win
}

struct ContentView: View {
    @State private var session: GameSession

    /// Light or dark. The cards already follow it; the screen must too, or
    /// the two halves of the palette end up on screen at the same time.
    @Environment(\.colorScheme) private var colorScheme

    let screen: RootScreen = .board

    var overlay: BoardOverlay? { session.isWinOverlayPresented ? .win : nil }

    var cards: [Card] { session.cards }

    init(session: GameSession = GameSession()) {
        _session = State(initialValue: session)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = BoardLayout.boardSize(
                availableWidth: geometry.size.width,
                availableHeight: geometry.size.height
            )

            ZStack {
                Palette.backgroundGradient(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: Metrics.topBarStackSpacing) {
                    // The timer ticks once a second; nothing else on the bar
                    // needs a schedule.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        TopBarView(
                            moveCount: session.moveCount,
                            elapsed: session.elapsed,
                            restart: { session.restart() }
                        )
                    }

                    BoardView(
                        cards: cards,
                        dealID: session.dealID,
                        tap: { session.tap($0) }
                    )
                    .frame(width: size.width, height: size.height)
                }

                if session.isWon {
                    ConfettiView(isActive: true)
                }

                if overlay == .win {
                    WinOverlayView(
                        moveCount: session.moveCount,
                        elapsed: session.elapsed,
                        playAgain: { session.playAgain() }
                    )
                    .transition(.opacity)
                }
            }
            .animation(
                Motion.flip(reduceMotion: false).animation,
                value: session.isWinOverlayPresented
            )
            .onChange(of: session.isWinOverlayPresented) { _, presented in
                guard presented else { return }
                SoundPlayer.shared.play(.win)
                Haptics.win()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .confirmationDialog(
            "Start a new game?",
            isPresented: Binding(
                get: { session.isRestartConfirmationRequested },
                set: { if !$0 { session.cancelRestart() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restart", role: .destructive) { session.confirmRestart() }
            Button("Keep playing", role: .cancel) { session.cancelRestart() }
        } message: {
            Text("This clears the pairs you have already matched.")
        }
    }
}

#Preview { ContentView() }
