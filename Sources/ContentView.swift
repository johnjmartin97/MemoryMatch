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
    @State private var model = GameModel()

    /// Light or dark. The cards already follow it; the screen must too, or
    /// the two halves of the palette end up on screen at the same time.
    @Environment(\.colorScheme) private var colorScheme

    let screen: RootScreen = .board
    let overlay: BoardOverlay? = nil

    var cards: [Card] { model.cards }

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
                    // Placeholder for the top bar PP-4 brings in; the launch
                    // UI test looks for this title.
                    Text("MemoryMatch")
                        .font(Typography.body.font)
                        .foregroundStyle(Palette.textMuted(colorScheme))
                        .frame(height: Metrics.topBarHeight)
                        .padding(.horizontal, Metrics.topBarSideInset)
                        .accessibilityIdentifier("app.title")

                    BoardView(cards: cards)
                        .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview { ContentView() }
